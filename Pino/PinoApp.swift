import SwiftUI

@main
struct PinoApp: App {
    private let environment = AppEnvironment.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(environment.store)
                .environmentObject(environment.location)
                .environmentObject(environment.settings)
                .environmentObject(environment)
                .preferredColorScheme(.dark)
                .onAppear { environment.start() }
        }
    }
}
