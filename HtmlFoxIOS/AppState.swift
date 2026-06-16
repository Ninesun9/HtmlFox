import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var currentDocument: HtmlDocument?
    @Published var recentDocuments: [RecentDocument] = []
    @Published var isImporterPresented = false
    @Published var activeShareItem: ShareItem?
    @Published var errorMessage: String?

    private let importer = DocumentImporter()
    private let recentStore = RecentDocumentStore()
    private let temporaryFileStore = TemporaryFileStore()

    init() {
        recentDocuments = recentStore.load()
        cleanUpStorage()
    }

    func openImporter() {
        isImporterPresented = true
    }

    func importDocument(from url: URL) async {
        do {
            let document = try await importer.importHTML(from: url)
            currentDocument = document
            remember(document)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openRecent(_ recent: RecentDocument) async {
        do {
            let document = try await importer.openSandboxDocument(fileName: recent.fileName)
            currentDocument = document
            remember(document)
        } catch {
            recentDocuments = recentStore.remove(recent, from: recentDocuments)
            errorMessage = error.localizedDescription
        }
    }

    func removeRecent(_ recent: RecentDocument) {
        recentDocuments = recentStore.remove(recent, from: recentDocuments)
        importer.pruneImports(keeping: Set(recentDocuments.map(\.fileName)))
    }

    func closeDocument() {
        currentDocument = nil
    }

    func updateCurrentHTML(_ html: String, for id: UUID? = nil) {
        guard var document = currentDocument else { return }
        // Ignore edits emitted by a screen that belongs to a document which is no
        // longer the current one (e.g. an editor's onDisappear firing after the
        // user opened a different file) — otherwise stale edits corrupt the new doc.
        if let id, document.id != id { return }
        document.html = html
        document.isDirty = true
        currentDocument = document
    }

    func setMode(_ mode: DocumentMode) {
        guard var document = currentDocument else { return }
        document.mode = mode
        currentDocument = document
    }

    func exportHTML() {
        guard let document = currentDocument else { return }

        do {
            let url = try temporaryFileStore.writeHTML(html: document.html, fileName: document.exportBaseName)
            activeShareItem = ShareItem(url: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func share(url: URL) {
        activeShareItem = ShareItem(url: url)
    }

    private func remember(_ document: HtmlDocument) {
        let item = RecentDocument(
            id: document.id,
            fileName: document.fileName,
            lastOpenedAt: document.lastOpenedAt
        )
        recentDocuments = recentStore.upsert(item, into: recentDocuments)
    }

    /// Removes stale export files and orphaned imports left over from previous sessions.
    private func cleanUpStorage() {
        temporaryFileStore.cleanUp()
        importer.pruneImports(keeping: Set(recentDocuments.map(\.fileName)))
    }
}
