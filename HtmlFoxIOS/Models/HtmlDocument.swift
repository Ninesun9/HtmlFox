import Foundation

struct HtmlDocument: Identifiable, Equatable {
    let id: UUID
    var fileName: String
    var originalURL: URL?
    var sandboxURL: URL?
    var html: String
    var isDirty: Bool
    var mode: DocumentMode
    var lastOpenedAt: Date

    init(
        id: UUID = UUID(),
        fileName: String,
        originalURL: URL?,
        sandboxURL: URL?,
        html: String,
        isDirty: Bool = false,
        mode: DocumentMode = .read,
        lastOpenedAt: Date = Date()
    ) {
        self.id = id
        self.fileName = fileName
        self.originalURL = originalURL
        self.sandboxURL = sandboxURL
        self.html = html
        self.isDirty = isDirty
        self.mode = mode
        self.lastOpenedAt = lastOpenedAt
    }

    var exportBaseName: String {
        let base = (fileName as NSString).deletingPathExtension
        return base.isEmpty ? "HtmlFox-Document" : base
    }
}
