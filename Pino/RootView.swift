import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: PinStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        TabView {
            MapScreen()
                .tabItem { Label("Map", systemImage: "map.fill") }
            HistoryScreen()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            SettingsScreen()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .onChange(of: store.pins) { _, _ in environment.refreshProximity() }
        .onChange(of: settings.proximityAlerts) { _, _ in environment.refreshProximity() }
        .onChange(of: settings.retention) { _, _ in store.prune() }
    }
}
