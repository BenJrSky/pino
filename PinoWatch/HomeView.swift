import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: PinStore
    @State private var findPin: Pin?

    var body: some View {
        NavigationStack {
            SaveMapScreen(findPin: $findPin)
                .toolbarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    if let pin = store.lastPin {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                findPin = pin
                            } label: {
                                Image(systemName: "location.north.line.fill")
                            }
                            .accessibilityLabel("Find")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            PinListView()
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                        .disabled(store.pins.isEmpty)
                        .accessibilityLabel("History")
                    }
                }
        }
    }
}
