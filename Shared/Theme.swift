import MapKit
import SwiftUI
#if os(iOS)
import UIKit
#endif

extension Color {
    static let pino = Color(red: 52 / 255, green: 199 / 255, blue: 89 / 255)
    static let route = Color(red: 0.0, green: 0.48, blue: 1.0)
}

enum PinoMaps {
    static func region(containing coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard let first = coordinates.first else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 39.223, longitude: 9.122),
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        }
        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude
        for coordinate in coordinates.dropFirst() {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(
                latitudeDelta: max((maxLat - minLat) * 1.9, 0.0035),
                longitudeDelta: max((maxLon - minLon) * 1.9, 0.0035)
            )
        )
    }

    static func userCamera(_ coordinate: CLLocationCoordinate2D) -> MapCameraPosition {
#if os(watchOS)
        let delta = 0.0026
#else
        let delta = 0.004
#endif
        return .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta)
        ))
    }

    static func camera(for route: MKRoute) -> MapCameraPosition {
        var rect = route.polyline.boundingMapRect
        let pad = max(rect.size.width, rect.size.height) * 0.25
        rect = rect.insetBy(dx: -pad, dy: -pad)
        return .rect(rect)
    }

    static func overview(user: CLLocationCoordinate2D, pin: CLLocationCoordinate2D, route: MKRoute?) -> MapCameraPosition {
        if let route {
            return camera(for: route)
        }
        return .region(region(containing: [user, pin]))
    }

    static func followUser(_ user: CLLocation, compass: Double?, route: MKRoute? = nil) -> MapCameraPosition {
        if let route, let snap = PinoWayfinding.snap(from: user.coordinate, onto: route), snap.offset < 40 {
            return streetCamera(snap)
        }
        let facing = PinoWayfinding.travelHeading(from: user, compass: compass) ?? 0
        return .camera(MapCamera(
            centerCoordinate: user.coordinate,
            distance: 52,
            heading: facing,
            pitch: 48
        ))
    }

    static func streetCamera(_ snap: PinoWayfinding.Snap) -> MapCameraPosition {
        .camera(MapCamera(
            centerCoordinate: snap.coordinate,
            distance: 46,
            heading: snap.heading,
            pitch: 50
        ))
    }
}

enum PinoWayfinding {
    struct Snap {
        var coordinate: CLLocationCoordinate2D
        var heading: Double
        var offset: CLLocationDistance
    }

