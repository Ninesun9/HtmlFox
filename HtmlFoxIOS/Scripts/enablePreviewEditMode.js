(() => {
  if (document.documentElement.dataset.htmlfoxEditMode === "true") {
    return;
  }

  document.documentElement.dataset.htmlfoxEditMode = "true";

  const style = document.createElement("style");
  style.id = "htmlfox-edit-style";
  style.textContent = `
    [data-htmlfox-editable="true"] {
      outline: 1px dashed rgba(0, 122, 255, 0.55) !important;
      outline-offset: 2px !important;
      -webkit-user-select: text !important;
      user-select: text !important;
    }

    [data-htmlfox-editable="true"]:focus {
      outline: 2px solid rgba(0, 122, 255, 0.9) !important;
    }
  `;
  document.head.appendChild(style);

  const selector = [
    "p",
    "h1",
    "h2",
    "h3",
    "h4",
    "h5",
    "h6",
    "li",
    "span",
    "a",
    "button",
    "figcaption",
    "td",
    "th"
  ].join(",");

  document.querySelectorAll(selector).forEach((element) => {
    const text = (element.innerText || "").trim();
    if (!text) {
      return;
    }

    element.setAttribute("contenteditable", "true");
    element.setAttribute("data-htmlfox-editable", "true");
  });

  document.addEventListener("click", window.__htmlfoxPreventClick = (event) => {
    const link = event.target.closest && event.target.closest("a");
    if (link) {
      event.preventDefault();
    }
  }, true);

  document.addEventListener("submit", window.__htmlfoxPreventSubmit = (event) => {
    event.preventDefault();
  }, true);
})();
