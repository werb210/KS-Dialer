// KEYSTONE_TV_v1 - where this TV keeps its pairing: the brokerage's server and company in UserDefaults, the read-only
// screen token in the Keychain.
import Foundation
import Security

struct TVPairing: Equatable {
    var serverURL: String
    var token: String
    var company: TVCompany
}

enum TVStore {
    private static let serverKey = "tv.server_url"
    private static let companyKey = "tv.company"
    private static let tokenAccount = "tv.screen_token"

    static func load() -> TVPairing? {
        let d = UserDefaults.standard
        guard let server = d.string(forKey: serverKey), let token = readToken() else { return nil }
        var company = TVCompany(name: "", logo_url: nil, primary_color: nil)
        if let data = d.data(forKey: companyKey), let c = try? JSONDecoder().decode(TVCompany.self, from: data) { company = c }
        return TVPairing(serverURL: server, token: token, company: company)
    }

    static func save(_ p: TVPairing) {
        let d = UserDefaults.standard
        d.set(p.serverURL, forKey: serverKey)
        d.set(try? JSONEncoder().encode(p.company), forKey: companyKey)
        writeToken(p.token)
    }

    static func clear() {
        let d = UserDefaults.standard
        d.removeObject(forKey: serverKey)
        d.removeObject(forKey: companyKey)
        SecItemDelete(query() as CFDictionary)
    }

    private static func query() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: tokenAccount, kSecAttrService as String: "keystone.tv"]
    }

    private static func readToken() -> String? {
        var q = query()
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func writeToken(_ token: String) {
        SecItemDelete(query() as CFDictionary)
        var q = query()
        q[kSecValueData as String] = Data(token.utf8)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(q as CFDictionary, nil)
    }
}
