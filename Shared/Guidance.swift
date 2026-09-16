import AVFoundation
import CoreLocation
import MapKit
import SwiftUI

enum VoiceGuide {
    private static let synth = AVSpeechSynthesizer()
    private static var lastKey = ""
    private static var lastAt = Date.distantPast

    static func tooSoon(_ interval: TimeInterval) -> Bool {
        Date().timeIntervalSince(lastAt) < interval
    }

    static func stop() {
        synth.stopSpeaking(at: .immediate)
        lastKey = ""
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    static func say(_ phrase: String, key: String, minInterval: TimeInterval, force: Bool = false) {
        let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let now = Date()
        if !force, key == lastKey, now.timeIntervalSince(lastAt) < minInterval { return }
        if !force, now.timeIntervalSince(lastAt) < 2.2 { return }
        lastKey = key
        lastAt = now
        prepareSession()
        synth.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.94
        synth.speak(utterance)
    }

    private static func prepareSession() {
        let session = AVAudioSession.sharedInstance()
#if os(iOS)
        try? session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
#else
        try? session.setCategory(.playback, mode: .default, options: [.duckOthers])
#endif
        try? session.setActive(true)
    }
}

struct FindGuidance: View {
    let pin: Pin
    var route: MKRoute?
    @EnvironmentObject private var location: LocationService
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var store: PinStore

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear { announce(force: true) }
            .onDisappear { VoiceGuide.stop() }
            .onChange(of: location.location?.timestamp) { _, _ in announce() }
#if os(iOS)
            .onChange(of: location.heading?.timestamp) { _, _ in
                guard route == nil else { return }
                announce()
            }
#endif
            .onChange(of: route?.distance) { _, _ in announce(force: true) }
            .onChange(of: settings.guidance) { _, on in
                if on {
                    announce(force: true)
                } else {
                    VoiceGuide.stop()
                }
            }
    }

    private func announce(force: Bool = false) {
        guard store.pins.contains(where: { $0.id == pin.id }) else {
            VoiceGuide.stop()
            return
        }
        guard settings.guidance, let user = location.location else { return }
#if os(watchOS)
        if !force, VoiceGuide.tooSoon(3) { return }
#endif
        if PinoWayfinding.hasArrived(user: user, pin: pin) {
            VoiceGuide.say(
                pin.displayName,
                key: "here-\(pin.id.uuidString)",
                minInterval: 40,
                force: force
            )
            return
        }
        if let route, let next = PinoWayfinding.upcomingStep(in: route, from: user.coordinate) {
            let phrase = next.remaining > 90
                ? "\(Formatters.distance(next.remaining)). \(next.instruction)"
                : next.instruction
            VoiceGuide.say(
                phrase,
                key: next.instruction,
                minInterval: next.remaining > 90 ? 22 : 10,
                force: force
            )
            return
        }
        guard let delta = PinoWayfinding.relativeDelta(
            from: user,
            to: pin.coordinate,
            heading: location.currentHeading
        ) else { return }
        let cue = PinoWayfinding.spokenCue(delta: delta)
        let meters: String
        if let value = location.distance(to: pin) {
            meters = Formatters.distance(value)
        } else {
            meters = ""
        }
        let phrase = meters.isEmpty ? cue : "\(meters). \(cue)"
        VoiceGuide.say(phrase, key: cue, minInterval: 9, force: force)
    }
}
