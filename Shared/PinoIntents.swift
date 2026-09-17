import AppIntents

struct SavePinIntent: AppIntent {
    static var title: LocalizedStringResource = "Save pin"
    static var description: IntentDescription = "Save a pin at your current location."
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let category = AppEnvironment.shared.settings.lastCategory
        _ = try await AppEnvironment.shared.savePin(category: category)
        return .result(dialog: "Pin saved.")
    }
}

struct SaveCarPinIntent: AppIntent {
    static var title: LocalizedStringResource = "Save car"
    static var description: IntentDescription = "Save a pin for your parked car."
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        _ = try await AppEnvironment.shared.savePin(category: .car)
        return .result(dialog: "Car saved.")
    }
}

struct FindLastPinIntent: AppIntent {
    static var title: LocalizedStringResource = "Find last pin"
    static var description: IntentDescription = "Find the last pin you saved."
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let pin = AppEnvironment.shared.store.lastPin else {
            return .result(dialog: "No pins yet.")
        }
        AppEnvironment.shared.find(pin)
        return .result(dialog: IntentDialog(stringLiteral: pin.displayName))
    }
}

struct PinoShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .lime

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SavePinIntent(),
            phrases: [
                "\(.applicationName) save",
                "\(.applicationName) salva",
                "\(.applicationName) enregistrer",
                "\(.applicationName) guardar",
                "\(.applicationName) speichern"
            ],
            shortTitle: "Save pin",
            systemImageName: "plus"
        )
        AppShortcut(
            intent: SaveCarPinIntent(),
            phrases: [
                "\(.applicationName) my car",
                "\(.applicationName) l'auto",
                "\(.applicationName) la macchina",
                "\(.applicationName) ma voiture",
                "\(.applicationName) mi coche",
                "\(.applicationName) el coche",
                "\(.applicationName) mein Auto"
            ],
            shortTitle: "Save car",
            systemImageName: "car.fill"
        )
        AppShortcut(
            intent: FindLastPinIntent(),
            phrases: [
                "\(.applicationName) find",
                "\(.applicationName) trova",
                "\(.applicationName) trouve",
                "\(.applicationName) encuentra",
                "\(.applicationName) finden"
            ],
            shortTitle: "Find",
            systemImageName: "location.north.fill"
        )
    }
}
