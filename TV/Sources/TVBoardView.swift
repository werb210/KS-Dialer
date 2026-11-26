// KEYSTONE_TV_v1 - the scoreboard: refreshes every 30 seconds, rotates through the screens chosen in Settings > Screens,
// and celebrates each newly funded deal for ten seconds. Press Play/Pause on the remote for the menu (unpair).
import SwiftUI

@MainActor
final class TVBoardModel: ObservableObject {
    @Published var board: TVBoard?
    @Published var slideIndex = 0
    @Published var celebrating: TVFunded?
    @Published var offline = false
    private var seen: Set<String>?
    private var refreshTask: Task<Void, Never>?
    private var rotateTask: Task<Void, Never>?
    private let api = TVAPI()

    var slides: [TVSlide] {
        if let pinned = TVDemo.pinnedSlide { return [pinned] }
        let names = board?.screen?.slides ?? TVSlide.allCases.map(\.rawValue)
        let list = names.compactMap(TVSlide.init(rawValue:))
        return list.isEmpty ? [.leaderboard] : list
    }

    func start(pairing: TVPairing?, onUnpaired: @escaping () -> Void) {
        refreshTask?.cancel()
        if pairing == nil {
            board = TVDemo.board
            if TVDemo.showsCelebration { celebrating = TVDemo.board.recent.first }
            startRotation()
            return
        }
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let pairing else { return }
                do {
                    let b = try await self.api.board(pairing)
                    self.apply(b)
                    self.offline = false
                } catch TVAPIError.unpaired {
                    onUnpaired()
                    return
                } catch {
                    self.offline = true
                }
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        rotateTask?.cancel()
    }

    private func apply(_ b: TVBoard) {
        let first = board == nil
        board = b
        let ids = Set(b.recent.map(\.id))
        if let seen, let fresh = b.recent.first(where: { !seen.contains($0.id) }) { celebrate(fresh) }
        seen = (seen ?? []).union(ids)
        if first { startRotation() }
    }

    private func celebrate(_ deal: TVFunded) {
        celebrating = deal
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            if self?.celebrating == deal { self?.celebrating = nil }
        }
    }

    private func startRotation() {
        rotateTask?.cancel()
        rotateTask = Task { [weak self] in
            while !Task.isCancelled {
                let seconds = max(self?.board?.screen?.rotate_seconds ?? 20, 8)
                try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
                guard let self, !Task.isCancelled else { return }
                if self.celebrating != nil { continue }
                withAnimation(.easeInOut(duration: 0.6)) { self.slideIndex = (self.slideIndex + 1) % max(self.slides.count, 1) }
            }
        }
    }
}

struct TVBoardView: View {
    var pairing: TVPairing?
    @EnvironmentObject var model: TVModel
    @StateObject private var vm = TVBoardModel()
    @State private var menu = false

