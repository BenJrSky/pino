import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Proximity alerts", isOn: $settings.proximityAlerts)
                } footer: {
                    Text("PinO can remind you when you are near a saved pin again.")
                }

                Section {
                    Toggle("Voice and vibration", isOn: $settings.guidance)
                } footer: {
                    Text("Spoken directions and haptics while you find a pin.")
                }

                Section {
                    Picker("Keep pins", selection: $settings.retention) {
                        ForEach(RetentionPeriod.allCases) { period in
                            Text(period.label).tag(period)
                        }
                    }
                } footer: {
                    Text("Pins older than the selected period are deleted automatically. Choose Forever to keep them all.")
                }

                Section {
                    NavigationLink("Privacy Policy") {
                        PrivacyPolicyView()
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            Text(privacyBody)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var privacyBody: String {
        switch Locale.current.language.languageCode?.identifier {
        case "it":
            return """
PinO salva i punti che crei su questo iPhone e Apple Watch. Posizioni, nomi, categorie e indirizzi restano sui tuoi dispositivi, si copiano su iCloud se è attivo, e si sincronizzano con l’Apple Watch con WatchConnectivity. Non vengono inviati a un server di PinO.

Quando salvi o ritrovi un punto, MapKit e il geocoding di Apple possono ricevere le coordinate per mostrare mappe, indirizzi e percorsi. Apple tratta quei dati secondo i propri termini.

Se attivi gli avvisi di prossimità, PinO chiede l’accesso Always alla posizione e le notifiche, per avvisarti quando torni vicino a un punto salvato. Puoi disattivarli in Impostazioni. Il ritrova usa la posizione solo mentre l’app è aperta.

PinO non usa pubblicità, SDK di analisi né tracciamento. Non c’è un account. Eliminando l’app i dati spariscono dal dispositivo. La copia su iCloud resta finché non la rimuovi da tutti i dispositivi.

Domande: https://benjrsky.github.io/pino/privacy.html oppure il contatto dello sviluppatore nella scheda App Store di PinO (it.devben.pino).
"""
        case "de":
            return """
PinO speichert Pins, die du auf diesem iPhone und Apple Watch anlegst. Orte, Namen, Kategorien und Adressen bleiben auf deinen Geräten, werden bei aktivem iCloud dorthin kopiert und per WatchConnectivity mit der Apple Watch synchronisiert. Sie werden nicht auf einen PinO-Server hochgeladen.

Beim Speichern oder Finden eines Pins können Apple MapKit und Geocoding Koordinaten erhalten, um Karten, Adressen und Routen zu zeigen. Apple verarbeitet diese Daten nach den eigenen Bedingungen.

Wenn du Näherungswarnungen einschaltest, fragt PinO nach Immer-Standortzugriff und Mitteilungen, um dich zu benachrichtigen, wenn du wieder in der Nähe eines Pins bist. Das kannst du in den Einstellungen ausschalten. Die Suche nutzt den Standort nur bei geöffneter App.

PinO verwendet keine Werbung, keine Analyse-SDKs und kein Tracking. Es gibt kein Konto. Das Löschen der App oder einzelner Pins entfernt die Daten vom Gerät.

Fragen: https://benjrsky.github.io/pino/privacy.html oder der Entwicklerkontakt auf der App-Store-Seite von PinO (it.devben.pino).
"""
        case "es":
            return """
PinO guarda los puntos que creas en este iPhone y Apple Watch. Ubicaciones, nombres, categorías y direcciones permanecen en tus dispositivos, se copian en iCloud si está activo y se sincronizan con el Apple Watch con WatchConnectivity. No se envían a un servidor de PinO.

Al guardar o encontrar un punto, MapKit y el geocodificado de Apple pueden recibir coordenadas para mostrar mapas, direcciones y rutas. Apple trata esos datos según sus propios términos.

Si activas las alertas de proximidad, PinO pide acceso Siempre a la ubicación y notificaciones para avisarte cuando vuelves cerca de un punto. Puedes desactivarlas en Ajustes. Buscar un punto usa la ubicación solo con la app abierta.

PinO no usa publicidad, SDK de analítica ni seguimiento. No hay cuenta. Al borrar la app, o los puntos de la lista, los datos desaparecen del dispositivo.

Preguntas: https://benjrsky.github.io/pino/privacy.html o el contacto del desarrollador en la ficha de App Store de PinO (it.devben.pino).
"""
        case "fr":
            return """
PinO enregistre les points que tu crées sur cet iPhone et Apple Watch. Lieux, noms, catégories et adresses restent sur tes appareils, se copient sur iCloud s’il est activé, et se synchronisent avec l’Apple Watch via WatchConnectivity. Ils ne sont pas envoyés vers un serveur PinO.

Quand tu enregistres ou retrouves un point, MapKit et le géocodage d’Apple peuvent recevoir des coordonnées pour afficher cartes, adresses et itinéraires. Apple traite ces données selon ses propres conditions.

Si tu actives les alertes de proximité, PinO demande l’accès Toujours à la position et les notifications, pour t’avertir quand tu reviens près d’un point. Tu peux les désactiver dans Réglages. La recherche utilise la position seulement tant que l’app est ouverte.

PinO n’utilise ni publicité, ni SDK d’analyse, ni suivi. Il n’y a pas de compte. Supprimer l’app, ou les points dans la liste, efface ces données de l’appareil.

Questions : https://benjrsky.github.io/pino/privacy.html ou le contact développeur sur la fiche App Store de PinO (it.devben.pino).
"""
        default:
            return """
PinO saves pins you create on this iPhone and Apple Watch. Locations, names, categories, and addresses stay on your devices, copy to iCloud when it is on, and sync to Apple Watch with WatchConnectivity. They are not uploaded to a PinO server.

When you save or find a pin, Apple MapKit and geocoding may receive coordinates to show maps, addresses, and routes. Apple processes that data under its own terms.

If you turn on proximity alerts, PinO asks for Always location access and notifications so it can tell you when you return near a saved pin. You can turn this off in Settings. Finding a pin uses location only while the app is open.

PinO does not use advertising, analytics SDKs, or tracking. There is no account. Deleting the app removes that data from the device. The iCloud copy remains until you remove it from all devices.

Questions: https://benjrsky.github.io/pino/privacy.html or the developer contact on the App Store listing for PinO (it.devben.pino).
"""
        }
    }
}
