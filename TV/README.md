# Keystone TV

The sales scoreboard for an office TV (Apple TV, tvOS 17+). One App Store app for every Keystone brokerage and for
Boreal Financial.

- **Pairing:** the TV asks KS-Ops for a 6-character code (`POST /api/tv/pair/start`) and shows it. An admin enters it in
  their portal (Settings > Screens > Add a TV). Their server makes a read-only screen token and claims the code at
  KS-Ops; the TV collects the server address and token (`POST /api/tv/pair/collect`) and keeps the token in the Keychain.
- **Scoreboard:** `GET {server}/api/scoreboard/tv` every 30 seconds. Screens: broker leaderboard, team vs team, monthly
  goal, latest funded deals, deals funded. Each newly funded deal gets a ten-second "Deal funded" moment.
- **Remote:** Play/Pause opens the menu (Unpair this TV). Removing the TV in Settings > Screens also unpairs it.
- **Privacy:** broker and team names and amounts only; never a client's or company's name.

Build: `cd TV && xcodegen generate`, open `KeystoneTV.xcodeproj`. Launch arguments `-demo` (sample data),
`-demoSlide leaderboard|teams|goal|recent|deals`, `-demoCelebrate`, `-demoPairing`.
CI: `.github/workflows/tv.yml` builds, tests and screenshots every screen; `tv-upload.yml` uploads to TestFlight.