    static func coordinates(of route: MKRoute) -> [CLLocationCoordinate2D] {
        let count = route.polyline.pointCount
        guard count > 0 else { return [] }
        var coords = Array(repeating: kCLLocationCoordinate2DInvalid, count: count)
        route.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: count))
        return coords.filter { $0.latitude.isFinite }
    }

    static func snap(from user: CLLocationCoordinate2D, onto route: MKRoute) -> Snap? {
        let coords = coordinates(of: route)
        guard coords.count > 1 else { return nil }
        var best = Snap(coordinate: coords[0], heading: GeoMath.bearing(from: coords[0], to: coords[1]), offset: .greatestFiniteMagnitude)
        for index in 0..<(coords.count - 1) {
            let a = coords[index]
            let b = coords[index + 1]
            let point = GeoMath.project(user, onto: a, b)
            let offset = GeoMath.distance(from: user, to: point)
            if offset < best.offset {
                best = Snap(coordinate: point, heading: GeoMath.bearing(from: a, to: b), offset: offset)
            }
        }
        return best
    }

    static func lookAhead(
        from user: CLLocationCoordinate2D,
        to pin: CLLocationCoordinate2D,
        route: MKRoute?
    ) -> CLLocationCoordinate2D {
        guard let route else { return pin }
        let coords = coordinates(of: route)
        guard coords.count > 1 else { return pin }
        let origin = snap(from: user, onto: route)?.coordinate ?? user
        for coordinate in coords {
            if GeoMath.distance(from: origin, to: coordinate) > 18 {
                return coordinate
            }
        }
        return pin
    }

    static func travelHeading(from user: CLLocation, compass: Double?) -> Double? {
        if user.speed >= 0.5, user.course >= 0 {
            return user.course
        }
#if os(watchOS)
        return nil
#else
        if let compass { return compass }
        if user.course >= 0 { return user.course }
        return nil
#endif
    }

    static func relativeDelta(
        from user: CLLocation,
        to target: CLLocationCoordinate2D,
        heading: Double?
    ) -> Double? {
        guard let facing = travelHeading(from: user, compass: heading) else { return nil }
        var delta = GeoMath.bearing(from: user.coordinate, to: target) - facing
        while delta > 180 { delta -= 360 }
        while delta < -180 { delta += 360 }
        return delta
    }

    static func edge(for delta: Double) -> Edge {
        let magnitude = abs(delta)
        if magnitude <= 45 { return .top }
        if magnitude >= 135 { return .bottom }
        return delta > 0 ? .trailing : .leading
    }

    static func hasArrived(user: CLLocation, pin: Pin) -> Bool {
        let accuracy = user.horizontalAccuracy
        guard accuracy > 0, accuracy < 35 else { return false }
        let meters = GeoMath.distance(from: user.coordinate, to: pin.coordinate)
        return meters <= 10 && meters + accuracy / 2 <= 18
    }

    static func isHere(user: CLLocation?, pin: Pin, finding: Pin?) -> Bool {
        guard let user, finding?.id == pin.id else { return false }
        return hasArrived(user: user, pin: pin)
    }

    static func spokenCue(delta: Double) -> String {
        let magnitude = abs(delta)
        if magnitude <= 35 { return String(localized: "Straight ahead") }
        if magnitude >= 135 { return String(localized: "Turn around") }
        return delta > 0 ? String(localized: "Turn right") : String(localized: "Turn left")
    }

    static func upcomingStep(in route: MKRoute, from user: CLLocationCoordinate2D) -> (instruction: String, remaining: CLLocationDistance)? {
        let steps = route.steps
        guard !steps.isEmpty else { return nil }
        var bestIndex = 0
        var bestDist = CLLocationDistance.greatestFiniteMagnitude
        for (index, step) in steps.enumerated() {
            let count = step.polyline.pointCount
            guard count > 0 else { continue }
            var coords = Array(repeating: kCLLocationCoordinate2DInvalid, count: count)
            step.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: count))
            for coordinate in coords where coordinate.latitude.isFinite {
                let distance = GeoMath.distance(from: user, to: coordinate)
                if distance < bestDist {
                    bestDist = distance
                    bestIndex = index
                }
            }
        }
        var index = bestIndex
        if let finish = end(of: steps[index]), GeoMath.distance(from: user, to: finish) < 18, index + 1 < steps.count {
            index += 1
        }
        let step = steps[index]
        let instruction = step.instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !instruction.isEmpty else { return nil }
        let remaining = end(of: step).map { GeoMath.distance(from: user, to: $0) } ?? step.distance
        return (instruction, remaining)
    }

    private static func end(of step: MKRoute.Step) -> CLLocationCoordinate2D? {
        let count = step.polyline.pointCount
        guard count > 0 else { return nil }
        var coords = Array(repeating: kCLLocationCoordinate2DInvalid, count: count)
        step.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: count))
        return coords.last
    }
}

struct SavedPinMark: View {
    var category: PinCategory?
    var skinTone: SkinTone = .none
    var diameter: CGFloat = 28
    var here: Bool = false

    var body: some View {
        Text(category?.emoji(tone: skinTone) ?? "📍")
            .font(.system(size: diameter * (here ? 0.4 : 0.52)))
            .frame(width: diameter, height: diameter)
            .background {
                Image(systemName: here ? "star.fill" : "circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(here ? Color(red: 1, green: 0.76, blue: 0.12) : Color.pino)
                    .frame(width: here ? diameter * 1.22 : diameter, height: here ? diameter * 1.22 : diameter)
            }
            .accessibilityLabel(here ? String(localized: "Here") : (category?.label ?? ""))
    }
}

struct OnRoutePuck: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 16, height: 16)
            Circle()
                .fill(Color.pino)
                .frame(width: 11, height: 11)
        }
        .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
        .accessibilityLabel("You")
    }
}

struct MapSaveHint: View {
    var body: some View {
        Text("Tap to save")
#if os(watchOS)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
#else
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
#endif
            .foregroundStyle(.white)
            .background(.black.opacity(0.55), in: Capsule())
    }
}

