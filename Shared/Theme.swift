import MapKit
import SwiftUI

extension Color {
    static let pino = Color(red: 0.17, green: 0.52, blue: 0.35)
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

    static func camera(for route: MKRoute) -> MapCameraPosition {
        var rect = route.polyline.boundingMapRect
        let pad = max(rect.size.width, rect.size.height) * 0.25
        rect = rect.insetBy(dx: -pad, dy: -pad)
        return .rect(rect)
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
}

struct SavedPinMark: View {
    var category: PinCategory?
    var diameter: CGFloat = 28

    var body: some View {
        Text(category?.emoji ?? "📍")
            .font(.system(size: diameter * 0.52))
            .frame(width: diameter, height: diameter)
            .background(Color.pino, in: Circle())
            .accessibilityLabel(category?.label ?? "")
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
        if #available(iOS 18.0, watchOS 11.0, *) {
            self.mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        } else {
            self.mapStyle(.standard(pointsOfInterest: .excludingAll, showsTraffic: false))
        }
    }
}
