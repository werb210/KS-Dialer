// KEYSTONE_COMPANY_CODE_v1
import XCTest
@testable import BorealDialer

/// A stored company for tests that build server URLs. Requests go to https://ks.example.com/api.
enum KeystoneTestCompany {
    static let profile = CompanyProfile(
        companyCode: "keystone-demo",
        companyName: "Keystone Demo",
        serverURL: "https://ks.example.com",
        logoURL: nil,
        primaryColor: "#1E6FD9",
        portalURL: "https://portal.example.com"
    )

    static func install() { CompanyStore.save(profile) }
}

final class KeystoneCompanyTests: XCTestCase {
    override func tearDown() {
        KeystoneTestCompany.install()
        super.tearDown()
    }

    func testCompanyCodesAreNormalisedAndValidated() {
        XCTAssertEqual(CompanyStore.normalizedCode("  Keystone-Demo "), "keystone-demo")
        XCTAssertEqual(CompanyStore.normalizedCode("abc"), "abc")
        XCTAssertNil(CompanyStore.normalizedCode("ab"))
        XCTAssertNil(CompanyStore.normalizedCode(String(repeating: "a", count: 33)))
        XCTAssertNil(CompanyStore.normalizedCode("acme/../x"))
        XCTAssertNil(CompanyStore.normalizedCode("acme co"))
    }

    func testDirectoryURLUsesTheOpsBase() {
        let url = CompanyStore.directoryURL(for: "keystone-demo")
        XCTAssertEqual(url?.path, "/api/directory/keystone-demo")
        XCTAssertEqual(url?.scheme, "https")
    }

    func testServerURLBecomesTheAPIBase() {
        XCTAssertEqual(CompanyStore.apiBase(fromServerURL: "https://acme.example.com"), "https://acme.example.com/api")
        XCTAssertEqual(CompanyStore.apiBase(fromServerURL: "https://acme.example.com/"), "https://acme.example.com/api")
        XCTAssertEqual(CompanyStore.apiBase(fromServerURL: "https://acme.example.com/api/"), "https://acme.example.com/api")
    }

    func testDirectoryResponseDecodes() throws {
        let json = ##"{"company_code":"acme","company_name":"Acme Lending","server_url":"https://acme.example.com","client_url":"https://apply.acme.example.com","portal_url":"https://staff.acme.example.com","logo_url":"https://cdn.example.com/acme.png","primary_color":"#0B1F3A"}"##
        let profile = try CompanyStore.decodeDirectoryResponse(data: Data(json.utf8), statusCode: 200)
        XCTAssertEqual(profile.companyCode, "acme")
        XCTAssertEqual(profile.companyName, "Acme Lending")
        XCTAssertEqual(profile.apiBaseURL, "https://acme.example.com/api")
        XCTAssertEqual(profile.portalURL, "https://staff.acme.example.com")
        XCTAssertEqual(profile.primaryColor, "#0B1F3A")
    }

