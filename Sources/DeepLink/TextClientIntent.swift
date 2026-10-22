import Foundation
#if canImport(AppIntents)
import AppIntents

// BOREAL_DIALER_v593_SIRI_TEXT_CLIENT
@available(iOS 16.0, *)
struct TextBorealClientIntent: AppIntent {
    static var title: LocalizedStringResource = "Text a Client"
    static var description = IntentDescription("Finds a client in the CRM and texts them from your office line.")

    @Parameter(title: "Client", requestValueDialog: "Who do you want to text?")
    var client: String

    @Parameter(title: "Message", requestValueDialog: "What's the message?")
    var message: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard TokenStorage.shared.getToken() != nil else {
            return .result(dialog: "Open the dialer app and sign in first.")
        }
        let body = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return .result(dialog: "The message was empty, so nothing was sent.") }
        let matches: [CRMContact]
        do {
            matches = try await BorealClientLookup.search(client)
        } catch {
            return .result(dialog: "I couldn't reach the server right now.")
        }
        guard let match = BorealClientLookup.best(matches, for: client),
              let phone = BorealClientLookup.e164(match.callablePhone) else {
            return .result(dialog: "I couldn't find a mobile number for \(client) in the CRM.")
        }
        try await requestConfirmation(result: .result(dialog: "Text \(match.displayName): \(body)?"))
        do {
            try await API.sendSMS(SendSMSPayload(to: phone, body: body, contactId: match.id))
        } catch {
            return .result(dialog: "That text didn't send. Try again from the app.")
        }
        return .result(dialog: "Sent to \(match.displayName).")
    }
}
#endif
