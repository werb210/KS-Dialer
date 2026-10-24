// KS_STAFF_DIRECTORY_v1
// First screen on a new install: "Enter your work email or mobile number". KS-Ops answers which company (or companies)
// that person works for (CompanyStore.lookupStaff); one answer goes straight on, several show a list. The chosen
// company is kept in the App Group and LoginView signs in against its server, with a typed mobile number filled in.
// "Enter company code instead" opens the old company-code screen as a hidden fallback.
import SwiftUI

struct StaffLookupView: View {
    /// The chosen company, and the mobile number typed here (nil when an email was typed).
    var onResolved: (CompanyProfile, String?) -> Void

    @State private var identifier = ""
    @State private var matches: [StaffDirectoryMatch] = []
    @State private var busy = false
    @State private var errorMessage: String?
    @State private var usingCompanyCode = false
    @FocusState private var focused: Bool

    private var canContinue: Bool { CompanyStore.normalizedIdentifier(identifier) != nil }

    private func choose(_ match: StaffDirectoryMatch) {
        guard !busy else { return }
        Task {
            busy = true
            let profile = await CompanyStore.profile(for: match)
            CompanyStore.save(profile)
            busy = false
            onResolved(profile, CompanyStore.phoneIdentifier(identifier))
        }
    }

    private func submit() {
        guard !busy, canContinue else { return }
        Task {
            busy = true
            errorMessage = nil
            matches = []
            do {
                let found = try await CompanyStore.lookupStaff(identifier: identifier)
                busy = false
                if found.isEmpty {
                    errorMessage = "We couldn't find a Keystone account for that email or number. Check it, or ask your administrator to add you."
                } else if found.count == 1, let only = found.first {
                    choose(only)
                } else {
                    matches = found
                }
            } catch let error as StaffLookupError {
                busy = false
                errorMessage = error.message
            } catch {
                busy = false
                errorMessage = StaffLookupError.unavailable.message
            }
        }
    }

    var body: some View {
        if usingCompanyCode {
            CompanyCodeView(onResolved: { onResolved($0, nil) }, onBack: { usingCompanyCode = false })
        } else {
            lookup
        }
    }

    private var lookup: some View {
        ZStack {
            KeystoneBrand.navy.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    Spacer(minLength: 60)

                    CompanyLogoView(company: nil, size: 56)
                    Text("Sign in")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    Text("Enter your work email or mobile number. We'll find your company, then text you a code.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)

                    TextField("Work email or mobile number", text: $identifier)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .textContentType(.username)
                        .submitLabel(.continue)
                        .focused($focused)
                        .onSubmit { submit() }
                        .foregroundColor(.white)
                        .tint(KeystoneBrand.accent)
                        .padding(14)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                        .onChange(of: identifier) { _ in
                            matches = []
                            errorMessage = nil
                        }

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
                    .disabled(busy || !canContinue)

                    if !matches.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("You work with more than one company. Which one do you want to sign in to?")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.85))
                            ForEach(matches) { match in
                                Button {
                                    choose(match)
                                } label: {
                                    HStack {
                                        Text(match.name).font(.headline)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }
                                    .padding(14)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white.opacity(0.12))
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                .disabled(busy)
                            }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(Color(red: 1, green: 0.55, blue: 0.55))
                            .multilineTextAlignment(.center)
                    }

                    Button("Enter company code instead") {
                        errorMessage = nil
                        usingCompanyCode = true
                    }
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.7))
                    .disabled(busy)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 28)
            }
        }
        .onAppear { focused = true }
    }
}
