# HtmlFox

HtmlFox is a native SwiftUI app for opening HTML files, reading them as rendered documents, searching inside previews, switching between mobile and web preview sizes, making simple text edits directly in the preview, and exporting the result as HTML or PDF.

The app is fully on-device: it does not collect data, does not track users, and only reaches the network when an opened document itself references remote resources.

## Features

- Open `.html` / `.htm` / `.xhtml` files through the iOS document picker
- Render HTML in `WKWebView` with mobile and web (desktop-width) preview modes
- Adjustable zoom for the web preview
- Find-in-page search with match count and next/previous navigation
- Preview edit mode: edit visible text directly in the rendered page
- Advanced source editor with monospaced editing
- Recent documents list on the home screen
- Export the current HTML via the iOS share sheet
- Export the rendered preview as a PDF
- Localized in English and Simplified Chinese (简体中文)

## Requirements

- iOS 16.0 or later (iPhone and iPad)
- Xcode 16 or later

## Building

The project ships with a generated `HtmlFox.xcodeproj`. It can also be regenerated from `project.yml` with [XcodeGen](https://github.com/yonyz/XcodeGen).

### Using the existing project

1. Open `HtmlFox.xcodeproj` in Xcode.
2. Select the `HtmlFox` target → Signing & Capabilities and choose your development team.
3. Build and run on an iPhone or iPad simulator or device.

### Regenerating with XcodeGen

1. Install XcodeGen: `brew install xcodegen`.
2. Run `xcodegen generate` from this folder.
3. Open `HtmlFox.xcodeproj` and set your development team.

## Project Configuration

- Product name: `HtmlFox`
- Bundle identifier: `com.htmlfox.ios`
- Interface: SwiftUI
- Minimum iOS: 16.0
- Supported devices: iPhone and iPad
- App icon: `Assets.xcassets/AppIcon`
- Privacy manifest: `HtmlFoxIOS/Resources/PrivacyInfo.xcprivacy`
- Localizations: `HtmlFoxIOS/Resources/Localizable.xcstrings` (en, zh-Hans)

## Document Types

The app registers itself as an opener for HTML documents:

- `public.html`
- `public.xhtml`

Imported files are copied into the app sandbox; the originals are never modified. Two files that share a name (e.g. `index.html` from different folders) currently share one sandbox slot — opening the second one replaces the first in the Recent list. If you need to keep multiple copies side by side, rename one of them before opening.

## App Store Submission Checklist

- [ ] Set `DEVELOPMENT_TEAM` (Signing & Capabilities) — required to archive.
- [ ] Bump `CFBundleShortVersionString` / `CFBundleVersion` in `Info.plist` per release.
- [ ] Archive with the Release configuration and validate in the Organizer.
- [ ] Provide App Privacy details in App Store Connect: **Data Not Collected**.
- [ ] Prepare iPhone and iPad screenshots in both English and Simplified Chinese.
