# HtmlFox

> A native, offline-first HTML reader, editor, and exporter for iPhone and iPad.

HtmlFox opens `.html` / `.htm` / `.xhtml` files, renders them as documents, lets you search inside the page, switch between mobile and desktop preview widths, edit visible text directly in the rendered page or in a raw source editor, and export the result as **HTML** or **PDF**.

The app is **fully on-device**. It has no accounts, no analytics, no advertising, and no tracking. It only touches the network when a document you open references remote resources (images, fonts, etc.), exactly as a browser would.

**Languages:** English · [简体中文](README.zh-CN.md)

- Platform: iOS 17+ (iPhone & iPad) · Built with: SwiftUI + WebKit + StoreKit 2 · Bundle ID: `com.htmlfox.ios`

---

## Table of Contents

- [Highlights](#highlights)
- [Features](#features)
- [Free vs. Pro](#free-vs-pro)
- [Privacy](#privacy)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Requirements](#requirements)
- [Getting Started](#getting-started)
- [Testing In-App Purchases Locally](#testing-in-app-purchases-locally)
- [Configuration Reference](#configuration-reference)
- [File Handling & Document Types](#file-handling--document-types)
- [App Store Submission](#app-store-submission)
- [Known Limitations](#known-limitations)
- [Roadmap](#roadmap)
- [License](#license)

---

## Highlights

- 📄 **Read** any HTML file as a clean, rendered document.
- 🔍 **Find in page** with live match counts and next/previous navigation.
- 📱💻 **Mobile / Web preview** toggle with adjustable zoom for desktop-width layouts.
- ✏️ **Edit in place** — change visible text right in the rendered page, or drop into a monospaced **source editor**.
- 📤 **Export** to HTML (share sheet) or **PDF** (rendered from the live preview).
- 🕘 **Recent documents** on the home screen.
- 🌐 **Bilingual** UI (English / Simplified Chinese), following the system language.
- 🔒 **Private by design** — no data collection, no network calls of its own.

## Features

### Viewing & navigation
- Open files via the iOS document picker, or by choosing **"Open with HtmlFox"** from Files, Mail, and other apps (handled through `onOpenURL`).
- Render with `WKWebView`.
- **Mobile** preview (phone width) and **Web** preview (desktop width) with a zoom slider.
- Find-in-page search: case-insensitive matching, total match count, and up/down navigation that scrolls each hit to the center.

### Editing (Pro)
- **Preview edit mode** — tap to make visible text editable directly in the rendered page; controlled by injected JavaScript, with links/forms suppressed while editing.
- **Source editor** — a monospaced editor for the raw HTML, with smart quotes / auto-correction disabled.
- Edits are flushed and committed automatically when you leave edit mode, close the document, or switch screens, so in-progress work is not lost.

### Export (Pro)
- **Export HTML** through the iOS share sheet.
- **Export PDF** rendered from the current preview via `WKWebView.createPDF`.

## Free vs. Pro

HtmlFox uses a single one-time purchase (no subscription) with a free trial.

| Capability | Free | 3-day trial | Pro (unlocked) |
| --- | :---: | :---: | :---: |
| Open / read documents | ✅ | ✅ | ✅ |
| Find in page | ✅ | ✅ | ✅ |
| Mobile / Web preview & zoom | ✅ | ✅ | ✅ |
| Recent documents | ✅ | ✅ | ✅ |
| **Edit** (preview + source) | — | ✅ | ✅ |
| **Export** HTML / PDF | — | ✅ | ✅ |

- **Product:** `com.htmlfox.ios.pro` — a **non-consumable** unlock, **US$2.99**, yours forever.
- **Free trial:** 3 days from first launch, unlocking all Pro features. The trial start date is stored in the **Keychain** so reinstalling the app does not reset it.
- **Restore:** A *Restore Purchase* action is available on the paywall and from the home-screen "Unlock Pro" entry.

Implementation lives in [`PurchaseManager.swift`](HtmlFoxIOS/Services/PurchaseManager.swift) (StoreKit 2); the paywall is [`PaywallView.swift`](HtmlFoxIOS/Views/PaywallView.swift).

## Privacy

- **No data collection, no tracking, no ads, no accounts.**
- The app makes **no network requests of its own**; remote resources only load if the opened document references them.
- A privacy manifest ([`PrivacyInfo.xcprivacy`](HtmlFoxIOS/Resources/PrivacyInfo.xcprivacy)) declares the one required-reason API in use (`UserDefaults`, reason `CA92.1`) and that no data is collected.
- Full policy: [`docs/privacy.html`](docs/privacy.html) (also intended for hosting as the App Store "Privacy Policy URL").

## Architecture

HtmlFox is a small, single-target SwiftUI app. State flows through two `@MainActor` observable objects injected into the environment:

- **`AppState`** — the current document, recent list, importer/share presentation, and error surface.
- **`PurchaseManager`** — StoreKit 2 entitlement state plus the local free-trial clock.

Documents are modeled by `HtmlDocument`, and the active screen is selected by `DocumentMode` (`read` / `editPreview` / `editSource`). The rendered view is a `UIViewRepresentable` wrapper (`WebPreview`) over `WKWebView`; editing is driven by injecting small JavaScript snippets (in `Scripts/`) to toggle `contenteditable` and to extract the edited DOM back into Swift.

Key design points:
- `WebPreview` avoids a full page reload when the edited HTML round-trips back through SwiftUI state, preserving scroll position and avoiding flashes.
- Imported files are copied into the sandbox and re-opened from there; relative resources resolve against the import's directory via `baseURL`.
- The trial anchor persists in the Keychain to resist reinstall-based trial resets.

For a detailed account of recent fixes and intentional trade-offs, see [`docs/2026-06-15-review-fixes.md`](docs/2026-06-15-review-fixes.md).

## Project Structure

```
HtmlFox/
├─ HtmlFox.xcodeproj/          # Xcode project (also generable from project.yml)
├─ HtmlFox.storekit            # Local StoreKit testing configuration
├─ project.yml                 # XcodeGen project definition
├─ docs/
│  ├─ privacy.html             # Privacy policy page (host for App Store URL)
│  └─ 2026-06-15-review-fixes.md
└─ HtmlFoxIOS/
   ├─ HtmlFoxIOSApp.swift      # App entry; injects state, onOpenURL, scenePhase
   ├─ AppState.swift           # Document & app-level state
   ├─ Models/                  # HtmlDocument, DocumentMode, RecentDocument, …
   ├─ Views/                   # HomeView, PreviewScreen, SourceEditorScreen, PaywallView, …
   ├─ Components/              # WebPreview (WKWebView), ShareSheet, SourceTextView, AppChrome
   ├─ Services/                # DocumentImporter, PurchaseManager, RecentDocumentStore,
   │                           #   TemporaryFileStore, PreviewEditScriptStore
   ├─ Scripts/                 # enable/disable preview-edit JavaScript
   ├─ Resources/               # Info.plist, Localizable.xcstrings, PrivacyInfo.xcprivacy
   └─ Assets.xcassets/         # AppIcon
```

## Requirements

- **iOS 17.0** or later (iPhone and iPad)
- **Xcode 16** or later
- An Apple Developer account (to run on device and to submit to the App Store)

## Getting Started

### Use the existing project

1. Open `HtmlFox.xcodeproj` in Xcode.
2. Select the `HtmlFox` target → **Signing & Capabilities** and choose your development team.
3. Choose an iPhone or iPad simulator (or a connected device) and **Run**.

### Regenerate with XcodeGen (optional)

The Xcode project can be regenerated from `project.yml`:

```bash
brew install xcodegen
xcodegen generate
open HtmlFox.xcodeproj
```

## Testing In-App Purchases Locally

You can exercise purchase and restore flows in the simulator without real payment:

1. In Xcode, **Edit Scheme… → Run → Options**.
2. Set **StoreKit Configuration** to `HtmlFox.storekit`.
3. Run. The paywall shows the `US$2.99` product; purchases are simulated.
4. Reset purchase state any time via **Debug → StoreKit → Manage Transactions** while running.

The free trial is independent of StoreKit: it starts on first launch and is read from the Keychain.

## Configuration Reference

| Setting | Value |
| --- | --- |
| Product name | `HtmlFox` |
| Bundle identifier | `com.htmlfox.ios` |
| IAP product ID | `com.htmlfox.ios.pro` (non-consumable, US$2.99) |
| Minimum iOS | 17.0 |
| Devices | iPhone & iPad (`TARGETED_DEVICE_FAMILY = 1,2`) |
| Interface | SwiftUI |
| App icon | `Assets.xcassets/AppIcon` |
| Privacy manifest | `HtmlFoxIOS/Resources/PrivacyInfo.xcprivacy` |
| Localizations | `Localizable.xcstrings` (en, zh-Hans) |
| Encryption | `ITSAppUsesNonExemptEncryption = false` |

## File Handling & Document Types

The app registers as an opener for:

- `public.html`
- `public.xhtml`

Imported files are copied into the app sandbox; **originals are never modified**. Two files that share a name (for example `index.html` from different folders) currently share one sandbox slot, so opening the second one replaces the first in the Recent list. If you need to keep multiple copies side by side, rename one before opening.

## App Store Submission

1. Set `DEVELOPMENT_TEAM` (Signing & Capabilities) — required to archive.
2. In **App Store Connect**, create the app record with bundle ID `com.htmlfox.ios`.
3. Create the in-app purchase:
   - Type: **Non-Consumable**
   - Product ID: **`com.htmlfox.ios.pro`** (must match the code)
   - Price: **US$2.99**; add display name, description, and a review screenshot.
4. Bump `CFBundleShortVersionString` / `CFBundleVersion` in `Info.plist` for each release.
5. **Archive** with the Release configuration and validate in the Organizer, then upload.
6. Fill **App Privacy** as **Data Not Collected**, and provide the **Privacy Policy URL** (host `docs/privacy.html`).
7. Prepare iPhone and iPad screenshots, ideally in both English and Simplified Chinese.
8. Submit the IAP **together with** the app version for the first review, and note in *App Review Information* that opening / preview / search are free while editing and export require the one-time unlock (with a 3-day trial and a Restore option).

> **Note:** Archiving, signing, and uploading require macOS + Xcode. App Store Connect configuration (records, IAP, metadata, screenshots) can be done from any browser, including on Windows.

## Known Limitations

- **Single-file import:** sibling resources of an HTML file are not copied into the sandbox, so relative assets only resolve if they happen to live in the import directory.
- **Same-name documents** share one sandbox slot (see above).
- **Character encodings:** the importer tries UTF-8 then Unicode; some legacy encodings (GB18030, Shift-JIS) may render incorrectly.

These and their rationale are documented in [`docs/2026-06-15-review-fixes.md`](docs/2026-06-15-review-fixes.md).

## Roadmap

- Throttled HTML sync during preview editing (snapshot on blur / backgrounding).
- Whole-folder import so relative assets resolve fully.
- iCloud Drive / Files integration via `UIDocument`.
- Smarter charset sniffing (BOM / `meta charset` / heuristics).

## License

© HtmlFox. All rights reserved. No open-source license is granted at this time. The project depends only on Apple's first-party frameworks (SwiftUI, WebKit, StoreKit, Foundation, UIKit).
