import MapKit

enum PinoDirections {
    static func route(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async -> MKRoute? {
        if let walking = await calculate(from: from, to: to, type: .walking) {
            return walking
        }
        return await calculate(from: from, to: to, type: .automobile)
    }

    private static func calculate(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        type: MKDirectionsTransportType
    ) async -> MKRoute? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = type
        request.requestsAlternateRoutes = false
        return await withCheckedContinuation { continuation in
            MKDirections(request: request).calculate { response, _ in
                continuation.resume(returning: response?.routes.first)
            }
        }
    }
}
