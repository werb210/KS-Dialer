// KEYSTONE_TV_v1 - what the brokerage's server sends (GET {server}/api/scoreboard/tv) and what KS-Ops sends while pairing.
import Foundation

struct TVCompany: Codable, Equatable {
    var name: String
    var logo_url: String?
    var primary_color: String?
}

struct TVScreenSettings: Codable, Equatable {
    var name: String
    var slides: [String]
    var rotate_seconds: Int
}

struct TVPeriod: Codable, Equatable {
    var month: String
    var label: String
    var days_left: Int
}

struct TVBroker: Codable, Equatable, Identifiable {
    var user_id: String
    var name: String
    var initials: String
    var photo_url: String?
    var team_id: String?
    var team: String?
    var volume: Double
    var deals: Int
    var goal: Double?
    var rank: Int
    var movement: Int
    var id: String { user_id }
}

struct TVTeam: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var volume: Double
    var deals: Int
    var goal: Double?
    var brokers: Int
    var rank: Int
}

struct TVOffice: Codable, Equatable {
    var volume: Double
    var deals: Int
    var goal: Double?
}

struct TVFunded: Codable, Equatable, Identifiable {
    var id: String
    var broker: String
    var initials: String
    var photo_url: String?
    var team: String?
    var amount: Double
    var funded_at: String
}

struct TVBoard: Codable, Equatable {
    var company: TVCompany?
    var screen: TVScreenSettings?
    var period: TVPeriod
    var currency: String
    var brokers: [TVBroker]
    var teams: [TVTeam]
    var office: TVOffice
    var recent: [TVFunded]
}

struct TVPairStart: Codable {
    var code: String
    var device_secret: String
    var expires_in: Int
}

struct TVPairCollect: Codable {
    var state: String
    var server_url: String?
    var token: String?
    var company: TVCompany?
}

/// The slides a TV can rotate through, in the order Settings > Screens lists them.
enum TVSlide: String, CaseIterable {
    case leaderboard, teams, goal, recent, deals
}

enum TVFormat {
    static func money(_ value: Double, currency: String = "CAD") -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency
        f.maximumFractionDigits = 0
        f.locale = Locale(identifier: "en_CA")
        return f.string(from: NSNumber(value: value)) ?? "$\(Int(value))"
    }

    /// $1.2M / $850K for big headline numbers.
    static func short(_ value: Double) -> String {
        if value >= 1_000_000 { return String(format: "$%.1fM", value / 1_000_000) }
        if value >= 1_000 { return String(format: "$%.0fK", value / 1_000) }
        return "$\(Int(value))"
    }

    static func percent(_ value: Double, of goal: Double?) -> Int? {
        guard let goal, goal > 0 else { return nil }
        return min(Int((value / goal * 100).rounded()), 999)
    }

    /// "ABC234" shown as "ABC 234" so it reads well across a room.
    static func spacedCode(_ code: String) -> String {
        guard code.count == 6 else { return code }
        return "\(code.prefix(3)) \(code.suffix(3))"
    }

    static func ago(_ iso: String, now: Date = Date()) -> String {
        let f = ISO8601DateFormatter()
        guard let date = f.date(from: iso) else { return "" }
        let mins = Int(now.timeIntervalSince(date) / 60)
        if mins < 1 { return "just now" }
        if mins < 60 { return "\(mins) min ago" }
        let hours = mins / 60
        if hours < 24 { return "\(hours) h ago" }
        let days = hours / 24
        return days == 1 ? "yesterday" : "\(days) days ago"
    }
}
