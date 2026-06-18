# HtmlFox

> 一款原生、离线优先的 HTML 阅读、编辑与导出工具，支持 iPhone 与 iPad。

HtmlFox 可以打开 `.html` / `.htm` / `.xhtml` 文件，以渲染后的文档形式呈现，支持页内搜索、在移动端与桌面端预览宽度之间切换，直接在渲染页面中或在原始源码编辑器里修改可见文本，并将结果导出为 **HTML** 或 **PDF**。

应用**完全在设备本地运行**：没有账号、没有数据分析、没有广告、没有追踪。只有当你打开的文档本身引用了远程资源（图片、字体等）时，才会像浏览器一样访问网络。

**语言：** [English](README.en.md) · 简体中文

- 平台：iOS 17+（iPhone 与 iPad） · 技术栈：SwiftUI + WebKit + StoreKit 2 · Bundle ID：`com.htmlfox.ios`

---

## 目录

- [亮点](#亮点)
- [功能特性](#功能特性)
- [免费版与 Pro](#免费版与-pro)
- [隐私](#隐私)
- [架构](#架构)
- [项目结构](#项目结构)
- [运行要求](#运行要求)
- [快速开始](#快速开始)
- [本地测试内购](#本地测试内购)
- [配置速查](#配置速查)
- [文件处理与文档类型](#文件处理与文档类型)
- [App Store 上架](#app-store-上架)
- [已知限制](#已知限制)
- [路线图](#路线图)
- [许可](#许可)

---

## 亮点

- 📄 **阅读**：把任意 HTML 文件渲染成干净的文档。
- 🔍 **页内搜索**：实时匹配数量统计 + 上一项/下一项跳转。
- 📱💻 **移动端 / 网页端预览**切换，桌面宽度布局可调缩放。
- ✏️ **就地编辑**：直接在渲染页面里改可见文本，或进入等宽**源码编辑器**。
- 📤 **导出**：HTML（分享面板）或 **PDF**（从实时预览渲染）。
- 🕘 主页显示**最近打开**文档。
- 🌐 **中英双语**界面，跟随系统语言。
- 🔒 **隐私优先**：不收集数据，自身不发起任何网络请求。

## 功能特性

### 浏览与导航
- 通过 iOS 文档选择器打开文件，或在「文件」「邮件」等 App 中选择**「用 HtmlFox 打开」**（由 `onOpenURL` 处理）。
- 使用 `WKWebView` 渲染。
- **移动端**预览（手机宽度）与**网页端**预览（桌面宽度），并带缩放滑块。
- 页内搜索：不区分大小写，显示匹配总数，上/下跳转会把命中项滚动到屏幕中央。

### 编辑（Pro）
- **预览编辑模式**：点按即可在渲染后的页面中直接编辑可见文本；由注入的 JavaScript 控制，编辑期间屏蔽链接跳转与表单提交。
- **源码编辑器**：等宽字体编辑原始 HTML，关闭智能引号与自动更正。
- 离开编辑模式、关闭文档或切换界面时，编辑内容会自动落盘提交，不会丢失进行中的工作。

### 导出（Pro）
- **导出 HTML**：通过 iOS 分享面板。
- **导出 PDF**：通过 `WKWebView.createPDF` 从当前预览渲染。

## 免费版与 Pro

HtmlFox 采用一次性买断（非订阅）+ 免费试用的模式。

| 能力 | 免费 | 3 天试用 | Pro（已解锁） |
| --- | :---: | :---: | :---: |
| 打开 / 阅读文档 | ✅ | ✅ | ✅ |
| 页内搜索 | ✅ | ✅ | ✅ |
| 移动端 / 网页端预览与缩放 | ✅ | ✅ | ✅ |
| 最近打开列表 | ✅ | ✅ | ✅ |
| **编辑**（预览 + 源码） | — | ✅ | ✅ |
| **导出** HTML / PDF | — | ✅ | ✅ |

- **产品：** `com.htmlfox.ios.pro` —— **非消耗型**解锁，**US$2.99**，永久有效。
- **免费试用：** 首次启动起 3 天，期间解锁全部 Pro 功能。试用起始时间存于 **Keychain**，卸载重装不会重置。
- **恢复购买：** 付费墙以及主页「解锁完整版」入口都提供「恢复购买」。

实现见 [`PurchaseManager.swift`](HtmlFoxIOS/Services/PurchaseManager.swift)（StoreKit 2），付费墙为 [`PaywallView.swift`](HtmlFoxIOS/Views/PaywallView.swift)。

## 隐私

- **不收集数据、不追踪、无广告、无账号。**
- 应用**自身不发起任何网络请求**；只有当打开的文档引用远程资源时才会加载它们。
- 隐私清单 [`PrivacyInfo.xcprivacy`](HtmlFoxIOS/Resources/PrivacyInfo.xcprivacy) 声明了所用的唯一「需说明原因 API」（`UserDefaults`，原因码 `CA92.1`），并声明不收集任何数据。
- 完整政策：[`docs/privacy.html`](docs/privacy.html)（同时用于托管为 App Store 的「隐私政策 URL」）。

## 架构

HtmlFox 是一个小型单 target 的 SwiftUI 应用。状态通过两个注入到环境中的 `@MainActor` 可观察对象流转：

- **`AppState`** —— 当前文档、最近列表、导入/分享的弹层呈现、错误提示。
- **`PurchaseManager`** —— StoreKit 2 的权益状态 + 本地免费试用计时。

文档由 `HtmlDocument` 建模，当前界面由 `DocumentMode`（`read` / `editPreview` / `editSource`）决定。渲染视图是对 `WKWebView` 的 `UIViewRepresentable` 封装（`WebPreview`）；编辑通过注入 `Scripts/` 中的小段 JavaScript 来切换 `contenteditable`，并把编辑后的 DOM 提取回 Swift。

关键设计点：
- 当编辑后的 HTML 经 SwiftUI 状态回流时，`WebPreview` 会跳过整页重载，保留滚动位置、避免闪屏。
- 导入文件会被拷入沙盒并从沙盒重新打开；相对资源通过 `baseURL` 相对于导入目录解析。
- 试用锚点持久化在 Keychain 中，以抵御「卸载重装刷新试用」。

近期修复与有意取舍的详细记录见 [`docs/2026-06-15-review-fixes.md`](docs/2026-06-15-review-fixes.md)。

## 项目结构

```
HtmlFox/
├─ HtmlFox.xcodeproj/          # Xcode 工程（也可由 project.yml 生成）
├─ HtmlFox.storekit            # 本地 StoreKit 测试配置
├─ project.yml                 # XcodeGen 工程定义
├─ docs/
│  ├─ privacy.html             # 隐私政策页（用于 App Store URL 托管）
│  └─ 2026-06-15-review-fixes.md
└─ HtmlFoxIOS/
   ├─ HtmlFoxIOSApp.swift      # 入口；注入状态、onOpenURL、scenePhase
   ├─ AppState.swift           # 文档与应用级状态
   ├─ Models/                  # HtmlDocument、DocumentMode、RecentDocument …
   ├─ Views/                   # HomeView、PreviewScreen、SourceEditorScreen、PaywallView …
   ├─ Components/              # WebPreview（WKWebView）、ShareSheet、SourceTextView、AppChrome
   ├─ Services/                # DocumentImporter、PurchaseManager、RecentDocumentStore、
   │                           #   TemporaryFileStore、PreviewEditScriptStore
   ├─ Scripts/                 # 启用/禁用预览编辑的 JavaScript
   ├─ Resources/               # Info.plist、Localizable.xcstrings、PrivacyInfo.xcprivacy
   └─ Assets.xcassets/         # AppIcon
```

## 运行要求

- **iOS 17.0** 或更高（iPhone 与 iPad）
- **Xcode 16** 或更高
- Apple 开发者账号（真机运行与上架 App Store 需要）

## 快速开始

### 使用现有工程

1. 在 Xcode 中打开 `HtmlFox.xcodeproj`。
2. 选择 `HtmlFox` target → **Signing & Capabilities**，设置你的开发团队。
3. 选择 iPhone/iPad 模拟器（或已连接的真机）并 **Run**。

### 使用 XcodeGen 重新生成（可选）

可由 `project.yml` 重新生成 Xcode 工程：

```bash
brew install xcodegen
xcodegen generate
open HtmlFox.xcodeproj
```

## 本地测试内购

无需真实付款即可在模拟器中走通购买与恢复流程：

1. Xcode 菜单 **Edit Scheme… → Run → Options**。
2. 将 **StoreKit Configuration** 设为 `HtmlFox.storekit`。
3. 运行。付费墙会显示 `US$2.99` 产品；购买为模拟。
4. 运行期间可随时通过 **Debug → StoreKit → Manage Transactions** 重置购买状态。

免费试用独立于 StoreKit：首次启动开始，从 Keychain 读取。

## 配置速查

| 配置项 | 值 |
| --- | --- |
| 产品名称 | `HtmlFox` |
| Bundle Identifier | `com.htmlfox.ios` |
| 内购产品 ID | `com.htmlfox.ios.pro`（非消耗型，US$2.99） |
| 最低 iOS | 17.0 |
| 设备 | iPhone 与 iPad（`TARGETED_DEVICE_FAMILY = 1,2`） |
| 界面框架 | SwiftUI |
| 应用图标 | `Assets.xcassets/AppIcon` |
| 隐私清单 | `HtmlFoxIOS/Resources/PrivacyInfo.xcprivacy` |
| 本地化 | `Localizable.xcstrings`（en、zh-Hans） |
| 加密合规 | `ITSAppUsesNonExemptEncryption = false` |

## 文件处理与文档类型

应用注册为以下类型的打开方：

- `public.html`
- `public.xhtml`

导入的文件会被拷贝到应用沙盒，**原始文件永不被修改**。当前若两个文件同名（例如来自不同文件夹的 `index.html`），它们会共用同一个沙盒槽位，因此打开第二个会替换最近列表中的第一个。若需同时保留多个副本，请在打开前先重命名其中一个。

## App Store 上架

1. 设置 `DEVELOPMENT_TEAM`（Signing & Capabilities）—— 归档前必需。
2. 在 **App Store Connect** 用 bundle ID `com.htmlfox.ios` 创建 App 记录。
3. 创建内购项目：
   - 类型：**非消耗型（Non-Consumable）**
   - 产品 ID：**`com.htmlfox.ios.pro`**（必须与代码一致）
   - 价格：**US$2.99**；填写显示名称、描述与审核截图。
4. 每次发布更新 `Info.plist` 中的 `CFBundleShortVersionString` / `CFBundleVersion`。
5. 用 Release 配置 **Archive**，在 Organizer 中校验后上传。
6. **App 隐私**选 **Data Not Collected**，并填写**隐私政策 URL**（托管 `docs/privacy.html`）。
7. 准备 iPhone 与 iPad 截图，最好中英文各一套。
8. 首次审核时把内购**与 App 版本一起**提交，并在「App 审核信息」备注：打开/预览/搜索免费，编辑与导出需一次性解锁（含 3 天试用与恢复购买）。

> **说明：** 归档、签名、上传需要 macOS + Xcode；App Store Connect 的网页配置（记录、内购、元数据、截图）在任意浏览器上都能做，包括 Windows。

## 已知限制

- **单文件导入**：HTML 文件的同目录兄弟资源不会被拷入沙盒，因此相对资源只有恰好位于导入目录时才能解析。
- **同名文档**共用一个沙盒槽位（见上文）。
- **字符编码**：导入时先尝试 UTF-8 再尝试 Unicode；部分旧编码（GB18030、Shift-JIS）可能渲染异常。

以上及其取舍理由记录在 [`docs/2026-06-15-review-fixes.md`](docs/2026-06-15-review-fixes.md)。

## 路线图

- 预览编辑过程中的节流式 HTML 同步（失焦/进入后台时快照）。
- 整目录导入，使相对资源完整可用。
- 通过 `UIDocument` 集成 iCloud Drive / 「文件」。
- 更智能的字符集嗅探（BOM / `meta charset` / 启发式）。

## 许可

© HtmlFox，保留所有权利。目前不授予任何开源许可。项目仅依赖 Apple 第一方框架（SwiftUI、WebKit、StoreKit、Foundation、UIKit）。
