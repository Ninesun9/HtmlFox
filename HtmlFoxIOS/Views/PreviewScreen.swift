import SwiftUI

struct PreviewScreen: View {
    @EnvironmentObject private var appState: AppState
    let document: HtmlDocument

    @StateObject private var webViewController = WebPreviewController()
    @FocusState private var isSearchFocused: Bool
    @State private var searchText = ""
    @State private var searchStatus = ""
    @State private var searchMatchCount = 0
    @State private var searchCurrentIndex = 0
    @State private var viewportMode: PreviewViewportMode = .mobile
    @State private var webZoom = 0.75

    var body: some View {
        VStack(spacing: 0) {
            searchPanel
            previewCanvas
            statusBar
        }
        .background(previewBackground)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    toggleEditMode()
                } label: {
                    Label(editButtonTitle, systemImage: document.mode == .editPreview ? "checkmark" : "pencil")
                }

                Menu {
                    Button {
                        appState.setMode(.editSource)
                    } label: {
                        Label("Source", systemImage: "chevron.left.forwardslash.chevron.right")
                    }

                    Button {
                        exportPDF()
                    } label: {
                        Label("Export PDF", systemImage: "doc.richtext")
                    }

                    Button {
                        appState.exportHTML()
                    } label: {
                        Label("Export HTML", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private var previewCanvas: some View {
        GeometryReader { geometry in
            let availableWidth = max(geometry.size.width - 32, 240)
            let cardWidth = min(viewportMode.viewportWidth, availableWidth)
            let cardHeight = max(geometry.size.height - 32, 360)
            let webScale = CGFloat(webZoom)
            let webWidth = viewportMode.viewportWidth
            let webDisplayHeight = max(geometry.size.height - 32, 360)
            let webHeight = webDisplayHeight / webScale

            Group {
                if viewportMode == .mobile {
                    previewCard(width: cardWidth, height: cardHeight)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .frame(width: geometry.size.width,
                               height: geometry.size.height,
                               alignment: .center)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal) {
                            previewCard(width: webWidth, height: webHeight)
                                .id("webCard")
                                .scaleEffect(webScale, anchor: .topLeading)
                                .frame(width: webWidth * webScale,
                                       height: webDisplayHeight,
                                       alignment: .topLeading)
                                .padding(.horizontal, geometry.size.width / 2)
                                .padding(.vertical, 16)
                        }
                        .onAppear {
                            DispatchQueue.main.async {
                                proxy.scrollTo("webCard", anchor: .top)
                            }
                        }
                    }
                }
            }
            .background(previewBackground)
        }
    }

    private func previewCard(width: CGFloat, height: CGFloat) -> some View {
        WebPreview(
            html: document.html,
            mode: document.mode,
            controller: webViewController,
            onHTMLChanged: { html in
                appState.updateCurrentHTML(html)
            }
        )
        .frame(width: width, height: height)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8).stroke(AppChrome.line)
        }
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 5)
    }

    private var previewBackground: some View {
        ZStack {
            AppChrome.canvas
            LinearGradient(
                colors: [
                    AppChrome.accent.opacity(0.08),
                    AppChrome.violet.opacity(0.05),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }

    private var title: String {
        document.isDirty ? "\(document.fileName) *" : document.fileName
    }

    private var editButtonTitle: String {
        document.mode == .editPreview ? "Done" : "Edit"
    }

    private var statusBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                viewportPicker

                Spacer()

                Image(systemName: modeIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(modeTint)
                    .frame(width: 30, height: 30)
                    .background(modeTint.opacity(0.12), in: Circle())

                Image(systemName: document.isDirty ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(document.isDirty ? AppChrome.warm : AppChrome.success)
                    .frame(width: 30, height: 30)
                    .background((document.isDirty ? AppChrome.warm : AppChrome.success).opacity(0.12), in: Circle())
                    .padding(.leading, 8)
            }

            if viewportMode == .web {
                zoomControl
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: -3)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .background(AppChrome.canvas)
    }

    private var viewportPicker: some View {
        Picker("Preview", selection: $viewportMode) {
            ForEach(PreviewViewportMode.allCases) { mode in
                Label(mode.title, systemImage: mode.systemImage)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 156)
    }

    private var zoomControl: some View {
        HStack(spacing: 8) {
            Image(systemName: "minus.magnifyingglass")
                .font(.caption)
                .foregroundStyle(.secondary)
            Slider(value: $webZoom, in: 0.4...1.25, step: 0.05)
            Image(systemName: "plus.magnifyingglass")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(Int(webZoom * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
    }

    private var modeIcon: String {
        document.mode == .editPreview ? "pencil.line" : "doc.text.magnifyingglass"
    }

    private var modeTint: Color {
        document.mode == .editPreview ? AppChrome.violet : AppChrome.accent
    }

    private var searchPanel: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search page content", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($isSearchFocused)
                    .onChange(of: searchText) { _ in
                        updateSearchCount()
                    }
                    .onSubmit {
                        findNext()
                    }

                if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        clearSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                Text(searchSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Button {
                    findPrevious()
                } label: {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderless)
                .disabled(!canNavigateSearch)
                .accessibilityLabel("Previous")

                Button {
                    findNext()
                } label: {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
                .disabled(!canNavigateSearch)
                .accessibilityLabel("Next")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.thinMaterial)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var canNavigateSearch: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && searchMatchCount > 0
    }

    private var searchSummary: String {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if query.isEmpty {
            return String(localized: "Enter a keyword, then use the arrows to search")
        }

        if searchMatchCount == 0 {
            return searchStatus.isEmpty ? String(localized: "No matches") : searchStatus
        }

        if searchCurrentIndex == 0 {
            return String(localized: "\(searchMatchCount) results")
        }

        return String(localized: "\(searchCurrentIndex) of \(searchMatchCount)")
    }

    private func clearSearch() {
        searchText = ""
        searchStatus = ""
        searchMatchCount = 0
        searchCurrentIndex = 0
    }

    private func findNext() {
        runSearch(backwards: false)
    }

    private func findPrevious() {
        runSearch(backwards: true)
    }

    private func runSearch(backwards: Bool) {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            clearSearch()
            return
        }

        webViewController.find(query, backwards: backwards) { found in
            Task { @MainActor in
                guard found else {
                    searchStatus = String(localized: "No matches")
                    searchCurrentIndex = 0
                    return
                }

                searchStatus = ""
                if searchMatchCount > 0 {
                    if backwards {
                        searchCurrentIndex = searchCurrentIndex <= 1 ? searchMatchCount : searchCurrentIndex - 1
                    } else {
                        searchCurrentIndex = searchCurrentIndex >= searchMatchCount ? 1 : searchCurrentIndex + 1
                    }
                }
            }
        }
    }

    private func updateSearchCount() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchStatus = ""
            searchMatchCount = 0
            searchCurrentIndex = 0
            return
        }

        webViewController.countMatches(for: query) { count in
            Task { @MainActor in
                guard searchText.trimmingCharacters(in: .whitespacesAndNewlines) == query else { return }

                searchMatchCount = count
                searchCurrentIndex = 0
                searchStatus = count > 0 ? "" : String(localized: "No matches")

                if count > 0 {
                    runSearch(backwards: false)
                }
            }
        }
    }

    private func toggleEditMode() {
        if document.mode == .editPreview {
            webViewController.finishEditing { html in
                if let html {
                    appState.updateCurrentHTML(html)
                }
                appState.setMode(.read)
            }
        } else {
            appState.setMode(.editPreview)
        }
    }

    private func exportPDF() {
        if document.mode == .editPreview {
            webViewController.finishEditing { html in
                if let html {
                    appState.updateCurrentHTML(html)
                }
                appState.setMode(.read)
                renderPDF()
            }
            return
        }

        renderPDF()
    }

    private func renderPDF() {
        webViewController.exportPDF(fileName: document.exportBaseName) { result in
            switch result {
            case .success(let url):
                appState.share(url: url)
            case .failure(let error):
                appState.errorMessage = error.localizedDescription
            }
        }
    }
}
