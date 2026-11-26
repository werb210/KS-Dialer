// KEYSTONE_TV_v1 - the five scoreboard screens. Broker and team names and amounts only - never a client's name.
import SwiftUI

struct TVSlideView: View {
    var slide: TVSlide
    var board: TVBoard
    var accent: Color

    var body: some View {
        switch slide {
        case .leaderboard: TVLeaderboardSlide(board: board, accent: accent, byDeals: false)
        case .deals: TVLeaderboardSlide(board: board, accent: accent, byDeals: true)
        case .teams: TVTeamsSlide(board: board, accent: accent)
        case .goal: TVGoalSlide(board: board, accent: accent)
        case .recent: TVRecentSlide(board: board, accent: accent)
        }
    }
}

struct TVSlideTitle: View {
    var title: String
    var subtitle: String?
    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 20) {
            Text(title).font(.system(size: 64, weight: .heavy)).foregroundStyle(TVTheme.text)
            if let subtitle { Text(subtitle).font(.system(size: 30)).foregroundStyle(TVTheme.muted) }
            Spacer()
        }
        .padding(.bottom, 24)
    }
}

struct TVMovement: View {
    var n: Int
    var body: some View {
        Group {
            if n > 0 { Label("\(n)", systemImage: "arrowtriangle.up.fill").foregroundStyle(TVTheme.up) }
            else if n < 0 { Label("\(-n)", systemImage: "arrowtriangle.down.fill").foregroundStyle(TVTheme.down) }
            else { Text("–").foregroundStyle(TVTheme.muted) }
        }
        .font(.system(size: 26, weight: .bold))
        .labelStyle(.titleAndIcon)
        .frame(width: 90, alignment: .leading)
    }
}

/// Top brokers by funded volume (or, on the "Deals funded" screen, by number of deals).
struct TVLeaderboardSlide: View {
    var board: TVBoard
    var accent: Color
    var byDeals: Bool

    struct Ranked: Identifiable {
        var rank: Int
        var broker: TVBroker
        var id: String { broker.id }
    }

