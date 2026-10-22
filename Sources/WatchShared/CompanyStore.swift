// KEYSTONE_COMPANY_CODE_v1
// Keystone is licensed to many companies and each one runs its own KS-server. The app is the same for all of them:
// on first launch it asks for a company code, resolves it through the KS-Ops directory
//
//   GET {KSOpsURL}/api/directory/{company_code}
//     -> 200 { company_code, company_name, server_url, client_url, portal_url, logo_url, primary_color }
//     -> 404 { error: "unknown_company" }
//
// and keeps the answer in the App Group UserDefaults (the same container the widgets, Live Activity and Call Directory
// already read). Every API request then goes to {server_url}/api. "Switch company" in Account clears it.
//
// Compiled into the iPhone app and the Watch app (Sources/WatchShared). The Watch cannot read the iPhone's App Group,
// so the iPhone sends the API base URL with the Watch link code (WatchEnrollMessage.serverURL) and the Watch keeps it
// in its own App Group with adoptServerURL(_:).
import Foundation

public struct CompanyProfile: Codable, Equatable, Sendable {
    public let companyCode: String
    public let companyName: String
    public let serverURL: String
    public let logoURL: String?
    public let primaryColor: String?
    /// The company's staff portal (portal_url), for links that open a record there.
    public let portalURL: String?

    enum CodingKeys: String, CodingKey {
        case companyCode = "company_code"
        case companyName = "company_name"
        case serverURL = "server_url"
        case logoURL = "logo_url"
        case primaryColor = "primary_color"
        case portalURL = "portal_url"
    }

    public init(companyCode: String, companyName: String, serverURL: String,
                logoURL: String? = nil, primaryColor: String? = nil, portalURL: String? = nil) {
        self.companyCode = companyCode
        self.companyName = companyName
        self.serverURL = serverURL
        self.logoURL = logoURL
        self.primaryColor = primaryColor
        self.portalURL = portalURL
    }

    /// The base every request path is relative to: server_url with "/api" (paths in the app start after /api).
    public var apiBaseURL: String { CompanyStore.apiBase(fromServerURL: serverURL) }
}

public enum CompanyLookupError: Error, Equatable {
    case invalidCode
    case unknownCompany
    case offline
    case unavailable

    public var message: String {
        switch self {
        case .invalidCode: return "Company codes are 3 to 32 letters, numbers or dashes."
        case .unknownCompany: return "We couldn't find that company code. Check it with your administrator."
        case .offline: return "No connection. Try again when you're back online."
        case .unavailable: return "The company directory isn't responding. Please try again."
        }
    }
}

public enum CompanyStore {
    public static let didChange = Notification.Name("KeystoneCompanyDidChange")
    static let profileKey = "keystone.company.v1"
    /// Watch only: the API base URL the iPhone sent with the link code.
    static let watchAPIBaseKey = "keystone.company.apiBaseURL.v1"
    static let defaultOpsURL = "https://ops.keystone.example"
    static let fallbackAppGroup = "group.com.keystone.dialer"

    /// The App Group shared with the widgets and extensions (KSAppGroupIdentifier in each target's Info.plist,
    /// from KS_APP_GROUP in Config/Keystone.xcconfig).
    public static var appGroupIdentifier: String {
        (Bundle.main.object(forInfoDictionaryKey: "KSAppGroupIdentifier") as? String).flatMap { $0.isEmpty ? nil : $0 }
            ?? fallbackAppGroup
    }

    static var defaults: UserDefaults { UserDefaults(suiteName: appGroupIdentifier) ?? .standard }

    /// KS-Ops base URL (KSOpsURL in Info.plist, from KS_OPS_URL in Config/Keystone.xcconfig).
    public static var opsURL: String {
        let configured = (Bundle.main.object(forInfoDictionaryKey: "KSOpsURL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let value = configured.isEmpty ? defaultOpsURL : configured
        return value.hasSuffix("/") ? String(value.dropLast()) : value
    }

    public static var current: CompanyProfile? {
        guard let data = defaults.data(forKey: profileKey) else { return nil }
        return try? JSONDecoder().decode(CompanyProfile.self, from: data)
    }

    /// The API base for this device: the stored company on the iPhone, the adopted URL on the Watch.
    public static var apiBaseURL: String? {
        if let profile = current { return profile.apiBaseURL }
        guard let stored = defaults.string(forKey: watchAPIBaseKey), !stored.isEmpty else { return nil }
        return stored
    }

    public static func save(_ profile: CompanyProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: profileKey)
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    public static func clear() {
        defaults.removeObject(forKey: profileKey)
        defaults.removeObject(forKey: watchAPIBaseKey)
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    /// Watch: keep the API base URL the iPhone sent. Returns true when it changed (a different company), so the
    /// caller can drop a Watch session that belongs to the previous server.
    @discardableResult
    public static func adoptServerURL(_ apiBase: String?) -> Bool {
        guard let base = apiBase, let url = URL(string: base), url.scheme == "https", url.host != nil else { return false }
        let previous = defaults.string(forKey: watchAPIBaseKey)
        guard previous != base else { return false }
        defaults.set(base, forKey: watchAPIBaseKey)
        return previous != nil
    }

    /// Lower-cases and trims a typed code; nil unless it is 3-32 of [a-z0-9-].
    public static func normalizedCode(_ raw: String) -> String? {
        let code = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        guard (3...32).contains(code.count), code.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        return code
    }

    /// "https://acme.example.com/" -> "https://acme.example.com/api"; a server_url already ending in /api is kept.
    public static func apiBase(fromServerURL serverURL: String) -> String {
        var base = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        return base.hasSuffix("/api") ? base : base + "/api"
    }

    public static func directoryURL(for code: String) -> URL? {
        URL(string: opsURL + "/api/directory/" + code)
    }

    /// Resolves a company code through KS-Ops. Does not store the result; call save(_:) once it is accepted.
    public static func lookup(code raw: String, session: URLSession = .shared) async throws -> CompanyProfile {
        guard let code = normalizedCode(raw), let url = directoryURL(for: code) else {
            throw CompanyLookupError.invalidCode
        }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20
        let result: (Data, URLResponse)
        do {
            result = try await session.data(for: request)
        } catch let error as URLError where error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
            throw CompanyLookupError.offline
        } catch {
            throw CompanyLookupError.unavailable
        }
        let (data, response) = result
        return try decodeDirectoryResponse(data: data, statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
    }

    /// Separate from lookup(code:) so tests can check it without a network.
    public static func decodeDirectoryResponse(data: Data, statusCode: Int) throws -> CompanyProfile {
        if statusCode == 404 { throw CompanyLookupError.unknownCompany }
        guard (200..<300).contains(statusCode),
              let profile = try? JSONDecoder().decode(CompanyProfile.self, from: data),
              let server = URL(string: profile.serverURL), server.scheme == "https", server.host != nil
        else { throw CompanyLookupError.unavailable }
        return profile
    }
}
