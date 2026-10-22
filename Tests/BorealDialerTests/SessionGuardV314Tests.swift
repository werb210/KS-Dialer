import XCTest
@testable import BorealDialer

// BOREAL_DIALER_SESSION_GUARD_v314
final class SessionGuardV314Tests: XCTestCase {
    // KEYSTONE_COMPANY_CODE_v1 - the main server is the stored company's server.
    override func setUp() {
        super.setUp()
        KeystoneTestCompany.install()
    }

    func testOnlyTheMainServerCanEndTheSession() {
        XCTAssertTrue(SessionGuard.isMainServer(URL(string: "https://ks.example.com/api/voice/token")!))
        XCTAssertFalse(SessionGuard.isMainServer(URL(string: "https://other.example.com/api/crm/contacts")!))
    }

    func testSignOutReasonIsShownOnce() {
        SessionGuard.recordReason("test reason")
        XCTAssertEqual(SessionGuard.takeLastReason(), "test reason")
        XCTAssertNil(SessionGuard.takeLastReason())
    }

    func testWatchEnrollmentPathIsNotDoubled() throws {
        let request = try APIClient.shared.makeRequest(path: "/watch/auth/enrollment", method: "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://ks.example.com/api/watch/auth/enrollment")
    }
}
