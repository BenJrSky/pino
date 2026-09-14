import SwiftUI
#if os(iOS)
import UserNotifications
#endif

@main
struct PinoApp: App {
    private let environment = AppEnvironment.shared
#if os(iOS)
    private let notifications = ArrivalNotifications()
#endif

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(environment.store)
                .environmentObject(environment.location)
                .environmentObject(environment.settings)
                .environmentObject(environment)
                .preferredColorScheme(.dark)
                .onAppear {
#if os(iOS)
                    UNUserNotificationCenter.current().delegate = notifications
#endif
                    environment.start()
                }
        }
    }
}
