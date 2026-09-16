import MapKit
import SwiftUI

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
#if os(watchOS)
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
#else
        return userCamera(user.coordinate)
#endif
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

    var body: some View {
        Text(category?.emoji(tone: skinTone) ?? "📍")
            .font(.system(size: diameter * 0.52))
            .frame(width: diameter, height: diameter)
            .background(Color.pino, in: Circle())
            .accessibilityLabel(category?.label ?? "")
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
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
#else
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
#endif
            .foregroundStyle(.white)
            .background(.black.opacity(0.55), in: Capsule())
            .padding(.top, 72)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

extension View {
    func mapGestures(onFind: @escaping () -> Void, onEdit: @escaping () -> Void) -> some View {
        padding(12)
            .contentShape(Circle())
            .highPriorityGesture(TapGesture(count: 2).onEnded(onEdit))
            .onTapGesture(perform: onFind)
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
        Button {
            settings.guidance.toggle()
            if settings.guidance {
                PinoHaptics.click()
            } else {
                VoiceGuide.stop()
            }
        } label: {
            Image(systemName: settings.guidance ? "speaker.wave.2.fill" : "speaker.slash.fill")
#if os(watchOS)
                .font(.caption.weight(.semibold))
                .frame(width: 32, height: 32)
#else
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
#endif
                .foregroundStyle(.black.opacity(0.7))
                .background(.white.opacity(0.92), in: Circle())
                .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .accessibilityLabel("Voice and vibration")
        .accessibilityValue(settings.guidance ? "On" : "Off")
    }
}

struct RecenterButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "location.fill")
#if os(watchOS)
                .font(.caption.weight(.semibold))
                .frame(width: 32, height: 32)
#else
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
#endif
                .foregroundStyle(.black.opacity(0.7))
                .background(.white.opacity(0.92), in: Circle())
                .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .accessibilityLabel("My location")
    }
}

struct TravelModeButton: View {
    let pin: Pin
    @EnvironmentObject private var store: PinStore

    var body: some View {
        Button {
            var updated = pin
            updated.travelMode = pin.routeMode.next
            store.update(updated)
            PinoHaptics.click()
        } label: {
            Image(systemName: pin.routeMode.symbol)
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
        .accessibilityLabel(pin.routeMode.label)
        .accessibilityHint("Travel mode")
    }
}