struct PinoChrome {
#if os(watchOS)
    static let size: CGFloat = 24
    static let button: CGFloat = 32
#else
    static let size: CGFloat = 28
    static let button: CGFloat = 36
#endif
}

struct MapCircleButton: View {
    var systemName: String
    var action: () -> Void
    var label: String
    var value: String? = nil

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: PinoChrome.button * 0.4, weight: .semibold))
                .frame(width: PinoChrome.button, height: PinoChrome.button)
                .foregroundStyle(.black.opacity(0.7))
                .background(.white.opacity(0.92), in: Circle())
#if os(iOS)
                .shadow(color: .black.opacity(0.16), radius: 4, y: 1)
#endif
        }
        .buttonStyle(.plain)
        .frame(width: 44, height: 44, alignment: .bottom)
        .contentShape(Rectangle())
        .accessibilityLabel(label)
        .accessibilityValue(value ?? "")
    }
}

extension View {
    @ViewBuilder
    func pinoMapTap(_ enabled: Bool, perform action: @escaping () -> Void) -> some View {
        if enabled {
#if os(watchOS)
            self.onTapGesture(perform: action)
#else
            self.simultaneousGesture(TapGesture().onEnded(action))
#endif
        } else {
            self
        }
    }
}

extension View {
    func mapGestures(onFind: @escaping () -> Void, onEdit: @escaping () -> Void) -> some View {
        padding(12)
            .contentShape(Circle())
            .onTapGesture(perform: onFind)
            .onLongPressGesture(minimumDuration: 0.45, perform: onEdit)
    }
}

extension View {
    @ViewBuilder
    func pinoMapStyle() -> some View {
#if os(watchOS)
        if #available(watchOS 11.0, *) {
            self.mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
                .environment(\.colorScheme, .light)
                .preferredColorScheme(.light)
        } else {
            self.mapStyle(.standard(pointsOfInterest: .excludingAll, showsTraffic: false))
                .environment(\.colorScheme, .light)
                .preferredColorScheme(.light)
        }
#else
        if #available(iOS 18.0, *) {
            self.mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
                .environment(\.colorScheme, .light)
        } else {
            self.mapStyle(.standard(pointsOfInterest: .excludingAll, showsTraffic: false))
                .environment(\.colorScheme, .light)
        }
#endif
    }
}

struct GuidanceButton: View {
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        MapCircleButton(
            systemName: settings.guidance ? "speaker.wave.2.fill" : "speaker.slash.fill",
            action: {
                settings.guidance.toggle()
                if settings.guidance {
                    PinoHaptics.click()
                } else {
                    VoiceGuide.stop()
                }
            },
            label: "Voice and vibration",
            value: settings.guidance ? "On" : "Off"
        )
    }
}

struct StopFindButton: View {
    let action: () -> Void

    var body: some View {
        MapCircleButton(
            systemName: "xmark",
            action: action,
            label: "Stop"
        )
    }
}

struct LocationDeniedHint: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Location access is off. Turn it on in Settings.")
                .multilineTextAlignment(.center)
#if os(iOS)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.subheadline.weight(.semibold))
#endif
        }
#if os(watchOS)
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
#else
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
#endif
        .foregroundStyle(.white)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.top, 72)
        .padding(.horizontal, 16)
    }
}

struct TravelModeButton: View {
    let pin: Pin
    @EnvironmentObject private var store: PinStore

    private var live: Pin {
        store.pins.first(where: { $0.id == pin.id }) ?? pin
    }

    var body: some View {
        Button(action: cycle) {
            Image(systemName: live.routeMode.symbol)
#if os(watchOS)
                .font(.caption.weight(.semibold))
                .frame(width: 28, height: 28)
#else
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
#endif
                .foregroundStyle(.white)
                .contentShape(Rectangle())
        }
#if os(watchOS)
        .buttonStyle(.plain)
#else
        .buttonStyle(.borderless)
#endif
        .accessibilityLabel(live.routeMode.label)
        .accessibilityHint("Travel mode")
    }

    private func cycle() {
        var updated = live
        updated.travelMode = live.routeMode.next
        store.update(updated)
        PinoHaptics.click()
    }
}
