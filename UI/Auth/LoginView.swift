import Combine
import SwiftUI

struct LoginView: View {

    @State private var phone = ""
    @State private var otp = ""
    @State private var otpRequested = false
    // BOREAL_DIALER_UI_COMPILES_v6
    @State private var errorMessage: String?
    @State private var busy = false
    // BOREAL_DIALER_FACE_ID_SIGN_IN_v299
    @State private var faceIDReady = false
    @ObservedObject var auth = AuthService.shared
    // BOREAL_DIALER_KEYPAD_ICON_PLIST_v22
    private enum Field { case phone, code }
    @FocusState private var focused: Field?

    // KEYSTONE_COMPANY_CODE_v1 / KS_STAFF_DIRECTORY_v1 - the company this phone signs in to; nil shows the
    // "work email or mobile number" screen first (StaffLookupView; the company code is its hidden fallback).
    @State private var company: CompanyProfile? = CompanyStore.current

    // BOREAL_DIALER_LOGIN_STYLE_v26 - neutral navy field; the accent is the company's primary colour when it has one.
    private let navy = KeystoneBrand.navy
    private var gold: Color { KeystoneBrand.accent(for: company) }

    private func fieldStyle<V: View>(_ v: V) -> some View {
        v.foregroundColor(.white)
            .tint(gold)
            .padding(14)
            .background(Color.white.opacity(0.08))
            .cornerRadius(12)
    }

    // BOREAL_DIALER_v831_DIALER_POLISH - a number that isn't staff is told so, not "That code didn't work".
    nonisolated static func codeErrorMessage(_ error: Error) -> String {
        if case APIError.http(_, let code, _) = error, code == "not_staff" {
            return APIError.knownCodes["not_staff"] ?? "This number isn't set up as a staff account."
        }
        if OfflineQueue.isOffline(error) { return "No signal. Try again when you're back online." }
        return "That code didn't work. Please try again."
    }

    private func submitCode(_ code: String) {
        Task {
            busy = true
            errorMessage = nil
            do {
                try await auth.login(phone: phone, otp: code)
            } catch {
                errorMessage = LoginView.codeErrorMessage(error)
            }
            busy = false
        }
    }

    var body: some View {
        Group {
            if company == nil {
                StaffLookupView { resolved, typedPhone in
                    company = resolved
                    if let typedPhone, phone.isEmpty { phone = typedPhone }
                }
            } else {
                signIn
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: CompanyStore.didChange)) { _ in
            company = CompanyStore.current
        }
    }

    private var signIn: some View {
        ZStack {
            navy.ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                CompanyLogoView(company: company, size: 64)
                Text(company?.companyName ?? "Dialer")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("Sign in with your work number")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))

                if faceIDReady {
                    Button {
                        Task {
                            busy = true
                            errorMessage = nil
                            do {
                                try await auth.loginWithFaceID()
                            } catch FaceIDSignInError.cancelled {
                                errorMessage = nil
                            } catch FaceIDSignInError.rejected {
                                faceIDReady = false
                                errorMessage = "Face ID sign-in has expired. Sign in with a text code to turn it back on."
                            } catch {
                                errorMessage = "Face ID sign-in didn't work. Use a text code instead."
                            }
                            busy = false
                        }
                    } label: {
                        Label("Sign in with Face ID", systemImage: "faceid")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(gold)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(busy)

                    Text("or get a text code")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.6))
                }

                VStack(spacing: 14) {
                    fieldStyle(
                        TextField("Phone", text: $phone)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                            .focused($focused, equals: .phone)
                    )

                    if otpRequested {
                        fieldStyle(
                            TextField("6-digit code", text: $otp)
                                .keyboardType(.numberPad)
                                .textContentType(.oneTimeCode)
                                .focused($focused, equals: .code)
                        )
                    }
                }

                Button {
                    Task {
                        busy = true
                        errorMessage = nil
                        do {
                            otpRequested = try await auth.startOTP(phone: phone)
                            if otpRequested { focused = .code }
                            if !otpRequested {
                                errorMessage = "We couldn't send a code to that number."
                            }
                        } catch {
                            errorMessage = "We couldn't send a code. Check the number and try again."
                        }
                        busy = false
                    }
                } label: {
                    Text(otpRequested ? "Resend code" : "Send code")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(otpRequested ? Color.white.opacity(0.12) : Color.green)
                        .foregroundColor(otpRequested ? .white : .black)
                        .cornerRadius(12)
                }
                .disabled(busy || phone.isEmpty)

                if otpRequested {
                    Button {
                        submitCode(otp)
                    } label: {
                        Text("Log in")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.green)
                            .foregroundColor(.black)
                            .cornerRadius(12)
                    }
                    .disabled(busy || otp.isEmpty)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                // KEYSTONE_COMPANY_CODE_v1 / KS_STAFF_DIRECTORY_v1 - wrong company, or a new one: back to the
                // "work email or mobile number" screen.
                Button("Not with \(company?.companyName ?? "this company")? Change company") {
                    CompanyStore.clear()
                }
                .font(.footnote)
                .foregroundColor(.white.opacity(0.75))
                .disabled(busy)

                Spacer()
            }
            .padding(.horizontal, 28)
        }
        .onAppear {
            // BOREAL_DIALER_SESSION_GUARD_v314 - say why the session ended.
            if let reason = SessionGuard.takeLastReason() { errorMessage = reason }
            faceIDReady = FaceIDSignIn.shared.isEnrolled && FaceIDSignIn.shared.biometryAvailable
            if !faceIDReady { focused = .phone }
        }
        // Six digits is the whole code - no reason to make anyone tap Login.
        .onChange(of: otp) { value in
            if value.count == 6, otpRequested, !busy {
                submitCode(value)
            }
        }
    }
}
