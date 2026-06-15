import SwiftUI

enum AppChrome {
    static var canvas: Color { Color(.systemGroupedBackground) }
    static var cardSurface: Color { Color(.secondarySystemGroupedBackground) }
    static var ink: Color { Color(.label) }
    static var line: Color { Color(.separator) }

    static let accent = Color(.systemBlue)
    static let success = Color(.systemGreen)
    static let warm = Color(.systemOrange)
    static let violet = Color(.systemPurple)

    static var panel: Color { cardSurface }
}

struct Panel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(AppChrome.cardSurface,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 3)
    }
}

struct IconTile: View {
    let systemImage: String
    let tint: Color
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
    }
}
