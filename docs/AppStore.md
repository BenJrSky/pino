# App Store Connect — PINO

Paste this after the Apple Developer Program is active. Create the app with bundle `it.devben.pino` (Watch `it.devben.pino.watchkitapp`).

## Identity
- Name: PINO
- Subtitle (EN, 30 chars): A pin. And you're back.
- Subtitle (IT): Un pin. E torni.
- Bundle ID: `it.devben.pino`
- Watch: `it.devben.pino.watchkitapp`
- SKU: `pino`
- Category: Navigation
- Secondary: Travel
- Age: 4+
- Price: Free
- Copyright: 2026 DevBen
- Availability: **All countries and regions** (App Store Connect → Pricing and Availability). The `it.` in the bundle ID is reverse-DNS, not a store restriction.

## URLs (GitHub Pages)

Site files live in `docs/` (`index.html`, `privacy.html`). Workflow: `.github/workflows/pages.yml`.

After the first push of this repo to `main`:
1. GitHub repo **Settings → Pages → Source: GitHub Actions**
2. Wait for the **Pages** workflow on the Actions tab
3. URLs:
   - Support / marketing: `https://benjrsky.github.io/pino/`
   - Privacy (required): `https://benjrsky.github.io/pino/privacy.html`

The repo must be **public** for free GitHub Pages. The same privacy text is in **Settings → Privacy Policy**.

## Promotional text (EN, 170 characters max)
A pin. And you're back. Tap the map, walk, PINO brings you back. iPhone and Apple Watch.

## Promotional text (IT)
Un pin. E torni. Tocca la mappa, cammina, PINO ti riporta. iPhone e Apple Watch.

## Description (EN)
A pin. And you're back.

Tap the map on iPhone or Apple Watch. Save a hotel, a parked car, a square, a shop — any place. Then walk. When you want back, tap it. PINO shows the distance, the time, and a route. On foot, by car, or on transit. While you move, the map is first-person.

Places stay on your iPhone and Watch and sync between them, even offline for GPS saves. Optional alerts can remind you when you are near a saved place again. No account. No PINO server.

## Description (IT)
Un pin. E torni.

Tocca la mappa su iPhone o Apple Watch. Salva l’hotel, l’auto, una piazza, un negozio — qualunque posto. Poi cammina. Quando vuoi tornare, tocca il pin. PINO mostra distanza, tempo e il percorso. A piedi, in auto o con i mezzi. In movimento la mappa è in prima persona.

I posti restano su iPhone e Watch e si sincronizzano, anche offline per il GPS. Gli avvisi opzionali ti ricordano quando sei di nuovo vicino. Senza account. Senza server PINO.

## Keywords (100 characters max)
walk,city,tourist,travel,hotel,pin,find,map,watch,gps,route,back,park,visit,location

## What’s New (1.0)
First release. A pin. And you're back. iPhone and Apple Watch.

Prima versione. Un pin. E torni. iPhone e Apple Watch.

## Export compliance
The project sets `ITSAppUsesNonExemptEncryption = NO`. In App Store Connect answer: this app uses only standard encryption (HTTPS / MapKit). No custom crypto.

## Age rating
None of the content descriptors apply (no violence, sexual content, profanity, alcohol, smoking, drugs, gambling, horror, medical, unrestricted web, or user-generated public content). Not Made for Kids. Result: 4+.

## Privacy nutrition label
Do you collect data? Yes.

- Precise Location — collected — not linked to identity — not used for tracking — purpose: App Functionality
- Tracking: No
- Used for third-party advertising: No
- Used for developer’s advertising: No
- Other data types: No (pins stay on device; no account, no analytics SDK)

## Review notes
PINO saves user-created map pins and helps find them again.

Location When In Use: save and navigate to pins.

Location Always: only if the user enables Proximity alerts in Settings. Used for geofence notifications (CLCircularRegion), not continuous background GPS. The app does not use the location background mode.

Notifications: only for those proximity alerts.

Apple Watch companion is required for the Watch app. Test save on Watch, list on iPhone, and Find on the map.

Demo: allow location, tap the map, choose an icon, open Pins, tap Find. Sample pins are not required; the map is empty until you tap.

## Screenshots

Ready in `docs/screenshots/` (simulator, 9:41 status bar, sample pins in Rome). Upload in this order.

iPhone 6.9" (1320 × 2868, iPhone 17 Pro Max):
1. `iphone-map.png` — map with saved pins
2. `iphone-find.png` — Find with blue route and distance/time
3. `iphone-pins.png` — Pins list with travel mode
4. `iphone-settings.png` — Settings including Privacy Policy

Apple Watch Series 11 46mm (416 × 496):
1. `watch-map.png` — map with pins
2. `watch-find.png` — Find with route
3. `watch-pins.png` — Pins list

If Connect asks for 49mm Ultra, recapture on Apple Watch Ultra 3 in Simulator.
