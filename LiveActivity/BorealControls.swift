import SwiftUI
import WidgetKit
import AppIntents

// BOREAL_DIALER_CONTROLS_v321
// Control Center and Action Button controls (iOS 18). Two buttons:
//   - "Boreal Call": opens the Boreal keypad.
//   - "Boreal Quick Call": calls the first contact in the dialer's quick-call
//     list (the same list the home-screen widget shows); opens the keypad when
//     that list is empty.
// On iPhones with an Action Button: Settings > Action Button > Controls, then
// pick either one. The Siri shortcuts (New Call, Call a Client, What's Due)
// are also offered there under Shortcut.
// Lives in the widget extension, so it only uses Sources/Shared (no networking).
enum BorealControlLinks {
    static let newCall = URL(string: "ksdialer://new-call")!

    static func quickCall(_ contacts: [WidgetContact]) -> (url: URL, name: String?) {
        guard let first = contacts.first, first.number.hasPrefix("+") else { return (newCall, nil) }
        var components = URLComponents()
        components.scheme = "ksdialer"
        components.host = "call"
        components.queryItems = [URLQueryItem(name: "phone", value: first.number), URLQueryItem(name: "start", value: "true")]
        return (components.url ?? newCall, first.name)
    }
}

@available(iOS 18.0, *)
struct BorealNewCallControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.keystone.dialer.control.new-call") {
            ControlWidgetButton(action: OpenURLIntent(BorealControlLinks.newCall)) {
                Label("Dialer Call", systemImage: "phone.fill")
            }
        }
        .displayName("Dialer Call")
        .description("Opens the dialer keypad.")
    }
}

@available(iOS 18.0, *)
struct BorealQuickCallControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.keystone.dialer.control.quick-call") {
            let target = BorealControlLinks.quickCall(WidgetSnapshotStore.load().contacts)
            ControlWidgetButton(action: OpenURLIntent(target.url)) {
                Label(target.name ?? "Quick Call", systemImage: "phone.arrow.up.right.fill")
            }
        }
        .displayName("Quick Call")
        .description("Calls your first quick-call contact from your office line.")
    }
}

// BOREAL_DIALER_v823_WIDGET_ACTIONS - three more controls for Control Center, the Lock Screen and the Action Button:
//   - "Boreal Busy": a switch; Busy sends callers to voicemail, without opening the app.
//   - "Boreal Voice Note": opens the app recording a note for your last call's client.
//   - "Boreal Next Follow-up": opens the app and calls the client on your next follow-up task.
enum BorealActionLinks {
    static let voiceNote = URL(string: "ksdialer://action/voice-note")!
    static let nextFollowUp = URL(string: "ksdialer://action/next-follow-up")!
}

@available(iOS 18.0, *)
struct BorealBusyControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: StaffWidgetActionKinds.busyControl) {
            ControlWidgetToggle("Dialer Busy", isOn: StaffWidgetActionStore.isBusy, action: BorealBusyControlIntent()) { busy in
                Label(busy ? "Busy" : "Available", systemImage: busy ? "phone.down.fill" : "phone.fill")
            }
        }
        .displayName("Dialer Busy")
        .description("Busy sends callers to voicemail. Turn it off to take calls again.")
    }
}

@available(iOS 18.0, *)
struct BorealVoiceNoteControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.keystone.dialer.control.voice-note") {
            ControlWidgetButton(action: OpenURLIntent(BorealActionLinks.voiceNote)) {
                Label("Voice Note", systemImage: "mic.fill")
            }
        }
        .displayName("Voice Note")
        .description("Record a note for your last call's client. It is saved to their timeline.")
    }
}

@available(iOS 18.0, *)
struct BorealNextFollowUpControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.keystone.dialer.control.next-follow-up") {
            ControlWidgetButton(action: OpenURLIntent(BorealActionLinks.nextFollowUp)) {
                Label("Next Follow-up", systemImage: "checklist")
            }
        }
        .displayName("Next Follow-up")
        .description("Calls the client on your next follow-up task.")
    }
}
