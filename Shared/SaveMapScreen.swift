import MapKit
import SwiftUI

struct SaveMapScreen: View {
    @Binding var findPin: Pin?
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var store: PinStore
    @EnvironmentObject private var location: LocationService
    @State private var isSaving = false
    @State private var pickerVisible = false
    @State private var selected: PinCategory = .car
    @State private var errorMessage: String?
    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var route: MKRoute?
    @State private var lastRoutedFrom: CLLocation?
    @State private var pinTapAt: Date?
    @State private var lastTappedPin: Pin?
    @State private var settingsPin: Pin?
    @State private var pendingPinTap: Task<Void, Never>?
    @State private var lastHeadingCamera = Date.distantPast

#if os(watchOS)
    private let markSize: CGFloat = 26
#else
    private let markSize: CGFloat = 40
#endif

    var body: some View {
        ZStack {
            Map(position: $camera) {
                if let route {
                    MapPolyline(route.polyline)
                        .stroke(Color.route, lineWidth: 6)
                } else if let findPin, let user = location.location {
                    MapPolyline(coordinates: [user.coordinate, findPin.coordinate])
                        .stroke(Color.route.opacity(0.75), style: StrokeStyle(lineWidth: 5, dash: [10, 7]))
                }
                ForEach(store.pins) { pin in
                    Annotation("", coordinate: pin.coordinate) {
                        SavedPinMark(category: pin.category, skinTone: pin.skinTone ?? .none, diameter: markSize)
                            .scaleEffect(findPin?.id == pin.id ? 1.18 : 1)
                            .mapGestures(
                                onFind: { handleIconTap(pin) },
                                onEdit: { openEdit(pin) }
                            )
                            .accessibilityHint("Find")
                    }
                }
#if os(watchOS)
                if let snap = routeSnap {
                    Annotation("", coordinate: snap.coordinate) {
                        OnRoutePuck()
                            .allowsHitTesting(false)
                    }
                } else {
                    UserAnnotation()
                }
#else
                UserAnnotation()
#endif
            }
            .pinoMapStyle()
            .mapControlVisibility(.hidden)
            .ignoresSafeArea()
            .allowsHitTesting(!pickerVisible)
#if os(watchOS)
            .onTapGesture(perform: handleMapTap)
#else
            .simultaneousGesture(TapGesture().onEnded(handleMapTap))
#endif

            if let findPin, !pickerVisible {
                WayfindingBanner(pin: findPin, route: route)
                FindGuidance(pin: findPin, route: route)
            }

            if !pickerVisible {
                VStack(spacing: 0) {
                    Spacer()
                        .allowsHitTesting(false)
                    HStack(alignment: .center, spacing: 8) {
                        if let findPin {
                            FindHUD(pin: findPin, route: route)
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
                    .padding(.bottom, 28)
#endif
                }
            }

            if pickerVisible {
#if os(watchOS)
                gallery
#else
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .onTapGesture { pickerVisible = false }

                VStack {
                    Spacer()
                    gallery
                }
                .allowsHitTesting(true)
#endif
            }

            if store.pins.isEmpty, findPin == nil, !pickerVisible {
                MapSaveHint()
                    .allowsHitTesting(false)
            }

            if isSaving {
                ProgressView()
                    .tint(.white)
            }
        }
        .toolbar(pickerVisible ? .hidden : .automatic, for: .navigationBar)
        .onChange(of: findPin) { _, pin in
            lastRoutedFrom = nil
            route = nil
            if pin == nil {
                VoiceGuide.stop()
                followUser()
            }
            Task { await loadRoute() }
            updateFollow()
        }
        .onChange(of: store.pins) { _, pins in
            guard let id = findPin?.id, !pins.contains(where: { $0.id == id }) else { return }
            environment.stopFind()
            route = nil
        }
        .onChange(of: location.location?.timestamp) { _, _ in
#if DEBUG
            applyScreenshotOverview()
#endif
            updateFollow()
            Task { await loadRoute() }
        }
        .onChange(of: location.heading?.timestamp) { _, _ in
#if os(watchOS)
            let now = Date()
            guard now.timeIntervalSince(lastHeadingCamera) >= 0.3 else { return }
            lastHeadingCamera = now
            followUser()
#endif
        }
        .alert("PinO", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            location.start()
            followUser()
            Task { await loadRoute() }
#if DEBUG
            applyScreenshotOverview()
#endif
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

    private var routeSnap: PinoWayfinding.Snap? {
        guard findPin != nil, let user = location.location, let route else { return nil }
        guard let snap = PinoWayfinding.snap(from: user.coordinate, onto: route), snap.offset < 40 else {
            return nil
        }
        return snap
    }

    private var gallery: some View {
#if os(watchOS)
        VStack(spacing: 6) {
            CategoryGallery(
                selection: $selected,
                hint: "Tap to save",
                onConfirm: { category in
                    Task { await save(category) }
                }
            )
            Button("Cancel") {
                pickerVisible = false
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.bordered)
            .tint(.white)
            .accessibilityLabel("Cancel")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.72))
#else
        CategoryGallery(
            selection: $selected,
            hint: "Tap to save",
            showsChrome: true,
            onConfirm: { category in
                Task { await save(category) }
            }
        )
#endif
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
            environment.stopFind()
            route = nil
            return
        }
#if os(watchOS)
        Task { await save(.place) }
#else
        showPicker()
#endif
    }

    private func showPicker() {
        guard !isSaving, !pickerVisible else { return }
        pickerVisible = true
        PinoHaptics.click()
    }

    private func recenter() {
#if os(watchOS)
        followUser()
#else
        if findPin != nil {
            applyOverview()
        } else if let user = location.location {
            camera = PinoMaps.userCamera(user.coordinate)
        } else {
            camera = .userLocation(fallback: .automatic)
        }
#endif
        PinoHaptics.click()
    }

    private func followUser() {
        guard let user = location.location, user.horizontalAccuracy > 0, user.horizontalAccuracy < 45 else {
            return
        }
        camera = PinoMaps.followUser(user, compass: location.currentHeading, route: route)
    }

    private func updateFollow() {
#if os(iOS)
        return
#else
        followUser()
#endif
    }

    private func applyOverview() {
        guard let pin = findPin, let origin = location.location else { return }
        camera = PinoMaps.overview(user: origin.coordinate, pin: pin.coordinate, route: route)
    }

    private func loadRoute() async {
        guard let pin = findPin,
              store.pins.contains(where: { $0.id == pin.id }),
              let origin = location.location else { return }
#if os(watchOS)
        if let route,
           let snap = PinoWayfinding.snap(from: origin.coordinate, onto: route),
           snap.offset < 25,
           let lastRoutedFrom,
           origin.distance(from: lastRoutedFrom) < 12 {
            return
        }
        lastRoutedFrom = origin
        let found = await PinoDirections.route(
            from: origin.coordinate,
            to: pin.coordinate,
            mode: .walking
        )
#else
        if let lastRoutedFrom, origin.distance(from: lastRoutedFrom) < 30 {
            return
        }
        lastRoutedFrom = origin
        let found = await PinoDirections.route(
            from: origin.coordinate,
            to: pin.coordinate,
            mode: (store.pins.first(where: { $0.id == pin.id }) ?? pin).routeMode
        )
#endif
        guard findPin?.id == pin.id else { return }
        route = found
#if os(watchOS)
        followUser()
#else
        applyOverview()
#endif
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
#if os(watchOS)
            environment.showPinsList = true
#endif
        } catch {
            isSaving = false
            PinoHaptics.failure()
            errorMessage = error.localizedDescription
        }
    }

#if DEBUG
    private func applyScreenshotOverview() {
        guard ProcessInfo.processInfo.arguments.contains("-pino-overview") else { return }
        var coords = store.pins.map(\.coordinate)
        if let user = location.location {
            coords.append(user.coordinate)
        }
        guard coords.count >= 2 else { return }
        camera = .region(PinoMaps.region(containing: coords))
    }
#endif
}

struct FindHUD: View {
    let pin: Pin
    var route: MKRoute?
    @EnvironmentObject private var location: LocationService

