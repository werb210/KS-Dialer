// KEYSTONE_TV_v1 - decoding the server's scoreboard and the small formatting rules the screens rely on.
import XCTest
@testable import KeystoneTV

final class KeystoneTVTests: XCTestCase {
    func testDecodesTheServerBoard() throws {
        let json = """
        {"ok":true,"company":{"name":"Boreal Financial","logo_url":null,"primary_color":null},
         "screen":{"name":"Sales floor","slides":["leaderboard","teams"],"rotate_seconds":20},
         "period":{"month":"2026-11","label":"November 2026","days_left":5},"currency":"CAD",
         "brokers":[{"user_id":"u1","name":"Ann Able","initials":"AA","photo_url":null,"team_id":"t1","team":"Eagles","volume":250000,"deals":1,"goal":500000,"rank":1,"movement":2}],
         "teams":[{"id":"t1","name":"Eagles","volume":250000,"deals":1,"goal":null,"brokers":1,"rank":1}],
         "office":{"volume":250000,"deals":1,"goal":500000},
         "recent":[{"id":"a1","broker":"Ann Able","initials":"AA","photo_url":null,"team":"Eagles","amount":250000,"funded_at":"2026-11-25T22:53:46Z"}],
         "generated_at":"2026-11-25T23:00:00.000Z"}
        """
        let board = try JSONDecoder().decode(TVBoard.self, from: Data(json.utf8))
        XCTAssertEqual(board.brokers.first?.name, "Ann Able")
        XCTAssertEqual(board.screen?.slides.compactMap(TVSlide.init(rawValue:)), [.leaderboard, .teams])
        XCTAssertNil(board.teams.first?.goal)
    }

    func testDecodesPairingStates() throws {
        let waiting = try JSONDecoder().decode(TVPairCollect.self, from: Data(#"{"ok":true,"state":"waiting"}"#.utf8))
        XCTAssertEqual(waiting.state, "waiting")
        let paired = try JSONDecoder().decode(TVPairCollect.self, from: Data(#"{"ok":true,"state":"paired","server_url":"https://s.example","token":"tvs_x","company":{"name":"Acme"}}"#.utf8))
        XCTAssertEqual(paired.server_url, "https://s.example")
        XCTAssertEqual(paired.company?.name, "Acme")
    }

    func testFormatting() {
        XCTAssertEqual(TVFormat.spacedCode("ABC234"), "ABC 234")
        XCTAssertEqual(TVFormat.short(1_840_000), "$1.8M")
        XCTAssertEqual(TVFormat.short(850_000), "$850K")
        XCTAssertEqual(TVFormat.percent(250_000, of: 500_000), 50)
        XCTAssertNil(TVFormat.percent(1, of: nil))
        XCTAssertEqual(TVFormat.ago("2026-11-25T22:00:00Z", now: ISO8601DateFormatter().date(from: "2026-11-25T22:30:00Z")!), "30 min ago")
    }

    func testDemoBoardHasEverySlide() {
        XCTAssertEqual(TVDemo.board.screen?.slides.count, TVSlide.allCases.count)
    }
}
