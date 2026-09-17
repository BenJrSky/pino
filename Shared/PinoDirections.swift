@preconcurrency import MapKit

enum PinoDirections {
    nonisolated static func route(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        mode: TravelMode
    ) async -> MKRoute? {
        await calculate(from: from, to: to, type: transportType(mode))
    }

    nonisolated private static func transportType(_ mode: TravelMode) -> MKDirectionsTransportType {
        switch mode {
        case .walking: .walking
        case .automobile: .automobile
        case .transit: .transit
        }
    }

    nonisolated private static func calculate(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        type: MKDirectionsTransportType
    ) async -> MKRoute? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = type
        request.requestsAlternateRoutes = false
        if type == .automobile {
            request.departureDate = Date()
        }
        let timeout: TimeInterval = type == .walking ? 3.5 : 8
        let directions = MKDirections(request: request)
        return await withCheckedContinuation { continuation in
            let once = Once(continuation)
            directions.calculate { response, _ in
                once.resume(response?.routes.first)
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                directions.cancel()
                once.resume(nil)
            }
        }
    }
}

nonisolated private final class Once<Value>: @unchecked Sendable {
    private var continuation: CheckedContinuation<Value, Never>?
    private let lock = NSLock()

    init(_ continuation: CheckedContinuation<Value, Never>) {
        self.continuation = continuation
    }

    func resume(_ value: Value) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(returning: value)
    }
}
