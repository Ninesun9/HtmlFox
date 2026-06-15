import SwiftUI

struct SourceEditorScreen: View {
    @EnvironmentObject private var appState: AppState
    let document: HtmlDocument

    @State private var draftHTML: String

    init(document: HtmlDocument) {
        self.document = document
        _draftHTML = State(initialValue: document.html)
    }

    var body: some View {
        SourceTextView(text: $draftHTML)
            .navigationTitle("Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Preview") {
                        appState.updateCurrentHTML(draftHTML)
                        appState.setMode(.read)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        appState.updateCurrentHTML(draftHTML)
                        appState.exportHTML()
                    } label: {
                        Label("Export HTML", systemImage: "square.and.arrow.up")
                    }
                }
            }
    }
}
