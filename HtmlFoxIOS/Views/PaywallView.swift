import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var isWorking = false

    private let privacyURL = URL(string: "https://ninesun9.github.io/htmlfox-privacy/")!
    private let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    featureList
                    trialStatus
                    purchaseButton
                    restoreButton
                    legalLinks
                }
                .padding(24)
            }
            .background(AppChrome.canvas)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Close")
                }
            }
            .alert("Error", isPresented: errorBinding) {
                Button("OK") { purchases.purchaseError = nil }
            } message: {
                Text(purchases.purchaseError ?? "")
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            IconTile(systemImage: "curlybraces.square.fill", tint: AppChrome.accent, size: 72)
            Text("Unlock HtmlFox Pro")
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
            Text("A one-time purchase. Yours forever.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            featureRow(icon: "pencil", title: "Edit in preview and source")
            featureRow(icon: "square.and.arrow.up", title: "Export as HTML")
            featureRow(icon: "doc.richtext", title: "Export as PDF")
            featureRow(icon: "infinity", title: "One-time purchase, no subscription")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(AppChrome.cardSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func featureRow(icon: String, title: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppChrome.accent)
                .frame(width: 28)
            Text(title)
                .foregroundStyle(AppChrome.ink)
            Spacer()
        }
    }

    @ViewBuilder
    private var trialStatus: some View {
        if purchases.isInTrial {
            Label {
                Text("Free trial: \(purchases.trialDaysRemaining) days left")
            } icon: {
                Image(systemName: "clock")
            }
            .font(.subheadline)
            .foregroundStyle(AppChrome.accent)
        } else if !purchases.isPurchased {
            Label {
                Text("Your free trial has ended")
            } icon: {
                Image(systemName: "clock.badge.exclamationmark")
            }
            .font(.subheadline)
            .foregroundStyle(AppChrome.warm)
        }
    }

    private var purchaseButton: some View {
        Button {
            Task { await buy() }
        } label: {
            Group {
                if isWorking {
                    ProgressView()
                } else if let price = purchases.displayPrice {
                    Text("Unlock for \(price)")
                } else {
                    Text("Unlock")
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isWorking)
    }

    private var restoreButton: some View {
        Button {
            Task { await restore() }
        } label: {
            Text("Restore Purchase")
                .font(.subheadline)
        }
        .disabled(isWorking)
    }

    private var legalLinks: some View {
        HStack(spacing: 16) {
            Button("Privacy Policy") { openURL(privacyURL) }
            Text("·").foregroundStyle(.secondary)
            Button("Terms of Use") { openURL(termsURL) }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.top, 4)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { purchases.purchaseError != nil },
            set: { if !$0 { purchases.purchaseError = nil } }
        )
    }

    private func buy() async {
        isWorking = true
        let success = await purchases.purchase()
        isWorking = false
        if success { dismiss() }
    }

    private func restore() async {
        isWorking = true
        let success = await purchases.restore()
        isWorking = false
        if success { dismiss() }
    }
}
