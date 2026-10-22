import Foundation

struct APIConfig {
    // KEYSTONE_COMPANY_CODE_v1 - every request goes to the signed-in company's own KS-server: {server_url}/api from
    // the KS-Ops directory, kept by CompanyStore. Before a company is chosen the app only shows the company-code
    // screen; the placeholder below is an unroutable host so nothing can reach a real server by accident.
    static let unconfiguredBaseURL = "https://company-not-set.invalid/api"

    static var BASE_URL: String { CompanyStore.apiBaseURL ?? unconfiguredBaseURL }

    // BOREAL_DIALER_TEAM_WS_CONFIG_v789 - the team chat websocket lives on the
    // same server; derived here so a host change is made in one place.
    static var TEAM_WS_URL: String { webSocketURL(fromHTTPBase: BASE_URL) + "/team/ws" }

    /// https://host/api -> wss://host/api, http -> ws.
    static func webSocketURL(fromHTTPBase base: String) -> String {
        if base.hasPrefix("https://") { return "wss://" + String(base.dropFirst("https://".count)) }
        if base.hasPrefix("http://") { return "ws://" + String(base.dropFirst("http://".count)) }
        return base
    }

    // Keystone has a single line. KS-server still reads X-Silo, so requests keep sending "BF".
    static var activeBaseURL: String = BASE_URL
    static var activeSilo: Silo = .bf

    static var baseURL: String { BASE_URL }

    static func url(for silo: Silo) -> String { BASE_URL }

    static func siloHeader(for silo: Silo) -> String {
        switch silo {
        case .bf:  return "BF"
        case .bi:  return "BI"
        case .slf: return "SLF"
        }
    }
}