    private var line: String {
        if let route {
            let distance = Formatters.distance(route.distance)
            let time = Formatters.duration(route.expectedTravelTime)
            return time.isEmpty ? distance : "\(distance) · \(time)"
        }
        if let distance = location.distance(to: pin) {
            return Formatters.distance(distance)
        }
        return ""
    }

    var body: some View {
        if !line.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: pin.routeMode.symbol)
                Text(line)
            }
#if os(watchOS)
            .font(.system(size: 10, weight: .semibold))
#else
            .font(.caption2.weight(.semibold))
#endif
            .monospacedDigit()
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.ultraThinMaterial, in: Capsule())
            .allowsHitTesting(false)
            .accessibilityLabel("\(pin.routeMode.label), \(line)")
        }
    }
}

struct WayfindingBanner: View {
    let pin: Pin
    var route: MKRoute?
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var settings: SettingsStore
    @State private var lastWrongPulse: Date?

    private var delta: Double? {
        guard let user = location.location else { return nil }
        if let route, let snap = PinoWayfinding.snap(from: user.coordinate, onto: route), snap.offset < 40 {
            let target = PinoWayfinding.lookAhead(from: user.coordinate, to: pin.coordinate, route: route)
            var value = GeoMath.bearing(from: snap.coordinate, to: target) - snap.heading
            while value > 180 { value -= 360 }
            while value < -180 { value += 360 }
            return value
        }
        let target = PinoWayfinding.lookAhead(from: user.coordinate, to: pin.coordinate, route: route)
        return PinoWayfinding.relativeDelta(from: user, to: target, heading: location.currentHeading)
    }

    var body: some View {
        GeometryReader { geo in
            if let delta {
                let magnitude = abs(delta)
                if magnitude > 50, magnitude < 125 {
                    Color.clear
                } else {
                    let edge = PinoWayfinding.edge(for: delta)
                    let correct = magnitude <= 50
                    strip(edge: edge, color: correct ? Color.pino : .red, in: geo.size)
                        .animation(.easeInOut(duration: 0.2), value: edge)
                        .animation(.easeInOut(duration: 0.2), value: correct)
                        .onChange(of: correct) { _, isCorrect in
                            if isCorrect {
                                lastWrongPulse = nil
                            } else {
                                pulseWrong()
                            }
                        }
                        .onChange(of: location.heading?.timestamp) { _, _ in
                            guard !correct else { return }
                            pulseWrongIfNeeded()
                        }
                        .onAppear {
                            if !correct { pulseWrong() }
                        }
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    private func pulseWrong() {
        lastWrongPulse = Date()
        guard settings.guidance else { return }
        PinoHaptics.wrongWay()
    }

    private func pulseWrongIfNeeded() {
        if let lastWrongPulse, Date().timeIntervalSince(lastWrongPulse) < 2.8 {
            return
        }
        pulseWrong()
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
