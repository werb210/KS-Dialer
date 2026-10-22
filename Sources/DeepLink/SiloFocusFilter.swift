import Foundation
#if canImport(AppIntents)
import AppIntents

// BOREAL_DIALER_v593_FOCUS_FILTER
// KEYSTONE_SINGLE_LINE_v1 - Keystone has one line, so the Focus filter only chooses which alerts show.

// BOREAL_DIALER_v821 - which alerts this Focus lets through (FocusAlertPolicy).
@available(iOS 16.0, *)
enum BorealFocusAlerts: String, AppEnum {
    case all, clientOnly
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Dialer alerts"
    static var caseDisplayRepresentations: [BorealFocusAlerts: DisplayRepresentation] = [
        .all: "All dialer alerts",
        .clientOnly: "Only client calls and messages",
    ]

    var mode: FocusAlertMode {
        switch self {
        case .all: return .all
        case .clientOnly: return .clientOnly
        }
    }
}

// BOREAL_DIALER_v821 - the one Focus filter: which alerts show while the Focus is on.
@available(iOS 16.0, *)
struct BorealSiloFocusFilter: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "Dialer Alerts"
    static var description = IntentDescription("Choose which dialer alerts reach you while this Focus is on.")

    // BOREAL_DIALER_v821 - the default (.all) is also what the app falls back to when the Focus ends.
    @Parameter(title: "Alerts", default: .all)
    var alerts: BorealFocusAlerts

    var displayRepresentation: DisplayRepresentation {
        let alertText = alerts == .clientOnly ? "Client calls and messages only" : "All alerts"
        return DisplayRepresentation(title: "Dialer Alerts", subtitle: "\(alertText)")
    }

    // BOREAL_DIALER_v821 - the system hides notifications marked "internal" (filterCriteria) while this Focus is on.
    var appContext: FocusFilterAppContext {
        FocusFilterAppContext(notificationFilterPredicate: FocusAlertPolicy.notificationPredicate(for: alerts.mode))
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        FocusAlertPolicy.currentMode = alerts.mode // BOREAL_DIALER_v821 - read by willPresent
        return .result()
    }
}
#endif
