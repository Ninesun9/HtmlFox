import Foundation

struct RecentDocument: Identifiable, Codable, Equatable {
    let id: UUID
    var fileName: String
    var lastOpenedAt: Date

    init(id: UUID = UUID(), fileName: String, lastOpenedAt: Date = Date()) {
        self.id = id
        self.fileName = fileName
        self.lastOpenedAt = lastOpenedAt
    }
}
