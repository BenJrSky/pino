import Combine
import CoreLocation
import MapKit

enum LocationError: LocalizedError {
    case denied
    case unavailable

    var errorDescription: String? {
        switch self {
        case .denied:
            String(localized: "Location access is off. Turn it on in Settings.")
        case .unavailable:
            String(localized: "Location unavailable.")
        }
    }
}

final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation?
    @Published var heading: CLHeading?
    @Published var status: CLAuthorizationStatus

    private let manager = CLLocationManager()
    private var waiters: [UUID: CheckedContinuation<CLLocation, Error>] = [:]

    override init() {
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 4
        manager.headingFilter = 2
        status = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    var currentHeading: Double? {
        guard let heading else { return nil }
        let value = heading.trueHeading >= 0 ? heading.trueHeading : heading.magneticHeading
        return value >= 0 ? value : nil
    }

    func requestAccess() {
        manager.requestWhenInUseAuthorization()
    }

    func start() {
        if status == .notDetermined {
            requestAccess()
        }
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    func distance(to pin: Pin) -> CLLocationDistance? {
        guard let location else { return nil }
        return GeoMath.distance(from: location.coordinate, to: pin.coordinate)
    }

    func requestLocation() async throws -> CLLocation {
        if status == .denied || status == .restricted {
            throw LocationError.denied
        }
        if status == .notDetermined {
            requestAccess()
        }
        start()
        if let location {
            return location
        }

        let id = UUID()
        return try await withCheckedThrowingContinuation { continuation in
            waiters[id] = continuation
            Task {
                try? await Task.sleep(for: .seconds(8))
                finishWaiter(id, with: .unavailable)
            }
        }
    }

    private func finishWaiter(_ id: UUID, with error: LocationError) {
        guard let continuation = waiters.removeValue(forKey: id) else { return }
        if let location {
            continuation.resume(returning: location)
        } else {
            continuation.resume(throwing: error)
        }
    }

    private func resumeWaiters(_ result: Result<CLLocation, Error>) {
        let pending = waiters
        waiters.removeAll()
        for continuation in pending.values {
            continuation.resume(with: result)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.status = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.location = location
            resumeWaiters(.success(location))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            if let location {
                resumeWaiters(.success(location))
            } else {
                resumeWaiters(.failure(LocationError.unavailable))
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        Task { @MainActor in
            heading = newHeading
        }
    }
}

enum PinSaveError: LocalizedError {
    case addressNotFound

    var errorDescription: String? {
        String(localized: "Address not found")
    }
}

struct AddressHit: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D

    var line: String {
        if subtitle.isEmpty { return title }
        if title.isEmpty { return subtitle }
        return "\(title), \(subtitle)"
    }
}

enum PinoTimeout {
    nonisolated static func value<T: Sendable>(_ seconds: TimeInterval, _ work: @escaping @Sendable () async -> T?) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            group.addTask { await work() }
            group.addTask {
                try? await Task.sleep(for: .seconds(seconds))
                return nil
            }
            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }
}

enum ReverseGeocoder {
    nonisolated static func address(for coordinate: CLLocationCoordinate2D) async -> String? {
        await PinoTimeout.value(3) {
            let placemarks = try? await CLGeocoder().reverseGeocodeLocation(
                CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            )
            guard let placemark = placemarks?.first else { return nil }
            return format(placemark)
        }
    }

    nonisolated static func format(_ placemark: CLPlacemark) -> String? {
        if let street = placemark.thoroughfare {
            let number = placemark.subThoroughfare.map { " \($0)" } ?? ""
            let city = placemark.locality.map { ", \($0)" } ?? ""
            return "\(street)\(number)\(city)"
        }
        let joined = [placemark.name, placemark.locality].compactMap { $0 }.joined(separator: ", ")
        return joined.isEmpty ? nil : joined
    }
}

enum ForwardGeocoder {
    nonisolated static func suggest(_ query: String, near: CLLocation?) async -> [AddressHit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { return [] }
        return await PinoTimeout.value(2.5) {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = trimmed
            request.resultTypes = [.address, .pointOfInterest]
            if let near {
                request.region = MKCoordinateRegion(
                    center: near.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.4, longitudeDelta: 0.4)
                )
            }
            guard let response = try? await MKLocalSearch(request: request).start() else { return [] }
            return response.mapItems.prefix(8).map { item in
                AddressHit(
                    title: item.name ?? "",
                    subtitle: item.placemark.title ?? ReverseGeocoder.format(item.placemark) ?? "",
                    coordinate: item.placemark.coordinate
                )
            }
        } ?? []
    }

    nonisolated static func lookup(_ query: String, near: CLLocation?) async -> AddressHit? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let first = await suggest(trimmed, near: near).first {
            return first
        }
        return await PinoTimeout.value(3) {
            let placemarks = try? await CLGeocoder().geocodeAddressString(trimmed)
            guard let placemark = placemarks?.first, let location = placemark.location else { return nil }
            return AddressHit(
                title: ReverseGeocoder.format(placemark) ?? trimmed,
                subtitle: "",
                coordinate: location.coordinate
            )
        }
    }
}
