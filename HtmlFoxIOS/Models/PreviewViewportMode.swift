import CoreGraphics
import Foundation

enum PreviewViewportMode: String, CaseIterable, Identifiable {
    case mobile
    case web

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mobile:
            String(localized: "Mobile")
        case .web:
            String(localized: "Web")
        }
    }

    var systemImage: String {
        switch self {
        case .mobile:
            "iphone"
        case .web:
            "desktopcomputer"
        }
    }

    var viewportWidth: CGFloat {
        switch self {
        case .mobile:
            390
        case .web:
            1200
        }
    }
}
