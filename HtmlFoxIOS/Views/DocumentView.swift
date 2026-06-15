import SwiftUI

struct DocumentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if let document = appState.currentDocument {
                switch document.mode {
                case .editSource:
                    SourceEditorScreen(document: document)
                case .read, .editPreview:
                    PreviewScreen(document: document)
                }
            }
        }
    }
}