    private var rows: [Ranked] {
        if !byDeals { return board.brokers.prefix(8).map { Ranked(rank: $0.rank, broker: $0) } }
        let sorted = board.brokers.sorted { $0.deals != $1.deals ? $0.deals > $1.deals : $0.volume > $1.volume }
        var out: [Ranked] = []
        for (i, b) in sorted.prefix(8).enumerated() {
            let rank = i > 0 && sorted[i - 1].deals == b.deals ? out[i - 1].rank : i + 1
            out.append(Ranked(rank: rank, broker: b))
        }
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TVSlideTitle(title: byDeals ? "Deals funded" : "Broker leaderboard", subtitle: byDeals ? "Most deals funded this month" : "Funded volume this month")
            if rows.isEmpty {
                TVEmpty(text: "No funded deals yet this month. The first one takes the top spot.")
            } else {
                VStack(spacing: 10) {
                    ForEach(rows) { row in
                        TVBrokerRow(rank: row.rank, broker: row.broker, accent: accent, currency: board.currency, byDeals: byDeals)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct TVBrokerRow: View {
    var rank: Int
    var broker: TVBroker
    var accent: Color
    var currency: String
    var byDeals: Bool

    var body: some View {
        HStack(spacing: 28) {
            Text("\(rank)").font(.system(size: 44, weight: .heavy)).foregroundStyle(TVTheme.medal(rank) ?? TVTheme.muted).frame(width: 70)
            if !byDeals { TVMovement(n: broker.movement) }
            TVAvatar(initials: broker.initials, photoURL: broker.photo_url, size: 60, accent: accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(broker.name).font(.system(size: 34, weight: .semibold)).foregroundStyle(TVTheme.text).lineLimit(1)
                if let team = broker.team { Text(team).font(.system(size: 22)).foregroundStyle(TVTheme.muted).lineLimit(1) }
            }
            .frame(width: 440, alignment: .leading)
            if !byDeals, let p = TVFormat.percent(broker.volume, of: broker.goal) {
                VStack(alignment: .leading, spacing: 6) {
                    TVProgressBar(fraction: Double(p) / 100, accent: accent)
                    Text("\(p)% of \(TVFormat.short(broker.goal ?? 0)) goal").font(.system(size: 22)).foregroundStyle(TVTheme.muted).lineLimit(1).fixedSize()
                }
                .frame(minWidth: 300, maxWidth: .infinity)
            } else {
                Spacer()
            }
            Text(byDeals ? "\(broker.deals)" : "\(broker.deals) \(broker.deals == 1 ? "deal" : "deals")")
                .font(.system(size: byDeals ? 48 : 30, weight: byDeals ? .heavy : .medium))
                .foregroundStyle(byDeals ? TVTheme.text : TVTheme.muted).frame(width: byDeals ? 120 : 150, alignment: .trailing)
            Text(TVFormat.money(broker.volume, currency: currency))
                .font(.system(size: byDeals ? 32 : 44, weight: byDeals ? .medium : .heavy)).monospacedDigit()
                .foregroundStyle(byDeals ? TVTheme.muted : TVTheme.text).frame(width: 330, alignment: .trailing)
        }
        .padding(.horizontal, 30).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 20).fill(rank == 1 ? accent.opacity(0.22) : TVTheme.panel))
    }
}

/// Team vs team: each team racing towards its goal (or towards the leading team when no goals are set).
struct TVTeamsSlide: View {
    var board: TVBoard
    var accent: Color

    var body: some View {
        let top = max(board.teams.map { max($0.goal ?? 0, $0.volume) }.max() ?? 1, 1)
        VStack(alignment: .leading, spacing: 0) {
            TVSlideTitle(title: "Team vs team", subtitle: "Funded volume this month")
            if board.teams.isEmpty {
                TVEmpty(text: "Create teams in Settings > Teams to start the team race.")
            } else {
                VStack(spacing: 36) {
                    ForEach(board.teams.prefix(6)) { team in
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .lastTextBaseline) {
                                Text("\(team.rank)").font(.system(size: 44, weight: .heavy)).foregroundStyle(TVTheme.medal(team.rank) ?? TVTheme.muted).frame(width: 70, alignment: .leading)
                                Text(team.name).font(.system(size: 46, weight: .bold)).foregroundStyle(TVTheme.text)
                                Text("\(team.brokers) \(team.brokers == 1 ? "broker" : "brokers") · \(team.deals) \(team.deals == 1 ? "deal" : "deals")")
                                    .font(.system(size: 28)).foregroundStyle(TVTheme.muted).padding(.leading, 16)
                                Spacer()
                                Text(TVFormat.money(team.volume, currency: board.currency)).font(.system(size: 48, weight: .heavy)).monospacedDigit().foregroundStyle(TVTheme.text)
                                if let goal = team.goal { Text("/ \(TVFormat.short(goal))").font(.system(size: 32)).foregroundStyle(TVTheme.muted) }
                            }
                            TVProgressBar(fraction: team.volume / (team.goal ?? top), accent: team.rank == 1 ? TVTheme.gold : accent, height: 30)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

/// The office's month: funded volume against the combined goal, deals funded and days left.
struct TVGoalSlide: View {
    var board: TVBoard
    var accent: Color

    var body: some View {
        let fraction = board.office.goal.map { $0 > 0 ? board.office.volume / $0 : 0 } ?? 0
        VStack(alignment: .leading, spacing: 0) {
            TVSlideTitle(title: "Monthly goal", subtitle: board.period.label)
            HStack(spacing: 120) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.1), lineWidth: 46)
                    Circle().trim(from: 0, to: min(fraction, 1)).stroke(fraction >= 1 ? TVTheme.up : accent, style: StrokeStyle(lineWidth: 46, lineCap: .round)).rotationEffect(.degrees(-90))
                    VStack(spacing: 8) {
                        Text(board.office.goal == nil ? "—" : "\(Int((fraction * 100).rounded()))%").font(.system(size: 130, weight: .heavy)).foregroundStyle(TVTheme.text)
                        Text(board.office.goal == nil ? "No goal set" : "of goal").font(.system(size: 34)).foregroundStyle(TVTheme.muted)
                    }
                }
                .frame(width: 560, height: 560)
                VStack(alignment: .leading, spacing: 44) {
                    stat("Funded", TVFormat.money(board.office.volume, currency: board.currency))
                    if let goal = board.office.goal {
                        stat("Goal", TVFormat.money(goal, currency: board.currency))
                        stat("Still to go", TVFormat.money(max(goal - board.office.volume, 0), currency: board.currency))
                    }
                    stat("Deals funded", "\(board.office.deals)")
                    stat("Days left", "\(board.period.days_left)")
                }
            }
            .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased()).font(.system(size: 24, weight: .semibold)).tracking(3).foregroundStyle(TVTheme.muted)
            Text(value).font(.system(size: 64, weight: .heavy)).monospacedDigit().foregroundStyle(TVTheme.text)
        }
    }
}

/// The latest funded deals: who funded it and how much (no client names).
struct TVRecentSlide: View {
    var board: TVBoard
    var accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TVSlideTitle(title: "Latest funded deals", subtitle: board.period.label)
            if board.recent.isEmpty {
                TVEmpty(text: "No funded deals yet this month.")
            } else {
                VStack(spacing: 16) {
                    ForEach(board.recent.prefix(6)) { deal in
                        HStack(spacing: 30) {
                            TVAvatar(initials: deal.initials, photoURL: deal.photo_url, size: 84, accent: accent)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(deal.broker).font(.system(size: 42, weight: .semibold)).foregroundStyle(TVTheme.text)
                                if let team = deal.team { Text(team).font(.system(size: 26)).foregroundStyle(TVTheme.muted) }
                            }
                            Spacer()
                            Text(TVFormat.ago(deal.funded_at)).font(.system(size: 28)).foregroundStyle(TVTheme.muted)
                            Text(TVFormat.money(deal.amount, currency: board.currency)).font(.system(size: 52, weight: .heavy)).monospacedDigit().foregroundStyle(TVTheme.up)
                                .frame(width: 360, alignment: .trailing)
                        }
                        .padding(.horizontal, 32).padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 22).fill(TVTheme.panel))
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct TVEmpty: View {
    var text: String
    var body: some View {
        Text(text).font(.system(size: 40)).foregroundStyle(TVTheme.muted).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
