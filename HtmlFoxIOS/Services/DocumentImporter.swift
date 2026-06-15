import Foundation

struct DocumentImporter {
    func importHTML(from url: URL) async throws -> HtmlDocument {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        let html = Self.decodeHTML(data)
        let sandboxURL = try copyIntoSandbox(sourceURL: url, data: data)

        return HtmlDocument(
            fileName: url.lastPathComponent,
            originalURL: url,
            sandboxURL: sandboxURL,
            html: html
        )
    }

    /// Re-opens a document that was previously imported into the app sandbox.
    func openSandboxDocument(fileName: String) throws -> HtmlDocument {
        let url = try importsDirectory().appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw DocumentImporterError.documentUnavailable
        }

        let data = try Data(contentsOf: url)
        return HtmlDocument(
            fileName: fileName,
            originalURL: nil,
            sandboxURL: url,
            html: Self.decodeHTML(data)
        )
    }

    /// Removes imported copies that are no longer referenced by the recent list.
    func pruneImports(keeping fileNames: Set<String>) {
        guard let directory = try? importsDirectory(),
              let contents = try? FileManager.default.contentsOfDirectory(
                  at: directory,
                  includingPropertiesForKeys: nil
              )
        else {
            return
        }

        for fileURL in contents where !fileNames.contains(fileURL.lastPathComponent) {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    func importsDirectory() throws -> URL {
        let documentsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let importsURL = documentsURL.appendingPathComponent("Imports", isDirectory: true)
        try FileManager.default.createDirectory(at: importsURL, withIntermediateDirectories: true)
        return importsURL
    }

    static func decodeHTML(_ data: Data) -> String {
        String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .unicode)
            ?? String(decoding: data, as: UTF8.self)
    }

    private func copyIntoSandbox(sourceURL: URL, data: Data) throws -> URL {
        let importsURL = try importsDirectory()
        let destinationURL = importsURL.appendingPathComponent(sourceURL.lastPathComponent)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try data.write(to: destinationURL, options: .atomic)
        return destinationURL
    }
}

enum DocumentImporterError: LocalizedError {
    case documentUnavailable

    var errorDescription: String? {
        String(localized: "This document is no longer available.")
    }
}
