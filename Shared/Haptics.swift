import Foundation
#if os(watchOS)
import WatchKit
#endif
#if os(iOS)
import AudioToolbox
import UIKit
#endif

enum PinoHaptics {
    static func click() {
#if os(watchOS)
        WKInterfaceDevice.current().play(.click)
#endif
#if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
    }

    static func success() {
#if os(watchOS)
        WKInterfaceDevice.current().play(.success)
#endif
#if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
#endif
    }

    static func failure() {
#if os(watchOS)
        WKInterfaceDevice.current().play(.failure)
#endif
#if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
#endif
    }

    static func wrongWay() {
#if os(watchOS)
        WKInterfaceDevice.current().play(.retry)
#endif
#if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
#endif
    }

    static func arrived() {
#if os(watchOS)
        WKInterfaceDevice.current().play(.notification)
#endif
#if os(iOS)
        AudioServicesPlayAlertSound(1007)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
#endif
    }
}
