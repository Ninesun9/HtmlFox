(() => {
  document.querySelectorAll('[data-htmlfox-editable="true"]').forEach((element) => {
    element.removeAttribute("contenteditable");
    element.removeAttribute("data-htmlfox-editable");
  });

  const style = document.getElementById("htmlfox-edit-style");
  if (style) {
    style.remove();
  }

  if (window.__htmlfoxPreventClick) {
    document.removeEventListener("click", window.__htmlfoxPreventClick, true);
    delete window.__htmlfoxPreventClick;
  }

  if (window.__htmlfoxPreventSubmit) {
    document.removeEventListener("submit", window.__htmlfoxPreventSubmit, true);
    delete window.__htmlfoxPreventSubmit;
  }

  delete document.documentElement.dataset.htmlfoxEditMode;

  return document.documentElement.outerHTML;
})();
