import Combine
import Foundation

final class SettingsStore: ObservableObject {
    @Published var retention: RetentionPeriod {
        didSet { UserDefaults.standard.set(retention.rawValue, forKey: Keys.retention) }
    }

    @Published var proximityAlerts: Bool {
        didSet { UserDefaults.standard.set(proximityAlerts, forKey: Keys.proximity) }
    }

    @Published var guidance: Bool {
        didSet { UserDefaults.standard.set(guidance, forKey: Keys.guidance) }
    }

    @Published var skinTone: SkinTone {
        didSet { UserDefaults.standard.set(skinTone.rawValue, forKey: Keys.skinTone) }
    }

    init() {
        retention = RetentionPeriod(rawValue: UserDefaults.standard.string(forKey: Keys.retention) ?? "") ?? .forever
        proximityAlerts = UserDefaults.standard.bool(forKey: Keys.proximity)
        guidance = UserDefaults.standard.object(forKey: Keys.guidance) as? Bool ?? true
        skinTone = SkinTone(rawValue: UserDefaults.standard.integer(forKey: Keys.skinTone)) ?? .none
    }

    private enum Keys {
        static let retention = "pino.retention"
        static let proximity = "pino.proximityAlerts"
        static let guidance = "pino.guidance"
        static let skinTone = "pino.skinTone"
    }
}

final class PinStore: ObservableObject {
    @Published private(set) var pins: [Pin] = []

    private var deletedIds: [UUID] = []
    private var applyingRemote = false
    private let settings: SettingsStore
    private let sync = SyncService()
    private let fileURL: URL

    init(settings: SettingsStore) {
        self.settings = settings
        fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("pino-pins.json")
        load()
        prune()
        sync.onReceive = { [weak self] snapshot in
            self?.apply(snapshot)
        }
        sync.start()
        push()
    }

    var lastPin: Pin? {
        pins.max(by: { $0.createdAt < $1.createdAt })
    }

    func add(_ pin: Pin) {
        pins.insert(pin, at: 0)
        persistAndPush()
    }

    func update(_ pin: Pin) {
        guard let index = pins.firstIndex(where: { $0.id == pin.id }) else { return }
        var updated = pin
        updated.updatedAt = Date()
        pins[index] = updated
        persistAndPush()
    }

    func delete(_ pin: Pin) {
        pins = pins.filter { $0.id != pin.id }
        if !deletedIds.contains(pin.id) {
            deletedIds.append(pin.id)
            if deletedIds.count > 200 {
                deletedIds = Array(deletedIds.suffix(200))
            }
        }
        persistAndPush()
    }

    func prune() {
        guard let duration = settings.retention.duration else { return }
        let cutoff = Date().addingTimeInterval(-duration)
        let expired = pins.filter { $0.createdAt < cutoff }
        guard !expired.isEmpty else { return }
        let ids = Set(expired.map(\.id))
        pins.removeAll { ids.contains($0.id) }
        deletedIds.append(contentsOf: ids)
        if deletedIds.count > 200 {
            deletedIds = Array(deletedIds.suffix(200))
        }
        persistAndPush()
    }

    private func apply(_ snapshot: PinSnapshot) {
        applyingRemote = true
        defer { applyingRemote = false }

        var deleted = Set(deletedIds)
        deleted.formUnion(snapshot.deletedIds)

        var map = Dictionary(uniqueKeysWithValues: pins.map { ($0.id, $0) })
        for pin in snapshot.pins where !deleted.contains(pin.id) {
            if let existing = map[pin.id] {
                if pin.updatedAt > existing.updatedAt {
                    map[pin.id] = pin
                }
            } else {
                map[pin.id] = pin
            }
        }
        snapshot.deletedIds.forEach { map.removeValue(forKey: $0) }

        let merged = map.values.sorted { $0.createdAt > $1.createdAt }
        let newDeleted = Array(deleted.suffix(200))
        guard merged != pins || newDeleted != deletedIds else { return }
        pins = merged
        deletedIds = newDeleted
        persist()
        let incoming = PinSnapshot(
            pins: snapshot.pins.sorted { $0.id.uuidString < $1.id.uuidString },
            deletedIds: snapshot.deletedIds.sorted { $0.uuidString < $1.uuidString }
        )
        let result = PinSnapshot(
            pins: merged.sorted { $0.id.uuidString < $1.id.uuidString },
            deletedIds: newDeleted.sorted { $0.uuidString < $1.uuidString }
        )
        if result != incoming {
            applyingRemote = false
            push()
        }
    }

    private func persistAndPush() {
        persist()
        push()
    }

    private func push() {
        guard !applyingRemote else { return }
        sync.send(PinSnapshot(pins: pins, deletedIds: deletedIds))
    }

    private func persist() {
        let state = PinSnapshot(pins: pins, deletedIds: deletedIds)
        guard let data = try? PinoJSON.encoder.encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let state = try? PinoJSON.decoder.decode(PinSnapshot.self, from: data) else { return }
        pins = state.pins.sorted { $0.createdAt > $1.createdAt }
        deletedIds = state.deletedIds
    }
}
