import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: PinStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        TabView(selection: $environment.selectedTab) {
            MapScreen()
                .tabItem {
                    Image(systemName: "map.fill")
                        .accessibilityLabel("Map")
                }
                .tag(0)
            PinsScreen()
                .tabItem {
                    Image(systemName: "mappin")
                        .accessibilityLabel("Pins")
                }
                .tag(1)
            SettingsScreen()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                        .accessibilityLabel("Settings")
                }
                .tag(2)
        }
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-pino-tab-") }) { return }
            environment.selectedTab = 0
        }
        .onChange(of: store.pins) { _, _ in environment.refreshProximity() }
        .onChange(of: settings.proximityAlerts) { _, _ in environment.refreshProximity() }
        .onChange(of: settings.retention) { _, _ in store.prune() }
    }
}
