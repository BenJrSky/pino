import MapKit
import SwiftUI

struct FindView: View {
    let pin: Pin
    var showsManagement: Bool = true
    @EnvironmentObject private var store: PinStore
    @EnvironmentObject private var location: LocationService
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Pin
    @State private var confirmDelete = false
    @State private var camera: MapCameraPosition
    @State private var findPin: Pin?
    @State private var route: MKRoute?
    @State private var lastRoutedFrom: CLLocation?
    @State private var pinTapAt: Date?
    @State private var lastTappedPin: Pin?
    @State private var settingsPin: Pin?
    @State private var pendingPinTap: Task<Void, Never>?

    init(pin: Pin, showsManagement: Bool = true) {
        self.pin = pin
        self.showsManagement = showsManagement
        _draft = State(initialValue: pin)
        _findPin = State(initialValue: pin)
        _camera = State(initialValue: PinoMaps.userCamera(pin.coordinate))
    }

    private var livePin: Pin {
        if let findPin {
            return store.pins.first(where: { $0.id == findPin.id }) ?? findPin
        }
        return store.pins.first(where: { $0.id == pin.id }) ?? draft
    }

#if os(watchOS)
    private let markSize: CGFloat = 22
#else
    private let markSize: CGFloat = 40
#endif

    var body: some View {
        ZStack {
            Map(position: $camera) {
                UserAnnotation()
                ForEach(store.pins) { item in
                    Annotation("", coordinate: item.coordinate) {
                        SavedPinMark(category: item.category, skinTone: item.skinTone ?? .none, diameter: markSize)
                            .scaleEffect(item.id == findPin?.id ? 1.18 : 1)
                            .mapGestures(
                                onFind: { handleIconTap(item) },
                                onEdit: { openEdit(item) }
                            )
                    }
                }
                if let route {
                    MapPolyline(route.polyline)
                        .stroke(Color.route, lineWidth: 6)
                } else if let findPin, let user = location.location {
                    MapPolyline(coordinates: [user.coordinate, findPin.coordinate])
                        .stroke(Color.route.opacity(0.75), style: StrokeStyle(lineWidth: 5, dash: [10, 7]))
                }
            }
            .pinoMapStyle()
            .mapControlVisibility(.hidden)
            .ignoresSafeArea()
#if os(watchOS)
            .onTapGesture(perform: handleMapTap)
#else
            .simultaneousGesture(TapGesture().onEnded(handleMapTap))
#endif

            if let findPin {
                WayfindingBanner(pin: findPin, route: route)
                FindGuidance(pin: findPin, route: route)
            }

            VStack(spacing: 0) {
                Spacer()
                    .allowsHitTesting(false)
                HStack(alignment: .center, spacing: 8) {
                    if findPin != nil {
                        FindHUD(pin: livePin, route: route)
                        Spacer(minLength: 4)
                        GuidanceButton()
                    } else {
                        Spacer(minLength: 0)
                    }
                    RecenterButton(action: recenter)
                }
                .contentShape(Rectangle())
#if os(watchOS)
                .padding(6)
#else
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
#endif
            }
        }
        .modifier(FindMapChrome(
            showsManagement: showsManagement,
            livePin: livePin,
            confirmDelete: $confirmDelete,
            onDelete: {
                store.delete(livePin)
                dismiss()
            }
        ))
        .onAppear {
            location.start()
        }
        .task {
            await loadRoute()
        }
        .onChange(of: store.pins) { _, pins in
            guard let id = findPin?.id, !pins.contains(where: { $0.id == id }) else { return }
            findPin = nil
            route = nil
            VoiceGuide.stop()
        }
        .onChange(of: findPin?.id) { _, _ in
            lastRoutedFrom = nil
            route = nil
            Task { await loadRoute() }
        }
        .onChange(of: location.location?.timestamp) { _, _ in
            Task { await loadRoute() }
        }
        .onDisappear {
            pendingPinTap?.cancel()
        }
        .navigationDestination(item: $settingsPin) { item in
#if os(iOS)
            PinDetailView(pin: item)
#else
            PinEditView(pin: item)
#endif
        }
    }

