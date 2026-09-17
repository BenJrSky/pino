import MapKit
import SwiftUI

struct SaveMapScreen: View {
    @Binding var findPin: Pin?
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var store: PinStore
    @EnvironmentObject private var location: LocationService
    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var route: MKRoute?
    @State private var lastRoutedFrom: CLLocation?
    @State private var lastFollowed: CLLocation?
    @State private var lastFollowAt = Date.distantPast
    @State private var pinTapAt: Date?
    @State private var settingsPin: Pin?
    @State private var showAdd = false
    @State private var pendingPinTap: Task<Void, Never>?
    @State private var lastHeadingCamera = Date.distantPast
    @State private var visibleCamera: MapCamera?
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var followLocked = true

#if os(watchOS)
    private let markSize: CGFloat = 26
#else
    private let markSize: CGFloat = 40
#endif

    var body: some View {
        ZStack(alignment: .bottom) {
            MapReader { proxy in
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
                            SavedPinMark(
                                category: pin.category,
                                skinTone: pin.skinTone ?? .none,
                                diameter: markSize,
                                here: PinoWayfinding.isHere(user: location.location, pin: pin, finding: findPin)
                            )
                                .scaleEffect(findPin?.id == pin.id ? 1.18 : 1)
                                .mapGestures(
                                    onFind: { handleIconTap(pin) },
                                    onEdit: { openEdit(pin) }
                                )
                                .accessibilityHint("Find")
                        }
                    }
                }
                .pinoMapStyle()
                .mapControlVisibility(.hidden)
                .ignoresSafeArea()
                .allowsHitTesting(true)
                .pinoMapTap(findPin == nil, perform: handleMapTap)
                .pinoMapDoubleTap(findPin != nil, perform: recenterOnUser)
                .onMapCameraChange(frequency: .continuous) { context in
                    visibleCamera = context.camera
                    visibleRegion = context.region
                }
                .onMapCameraChange(frequency: .onEnd) { context in
                    visibleCamera = context.camera
                    visibleRegion = context.region
                    unlockFollowIfPanned(center: context.camera.centerCoordinate)
                }
                .overlay {
                    if let user = location.location {
                        let _ = visibleCamera
                        UserPuckLayer(proxy: proxy, coordinate: puckCoordinate(for: user))
                    }
                }
            }

            if let findPin {
                WayfindingBanner(pin: findPin, route: route)
                FindGuidance(pin: findPin, route: route)
            }

            mapChrome
        }
#if os(watchOS)
        .ignoresSafeArea(edges: .bottom)
