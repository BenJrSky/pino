import SwiftUI

struct HistoryScreen: View {
    @EnvironmentObject private var store: PinStore
    @EnvironmentObject private var location: LocationService

    var body: some View {
        NavigationStack {
            Group {
                if store.pins.isEmpty {
                    ContentUnavailableView(
                        "Pin it. Find it.",
                        systemImage: "mappin.and.ellipse",
                        description: Text("Tap the map to save a pin.")
                    )
                } else {
                    List {
                        ForEach(store.pins) { pin in
                            NavigationLink {
                                PinDetailView(pin: pin)
                            } label: {
                                HStack(spacing: 12) {
                                    SavedPinMark(category: pin.category, diameter: 32)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(Formatters.date.string(from: pin.createdAt))
                                            .font(.headline)
                                        if let distance = location.distance(to: pin) {
                                            Text(Formatters.distance(distance))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .onDelete { indexSet in
                            indexSet.map { store.pins[$0] }.forEach(store.delete)
                        }
                    }
                }
            }
            .navigationTitle("History")
        }
    }
}
