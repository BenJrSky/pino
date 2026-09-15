import SwiftUI

struct PinsScreen: View {
    @EnvironmentObject private var store: PinStore
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var environment: AppEnvironment
    @State private var query = ""
    @State private var detailPin: Pin?

    private var pins: [Pin] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return store.pins }
        return store.pins.filter { pin in
            pin.displayName.localizedCaseInsensitiveContains(q)
                || (pin.address?.localizedCaseInsensitiveContains(q) ?? false)
                || (pin.category?.label.localizedCaseInsensitiveContains(q) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.pins.isEmpty {
                    ContentUnavailableView {
                        Label {
                            Text("A pin.\nAnd you're back.")
                                .multilineTextAlignment(.center)
                        } icon: {
                            Image(systemName: "mappin.and.ellipse")
                        }
                    } description: {
                        Text("Tap the map.")
                    }
                } else {
                    List {
                        ForEach(pins) { pin in
                            HStack(spacing: 8) {
                                Button {
                                    detailPin = pin
                                } label: {
                                    HStack(spacing: 12) {
                                        SavedPinMark(category: pin.category, skinTone: pin.skinTone ?? .none, diameter: 32)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(pin.displayName)
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                            if let address = pin.address, !address.isEmpty {
                                                Text(address)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            } else if let distance = location.distance(to: pin) {
                                                Text(Formatters.distance(distance))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(pin.displayName)

                                TravelModeButton(pin: pin)

                                Button {
                                    environment.find(pin)
                                } label: {
                                    Image(systemName: "location.north.fill")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Find")
                            }
                            .swipeActions(edge: .leading) {
                                ShareLink(item: pin.mapsURL) {
                                    Label("Share", systemImage: "square.and.arrow.up")
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
                }
            }
            .navigationTitle("Pins")
            .navigationDestination(item: $detailPin) { pin in
                PinDetailView(pin: pin)
            }
            .searchable(text: $query, prompt: "Search")
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
}
