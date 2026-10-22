# KS-Dialer

The Keystone staff dialler for iPhone: a native Twilio Voice dialer with CallKit, VoIP push, a Live Activity, home-screen
and Control Center widgets, a Call Directory (caller ID) extension, a notification service extension (Siri reads texts
aloud in CarPlay) and an independent Apple Watch app with its own complications. There is no iPad target.

Keystone is licensed to many companies and each one runs its own KS-server. KS-Dialer is one App Store app for all of
them: staff enter their **company code** once, the app looks it up in the KS-Ops directory, and from then on every API
call goes to that company's server.

## How the company code works

1. First launch (or after **Account > Switch company**) shows **Enter your company code**.
2. The app calls `GET {KSOpsURL}/api/directory/{company_code}` (codes are 3-32 characters, `a-z`, `0-9`, `-`).
   - `200 { company_code, company_name, server_url, client_url, portal_url, logo_url, primary_color }`
   - `404 { error: "unknown_company" }` shows "We couldn't find that company code".
3. The answer is stored in the App Group `UserDefaults` (`KS_APP_GROUP`), which the widgets, Live Activity and Call
   Directory extension already share (`Sources/WatchShared/CompanyStore.swift`).
4. Every request goes to `{server_url}/api` (`APIConfig.BASE_URL`), including the team chat websocket. Requests still
   send `X-Silo: BF`; KS-server has a single silo.
5. The sign-in screen shows the company's name and logo, and uses its `primary_color` as the accent (neutral navy and
   blue otherwise). Staff then sign in with their work number and a text code, as before.
6. **Switch company** signs out (revoking push and Face ID on the current server while the token still works) and
   clears the stored company. A sign-in token that survives a reinstall without a company is discarded.
7. The Apple Watch has no company-code screen: the iPhone sends its `{server_url}/api` with the Watch link code, and
   the Watch keeps it in its own App Group. Linking to a different server clears the Watch's old session.

## Keystone setup

Everything that identifies the app is in **`Config/Keystone.xcconfig`**, which `project.yml` applies to every target.
The committed values are placeholders.

| Setting | Placeholder | What it is |
| --- | --- | --- |
| `KS_APP_BUNDLE_ID` | `com.keystone.dialer` | iPhone app bundle id. The others are derived: `.watchkitapp`, `.watchkitapp.widget`, `.liveactivity`, `.calldirectory`, `.notificationservice` |
| `KS_APP_GROUP` | `group.com.keystone.dialer` | App Group in every entitlements file and in each target's `KSAppGroupIdentifier` Info.plist key |
| `KS_APP_DISPLAY_NAME` | `Keystone Dialer` | Home-screen name, permission prompts, Caller ID extension name |
| `KS_SHORT_NAME` | `Dialer` | Watch app, widgets, Live Activity and notification extension names |
| `KS_OPS_URL` | `https:/$()/ops.keystone.example` | KS-Ops base URL (`//` starts a comment in an xcconfig, hence `$()`) |
| `DEVELOPMENT_TEAM` | empty | Apple team id; empty builds unsigned for the simulator (CI) |

Also update, if the product name changes: the Siri example phrases in `Config/en.lproj/AppIntentVocabulary.plist`
("... with Keystone Dialer"). The URL scheme is `ksdialer://` (Watch complications use `kswatch://`).

### App Store Connect / Apple Developer steps

1. Enrol the company in the Apple Developer Program and note the team id; set `DEVELOPMENT_TEAM`.
2. Choose the bundle id prefix and set `KS_APP_BUNDLE_ID` and `KS_APP_GROUP`.
3. In Certificates, Identifiers & Profiles register:
   - the App Group `KS_APP_GROUP`;
   - six App IDs: the app and its five derived ids above, each with **App Groups** (the group above);
   - on the iPhone App ID: **Push Notifications**, **Time Sensitive Notifications**, **Communication Notifications**,
     **SiriKit**; request the **CarPlay Communication** entitlement from Apple (`com.apple.developer.carplay-communication`
     is in the entitlements and signing fails without it - remove it from `project.yml` until Apple grants it);
   - on the Watch App ID: **Push Notifications**.
4. Create a VoIP Services certificate (or use an APNs auth key) for the iPhone bundle id and add it to Twilio as the
   iOS push credential; set the company's KS-server `TWILIO_PUSH_CREDENTIAL_SID` and `STAFF_APNS_BUNDLE_ID`
   (= `KS_APP_BUNDLE_ID`) to match.
5. In App Store Connect create the app with bundle id `KS_APP_BUNDLE_ID`, then create an App Store Connect API key
   (Users and Access > Integrations, App Manager role) and save it as the repository secrets `ASC_KEY_ID`,
   `ASC_ISSUER_ID` and `ASC_KEY_P8` (the full text of the .p8 file).
6. Run **Actions > Upload iOS build**. It reads the team from `Config/Keystone.xcconfig`, archives with automatic
   signing and uploads to TestFlight. Nothing secret is stored in the repository.
7. Deploy KS-Ops with the public directory endpoint and set `KS_OPS_URL` to it.

## Development

```
brew install xcodegen
xcodegen generate
open BorealDialer.xcodeproj   # scheme BorealDialer; the Xcode target and module names are internal
```

The generated app targets iOS 16 and watchOS 9. CI (`.github/workflows/ci.yml`) runs the Linux checks in `scripts/`
(including `scripts/check-brand-strings.mjs`, which fails on "Boreal" in Swift string literals, Info.plists,
entitlements, `project.yml` or the xcconfig) and then builds and tests on macOS.

## Architecture and contracts

- [Canonical ownership](CALL_ARCHITECTURE.md)
- [Native API audit](DIALER_API_CONTRACT.md)
- [Cross-platform contract](CROSS_PLATFORM_DIALER_CONTRACT.md)
- [Apple and Twilio release setup](APPLE_RELEASE_SETUP.md), [physical device acceptance](PHYSICAL_DEVICE_ACCEPTANCE.md)
- Watch: [server requirements](WATCH_SERVER_REQUIREMENTS.md), [call contract](WATCH_CALL_SERVER_CONTRACT.md),
  [standalone acceptance](WATCH_STANDALONE_ACCEPTANCE.md)

Deep links: `ksdialer://call?phone=...` and `ksdialer://call?contactId=...` prefill by default; only an explicit,
validated `start=true` can start a call.