#endif
        .overlay(alignment: .top) {
            if location.isDenied {
                LocationDeniedHint()
            } else if showsRecenterHint {
                MapSaveHint(text: "Double tap to return", compact: true)
                    .padding(.top, 8)
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: findPin) { _, pin in
            lastRoutedFrom = nil
            route = nil
            if pin == nil {
                VoiceGuide.stop()
                followLocked = true
                followUser()
            } else {
                followLocked = true
            }
            Task { await loadRoute() }
            updateFollow()
        }
        .onChange(of: store.pins) { _, pins in
            guard let id = findPin?.id, !pins.contains(where: { $0.id == id }) else { return }
            environment.stopFind()
            route = nil
        }
        .onChange(of: findTravelMode) { _, mode in
            lastRoutedFrom = nil
            route = nil
            if let mode {
                location.setNavigating(true, mode: mode)
            }
            Task { await loadRoute() }
        }
        .onChange(of: location.location?.timestamp) { _, _ in
#if DEBUG
            applyScreenshotOverview()
#endif
            updateFollow()
            guard findPin != nil else { return }
            Task { await loadRoute() }
        }
        .onChange(of: location.heading?.timestamp) { _, _ in
            let now = Date()
            guard findPin != nil, followLocked else { return }
            guard now.timeIntervalSince(lastHeadingCamera) >= 0.4 else { return }
            guard now.timeIntervalSince(lastFollowAt) >= 0.35 else { return }
            guard let user = location.location, isUserMoving(user) else { return }
            lastHeadingCamera = now
            followUser()
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
        .navigationDestination(isPresented: $showAdd) {
            ManualPinView()
        }
        .navigationDestination(item: $settingsPin) { pin in
#if os(iOS)
            PinDetailView(pin: pin)
#else
            PinEditView(pin: pin)
#endif
        }
    }

    private var showsSaveHint: Bool {
        findPin == nil && (store.pins.isEmpty || !environment.settings.didMapSave) && !location.isDenied
    }

    private var showsRecenterHint: Bool {
        guard findPin != nil, let user = location.location, let region = visibleRegion else { return false }
        return !PinoMaps.contains(user.coordinate, in: region)
    }

    private var mapChrome: some View {
        Group {
            if let findPin {
                VStack(spacing: 2) {
                    HStack {
                        GuidanceButton()
                        Spacer(minLength: 0)
                        StopFindButton {
                            environment.stopFind()
                            PinoHaptics.click()
                        }
                    }
                    FindHUD(pin: findPin, route: route)
                }
            } else if showsSaveHint {
                MapSaveHint()
                    .allowsHitTesting(false)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
#if os(watchOS)
        .padding(.horizontal, 8)
#else
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
#endif
    }

    private func liveFindPin(_ pin: Pin) -> Pin {
        store.pins.first(where: { $0.id == pin.id }) ?? pin
    }

    private var findTravelMode: TravelMode? {
        guard let id = findPin?.id else { return nil }
        return store.pins.first(where: { $0.id == id })?.routeMode
    }

    private var routeSnap: PinoWayfinding.Snap? {
        guard findPin != nil, let user = location.location, let route else { return nil }
        guard let snap = PinoWayfinding.snap(from: user.coordinate, onto: route), snap.offset < 40 else {
            return nil
        }
        return snap
    }

    private func puckCoordinate(for user: CLLocation) -> CLLocationCoordinate2D {
        routeSnap?.coordinate ?? user.coordinate
    }

    private func handleIconTap(_ pin: Pin) {
        pinTapAt = Date()
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
        pinTapAt = Date()
        pendingPinTap?.cancel()
        pendingPinTap = nil
        settingsPin = pin
        PinoHaptics.click()
    }

    private func handleMapTap() {
        if let pinTapAt, Date().timeIntervalSince(pinTapAt) < 0.12 {
            return
        }
        showAdd = true
        PinoHaptics.click()
    }

    private func recenterOnUser() {
        followLocked = true
        followUser()
        PinoHaptics.click()
    }

    private func isUserMoving(_ user: CLLocation) -> Bool {
        if user.speed >= 0.7 { return true }
        if let lastFollowed, user.distance(from: lastFollowed) >= 8 { return true }
        return false
    }

    private func unlockFollowIfPanned(center: CLLocationCoordinate2D) {
        guard findPin != nil, followLocked, let user = location.location else { return }
        guard !isUserMoving(user) else { return }
        if GeoMath.distance(from: center, to: user.coordinate) > 28 {
            followLocked = false
        }
    }

    private func followUser() {
        guard let user = location.location, user.horizontalAccuracy > 0, user.horizontalAccuracy < 45 else {
            return
        }
#if os(iOS)
        if findPin == nil {
            camera = PinoMaps.userCamera(user.coordinate)
            lastFollowed = user
            lastFollowAt = Date()
            return
        }
#endif
        camera = PinoMaps.followUser(user, compass: location.currentHeading, route: route)
        lastFollowed = user
        lastFollowAt = Date()
    }

    private func updateFollow() {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-pino-overview") { return }
#endif
        guard let user = location.location, user.horizontalAccuracy > 0, user.horizontalAccuracy < 45 else {
            return
        }
        if findPin != nil {
            if isUserMoving(user) {
                followLocked = true
            }
            guard followLocked else { return }
            if Date().timeIntervalSince(lastFollowAt) < 0.4 { return }
            followUser()
            return
        }
        if let lastFollowed, user.speed < 0.4, user.distance(from: lastFollowed) < 10 {
            return
        }
        if Date().timeIntervalSince(lastFollowAt) < 1 {
            return
        }
        followUser()
    }

    private func loadRoute() async {
        guard let pin = findPin,
              store.pins.contains(where: { $0.id == pin.id }),
              let origin = location.location else { return }
        let mode = liveFindPin(pin).routeMode
        if let route, PinoWayfinding.isFollowing(origin.coordinate, route: route, mode: mode) {
            return
        }
        if let lastRoutedFrom, origin.distance(from: lastRoutedFrom) < 40 {
            return
        }
        lastRoutedFrom = origin
        let found = await PinoDirections.route(
            from: origin.coordinate,
            to: pin.coordinate,
            mode: mode
        )
        guard findPin?.id == pin.id else { return }
        if let found {
            route = found
            if followLocked {
                followUser()
            }
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
    @EnvironmentObject private var store: PinStore

    private var live: Pin {
        store.pins.first(where: { $0.id == pin.id }) ?? pin
    }

    private var distanceText: String {
        if let meters = location.distance(to: pin) {
            return Formatters.distance(meters)
        }
        if let route {
            return Formatters.distance(route.distance)
        }
        return ""
    }

    private var timeText: String {
        guard let route else { return "" }
        return Formatters.duration(route.expectedTravelTime)
    }

    var body: some View {
        Button(action: cycleMode) {
            HStack(spacing: 4) {
                Image(systemName: live.routeMode.symbol)
                if !distanceText.isEmpty {
                    Text(distanceText)
                }
                if !distanceText.isEmpty && !timeText.isEmpty {
                    Text("·")
                        .opacity(0.5)
                }
                if !timeText.isEmpty {
                    Text(timeText)
                }
            }
#if os(watchOS)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
#else
            .font(.caption.weight(.semibold))
#endif
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.black.opacity(0.55), in: Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityLabel([live.routeMode.label, distanceText, timeText].filter { !$0.isEmpty }.joined(separator: ", "))
        .accessibilityHint("Travel mode")
    }

    private func cycleMode() {
        var updated = live
        updated.travelMode = live.routeMode.next
        store.update(updated)
        PinoHaptics.click()
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

    private var arrived: Bool {
        guard let user = location.location else { return false }
        return PinoWayfinding.hasArrived(user: user, pin: pin)
    }

    var body: some View {
        GeometryReader { geo in
            if arrived {
                Color.clear
            } else if let delta {
                let magnitude = abs(delta)
                if magnitude > 50, magnitude < 125 {
                    Color.clear
                } else {
                    let edge = PinoWayfinding.edge(for: delta)
                    let correct = magnitude <= 50
                    strip(edge: edge, color: correct ? Color.pino : .red, short: correct, in: geo.size)
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
        if pin.routeMode != .walking { return }
        PinoHaptics.wrongWay()
    }

    private func pulseWrongIfNeeded() {
        if let lastWrongPulse, Date().timeIntervalSince(lastWrongPulse) < 2.8 {
            return
        }
        pulseWrong()
    }

    private func strip(edge: Edge, color: Color, short: Bool, in size: CGSize) -> some View {
#if os(watchOS)
        let thickness = min(size.width, size.height) * (short ? 0.14 : 0.18)
#else
        let thickness = min(size.width, size.height) * (short ? 0.09 : 0.13)
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
