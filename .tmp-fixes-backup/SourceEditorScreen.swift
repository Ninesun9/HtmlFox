import SwiftUI

struct SourceEditorScreen: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var purchases: PurchaseManager
    let document: HtmlDocument

    @State private var draftHTML: String
    @State private var showPaywall = false

    init(document: HtmlDocument) {
        self.document = document
        _draftHTML = State(initialValue: document.html)
    }

    var body: some View {
        SourceTextView(text: $draftHTML)
            .navigationTitle("Source")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button {
                        commitDraft()
                        appState.closeDocument()
                    } label: {
                        Label("Close", systemImage: "xmark")
                    }

                    Button("Preview") {
                        commitDraft()
                        appState.setMode(.read)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        commitDraft()
                        if purchases.canUseProFeatures {
                            appState.exportHTML()
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Label("Export HTML", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .onDisappear {
                // Capture pending edits if the user navigates away (back gesture,
                // close button, etc.) without explicitly tapping Preview / Export.
                commitDraft()
            }
    }

    private func commitDraft() {
        guard draftHTML != document.html else { return }
        appState.updateCurrentHTML(draftHTML)
    }
}
