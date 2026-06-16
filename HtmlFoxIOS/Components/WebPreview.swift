import SwiftUI
import UIKit
import WebKit

@MainActor
final class WebPreviewController: ObservableObject {
    private(set) weak var webView: WKWebView?
    private let temporaryFileStore = TemporaryFileStore()
    private var pendingSelfEmittedHTML: String?

    func attach(_ webView: WKWebView) {
        self.webView = webView
    }

    /// Returns true if `html` matches HTML this controller just extracted from the web
    /// view itself (via finishEditing). Used by `WebPreview.updateUIView` to skip the
    /// otherwise wasteful reload that would happen when the round-tripped html lands
    /// back through SwiftUI state.
    func consumePendingSelfEmittedHTML(_ html: String) -> Bool {
        guard pendingSelfEmittedHTML == html else { return false }
        pendingSelfEmittedHTML = nil
        return true
    }

    func find(_ text: String, backwards: Bool = false, completion: @escaping (Bool) -> Void) {
        guard let webView, !text.isEmpty else {
            completion(false)
            return
        }

        let query = javaScriptStringLiteral(text)
        let direction = backwards ? "true" : "false"
        let script = """
        (() => {
            const found = window.find(\(query), false, \(direction), true, false, true, false);
            if (!found) { return false; }

            const selection = window.getSelection();
            if (!selection || selection.rangeCount === 0) { return true; }

            const range = selection.getRangeAt(0);
            const rects = Array.from(range.getClientRects());
            const rect = rects.find((item) => item.width > 0 && item.height > 0) || range.getBoundingClientRect();
            if (!rect) {
                return true;
            }

            const targetCenterY = rect.top + rect.height / 2;
            const targetCenterX = rect.left + rect.width / 2;
            const viewportCenterY = window.innerHeight / 2;
            const viewportCenterX = window.innerWidth / 2;

            window.scrollBy({
                top: targetCenterY - viewportCenterY,
                left: targetCenterX - viewportCenterX,
                behavior: "auto"
            });

            return true;
        })()
        """

        webView.evaluateJavaScript(script) { result, _ in
            completion((result as? Bool) ?? false)
        }
    }

    func countMatches(for text: String, completion: @escaping (Int) -> Void) {
        guard let webView, !text.isEmpty else {
            completion(0)
            return
        }

        let query = javaScriptStringLiteral(text)
        let script = """
        (() => {
            const needle = \(query).toLocaleLowerCase();
            if (!needle) { return 0; }

            const root = document.body || document.documentElement;
            if (!root) { return 0; }

            const walker = document.createTreeWalker(
                root,
                NodeFilter.SHOW_TEXT,
                {
                    acceptNode(node) {
                        const parent = node.parentElement;
                        if (!parent) { return NodeFilter.FILTER_REJECT; }

                        const tag = parent.tagName;
                        if (tag === "SCRIPT" || tag === "STYLE" || tag === "NOSCRIPT") {
                            return NodeFilter.FILTER_REJECT;
                        }

                        // Skip text that isn't actually rendered (display:none, or an
                        // ancestor that is) so the count matches what window.find,
                        // which only navigates visible matches, can reach.
                        if (parent.getClientRects().length === 0) {
                            return NodeFilter.FILTER_REJECT;
                        }

                        return NodeFilter.FILTER_ACCEPT;
                    }
                }
            );

            let count = 0;
            let node;
            while ((node = walker.nextNode())) {
                const value = (node.nodeValue || "").toLocaleLowerCase();
                let index = 0;

                while ((index = value.indexOf(needle, index)) !== -1) {
                    count += 1;
                    index += needle.length;
                }
            }

            return count;
        })()
        """

        webView.evaluateJavaScript(script) { result, _ in
            completion((result as? NSNumber)?.intValue ?? 0)
        }
    }

