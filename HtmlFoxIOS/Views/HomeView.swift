import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            Group {
                if appState.currentDocument != nil {
                    DocumentView()
                } else {
                    emptyState
                }
            }
            .navigationTitle("HtmlFox")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        appState.openImporter()
                    } label: {
                        Label("Open", systemImage: "folder")
                    }
                }
            }
            .fileImporter(
                isPresented: $appState.isImporterPresented,
                allowedContentTypes: [.html, .text],
                allowsMultipleSelection: false
            ) { result in
                Task {
                    await handleImport(result)
                }
            }
            .sheet(item: $appState.activeShareItem) { item in
                ShareSheet(activityItems: [item.url])
            }
            .alert("Error", isPresented: errorBinding) {
                Button("OK") {
                    appState.errorMessage = nil
                }
            } message: {
                Text(appState.errorMessage ?? "")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            IconTile(systemImage: "curlybraces.square.fill", tint: AppChrome.accent, size: 64)

            VStack(spacing: 4) {
                Text("HtmlFox")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppChrome.ink)
                Text("HTML editor for iOS")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                appState.openImporter()
            } label: {
                Label("Open HTML", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.borderedProminent)

            if !appState.recentDocuments.isEmpty {
                recentList
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppChrome.canvas)
    }

    private var recentList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            List {
                ForEach(appState.recentDocuments) { recent in
                    Button {
                        appState.openRecent(recent)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .foregroundStyle(AppChrome.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(recent.fileName)
                                    .foregroundStyle(AppChrome.ink)
                                    .lineLimit(1)
                                Text(recent.lastOpenedAt, format: .relative(presentation: .named))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    offsets.map { appState.recentDocuments[$0] }.forEach(appState.removeRecent)
                }
            }
            .listStyle(.plain)
            .frame(maxWidth: 480)
        }
        .padding(.top, 8)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { appState.errorMessage != nil },
            set: { if !$0 { appState.errorMessage = nil } }
        )
    }

    private func handleImport(_ result: Result<[URL], Error>) async {
        do {
            guard let url = try result.get().first else { return }
            await appState.importDocument(from: url)
        } catch {
            appState.errorMessage = error.localizedDescription
        }
    }
}
