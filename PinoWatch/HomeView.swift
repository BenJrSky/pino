import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: PinStore
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-pino-tab-pins") {
            NavigationStack {
                PinListView()
            }
        } else {
            mapStack
        }
#else
        mapStack
#endif
    }

    private var mapStack: some View {
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
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if let pin = store.lastPin {
                            Button {
                                environment.find(pin)
                            } label: {
                                SavedPinMark(
                                    category: pin.category,
                                    skinTone: pin.skinTone ?? .none,
                                    diameter: PinoChrome.size
                                )
                            }
                            .accessibilityLabel("Find")
                        }
                        NavigationLink {
                            PinListView()
                        } label: {
                            Image(systemName: "mappin")
                                .font(.system(size: PinoChrome.size * 0.42, weight: .semibold))
                                .frame(width: PinoChrome.size, height: PinoChrome.size)
                                .symbolRenderingMode(.monochrome)
                        }
                        .disabled(store.pins.isEmpty)
                        .accessibilityLabel("Pins")
                    }
                }
                .navigationDestination(isPresented: $environment.showPinsList) {
                    PinListView()
                }
        }
    }
}
