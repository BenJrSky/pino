import MapKit
import SwiftUI

struct SaveMapScreen: View {
    @Binding var findPin: Pin?
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var store: PinStore
    @EnvironmentObject private var location: LocationService
    @State private var isSaving = false
    @State private var pickerVisible = false
    @State private var selected: PinCategory? = .car
    @State private var crownValue = 0.0
    @State private var errorMessage: String?
    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var route: MKRoute?
    @State private var lastRoutedFrom: CLLocation?
    @State private var pinTapAt: Date?
    @State private var lastTappedPin: Pin?
    @State private var settingsPin: Pin?
    @State private var pendingPinTap: Task<Void, Never>?

    private let categories = PinCategory.allCases

#if os(watchOS)
    private let markSize: CGFloat = 26
    private let centerSize: CGFloat = 58
    private let peekSize: CGFloat = 40
#else
    private let markSize: CGFloat = 40
    private let centerSize: CGFloat = 96
    private let peekSize: CGFloat = 68
#endif

    private var selectedCategory: PinCategory {
        selected ?? .car
    }

    var body: some View {
        ZStack {
            Map(position: $camera) {
                UserAnnotation()
                ForEach(store.pins) { pin in
                    Annotation("", coordinate: pin.coordinate) {
                        SavedPinMark(category: pin.category, diameter: markSize)
                            .scaleEffect(findPin?.id == pin.id ? 1.18 : 1)
                            .mapGestures(
                                onFind: { handleIconTap(pin) },
                                onEdit: { openEdit(pin) }
                            )
                            .accessibilityHint("Find")
                    }
                }
                if let route {
                    MapPolyline(route.polyline)
                        .stroke(Color.route, lineWidth: 6)
                } else if let findPin, let user = location.location {
                    MapPolyline(coordinates: [user.coordinate, findPin.coordinate])
                        .stroke(Color.route.opacity(0.7), style: StrokeStyle(lineWidth: 4, dash: [8, 6]))
                }
            }
            .pinoMapStyle()
            .mapControlVisibility(.hidden)
            .ignoresSafeArea()
            .allowsHitTesting(!pickerVisible)
            .onTapGesture(perform: handleMapTap)

            if let findPin, !pickerVisible {
                WayfindingBanner(pin: findPin, route: route)
                FindHUD(pin: findPin, route: route, heading: heading(to: findPin))
            }

            if pickerVisible {
                Color.black.opacity(0.12)
                    .ignoresSafeArea()
                    .onTapGesture { pickerVisible = false }

                slider
                    .allowsHitTesting(true)
            }

            if isSaving {
                ProgressView()
                    .tint(.white)
            }
        }
#if os(watchOS)
        .focusable(pickerVisible)
        .digitalCrownRotation(
            $crownValue,
            from: 0,
            through: Double(categories.count - 1),
            by: 1,
            sensitivity: .low,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
#endif
        .onChange(of: crownValue) { _, value in
            guard pickerVisible else { return }
            let index = min(max(Int(value.rounded()), 0), categories.count - 1)
            selected = categories[index]
        }
        .onChange(of: selected) { _, newValue in
            guard let newValue, let index = categories.firstIndex(of: newValue) else { return }
            let next = Double(index)
            if abs(crownValue - next) >= 0.5 {
                crownValue = next
            }
        }
        .onChange(of: findPin) { _, _ in
            lastRoutedFrom = nil
            route = nil
            Task { await loadRoute() }
        }
        .onChange(of: location.location?.timestamp) { _, _ in
            Task { await loadRoute() }
        }
        .alert("PINO", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            location.start()
            Task { await loadRoute() }
        }
        .onDisappear {
            pendingPinTap?.cancel()
        }
        .navigationDestination(item: $settingsPin) { pin in
#if os(iOS)
            PinDetailView(pin: pin)
#else
            PinEditView(pin: pin)
#endif
        }
    }

    private var selectedIndex: Int {
        categories.firstIndex(of: selectedCategory) ?? 0
    }

    private func circularDelta(for index: Int) -> Int {
        let count = categories.count
        var delta = index - selectedIndex
        if delta > count / 2 { delta -= count }
        if delta < -(count / 2) { delta += count }
        return delta
    }

    private func moveSelection(by steps: Int) {
        guard steps != 0 else { return }
        let count = categories.count
        let next = (selectedIndex + steps % count + count) % count
        selected = categories[next]
        PinoHaptics.click()
    }

    private var slider: some View {
        GeometryReader { geo in
            let spacing = peekSize * 0.42
            let maxOffset = geo.size.width / 2 + peekSize
            ZStack {
                ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                    let delta = circularDelta(for: index)
                    let x = CGFloat(delta) * spacing
                    if abs(x) < maxOffset {
                        sliderIcon(category, isCenter: delta == 0)
                            .offset(x: x)
                            .zIndex(delta == 0 ? 100 : Double(40 - abs(delta)))
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 12)
                    .onEnded { value in
                        moveSelection(by: Int((-value.translation.width / spacing).rounded()))
                    }
            )
        }
        .frame(height: centerSize + 8)
        .frame(maxWidth: .infinity)
        .animation(.snappy(duration: 0.22), value: selectedCategory)
        .accessibilityLabel(selectedCategory.label)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: moveSelection(by: 1)
            case .decrement: moveSelection(by: -1)
            @unknown default: break
            }
        }
    }

    private func sliderIcon(_ category: PinCategory, isCenter: Bool) -> some View {
        let size = isCenter ? centerSize : peekSize
        return Button {
            if isCenter {
                Task { await save(category) }
            } else {
                selected = category
                PinoHaptics.click()
            }
        } label: {
            Text(category.emoji)
                .font(.system(size: size * 0.5))
                .frame(width: size, height: size)
                .background(isCenter ? Color.pino : Color.white.opacity(0.18), in: Circle())
                .shadow(color: isCenter ? .black.opacity(0.35) : .clear, radius: 8, y: 3)
                .opacity(isCenter ? 1 : 0.72)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.label)
    }

    private func heading(to pin: Pin) -> Angle? {
        guard let user = location.location, let heading = location.currentHeading else { return nil }
        let bearing = GeoMath.bearing(from: user.coordinate, to: pin.coordinate)
        return .degrees(bearing - heading)
    }

    private func handleIconTap(_ pin: Pin) {
        lastTappedPin = pin
        pinTapAt = Date()
        pickerVisible = false
        pendingPinTap?.cancel()
        pendingPinTap = Task {
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            pendingPinTap = nil
            findPin = pin
            PinoHaptics.click()
        }
    }

    private func openEdit(_ pin: Pin) {
        lastTappedPin = pin
        pinTapAt = Date()
        pickerVisible = false
        pendingPinTap?.cancel()
        pendingPinTap = nil
        settingsPin = pin
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
        if findPin != nil {
            findPin = nil
            route = nil
            return
        }
        showPicker()
    }

    private func showPicker() {
        guard !isSaving, !pickerVisible else { return }
        pickerVisible = true
        PinoHaptics.click()
    }

    private func loadRoute() async {
        guard let pin = findPin, let origin = location.location else { return }
        if let lastRoutedFrom, origin.distance(from: lastRoutedFrom) < 30, route != nil {
            return
        }
        lastRoutedFrom = origin
        let found = await PinoDirections.route(from: origin.coordinate, to: pin.coordinate)
        guard findPin?.id == pin.id else { return }
        route = found
        if let found {
            camera = PinoMaps.camera(for: found)
        }
    }

    private func save(_ category: PinCategory) async {
        guard !isSaving else { return }
        selected = category
        isSaving = true
        do {
            _ = try await environment.savePin(category: category)
            isSaving = false
            pickerVisible = false
            PinoHaptics.success()
        } catch {
            isSaving = false
            PinoHaptics.failure()
            errorMessage = error.localizedDescription
        }
    }
}