    func testUnknownCompanyAndBadServersAreRefused() {
        XCTAssertThrowsError(try CompanyStore.decodeDirectoryResponse(data: Data(#"{"error":"unknown_company"}"#.utf8), statusCode: 404)) {
            XCTAssertEqual($0 as? CompanyLookupError, .unknownCompany)
        }
        let insecure = #"{"company_code":"acme","company_name":"Acme","server_url":"http://acme.example.com"}"#
        XCTAssertThrowsError(try CompanyStore.decodeDirectoryResponse(data: Data(insecure.utf8), statusCode: 200)) {
            XCTAssertEqual($0 as? CompanyLookupError, .unavailable)
        }
    }

    func testEveryRequestFollowsTheStoredCompany() throws {
        CompanyStore.save(CompanyProfile(companyCode: "acme", companyName: "Acme", serverURL: "https://acme.example.com"))
        XCTAssertEqual(APIConfig.BASE_URL, "https://acme.example.com/api")
        XCTAssertEqual(APIConfig.TEAM_WS_URL, "wss://acme.example.com/api/team/ws")
        let request = try APIClient.shared.makeRequest(path: "/voice/token")
        XCTAssertEqual(request.url?.absoluteString, "https://acme.example.com/api/voice/token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Silo"), "BF")
    }

    func testClearingTheCompanyLeavesNoServer() {
        CompanyStore.save(KeystoneTestCompany.profile)
        CompanyStore.clear()
        XCTAssertNil(CompanyStore.current)
        XCTAssertEqual(APIConfig.BASE_URL, APIConfig.unconfiguredBaseURL)
    }

    func testTheWatchEnrollmentCarriesTheServer() {
        let message = WatchEnrollMessage(oneTimeCode: "12345678", serverURL: "https://acme.example.com/api")
        let payload = WatchPayload.encode(message, under: WatchPayload.enrollKey)
        XCTAssertEqual(WatchPayload.decode(WatchEnrollMessage.self, from: payload, key: WatchPayload.enrollKey)?.serverURL,
                       "https://acme.example.com/api")
        // A message without the field (older sender) still decodes.
        let legacy: [String: Any] = [WatchPayload.enrollKey: Data(#"{"oneTimeCode":"12345678"}"#.utf8)]
        XCTAssertEqual(WatchPayload.decode(WatchEnrollMessage.self, from: legacy, key: WatchPayload.enrollKey)?.oneTimeCode,
                       "12345678")
    }

    // MARK: KS_STAFF_DIRECTORY_v1 - find the company from a work email or mobile number

    func testIdentifiersAreNormalisedLikeKSOps() {
        XCTAssertEqual(CompanyStore.normalizedIdentifier("  Nora@NorthWind.Example "), "nora@northwind.example")
        XCTAssertEqual(CompanyStore.normalizedIdentifier("(403) 555-0199"), "+14035550199")
        XCTAssertEqual(CompanyStore.normalizedIdentifier("+1 403 555 0199"), "+14035550199")
        XCTAssertNil(CompanyStore.normalizedIdentifier("555-0199"))
        XCTAssertNil(CompanyStore.normalizedIdentifier("nora@"))
        XCTAssertNil(CompanyStore.normalizedIdentifier("acme-capital"))
        XCTAssertEqual(CompanyStore.phoneIdentifier("403.555.0199"), "+14035550199")
        XCTAssertNil(CompanyStore.phoneIdentifier("nora@northwind.example"))
    }

    func testStaffLookupGoesToTheOpsDirectory() {
        XCTAssertEqual(CompanyStore.staffLookupURL?.path, "/api/staff-directory/lookup")
        XCTAssertEqual(CompanyStore.staffLookupURL?.scheme, "https")
    }

    func testStaffLookupResponseDecodesAndDropsInsecureServers() throws {
        let json = ##"{"matches":[{"name":"Alpha Capital","server_url":"https://ks-alpha.example.com"},{"name":"Bad","server_url":"http://bad.example.com"},{"name":"Beta Funding","server_url":"https://ks-beta.example.com"}]}"##
        let matches = try CompanyStore.decodeStaffLookupResponse(data: Data(json.utf8), statusCode: 200)
        XCTAssertEqual(matches.map(\.name), ["Alpha Capital", "Beta Funding"])
        XCTAssertEqual(try CompanyStore.decodeStaffLookupResponse(data: Data(#"{"matches":[]}"#.utf8), statusCode: 200), [])
        XCTAssertThrowsError(try CompanyStore.decodeStaffLookupResponse(data: Data("{}".utf8), statusCode: 429)) {
            XCTAssertEqual($0 as? StaffLookupError, .rateLimited)
        }
        XCTAssertThrowsError(try CompanyStore.decodeStaffLookupResponse(data: Data("oops".utf8), statusCode: 500)) {
            XCTAssertEqual($0 as? StaffLookupError, .unavailable)
        }
    }

    func testAMatchBecomesTheStoredCompanyWithTheServersBranding() throws {
        let match = StaffDirectoryMatch(name: "Alpha Capital", serverURL: "https://ks-alpha.example.com")
        let licensee = try JSONDecoder().decode(PublicLicensee.self, from: Data(##"{"company_name":"Alpha","logo_url":"https://cdn.example.com/a.png","primary_color":"#123456","urls":{"portal":"https://staff.alpha.example.com"}}"##.utf8))
        let profile = CompanyStore.profile(for: match, licensee: licensee)
        XCTAssertEqual(profile.companyName, "Alpha Capital")
        XCTAssertEqual(profile.apiBaseURL, "https://ks-alpha.example.com/api")
        XCTAssertEqual(profile.portalURL, "https://staff.alpha.example.com")
        XCTAssertEqual(profile.primaryColor, "#123456")
        XCTAssertEqual(profile.logoURL, "https://cdn.example.com/a.png")
        let bare = CompanyStore.profile(for: match, licensee: nil)
        XCTAssertEqual(bare.companyName, "Alpha Capital")
        XCTAssertNil(bare.portalURL)
        CompanyStore.save(profile)
        XCTAssertEqual(APIConfig.BASE_URL, "https://ks-alpha.example.com/api")
    }

    func testStaffLookupMessagesAreReadable() {
        for error in [StaffLookupError.invalidIdentifier, .rateLimited, .offline, .unavailable] {
            XCTAssertFalse(error.message.isEmpty)
            XCTAssertFalse(error.message.lowercased().contains("company code"))
        }
    }
}
