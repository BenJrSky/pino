import MapKit
import SwiftUI

struct PinDetailView: View {
    let pin: Pin
    @EnvironmentObject private var store: PinStore
    @EnvironmentObject private var location: LocationService
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
                        SavedPinMark(category: current.category)
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

                VStack(alignment: .leading, spacing: 4) {
                    if let address = current.address {
                        Text(address)
                    }
                    Text(Formatters.date.string(from: current.createdAt))
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)

                NavigationLink {
                    FindView(pin: current, showsManagement: false)
                } label: {
                    Label("Find", systemImage: "location.north.line.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)

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
        .onChange(of: name) { _, _ in save() }
        .onChange(of: category) { _, _ in save() }
    }

    private func save() {
        var updated = current
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.name = trimmed.isEmpty ? nil : trimmed
        updated.category = category
        if updated != current {
            store.update(updated)
        }
    }
}
