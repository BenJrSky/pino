import MapKit
import SwiftUI

struct PinDetailView: View {
    let pin: Pin
    @EnvironmentObject private var store: PinStore
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var category: PinCategory?
    @State private var confirmDelete = false

    init(pin: Pin) {
        self.pin = pin
        _name = State(initialValue: pin.name ?? "")
        _category = State(initialValue: pin.category)
    }

    private var current: Pin {
        store.pins.first(where: { $0.id == pin.id }) ?? pin
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: current.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.006, longitudeDelta: 0.006)
                ))) {
                    Annotation("", coordinate: current.coordinate) {
                        SavedPinMark(category: current.category, skinTone: current.skinTone ?? .none)
                    }
                    UserAnnotation()
                }
                .pinoMapStyle()
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                if let distance = location.distance(to: current) {
                    Text(Formatters.distance(distance))
                        .font(.largeTitle.weight(.bold))
                }

                TextField("Name", text: $name)
                    .textInputAutocapitalization(.sentences)
                    .padding(12)
                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                CategoryPicker(selection: $category)
                    .id(pin.id)

                VStack(alignment: .leading, spacing: 4) {
                    if let address = current.address {
                        Text(address)
                    }
                    Text(Formatters.date.string(from: current.createdAt))
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)

                Button {
                    environment.find(current)
                } label: {
                    Label("Find", systemImage: "location.north.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)

                ShareLink(item: current.mapsURL) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)

                Button("Delete pin", role: .destructive) {
                    confirmDelete = true
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .navigationTitle(current.symbol)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete this pin?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                store.delete(current)
                dismiss()
            }
        }
        .onAppear {
            if current.category?.takesSkinTone == true {
                environment.settings.skinTone = current.skinTone ?? .none
            }
        }
        .onChange(of: name) { _, _ in save() }
        .onDisappear(perform: save)
        .onChange(of: environment.settings.skinTone) { _, _ in save() }
    }

    private func save() {
        var updated = current
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.name = trimmed.isEmpty ? nil : trimmed
        updated.category = category
        updated.skinTone = category?.takesSkinTone == true ? environment.settings.skinTone : nil
        if updated != current {
            store.update(updated)
        }
    }
}
