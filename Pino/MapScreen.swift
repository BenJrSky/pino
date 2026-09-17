import SwiftUI

struct MapScreen: View {
    @EnvironmentObject private var store: PinStore
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        NavigationStack {
            SaveMapScreen(findPin: $environment.findPin)
                .toolbarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink {
                            ManualPinView()
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: PinoChrome.size * 0.42, weight: .semibold))
                                .frame(width: PinoChrome.size, height: PinoChrome.size)
                        }
                        .accessibilityLabel("Add pin")
                    }
                    if let pin = environment.findPin ?? store.lastPin {
                        ToolbarItem(placement: .topBarTrailing) {
                            FindToolbarButton(pin: pin, finding: environment.findPin != nil) {
                                environment.find(pin)
                            }
                        }
                    }
                }
        }
    }
}
