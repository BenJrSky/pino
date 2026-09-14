import CoreLocation
import Foundation

enum PinCategory: String, Codable, CaseIterable, Identifiable {
    case car, motorcycle, scooter, bike, bus, train, taxi, boat, airplane, parking
    case restaurant, hamburger, pizza, iceCream, coffee, bar
    case hotel, home, work, beach, park, forest, mountain, lake, monument, camp
    case luggage, keys, pet, pharmacy, hospital, gas, shop, gym, school
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

struct Pin: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String?
    var category: PinCategory?
    var latitude: Double
    var longitude: Double
    var address: String?
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
        category?.emoji ?? "📍"
    }

    static func make(location: CLLocation, category: PinCategory? = nil) -> Pin {
        let now = Date()
        return Pin(
            id: UUID(),
            name: nil,
            category: category,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            address: nil,
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

    static func distance(_ meters: CLLocationDistance) -> String {
        measurement.string(from: Measurement(value: meters, unit: UnitLength.meters))
    }

    static func duration(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = interval >= 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .short
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
