// KEYSTONE_TV_v1 - the three calls this app makes:
//   POST {KSOpsURL}/api/tv/pair/start              -> a code to show and a secret that never leaves the TV
//   POST {KSOpsURL}/api/tv/pair/collect            -> waiting | expired | paired (server address, screen token, company)
//   GET  {server}/api/scoreboard/tv  (Bearer token) -> the TV's settings and this month's scoreboard
import Foundation

enum TVAPIError: Error, Equatable {
    case unpaired
    case http(Int)
    case network
}

struct TVAPI {
    var session: URLSession = .shared

    static var opsURL: String {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "KSOpsURL") as? String) ?? ""
        return raw.isEmpty ? "https://ks-ops-dev.azurewebsites.net" : raw.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    func startPairing() async throws -> TVPairStart {
        try await post("\(TVAPI.opsURL)/api/tv/pair/start", body: [:])
    }

    func collect(code: String, secret: String) async throws -> TVPairCollect {
        try await post("\(TVAPI.opsURL)/api/tv/pair/collect", body: ["code": code, "device_secret": secret])
    }

    func board(_ pairing: TVPairing) async throws -> TVBoard {
        let base = pairing.serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/api/scoreboard/tv") else { throw TVAPIError.network }
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.setValue("Bearer \(pairing.token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await send(req)
    }

    private func post<T: Decodable>(_ urlString: String, body: [String: String]) async throws -> T {
        guard let url = URL(string: urlString) else { throw TVAPIError.network }
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await send(req)
    }

    private func send<T: Decodable>(_ req: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: req) } catch { throw TVAPIError.network }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 { throw TVAPIError.unpaired }
        guard (200..<300).contains(status) else { throw TVAPIError.http(status) }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
