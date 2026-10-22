import XCTest
@testable import BorealDialer

// BOREAL_DIALER_BLOCK_v506_TEAM_LINK_PREVIEWS
final class TeamLinkPreviewV506Tests: XCTestCase {
    func testFindsTheFirstWebLink() {
        XCTAssertEqual(TeamLinkPreviews.firstLink(in: "see https://example.com/rates thanks")?.absoluteString, "https://example.com/rates")
        XCTAssertNil(TeamLinkPreviews.firstLink(in: "no link here"))
    }

    func testDecodesServerPreview() throws {
        let json = #"{"url":"https://example.com/","ok":true,"title":"Example","description":null,"imageUrl":null,"siteName":"example.com"}"#
        let p = try JSONDecoder().decode(TeamLinkPreviewData.self, from: Data(json.utf8))
        XCTAssertEqual(p.title, "Example")
        XCTAssertTrue(p.ok)
    }
}
