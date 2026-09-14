import SwiftUI

struct PinListView: View {
    @EnvironmentObject private var store: PinStore
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(store.pins) { pin in
                Button {
                    environment.find(pin)
                    dismiss()
                } label: {
                    HStack {
                        SavedPinMark(category: pin.category, diameter: 22)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(pin.displayName)
                                .lineLimit(1)
                            if let distance = location.distance(to: pin) {
                                Text(Formatters.distance(distance))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        store.delete(pin)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .accessibilityLabel(pin.displayName)
                .accessibilityHint("Find")
            }
        }
        .navigationTitle("Pins")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ManualPinView()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add pin")
            }
        }
    }
}
