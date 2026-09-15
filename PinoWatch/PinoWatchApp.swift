import SwiftUI

@main
struct PinoWatchApp: App {
    private let environment = AppEnvironment.shared

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(environment)
                .environmentObject(environment.store)
                .environmentObject(environment.location)
                .environmentObject(environment.settings)
                .onOpenURL { environment.handle($0) }
                .onAppear { environment.start() }
        }
    }
}
