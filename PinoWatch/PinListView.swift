import SwiftUI

struct PinListView: View {
    @EnvironmentObject private var store: PinStore
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var editPin: Pin?

    var body: some View {
        List {
            ForEach(store.pins) { pin in
                HStack(spacing: 4) {
                    Button {
                        environment.find(pin)
                        dismiss()
                    } label: {
                        HStack {
                            SavedPinMark(category: pin.category, skinTone: pin.skinTone ?? .none, diameter: 22)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(pin.displayName)
                                    .lineLimit(1)
                                if let distance = location.distance(to: pin) {
                                    Text(Formatters.distance(distance))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(pin.displayName)
                    .accessibilityHint("Find")

                    TravelModeButton(pin: pin)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        editPin = pin
                    } label: {
                        Label("Details", systemImage: "pencil")
                    }
                    .tint(Color.pino)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        store.delete(pin)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("Pins")
        .navigationDestination(item: $editPin) { pin in
            PinEditView(pin: pin)
        }
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
