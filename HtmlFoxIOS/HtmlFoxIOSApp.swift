import SwiftUI

@main
struct HtmlFoxIOSApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var purchases = PurchaseManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(appState)
                .environmentObject(purchases)
                .onOpenURL { url in
                    Task { await appState.importDocument(from: url) }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        purchases.refreshTrialState()
                    }
                }
        }
    }
}
