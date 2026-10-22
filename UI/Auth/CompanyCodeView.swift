// KEYSTONE_COMPANY_CODE_v1
// First screen on a new install: "Enter your company code". The code is resolved through the KS-Ops directory
// (CompanyStore.lookup) and the result is kept in the App Group; LoginView then signs in against that company's
// server. Account > Switch company clears it and brings this screen back.
import SwiftUI

enum KeystoneBrand {
    /// Neutral defaults used until a company supplies its own colour.
    static let navy = Color(hex: 0x0B1F3A)
    static let accent = Color(hex: 0x5B8DEF)

    /// "#1E6FD9" / "1E6FD9" -> Color; nil for anything else.
    static func color(fromHex raw: String?) -> Color? {
        guard var hex = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !hex.isEmpty else { return nil }
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
        return Color(hex: value)
    }

    static func accent(for company: CompanyProfile?) -> Color {
        color(fromHex: company?.primaryColor) ?? accent
    }
}

/// The company's logo when it has one, otherwise a phone glyph.
struct CompanyLogoView: View {
    let company: CompanyProfile?
    var size: CGFloat = 64

    var body: some View {
        if let raw = company?.logoURL, let url = URL(string: raw), url.scheme == "https" {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    glyph
                }
            }
            .frame(width: size, height: size)
        } else {
            glyph
        }
    }

    private var glyph: some View {
        Image(systemName: "phone.fill")
            .font(.system(size: size * 0.66, weight: .semibold))
            .foregroundColor(KeystoneBrand.accent(for: company))
            .frame(width: size, height: size)
    }
}

struct CompanyCodeView: View {
    var onResolved: (CompanyProfile) -> Void

    @State private var code = ""
    @State private var busy = false
    @State private var errorMessage: String?
    @FocusState private var focused: Bool

    private func submit() {
        guard !busy else { return }
        Task {
            busy = true
            errorMessage = nil
            do {
                let profile = try await CompanyStore.lookup(code: code)
                CompanyStore.save(profile)
                onResolved(profile)
            } catch let error as CompanyLookupError {
                errorMessage = error.message
            } catch {
                errorMessage = CompanyLookupError.unavailable.message
            }
            busy = false
        }
    }

    var body: some View {
        ZStack {
            KeystoneBrand.navy.ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                CompanyLogoView(company: nil, size: 56)
                Text("Enter your company code")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("Your administrator gives you this code. You only enter it once.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)

                TextField("company-code", text: $code)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .submitLabel(.continue)
                    .focused($focused)
                    .onSubmit { submit() }
                    .foregroundColor(.white)
                    .tint(KeystoneBrand.accent)
                    .padding(14)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)

                Button {
                    submit()
                } label: {
                    Group {
                        if busy {
                            ProgressView().tint(.white)
                        } else {
                            Text("Continue").font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(KeystoneBrand.accent)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(busy || CompanyStore.normalizedCode(code) == nil)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding(.horizontal, 28)
        }
        .onAppear { focused = true }
    }
}
