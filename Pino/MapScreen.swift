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
                        }
                        .accessibilityLabel("Add pin")
                    }
                    if let pin = store.lastPin {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                environment.find(pin)
                            } label: {
                                Image(systemName: "location.north.line.fill")
                            }
                            .accessibilityLabel("Find")
                        }
                    }
                }
        }
    }
}
