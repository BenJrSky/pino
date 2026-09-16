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
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(environment.store)
                .environmentObject(environment.location)
                .environmentObject(environment.settings)
                .environmentObject(environment)
                .preferredColorScheme(.dark)
                .onOpenURL { environment.handle($0) }
                .onAppear {
#if os(iOS)
                    UNUserNotificationCenter.current().delegate = notifications
#endif
                    environment.start()
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
#if os(iOS)
                    environment.store.pullCloud()
#endif
                }
        }
    }
}
