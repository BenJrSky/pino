import CoreLocation
import Foundation

enum PinCategory: String, Codable, CaseIterable, Identifiable {
    case car, motorcycle, scooter, bike, bus, train, taxi, boat, airplane, parking
    case restaurant, hamburger, pizza, iceCream, coffee, bar
    case hotel, home, work, beach, park, forest, mountain, lake, monument, camp
    case luggage, keys, pet
    case man, woman, boy, girl
    case pharmacy, hospital, gas, shop, gym, school
    case place, other

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .car: "🚗"
        case .motorcycle: "🏍️"
        case .scooter: "🛵"
        case .bike: "🚲"
        case .bus: "🚌"
        case .train: "🚆"
        case .taxi: "🚕"
        case .boat: "⛵"
        case .airplane: "✈️"
        case .parking: "🅿️"
        case .restaurant: "🍽️"
        case .hamburger: "🍔"
        case .pizza: "🍕"
        case .iceCream: "🍦"
        case .coffee: "☕"
        case .bar: "🍺"
        case .hotel: "🏨"
        case .home: "🏠"
        case .work: "🏢"
        case .beach: "🏖️"
        case .park: "🌳"
        case .forest: "🌲"
        case .mountain: "⛰️"
        case .lake: "🏞️"
        case .monument: "🏛️"
        case .camp: "⛺"
        case .luggage: "🧳"
        case .keys: "🔑"
        case .pet: "🐶"
        case .man: "👨"
        case .woman: "👩"
        case .boy: "👦"
        case .girl: "👧"
        case .pharmacy: "💊"
        case .hospital: "🏥"
        case .gas: "⛽"
        case .shop: "🛍️"
        case .gym: "💪"
        case .school: "🏫"
        case .place: "📍"
        case .other: "📦"
        }
    }

    var label: String {
        switch self {
        case .car: String(localized: "Car")
        case .motorcycle: String(localized: "Motorcycle")
        case .scooter: String(localized: "Scooter")
        case .bike: String(localized: "Bicycle")
        case .bus: String(localized: "Bus")
        case .train: String(localized: "Train")
        case .taxi: String(localized: "Taxi")
        case .boat: String(localized: "Boat")
        case .airplane: String(localized: "Airplane")
        case .parking: String(localized: "Parking")
        case .restaurant: String(localized: "Restaurant")
        case .hamburger: String(localized: "Hamburger")
        case .pizza: String(localized: "Pizza")
        case .iceCream: String(localized: "Ice cream")
        case .coffee: String(localized: "Coffee")
        case .bar: String(localized: "Bar")
        case .hotel: String(localized: "Hotel")
        case .home: String(localized: "Home")
        case .work: String(localized: "Work")
        case .beach: String(localized: "Beach")
        case .park: String(localized: "Park")
        case .forest: String(localized: "Forest")
        case .mountain: String(localized: "Mountain")
        case .lake: String(localized: "Lake")
        case .monument: String(localized: "Monument")
        case .camp: String(localized: "Camp")
        case .luggage: String(localized: "Luggage")
        case .keys: String(localized: "Keys")
        case .pet: String(localized: "Pet")
        case .man: String(localized: "Man")
        case .woman: String(localized: "Woman")
        case .boy: String(localized: "Boy")
        case .girl: String(localized: "Girl")
        case .pharmacy: String(localized: "Pharmacy")
        case .hospital: String(localized: "Hospital")
        case .gas: String(localized: "Gas")
        case .shop: String(localized: "Shop")
        case .gym: String(localized: "Gym")
        case .school: String(localized: "School")
        case .place: String(localized: "Place")
        case .other: String(localized: "Other")
        }
    }

    var takesSkinTone: Bool {
        switch self {
        case .man, .woman, .boy, .girl: true
        default: false
        }
    }

    func emoji(tone: SkinTone = .none) -> String {
        takesSkinTone ? emoji + tone.modifier : emoji
    }

    static var alphabetically: [PinCategory] {
        let group: [PinCategory] = [.man, .woman, .boy, .girl]
        let clustered = Set(group)
        let rest = allCases.filter { !clustered.contains($0) }
            .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
        let anchor = group.map(\.label).min { $0.localizedStandardCompare($1) == .orderedAscending } ?? group[0].label
        if let index = rest.firstIndex(where: { $0.label.localizedStandardCompare(anchor) == .orderedDescending }) {
            return Array(rest[..<index]) + group + Array(rest[index...])
        }
        return rest + group
    }
}

enum SkinTone: Int, Codable, CaseIterable {
    case none
    case light
    case mediumLight
    case medium
    case mediumDark
    case dark

