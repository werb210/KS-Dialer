// KEYSTONE_TV_v1 - colours and type for a screen read from across a room.
import SwiftUI

enum TVTheme {
    static let background = Color(red: 0.04, green: 0.07, blue: 0.13)
    static let panel = Color(red: 0.08, green: 0.12, blue: 0.20)
    static let line = Color.white.opacity(0.08)
    static let text = Color.white
    static let muted = Color.white.opacity(0.6)
    static let up = Color(red: 0.20, green: 0.83, blue: 0.45)
    static let down = Color(red: 0.97, green: 0.40, blue: 0.40)
    static let gold = Color(red: 1.00, green: 0.80, blue: 0.25)
    static let silver = Color(red: 0.80, green: 0.84, blue: 0.90)
    static let bronze = Color(red: 0.86, green: 0.55, blue: 0.33)
    static let defaultAccent = Color(red: 0.23, green: 0.51, blue: 0.96)

    static func accent(_ hex: String?) -> Color {
        guard let hex, let c = Color(hex: hex) else { return defaultAccent }
        return c
    }

    static func medal(_ rank: Int) -> Color? {
        switch rank { case 1: return gold; case 2: return silver; case 3: return bronze; default: return nil }
    }
}

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}

/// A broker's photo, or their initials in a circle.
struct TVAvatar: View {
    var initials: String
    var photoURL: String?
    var size: CGFloat
    var accent: Color

    var body: some View {
        ZStack {
            Circle().fill(accent.opacity(0.35))
            Text(initials).font(.system(size: size * 0.38, weight: .bold)).foregroundStyle(.white)
            if let photoURL, let url = URL(string: photoURL) {
                AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.clear }
                    .clipShape(Circle())
            }
        }
        .frame(width: size, height: size)
    }
}

/// A rounded progress bar towards a goal.
struct TVProgressBar: View {
    var fraction: Double
    var accent: Color
    var height: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1))
                Capsule().fill(fraction >= 1 ? TVTheme.up : accent)
                    .frame(width: max(height, geo.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: height)
    }
}
