import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Keep pins", selection: $settings.retention) {
                        ForEach(RetentionPeriod.allCases) { period in
                            Text(period.label).tag(period)
                        }
                    }
                } footer: {
                    Text("Pins older than the selected period are deleted automatically. Choose Forever to keep them all.")
                }

                Section {
                    Toggle("Proximity alerts", isOn: $settings.proximityAlerts)
                } footer: {
                    Text("PINO can remind you when you are near a saved pin again.")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
