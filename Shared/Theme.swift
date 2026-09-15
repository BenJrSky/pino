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

    static func firstPerson(user: CLLocation, heading: Double?) -> MapCameraPosition {
        let facing = heading ?? (user.course >= 0 ? user.course : 0)
        let look = ahead(from: user.coordinate, heading: facing, meters: 18)
#if os(watchOS)
        let distance: CLLocationDistance = 90
        let pitch: Double = 55
#else
        let distance: CLLocationDistance = 120
        let pitch: Double = 68
#endif
        return .camera(MapCamera(
            centerCoordinate: look,
            distance: distance,
            heading: facing,
            pitch: pitch
        ))
    }

    static func ahead(from: CLLocationCoordinate2D, heading: Double, meters: CLLocationDistance) -> CLLocationCoordinate2D {
        let radians = heading * .pi / 180
        let north = meters * cos(radians) / 111_320
        let east = meters * sin(radians) / (111_320 * max(cos(from.latitude * .pi / 180), 0.01))
        return CLLocationCoordinate2D(latitude: from.latitude + north, longitude: from.longitude + east)
    }
}

enum PinoWayfinding {
    static func lookAhead(
        from user: CLLocationCoordinate2D,
        to pin: CLLocationCoordinate2D,
        route: MKRoute?
    ) -> CLLocationCoordinate2D {
        guard let route else { return pin }
        let count = route.polyline.pointCount
        guard count > 1 else { return pin }
        var coords = Array(repeating: kCLLocationCoordinate2DInvalid, count: count)
        route.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: count))
        for coordinate in coords where coordinate.latitude.isFinite {
            if GeoMath.distance(from: user, to: coordinate) > 28 {
                return coordinate
            }
        }
        return pin
    }

    static func relativeDelta(
        from user: CLLocation,
        to target: CLLocationCoordinate2D,
        heading: Double?
    ) -> Double? {
        let facing: Double
        if let heading {
            facing = heading
        } else if user.course >= 0 {
            facing = user.course
        } else {
            return nil
        }
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