    func finishEditing(completion: @escaping (String?) -> Void) {
        webView?.evaluateJavaScript(PreviewEditScriptStore().disableScript()) { [weak self] result, _ in
            let html = result as? String
            if let html {
                self?.pendingSelfEmittedHTML = html
            }
            completion(html)
        }
    }

    func exportPDF(fileName: String, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let webView else {
            completion(.failure(WebPreviewError.missingWebView))
            return
        }

        // Paginate across US-Letter pages with UIPrintPageRenderer instead of
        // WKWebView.createPDF: createPDF renders the whole document onto a single
        // page, which a long page can push past the PDF max page size (~14 400 pt),
        // producing a clipped or blank file.
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(webView.viewPrintFormatter(), startingAtPageAt: 0)

        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)   // US Letter @ 72 dpi
        let printableRect = pageRect.insetBy(dx: 36, dy: 36)         // 0.5" margins
        renderer.setValue(NSValue(cgRect: pageRect), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: printableRect), forKey: "printableRect")

        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, pageRect, nil)
        let pageCount = max(renderer.numberOfPages, 1)
        for index in 0..<pageCount {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: index, in: pageRect)
        }
        UIGraphicsEndPDFContext()

        do {
            let url = try temporaryFileStore.writePDF(data: pdfData as Data, fileName: fileName)
            completion(.success(url))
        } catch {
            completion(.failure(error))
        }
    }

    private func javaScriptStringLiteral(_ text: String) -> String {
        guard let data = try? JSONEncoder().encode(text),
              let literal = String(data: data, encoding: .utf8)
        else {
            return "\"\""
        }

        return literal
    }
}

struct WebPreview: UIViewRepresentable {
    let html: String
    let mode: DocumentMode
    let baseURL: URL?
    let controller: WebPreviewController
    let onHTMLChanged: (String) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.keyboardDismissMode = .interactive
        controller.attach(webView)
        load(html, into: webView, coordinator: context.coordinator)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self

        // Skip reloads triggered by HTML the controller just round-tripped through
        // the web view (finishEditing → updateCurrentHTML). The DOM is already in
        // the desired state — re-loading would only cost a flash and scroll position.
        if controller.consumePendingSelfEmittedHTML(html) {
            context.coordinator.loadedHTML = html
            context.coordinator.currentMode = mode
            return
        }

        if context.coordinator.loadedHTML != html && mode != .editPreview {
            load(html, into: webView, coordinator: context.coordinator)
            return
        }

        if context.coordinator.currentMode != mode {
            context.coordinator.currentMode = mode
            applyMode(mode, to: webView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private func load(_ html: String, into webView: WKWebView, coordinator: Coordinator) {
        coordinator.loadedHTML = html
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    private func applyMode(_ mode: DocumentMode, to webView: WKWebView) {
        // We only enter edit mode here. Exiting edit mode (and the matching DOM
        // teardown) goes through `WebPreviewController.finishEditing`, which both
        // strips the contenteditable attributes and reports the extracted HTML.
        if mode == .editPreview {
            webView.evaluateJavaScript(PreviewEditScriptStore().enableScript())
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebPreview
        var loadedHTML: String
        var currentMode: DocumentMode

        init(parent: WebPreview) {
            self.parent = parent
            self.loadedHTML = parent.html
            self.currentMode = parent.mode
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            loadedHTML = parent.html
            currentMode = parent.mode
            if parent.mode == .editPreview {
                webView.evaluateJavaScript(PreviewEditScriptStore().enableScript())
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            // The document itself is rendered via loadHTMLString. Any other top-level
            // navigation (tapping a link, a form submit) should never hijack the preview:
            // open web links in the system browser instead, and block everything else.
            if navigationAction.navigationType == .linkActivated || navigationAction.targetFrame == nil {
                if let url = navigationAction.request.url, ["http", "https"].contains(url.scheme?.lowercased()) {
                    UIApplication.shared.open(url)
                }
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }
    }
}

enum WebPreviewError: LocalizedError {
    case missingWebView

    var errorDescription: String? {
        String(localized: "The preview is not ready yet.")
    }
}
