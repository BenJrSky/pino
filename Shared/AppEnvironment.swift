import Combine
import CoreLocation
import Foundation

final class AppEnvironment: ObservableObject {
    static let shared = AppEnvironment()

    let settings: SettingsStore
    let store: PinStore
    let location: LocationService
#if os(iOS)
    let proximity: ProximityMonitor
#endif

    private init() {
        let settings = SettingsStore()
        self.settings = settings
        store = PinStore(settings: settings)
        location = LocationService()
#if os(iOS)
        proximity = ProximityMonitor()
#endif
    }

    func start() {
        selectedTab = 0
        arrivedPin = nil
        showPinsList = false
        findPin = nil
        location.requestAccess()
        location.start()
        store.prune()
#if os(iOS)
        refreshProximity()
#endif
        locationWatch = location.$location
            .compactMap { $0 }
            .sink { [weak self] value in
                self?.checkArrival(at: value)
            }
    }

    @Published var findPin: Pin?
    @Published var arrivedPin: Pin?
    @Published var showPinsList = false
    @Published var selectedTab = 0

    private var announcedNearby: Set<UUID> = []
    private var locationWatch: AnyCancellable?

    func find(_ pin: Pin) {
        findPin = pin
        selectedTab = 0
    }

    func savePin(category: PinCategory) async throws -> Pin {
        let current = try await location.requestLocation()
        let pin = Pin.make(location: current, category: category)
        store.add(pin)
        Task {
            guard let address = await ReverseGeocoder.address(for: pin.coordinate) else { return }
            var updated = store.pins.first(where: { $0.id == pin.id }) ?? pin
            updated.address = address
            store.update(updated)
        }
        return pin
    }

    func saveManualPin(name: String, address: String, category: PinCategory?, at coordinate: CLLocationCoordinate2D? = nil) async throws -> Pin {
        let hit: AddressHit
        if let coordinate {
            hit = AddressHit(title: address, subtitle: "", coordinate: coordinate)
        } else if let found = await ForwardGeocoder.lookup(address, near: location.location) {
            hit = found
        } else {
            throw PinSaveError.addressNotFound
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var pin = Pin.make(
            location: CLLocation(latitude: hit.coordinate.latitude, longitude: hit.coordinate.longitude),
            category: category
        )
        pin.name = trimmed.isEmpty ? nil : trimmed
        pin.address = hit.line
        store.add(pin)
        return pin
    }

    private func checkArrival(at user: CLLocation) {
        guard user.horizontalAccuracy > 0, user.horizontalAccuracy < 75 else { return }
        let arrive: CLLocationDistance = 35
        let leave: CLLocationDistance = 80
        var closest: Pin?
        var closestDistance = arrive
        for pin in store.pins {
            let here = CLLocation(latitude: pin.latitude, longitude: pin.longitude)
            let distance = user.distance(from: here)
            if distance > leave {
                announcedNearby.remove(pin.id)
                continue
            }
            if Date().timeIntervalSince(pin.createdAt) < 90 { continue }
            if distance <= arrive, !announcedNearby.contains(pin.id), distance <= closestDistance {
                closest = pin
                closestDistance = distance
            }
        }
        guard let closest else { return }
        announcedNearby.insert(closest.id)
        find(closest)
        PinoHaptics.arrived()
    }

#if os(iOS)
    func refreshProximity() {
        proximity.update(pins: store.pins, enabled: settings.proximityAlerts)
    }
#endif
}
