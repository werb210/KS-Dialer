// KEYSTONE_TV_v1 - Keystone TV: the sales scoreboard for an office TV. Unpaired, it shows a code to type into the
// brokerage's portal (Settings > Screens); paired, it rotates through the scoreboard screens chosen there.
import SwiftUI
import UIKit

@main
struct KeystoneTVApp: App {
    @StateObject private var model = TVModel()

    var body: some Scene {
        WindowGroup {
            TVRootView()
                .environmentObject(model)
                .onAppear { UIApplication.shared.isIdleTimerDisabled = true } // a scoreboard never sleeps
        }
    }
}

@MainActor
final class TVModel: ObservableObject {
    @Published var pairing: TVPairing?
    @Published var demo = TVDemo.isOn && !TVDemo.showsPairing

    init() {
        pairing = TVStore.load()
    }

    func paired(_ p: TVPairing) {
        TVStore.save(p)
        pairing = p
    }

    func unpair() {
        TVStore.clear()
        pairing = nil
        demo = false
    }
}

struct TVRootView: View {
    @EnvironmentObject var model: TVModel

    var body: some View {
        ZStack {
            TVTheme.background.ignoresSafeArea()
            if model.demo {
                TVBoardView(pairing: nil)
            } else if let p = model.pairing {
                TVBoardView(pairing: p).id(p.serverURL + p.token)
            } else {
                TVPairingView()
            }
        }
        .preferredColorScheme(.dark)
    }
}