struct FindHUD: View {
    let pin: Pin
    var route: MKRoute?
    var heading: Angle?
    @EnvironmentObject private var location: LocationService

    var body: some View {
        VStack {
            HStack(spacing: 8) {
                if let heading {
                    Image(systemName: "location.north.fill")
                        .rotationEffect(heading)
                        .animation(.easeInOut(duration: 0.2), value: heading)
                }
                Text(pin.symbol)
                    .font(.title3)
                if let route {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Formatters.distance(route.distance))
                            .font(.headline)
                        Text(Formatters.duration(route.expectedTravelTime))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if let distance = location.distance(to: pin) {
                    Text(Formatters.distance(distance))
                        .font(.headline)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.horizontal, 8)
            Spacer()
        }
        .allowsHitTesting(false)
    }
}

struct WayfindingBanner: View {
    let pin: Pin
    var route: MKRoute?
    @EnvironmentObject private var location: LocationService

    private var delta: Double? {
        guard let user = location.location else { return nil }
        let target = PinoWayfinding.lookAhead(from: user.coordinate, to: pin.coordinate, route: route)
        return PinoWayfinding.relativeDelta(from: user, to: target, heading: location.currentHeading)
    }

    var body: some View {
        GeometryReader { geo in
            if let delta {
                let edge = PinoWayfinding.edge(for: delta)
                let correct = abs(delta) < 90
                strip(edge: edge, color: correct ? Color.pino : .red, in: geo.size)
                    .animation(.easeInOut(duration: 0.2), value: edge)
                    .animation(.easeInOut(duration: 0.2), value: correct)
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    private func strip(edge: Edge, color: Color, in size: CGSize) -> some View {
#if os(watchOS)
        let thickness = min(size.width, size.height) * 0.3
#else
        let thickness = min(size.width, size.height) * 0.13
#endif
        return Group {
            switch edge {
            case .top:
                LinearGradient(colors: [color, color.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(height: thickness)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            case .bottom:
                LinearGradient(colors: [color, color.opacity(0)], startPoint: .bottom, endPoint: .top)
                    .frame(height: thickness)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            case .leading:
                LinearGradient(colors: [color, color.opacity(0)], startPoint: .leading, endPoint: .trailing)
                    .frame(width: thickness)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            case .trailing:
                LinearGradient(colors: [color, color.opacity(0)], startPoint: .trailing, endPoint: .leading)
                    .frame(width: thickness)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            }
        }
    }
}
