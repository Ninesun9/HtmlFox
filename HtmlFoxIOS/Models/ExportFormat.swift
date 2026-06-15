import Foundation

enum ExportFormat: String, CaseIterable, Identifiable {
    case html = "HTML"
    case pdf = "PDF"

    var id: String { rawValue }
}
