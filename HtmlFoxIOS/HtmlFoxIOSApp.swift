import SwiftUI

@main
struct HtmlFoxIOSApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var purchases = PurchaseManager()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(appState)
                .environmentObject(purchases)
        }
    }
}
