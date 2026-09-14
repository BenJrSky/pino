import SwiftUI

struct PinListView: View {
    @EnvironmentObject private var store: PinStore
    @EnvironmentObject private var location: LocationService

    var body: some View {
        List {
            ForEach(store.pins) { pin in
                NavigationLink {
                    FindView(pin: pin)
                } label: {
                    HStack {
                        SavedPinMark(category: pin.category, diameter: 22)
                        if let distance = location.distance(to: pin) {
                            Text(Formatters.distance(distance))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onDelete { indexSet in
                indexSet.map { store.pins[$0] }.forEach(store.delete)
            }
        }
        .navigationTitle("History")
    }
}