    var modifier: String {
        switch self {
        case .none: ""
        case .light: "\u{1F3FB}"
        case .mediumLight: "\u{1F3FC}"
        case .medium: "\u{1F3FD}"
        case .mediumDark: "\u{1F3FE}"
        case .dark: "\u{1F3FF}"
        }
    }

    func advanced(by delta: Int) -> SkinTone {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self) else { return self }
        return all[(index + delta + all.count) % all.count]
    }
}

enum RetentionPeriod: String, Codable, CaseIterable, Identifiable {
    case hours24
    case days3
    case days7
    case days30
    case forever

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hours24: String(localized: "24 hours")
        case .days3: String(localized: "3 days")
        case .days7: String(localized: "7 days")
        case .days30: String(localized: "30 days")
        case .forever: String(localized: "Forever")
        }
    }

    var duration: TimeInterval? {
        switch self {
        case .hours24: 24 * 3600
        case .days3: 3 * 24 * 3600
        case .days7: 7 * 24 * 3600
        case .days30: 30 * 24 * 3600
        case .forever: nil
        }
    }
}

enum TravelMode: String, Codable, CaseIterable, Identifiable {
    case walking
    case automobile
    case transit

    var id: String { rawValue }

    var label: String {
        switch self {
        case .walking: String(localized: "Walk")
        case .automobile: String(localized: "Drive")
        case .transit: String(localized: "Transit")
        }
    }

    var symbol: String {
        switch self {
        case .walking: "figure.walk"
        case .automobile: "car.fill"
        case .transit: "bus.fill"
        }
    }

    var next: TravelMode {
        let modes = Self.allCases
        guard let index = modes.firstIndex(of: self) else { return .walking }
        return modes[(index + 1) % modes.count]
    }
}

struct Pin: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String?
    var category: PinCategory?
    var latitude: Double
    var longitude: Double
    var address: String?
    var travelMode: TravelMode? = nil
    var skinTone: SkinTone? = nil
    var createdAt: Date
    var updatedAt: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var displayName: String {
        if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }
        if let category {
            return category.label
        }
        if let address, !address.isEmpty {
            return address
        }
        return String(localized: "Saved pin")
    }

    var symbol: String {
        category?.emoji(tone: skinTone ?? .none) ?? "📍"
    }

    var routeMode: TravelMode {
        travelMode ?? .walking
    }

    var mapsURL: URL {
        var components = URLComponents(string: "https://maps.apple.com/")!
        components.queryItems = [
            URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"),
            URLQueryItem(name: "q", value: displayName)
        ]
        return components.url!
    }

    static func make(location: CLLocation, category: PinCategory? = nil, skinTone: SkinTone = .none) -> Pin {
        let now = Date()
        return Pin(
            id: UUID(),
            name: nil,
            category: category,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            address: Formatters.coordinate(location.coordinate),
            skinTone: category?.takesSkinTone == true ? skinTone : nil,
            createdAt: now,
            updatedAt: now
        )
    }
}

struct PinSnapshot: Codable, Equatable {
    var pins: [Pin]
    var deletedIds: [UUID]
}

enum GeoMath {
    static func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: from.latitude, longitude: from.longitude)
            .distance(from: CLLocation(latitude: to.latitude, longitude: to.longitude))
    }

    static func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    static func lerp(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D, _ t: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: a.latitude + (b.latitude - a.latitude) * t,
            longitude: a.longitude + (b.longitude - a.longitude) * t
        )
    }

    static func project(_ point: CLLocationCoordinate2D, onto a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let ab = distance(from: a, to: b)
        guard ab > 0.4 else { return a }
        let ap = distance(from: a, to: point)
        let bp = distance(from: b, to: point)
        let t = (ap * ap + ab * ab - bp * bp) / (2 * ab * ab)
        return lerp(a, b, min(1, max(0, t)))
    }
}

enum Formatters {
    static let measurement: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.unitOptions = .naturalScale
        formatter.unitStyle = .medium
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter
    }()

    static let date: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static func coordinate(_ value: CLLocationCoordinate2D) -> String {
        String(format: "%.5f, %.5f", value.latitude, value.longitude)
    }

    static func distance(_ meters: CLLocationDistance) -> String {
        measurement.string(from: Measurement(value: meters, unit: UnitLength.meters))
    }

    static func duration(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = interval >= 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropLeading
        formatter.calendar = Calendar.autoupdatingCurrent
        return formatter.string(from: max(interval, 60)) ?? ""
    }
}

enum PinoJSON {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
