import Foundation

struct PreviewEditScriptStore {
    func enableScript() -> String {
        loadScript(named: "enablePreviewEditMode") ?? fallbackEnableScript
    }

    func disableScript() -> String {
        loadScript(named: "disablePreviewEditMode") ?? fallbackDisableScript
    }

    func extractScript() -> String {
        loadScript(named: "extractEditedHTML") ?? "document.documentElement.outerHTML;"
    }

    private func loadScript(named name: String) -> String? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "js") else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    private var fallbackEnableScript: String {
        """
        (() => {
          document.documentElement.dataset.htmlfoxEditMode = "true";
          const style = document.createElement("style");
          style.id = "htmlfox-edit-style";
          style.textContent = "[data-htmlfox-editable='true']{outline:1px dashed rgba(0,122,255,.55);outline-offset:2px;}[data-htmlfox-editable='true']:focus{outline:2px solid rgba(0,122,255,.9);}";
          document.head.appendChild(style);
          const selector = "p,h1,h2,h3,h4,h5,h6,li,span,a,button,figcaption,td,th";
          document.querySelectorAll(selector).forEach((element) => {
            if ((element.innerText || "").trim().length === 0) return;
            element.setAttribute("contenteditable", "true");
            element.setAttribute("data-htmlfox-editable", "true");
          });
        })();
        """
    }

    private var fallbackDisableScript: String {
        """
        (() => {
          document.querySelectorAll("[data-htmlfox-editable='true']").forEach((element) => {
            element.removeAttribute("contenteditable");
            element.removeAttribute("data-htmlfox-editable");
          });
          document.getElementById("htmlfox-edit-style")?.remove();
          delete document.documentElement.dataset.htmlfoxEditMode;
          return document.documentElement.outerHTML;
        })();
        """
    }
}
