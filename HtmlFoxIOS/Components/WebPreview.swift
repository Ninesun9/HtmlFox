import SwiftUI
import UIKit
import WebKit

final class WebPreviewController: ObservableObject {
    fileprivate weak var webView: WKWebView?
    private let temporaryFileStore = TemporaryFileStore()

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
        webView?.evaluateJavaScript(PreviewEditScriptStore().disableScript()) { result, _ in
            completion(result as? String)
        }
    }

    func exportPDF(fileName: String, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let webView else {
            completion(.failure(WebPreviewError.missingWebView))
            return
        }

        let config = WKPDFConfiguration()
        config.rect = CGRect(origin: .zero, size: webView.scrollView.contentSize)

        webView.createPDF(configuration: config) { result in
            switch result {
            case .success(let data):
                do {
                    let url = try self.temporaryFileStore.writePDF(data: data, fileName: fileName)
                    completion(.success(url))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
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
    let controller: WebPreviewController
    let onHTMLChanged: (String) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.keyboardDismissMode = .interactive
        controller.webView = webView
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self

        if context.coordinator.loadedHTML != html && mode != .editPreview {
            context.coordinator.loadedHTML = html
            webView.loadHTMLString(html, baseURL: nil)
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

    private func applyMode(_ mode: DocumentMode, to webView: WKWebView) {
        let scripts = PreviewEditScriptStore()
        switch mode {
        case .editPreview:
            webView.evaluateJavaScript(scripts.enableScript())
        case .read, .editSource:
            webView.evaluateJavaScript(scripts.disableScript()) { result, _ in
                if let html = result as? String {
                    onHTMLChanged(html)
                }
            }
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
