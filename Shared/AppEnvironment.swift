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
        pinsWatch = store.$pins
            .sink { [weak self] pins in
                self?.dropMissingFind(pins)
            }
#if DEBUG
        applyScreenshotLaunchArgs()
#endif
    }

#if DEBUG
    private func applyScreenshotLaunchArgs() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-pino-tab-pins") {
            selectedTab = 1
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                showPinsList = true
            }
        } else if args.contains("-pino-tab-settings") {
            selectedTab = 2
        }
        if args.contains("-pino-find"), let pin = store.pins.first {
            findPin = pin
            selectedTab = 0
        }
    }
#endif

    @Published var findPin: Pin?
    @Published var arrivedPin: Pin?
    @Published var showPinsList = false
    @Published var selectedTab = 0

    private var announcedNearby: Set<UUID> = []
    private var locationWatch: AnyCancellable?
    private var pinsWatch: AnyCancellable?

    func find(_ pin: Pin) {
        findPin = pin
        selectedTab = 0
    }

    func stopFind() {
        guard findPin != nil else {
            VoiceGuide.stop()
            return
        }
        findPin = nil
        announcedNearby.removeAll()
        VoiceGuide.stop()
    }

    func savePin(category: PinCategory) async throws -> Pin {
        let current = try await location.requestLocation()
        let pin = Pin.make(location: current, category: category, skinTone: settings.skinTone)
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
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedAddress.isEmpty, coordinate == nil {
            var pin = try await savePin(category: category ?? .place)
            if !trimmedName.isEmpty {
                pin.name = trimmedName
                store.update(pin)
            }
            return pin
        }
        let hit: AddressHit
        if let coordinate {
            hit = AddressHit(title: trimmedAddress, subtitle: "", coordinate: coordinate)
        } else if let found = await ForwardGeocoder.lookup(trimmedAddress, near: location.location) {
            hit = found
        } else {
            throw PinSaveError.addressNotFound
        }
        var pin = Pin.make(
            location: CLLocation(latitude: hit.coordinate.latitude, longitude: hit.coordinate.longitude),
            category: category,
            skinTone: settings.skinTone
        )
        pin.name = trimmedName.isEmpty ? nil : trimmedName
        pin.address = hit.line.isEmpty ? Formatters.coordinate(hit.coordinate) : hit.line
        store.add(pin)
        return pin
    }

    private func dropMissingFind(_ pins: [Pin]) {
        guard let id = findPin?.id else { return }
        if pins.contains(where: { $0.id == id }) { return }
        stopFind()
    }

    private func checkArrival(at user: CLLocation) {
        guard let pin = findPin else { return }
        guard let live = store.pins.first(where: { $0.id == pin.id }) else {
            dropMissingFind(store.pins)
            return
        }
        if PinoWayfinding.hasArrived(user: user, pin: live) {
            guard !announcedNearby.contains(live.id) else { return }
            announcedNearby.insert(live.id)
            if settings.guidance {
                PinoHaptics.arrived()
            }
            return
        }
        let here = CLLocation(latitude: live.latitude, longitude: live.longitude)
        if user.distance(from: here) > 80 {
            announcedNearby.remove(live.id)
        }
    }

#if os(iOS)
    func refreshProximity() {
        proximity.update(pins: store.pins, enabled: settings.proximityAlerts)
    }
#endif
}
