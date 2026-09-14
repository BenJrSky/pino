#if os(iOS)
import Combine
import CoreLocation
import UserNotifications

final class ProximityMonitor: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var names: [String: String] = [:]

    override init() {
        super.init()
        manager.delegate = self
        manager.pausesLocationUpdatesAutomatically = true
    }

    func update(pins: [Pin], enabled: Bool) {
        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }
        guard enabled else { return }
        manager.requestAlwaysAuthorization()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        if manager.authorizationStatus == .authorizedAlways {
            manager.allowsBackgroundLocationUpdates = true
        }
        names = Dictionary(uniqueKeysWithValues: pins.map { ($0.id.uuidString, $0.displayName) })
        for pin in pins.prefix(20) {
            let region = CLCircularRegion(center: pin.coordinate, radius: 80, identifier: pin.id.uuidString)
            region.notifyOnEntry = true
            region.notifyOnExit = false
            manager.startMonitoring(for: region)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task { @MainActor in
            let name = names[region.identifier] ?? String(localized: "a pin")
            let content = UNMutableNotificationContent()
            content.title = "PINO"
            content.body = String(format: String(localized: "You're near %@."), name)
            content.userInfo = ["pinId": region.identifier]
            content.sound = .default
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            try? await UNUserNotificationCenter.current().add(request)
        }
    }
}

final class ArrivalNotifications: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let raw = response.notification.request.content.userInfo["pinId"] as? String,
              let id = UUID(uuidString: raw),
              let pin = AppEnvironment.shared.store.pins.first(where: { $0.id == id })
        else { return }
        await MainActor.run {
            AppEnvironment.shared.find(pin)
        }
    }
}
#endif