    var body: some View {
        let accent = TVTheme.accent(vm.board?.company?.primary_color ?? pairing?.company.primary_color)
        VStack(spacing: 0) {
            header(accent: accent)
            ZStack {
                if let board = vm.board {
                    let slide = vm.slides[vm.slideIndex % vm.slides.count]
                    TVSlideView(slide: slide, board: board, accent: accent)
                        .id(slide)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                } else {
                    ProgressView().scaleEffect(2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()
            .padding(.horizontal, 80).padding(.bottom, 40)
        }
        .overlay { if let deal = vm.celebrating { TVCelebration(deal: deal, accent: accent, currency: vm.board?.currency ?? "CAD") } }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: vm.celebrating)
        .onAppear { vm.start(pairing: pairing) { model.unpair() } }
        .onDisappear { vm.stop() }
        .overlay(alignment: .bottom) {
            // KEYSTONE_TV_REVIEW_DEMO_v1 - the demo says it is sample data, and Menu goes back to pairing.
            if pairing == nil && !TVDemo.isOn {
                Text("Sample data. Press Menu to go back and pair this TV.")
                    .font(.system(size: 26, weight: .medium)).foregroundStyle(TVTheme.muted)
                    .padding(.horizontal, 28).padding(.vertical, 12)
                    .background(Capsule().fill(TVTheme.panel))
                    .padding(.bottom, 24)
            }
        }
        .onExitCommand(perform: pairing == nil && !TVDemo.isOn ? { model.demo = false } : nil)
        .onPlayPauseCommand { if pairing != nil { menu = true } }
        .confirmationDialog(vm.board?.screen?.name ?? "This TV", isPresented: $menu) {
            Button("Unpair this TV", role: .destructive) { model.unpair() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Unpairing removes this TV's access. You can pair it again from Settings > Screens.")
        }
    }

    private func header(accent: Color) -> some View {
        let company = vm.board?.company?.name ?? pairing?.company.name ?? ""
        return HStack(alignment: .center, spacing: 24) {
            if let logo = vm.board?.company?.logo_url ?? pairing?.company.logo_url, let url = URL(string: logo) {
                AsyncImage(url: url) { $0.resizable().scaledToFit() } placeholder: { Color.clear }.frame(height: 64)
            }
            Text(company).font(.system(size: 40, weight: .bold)).foregroundStyle(TVTheme.text)
            Spacer()
            if vm.offline { Label("Reconnecting", systemImage: "wifi.exclamationmark").font(.system(size: 26)).foregroundStyle(TVTheme.down) }
            if let p = vm.board?.period {
                Text(p.label).font(.system(size: 32, weight: .semibold)).foregroundStyle(TVTheme.text)
                Text(p.days_left == 1 ? "1 day left" : "\(p.days_left) days left")
                    .font(.system(size: 28, weight: .medium)).foregroundStyle(accent)
                    .padding(.horizontal, 18).padding(.vertical, 8).background(Capsule().fill(accent.opacity(0.18)))
            }
            HStack(spacing: 10) {
                ForEach(Array(vm.slides.enumerated()), id: \.offset) { i, _ in
                    Circle().fill(i == vm.slideIndex % max(vm.slides.count, 1) ? TVTheme.text : TVTheme.muted.opacity(0.4)).frame(width: 12, height: 12)
                }
            }
            .padding(.leading, 12)
        }
        .padding(.horizontal, 80).padding(.top, 50).padding(.bottom, 20)
    }
}

/// Full-screen "Deal funded!" moment for a newly funded deal.
struct TVCelebration: View {
    var deal: TVFunded
    var accent: Color
    var currency: String
    @State private var burst = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            ForEach(0..<36, id: \.self) { i in
                let angle = Double(i) / 36 * 2 * .pi
                Circle()
                    .fill([TVTheme.gold, accent, TVTheme.up, .white][i % 4])
                    .frame(width: 18, height: 18)
                    .offset(x: burst ? cos(angle) * 760 : 0, y: burst ? sin(angle) * 420 : 0)
                    .opacity(burst ? 0 : 1)
            }
            VStack(spacing: 28) {
                Text("DEAL FUNDED").font(.system(size: 54, weight: .heavy)).tracking(8).foregroundStyle(TVTheme.gold)
                TVAvatar(initials: deal.initials, photoURL: deal.photo_url, size: 220, accent: accent)
                Text(deal.broker).font(.system(size: 88, weight: .bold)).foregroundStyle(.white)
                if let team = deal.team { Text(team).font(.system(size: 40)).foregroundStyle(TVTheme.muted) }
                Text(TVFormat.money(deal.amount, currency: currency)).font(.system(size: 120, weight: .heavy)).foregroundStyle(TVTheme.up)
            }
            .scaleEffect(burst ? 1 : 0.6)
        }
        .transition(.opacity)
        .onAppear { withAnimation(.easeOut(duration: 1.6)) { burst = true } }
        .accessibilityElement(children: .combine)
    }
}
