#if os(iOS)
import AVFoundation
import CoreLocation
import Foundation
import UserNotifications

enum CarParkNotifications {
    static let category = "pino.park"
    static let save = "pino.park.save"
    static let request = "pino.park.offer"
}

final class CarParkMonitor {
    private var lastWasCar = false
    private var lastOffer = Date.distantPast
    private var observer: NSObjectProtocol?

    func start() {
        registerCategory()
        if AppEnvironment.shared.settings.suggestParking {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
        lastWasCar = Self.isCar(AVAudioSession.sharedInstance().currentRoute)
        observer = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.routeChanged()
        }
    }

    private func routeChanged() {
        let nowCar = Self.isCar(AVAudioSession.sharedInstance().currentRoute)
        let leftCar = lastWasCar && !nowCar
        lastWasCar = nowCar
        guard leftCar else { return }
        offer()
    }

    private func offer() {
        let environment = AppEnvironment.shared
        guard environment.settings.suggestParking else { return }
        guard Date().timeIntervalSince(lastOffer) > 12 * 60 else { return }
        if let last = environment.store.lastPin, last.category == .car,
           let here = environment.location.location {
            let pinLocation = CLLocation(latitude: last.latitude, longitude: last.longitude)
            if here.distance(from: pinLocation) < 80 { return }
        }
        lastOffer = Date()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { ok, _ in
            guard ok else { return }
            let content = UNMutableNotificationContent()
            content.title = "PinO"
            content.body = String(localized: "Save this parking spot?")
            content.sound = .default
            content.categoryIdentifier = CarParkNotifications.category
            let request = UNNotificationRequest(
                identifier: CarParkNotifications.request,
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    private func registerCategory() {
        let save = UNNotificationAction(
            identifier: CarParkNotifications.save,
            title: String(localized: "Save car"),
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: CarParkNotifications.category,
            actions: [save],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    private static func isCar(_ route: AVAudioSessionRouteDescription) -> Bool {
        route.outputs.contains { $0.portType == .carAudio }
    }
}
#endif
