// KEYSTONE_TV_v1 - sample data for screenshots and for trying the app without a server (launch argument -demo).
import Foundation

enum TVDemo {
    static var isOn: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }

    /// -demoSlide <name> pins one slide (for screenshots).
    static var pinnedSlide: TVSlide? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-demoSlide"), i + 1 < args.count else { return nil }
        return TVSlide(rawValue: args[i + 1])
    }

    static var showsCelebration: Bool { ProcessInfo.processInfo.arguments.contains("-demoCelebrate") }
    static var showsPairing: Bool { ProcessInfo.processInfo.arguments.contains("-demoPairing") }

    static let board: TVBoard = {
        func b(_ id: String, _ name: String, _ ini: String, _ team: String, _ teamId: String, _ vol: Double, _ deals: Int, _ goal: Double?, _ rank: Int, _ mv: Int) -> TVBroker {
            TVBroker(user_id: id, name: name, initials: ini, photo_url: nil, team_id: teamId, team: team, volume: vol, deals: deals, goal: goal, rank: rank, movement: mv)
        }
        let brokers = [
            b("1", "Jordan Lee", "JL", "Summit", "t1", 1_840_000, 7, 1_500_000, 1, 1),
            b("2", "Priya Shah", "PS", "Northern Lights", "t2", 1_620_000, 6, 1_500_000, 2, -1),
            b("3", "Marcus Bell", "MB", "Summit", "t1", 1_210_000, 5, 1_250_000, 3, 2),
            b("4", "Sofia Ramirez", "SR", "Northern Lights", "t2", 980_000, 4, 1_000_000, 4, 0),
            b("5", "Ethan Clarke", "EC", "Prairie", "t3", 860_000, 4, 1_000_000, 5, -2),
            b("6", "Hannah Kim", "HK", "Prairie", "t3", 640_000, 3, 750_000, 6, 1),
            b("7", "Liam O'Connor", "LO", "Summit", "t1", 410_000, 2, 750_000, 7, 0),
            b("8", "Ava Thompson", "AT", "Northern Lights", "t2", 255_000, 1, 500_000, 8, -1),
        ]
        let teams = [
            TVTeam(id: "t1", name: "Summit", volume: 3_460_000, deals: 14, goal: 3_500_000, brokers: 3, rank: 1),
            TVTeam(id: "t2", name: "Northern Lights", volume: 2_855_000, deals: 11, goal: 3_000_000, brokers: 3, rank: 2),
            TVTeam(id: "t3", name: "Prairie", volume: 1_500_000, deals: 7, goal: 1_750_000, brokers: 2, rank: 3),
        ]
        let iso = ISO8601DateFormatter()
        let now = Date()
        let recent = [
            TVFunded(id: "r1", broker: "Marcus Bell", initials: "MB", photo_url: nil, team: "Summit", amount: 325_000, funded_at: iso.string(from: now.addingTimeInterval(-600))),
            TVFunded(id: "r2", broker: "Priya Shah", initials: "PS", photo_url: nil, team: "Northern Lights", amount: 410_000, funded_at: iso.string(from: now.addingTimeInterval(-7_200))),
            TVFunded(id: "r3", broker: "Jordan Lee", initials: "JL", photo_url: nil, team: "Summit", amount: 180_000, funded_at: iso.string(from: now.addingTimeInterval(-20_000))),
            TVFunded(id: "r4", broker: "Hannah Kim", initials: "HK", photo_url: nil, team: "Prairie", amount: 95_000, funded_at: iso.string(from: now.addingTimeInterval(-90_000))),
            TVFunded(id: "r5", broker: "Ethan Clarke", initials: "EC", photo_url: nil, team: "Prairie", amount: 260_000, funded_at: iso.string(from: now.addingTimeInterval(-180_000))),
        ]
        return TVBoard(
            company: TVCompany(name: "Northwind Capital", logo_url: nil, primary_color: "#2563EB"),
            screen: TVScreenSettings(name: "Sales floor", slides: TVSlide.allCases.map(\.rawValue), rotate_seconds: 20),
            period: TVPeriod(month: "2026-11", label: "November 2026", days_left: 5),
            currency: "CAD", brokers: brokers, teams: teams,
            office: TVOffice(volume: 7_815_000, deals: 32, goal: 8_250_000), recent: recent)
    }()
}
