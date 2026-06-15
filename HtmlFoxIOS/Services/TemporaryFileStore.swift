import Foundation

struct TemporaryFileStore {
    private let exportDirectoryName = "Exports"

    func writeHTML(html: String, fileName: String) throws -> URL {
        let url = exportURL(fileName: fileName, extension: "html")
        guard let data = html.data(using: .utf8) else {
            throw TemporaryFileError.encodingFailed
        }
        try data.write(to: url, options: .atomic)
        return url
    }

    func writePDF(data: Data, fileName: String) throws -> URL {
        let url = exportURL(fileName: fileName, extension: "pdf")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Clears previously exported files so the temporary directory does not grow unbounded.
    func cleanUp() {
        guard let directory = exportDirectory(),
              let contents = try? FileManager.default.contentsOfDirectory(
                  at: directory,
                  includingPropertiesForKeys: nil
              )
        else {
            return
        }

        for fileURL in contents {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    private func exportURL(fileName: String, extension ext: String) -> URL {
        let directory = exportDirectory() ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
            .appendingPathComponent(Self.sanitize(fileName))
            .appendingPathExtension(ext)
    }

    private func exportDirectory() -> URL? {
        FileManager.default.temporaryDirectory.appendingPathComponent(exportDirectoryName, isDirectory: true)
    }

    /// Strips path separators and illegal characters so a document name can never escape the export directory.
    static func sanitize(_ fileName: String) -> String {
        var illegal = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        illegal.formUnion(.controlCharacters)
        illegal.formUnion(.newlines)

        let cleaned = fileName
            .components(separatedBy: illegal)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespaces)

        return cleaned.isEmpty ? "HtmlFox-Document" : cleaned
    }
}

enum TemporaryFileError: LocalizedError {
    case encodingFailed

    var errorDescription: String? {
        String(localized: "Unable to encode the HTML document.")
    }
}
