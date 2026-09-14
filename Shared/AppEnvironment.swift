import Combine
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
        location.requestAccess()
        location.start()
        store.prune()
#if os(iOS)
        refreshProximity()
#endif
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

#if os(iOS)
    func refreshProximity() {
        proximity.update(pins: store.pins, enabled: settings.proximityAlerts)
    }
#endif
}
