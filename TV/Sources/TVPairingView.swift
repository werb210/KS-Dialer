// KEYSTONE_TV_v1 - the pairing screen: a big code, the three steps, and a fresh code whenever the old one expires.
import SwiftUI

@MainActor
final class TVPairingModel: ObservableObject {
    @Published var code: String?
    @Published var problem: String?
    private var secret = ""
    private var expiresAt = Date.distantPast
    private var task: Task<Void, Never>?
    private let api = TVAPI()

    func start(onPaired: @escaping (TVPairing) -> Void) {
        task?.cancel()
        if TVDemo.showsPairing { code = "KQ7 4MX".replacingOccurrences(of: " ", with: ""); return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if self.code == nil || Date() >= self.expiresAt { await self.newCode() }
                if let code = self.code {
                    do {
                        let r = try await self.api.collect(code: code, secret: self.secret)
                        if r.state == "paired", let server = r.server_url, let token = r.token {
                            onPaired(TVPairing(serverURL: server, token: token, company: r.company ?? TVCompany(name: "", logo_url: nil, primary_color: nil)))
                            return
                        }
                        if r.state == "expired" { self.code = nil }
                        self.problem = nil
                    } catch {
                        self.problem = "Can't reach Keystone. Check this TV's internet connection."
                    }
                }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    func stop() { task?.cancel() }

    private func newCode() async {
        do {
            let s = try await api.startPairing()
            code = s.code
            secret = s.device_secret
            expiresAt = Date().addingTimeInterval(TimeInterval(max(s.expires_in - 15, 30)))
            problem = nil
        } catch {
            code = nil
            problem = "Can't reach Keystone. Check this TV's internet connection."
            try? await Task.sleep(nanoseconds: 5_000_000_000)
        }
    }
}

struct TVPairingView: View {
    @EnvironmentObject var model: TVModel
    @StateObject private var pairing = TVPairingModel()

    var body: some View {
        HStack(spacing: 120) {
            VStack(alignment: .leading, spacing: 28) {
                Text("Keystone TV").font(.system(size: 44, weight: .semibold)).foregroundStyle(TVTheme.muted)
                Text("Put your sales\nscoreboard on this TV").font(.system(size: 76, weight: .bold)).foregroundStyle(TVTheme.text)
                VStack(alignment: .leading, spacing: 22) {
                    step(1, "On a computer or iPad, open your staff portal.")
                    step(2, "Go to Settings, then Screens, and choose Add a TV.")
                    step(3, "Type the code shown here.")
                }
                .padding(.top, 12)
            }
            .frame(maxWidth: 900, alignment: .leading)

            VStack(spacing: 24) {
                Text("Your code").font(.system(size: 36, weight: .medium)).foregroundStyle(TVTheme.muted)
                Text(pairing.code.map(TVFormat.spacedCode) ?? "··· ···")
                    .font(.system(size: 130, weight: .heavy, design: .monospaced))
                    .lineLimit(1).fixedSize()
                    .foregroundStyle(TVTheme.text)
                    .padding(.horizontal, 60).padding(.vertical, 36)
                    .background(RoundedRectangle(cornerRadius: 36).fill(TVTheme.panel))
                    .accessibilityLabel(pairing.code.map { "Code " + $0.map { String($0) }.joined(separator: " ") } ?? "Getting a code")
                Text(pairing.problem ?? "A new code appears every few minutes.")
                    .font(.system(size: 28)).foregroundStyle(pairing.problem == nil ? TVTheme.muted : TVTheme.down)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(100)
        .onAppear { pairing.start { model.paired($0) } }
        .onDisappear { pairing.stop() }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 20) {
            Text("\(n)").font(.system(size: 34, weight: .bold)).foregroundStyle(TVTheme.background)
                .frame(width: 54, height: 54).background(Circle().fill(TVTheme.defaultAccent))
            Text(text).font(.system(size: 36)).foregroundStyle(TVTheme.text)
        }
    }
}
