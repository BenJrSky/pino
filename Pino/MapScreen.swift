import SwiftUI

struct MapScreen: View {
    @EnvironmentObject private var store: PinStore
    @State private var findPin: Pin?

    var body: some View {
        NavigationStack {
            SaveMapScreen(findPin: $findPin)
                .toolbarTitleDisplayMode(.inline)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    if let pin = store.lastPin {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                findPin = pin
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
