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
    @State private var firstPerson = false
    @State private var stopFollow: Task<Void, Never>?
    @State private var lastSample: CLLocation?
    @State private var lastHeadingCamera = Date.distantPast

#if os(watchOS)
    private let markSize: CGFloat = 26
#else
    private let markSize: CGFloat = 40
#endif

    var body: some View {
        ZStack {
            Map(position: $camera) {
                UserAnnotation()
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
            .allowsHitTesting(!pickerVisible)
#if os(watchOS)
            .onTapGesture(perform: handleMapTap)
#endif

            if let findPin, !pickerVisible {
                WayfindingBanner(pin: findPin, route: route)
                FindGuidance(pin: findPin, route: route)
            }

            if !pickerVisible {
                VStack(spacing: 0) {
#if os(iOS)
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture(perform: handleMapTap)
#else
                    Spacer()
                        .allowsHitTesting(false)
#endif
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

            if isSaving {
                ProgressView()
                    .tint(.white)
            }
        }
        .toolbar(pickerVisible ? .hidden : .automatic, for: .navigationBar)
        .onChange(of: findPin) { _, pin in
            lastRoutedFrom = nil
            route = nil
            firstPerson = false
            stopFollow?.cancel()
            if pin == nil {
                VoiceGuide.stop()
                if let user = location.location {
                    camera = PinoMaps.userCamera(user.coordinate)
                }
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
            guard firstPerson else { return }
#if os(watchOS)
            let now = Date()
            guard now.timeIntervalSince(lastHeadingCamera) >= 0.3 else { return }
            lastHeadingCamera = now
#endif
            applyFirstPerson()
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
#if DEBUG
            applyScreenshotOverview()
#endif
        }
        .onDisappear {
            pendingPinTap?.cancel()
            stopFollow?.cancel()
        }
        .navigationDestination(item: $settingsPin) { pin in
#if os(iOS)
            PinDetailView(pin: pin)
#else
            PinEditView(pin: pin)
#endif
        }
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
        if findPin != nil {
            if firstPerson {
                applyFirstPerson()
            } else {
                applyOverview()
            }
        } else if let user = location.location {
            camera = PinoMaps.userCamera(user.coordinate)
        } else {
            camera = .userLocation(fallback: .automatic)
        }
        PinoHaptics.click()
    }

    private func updateFollow() {
        guard findPin != nil, let user = location.location else {
            stopFollow?.cancel()
            if firstPerson {
                firstPerson = false
                applyOverview()
            }
            lastSample = nil
            return
        }
        let previous = lastSample
        lastSample = user
        if isMoving(user, from: previous) {
            stopFollow?.cancel()
            stopFollow = nil
            firstPerson = true
            applyFirstPerson()
        } else if firstPerson, isStopped(user, from: previous) {
            stopFollow?.cancel()
            stopFollow = Task {
                try? await Task.sleep(for: .milliseconds(800))
                guard !Task.isCancelled else { return }
                firstPerson = false
                applyOverview()
            }
        }
    }

    private func isMoving(_ user: CLLocation, from previous: CLLocation?) -> Bool {
        guard user.horizontalAccuracy > 0, user.horizontalAccuracy < 40 else { return false }
        if user.speed >= 0.35 { return true }
        guard let previous else { return false }
        let dt = user.timestamp.timeIntervalSince(previous.timestamp)
        let dist = user.distance(from: previous)
        guard dt > 0.4, dist >= 1.5 else { return false }
        return dist / dt >= 0.35
    }

    private func isStopped(_ user: CLLocation, from previous: CLLocation?) -> Bool {
        if user.speed >= 0 { return user.speed < 0.28 }
        guard let previous else { return true }
        return user.distance(from: previous) < 1.2
    }

    private func applyFirstPerson() {
        guard let user = location.location else { return }
        let heading = location.currentHeading ?? (user.course >= 0 ? user.course : nil)
        camera = PinoMaps.firstPerson(user: user, heading: heading)
    }

    private func applyOverview() {
        guard let pin = findPin, let origin = location.location else { return }
        camera = PinoMaps.overview(user: origin.coordinate, pin: pin.coordinate, route: route)
    }

    private func loadRoute() async {
        guard let pin = findPin,
              store.pins.contains(where: { $0.id == pin.id }),
              let origin = location.location else { return }
        if let lastRoutedFrom, origin.distance(from: lastRoutedFrom) < 30 {
            return
        }
        lastRoutedFrom = origin
        let found = await PinoDirections.route(
            from: origin.coordinate,
            to: pin.coordinate,
            mode: (store.pins.first(where: { $0.id == pin.id }) ?? pin).routeMode
        )
        guard findPin?.id == pin.id else { return }
        route = found
        if !firstPerson {
            applyOverview()
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
