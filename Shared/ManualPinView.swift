import SwiftUI

struct ManualPinView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var location: LocationService
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var address = ""
    @State private var category: PinCategory = .place
    @State private var suggestions: [AddressHit] = []
    @State private var picked: AddressHit?
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var suggestTask: Task<Void, Never>?

    var body: some View {
#if os(watchOS)
        watchBody
#else
        phoneBody
#endif
    }

#if os(watchOS)
    private var watchBody: some View {
        CategoryGallery(
            selection: $category,
            hint: "Tap to save",
            onConfirm: { chosen in
                Task { await saveHere(chosen) }
            }
        )
        .navigationTitle("Add pin")
        .overlay {
            if isSaving {
                ProgressView()
            }
        }
        .alert("PINO", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .disabled(isSaving)
    }

    private func saveHere(_ chosen: PinCategory) async {
        guard !isSaving else { return }
        isSaving = true
        do {
            _ = try await environment.savePin(category: chosen)
            isSaving = false
            PinoHaptics.success()
            environment.showPinsList = true
            dismiss()
        } catch {
            isSaving = false
            PinoHaptics.failure()
            errorMessage = error.localizedDescription
        }
    }
#else
    private var phoneBody: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                TextField("Address", text: $address)
                    .textInputAutocapitalization(.words)
                    .textContentType(.fullStreetAddress)
            }
            if !suggestions.isEmpty {
                Section {
                    ForEach(suggestions) { hit in
                        Button {
                            pick(hit)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(hit.title.isEmpty ? hit.line : hit.title)
                                if !hit.subtitle.isEmpty, hit.subtitle != hit.title {
                                    Text(hit.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            Section {
                CategoryPicker(selection: Binding(
                    get: { Optional(category) },
                    set: { if let value = $0 { category = value } }
                ))
            }
        }
        .navigationTitle("Add pin")
        .navigationBarTitleDisplayMode(.inline)
        .modifier(ManualPinChrome(
            canSave: canSave,
            isSaving: isSaving,
            errorMessage: $errorMessage,
            save: { Task { await save() } }
        ))
        .onChange(of: address) { _, value in
            handleAddressChange(value)
        }
        .onDisappear {
            suggestTask?.cancel()
        }
    }
#endif

#if os(iOS)
    private var canSave: Bool {
        !isSaving
    }

    private func pick(_ hit: AddressHit) {
        picked = hit
        address = hit.line
        suggestions = []
        PinoHaptics.click()
    }

    private func handleAddressChange(_ value: String) {
        if picked?.line != value {
            picked = nil
        }
        suggestTask?.cancel()
        suggestTask = Task {
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            suggestions = await ForwardGeocoder.suggest(value, near: location.location)
        }
    }

    private func save() async {
        guard canSave else { return }
        isSaving = true
        do {
            _ = try await environment.saveManualPin(
                name: name,
                address: picked?.line ?? address,
                category: category,
                at: picked?.coordinate
            )
            isSaving = false
            PinoHaptics.success()
            dismiss()
        } catch {
            isSaving = false
            PinoHaptics.failure()
            errorMessage = error.localizedDescription
        }
    }
#endif
}

private struct ManualPinChrome: ViewModifier {
    var canSave: Bool
    var isSaving: Bool
    @Binding var errorMessage: String?
    var save: () -> Void

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
            .overlay {
                if isSaving {
                    ProgressView()
                }
            }
            .alert("PINO", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
    }
}
