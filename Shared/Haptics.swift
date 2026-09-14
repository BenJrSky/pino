import Foundation
#if os(watchOS)
import WatchKit
#endif
#if os(iOS)
import UIKit
#endif

enum PinoHaptics {
    static func click() {
#if os(watchOS)
        WKInterfaceDevice.current().play(.click)
#elseif os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
    }

    static func success() {
#if os(watchOS)
        WKInterfaceDevice.current().play(.success)
#elseif os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
#endif
    }

    static func failure() {
#if os(watchOS)
        WKInterfaceDevice.current().play(.failure)
#elseif os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
#endif
    }
}