    private func handleIconTap(_ item: Pin) {
        lastTappedPin = item
        pinTapAt = Date()
        pendingPinTap?.cancel()
        pendingPinTap = Task {
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            pendingPinTap = nil
            findPin = item
        }
    }

    private func openEdit(_ item: Pin) {
        lastTappedPin = item
        pinTapAt = Date()
        pendingPinTap?.cancel()
        pendingPinTap = nil
        settingsPin = item
        PinoHaptics.click()
    }

    private func handleMapTap() {
        if let pinTapAt {
            let elapsed = Date().timeIntervalSince(pinTapAt)
            if elapsed < 0.12 {
                return
            }
            if elapsed < 0.45, let lastTappedPin {
                openEdit(lastTappedPin)
                return
            }
        }
        findPin = nil
        route = nil
    }

    private func recenter() {
        if let user = location.location {
            camera = PinoMaps.userCamera(user.coordinate)
        } else {
            camera = .userLocation(fallback: .automatic)
        }
        PinoHaptics.click()
    }

    private func loadRoute() async {
        guard let findPin,
              store.pins.contains(where: { $0.id == findPin.id }),
              let origin = location.location else { return }
        if let lastRoutedFrom, origin.distance(from: lastRoutedFrom) < 30 {
            return
        }
        lastRoutedFrom = origin
        let found = await PinoDirections.route(
            from: origin.coordinate,
            to: findPin.coordinate,
            mode: livePin.routeMode
        )
        route = found
        if let found {
            camera = PinoMaps.camera(for: found)
        } else {
            camera = .region(PinoMaps.region(containing: [origin.coordinate, findPin.coordinate]))
        }
    }
}

private struct FindMapChrome: ViewModifier {
    var showsManagement: Bool
    var livePin: Pin
    @Binding var confirmDelete: Bool
    var onDelete: () -> Void

    func body(content: Content) -> some View {
#if os(watchOS)
        content
#else
        content
            .safeAreaInset(edge: .bottom) {
                if showsManagement {
                    HStack {
                        NavigationLink("Details") {
                            PinEditView(pin: livePin)
                        }
                        Button("Delete", role: .destructive) {
                            confirmDelete = true
                        }
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.top, 6)
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle("Find")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Delete this pin?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive, action: onDelete)
            }
#endif
    }
}

struct PinEditView: View {
    let pin: Pin
    @EnvironmentObject private var store: PinStore
    @EnvironmentObject private var settings: SettingsStore
    @State private var name: String
    @State private var category: PinCategory?

    init(pin: Pin) {
        self.pin = pin
        _name = State(initialValue: pin.name ?? "")
        _category = State(initialValue: pin.category)
    }

    var body: some View {
        content
            .navigationTitle("Details")
            .onDisappear(perform: save)
            .onChange(of: name) { _, _ in save() }
            .onChange(of: category) { _, _ in save() }
#if os(iOS)
            .onAppear {
                if current.category?.takesSkinTone == true {
                    settings.skinTone = current.skinTone ?? .none
                }
            }
            .onChange(of: settings.skinTone) { _, _ in save() }
#endif
    }

    @ViewBuilder
    private var content: some View {
#if os(watchOS)
        VStack(alignment: .leading, spacing: 6) {
            TextField("Name", text: $name)
            if let address = current.address {
                Text(address)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
#else
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Name", text: $name)
                CategoryPicker(selection: $category)
                    .id(pin.id)
                if let address = current.address {
                    Text(address)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(Formatters.date.string(from: current.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
#endif
    }

    private var current: Pin {
        store.pins.first(where: { $0.id == pin.id }) ?? pin
    }

    private func save() {
        var updated = current
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.name = trimmed.isEmpty ? nil : trimmed
        updated.category = category
#if os(iOS)
        updated.skinTone = category?.takesSkinTone == true ? settings.skinTone : nil
#endif
        if updated != current {
            store.update(updated)
        }
    }
}
