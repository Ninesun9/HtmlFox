# HtmlFox 代码审阅修复说明（2026-06-15）

本次基于一次全量代码审阅，对项目进行的修复与优化记录。审阅范围：[HtmlFoxIOSApp.swift](../HtmlFoxIOS/HtmlFoxIOSApp.swift)、[Views/](../HtmlFoxIOS/Views/)、[Components/](../HtmlFoxIOS/Components/)、[Services/](../HtmlFoxIOS/Services/)、[Models/](../HtmlFoxIOS/Models/)、[Scripts/](../HtmlFoxIOS/Scripts/)、Info.plist、xcstrings、storekit 配置以及 pbxproj。

下文按 **问题 → 影响 → 修复方案** 的结构组织。每条都给出最终落地的文件位置，方便后续回查或回滚。

---

## 一、用户能直接感知的问题（P0）

### 1. 打开文档后无路可退

**问题**　[AppState.swift:51](../HtmlFoxIOS/AppState.swift#L51) 定义了 `closeDocument()`，但全代码库没有任何位置调用它。[HomeView.swift](../HtmlFoxIOS/Views/HomeView.swift) 通过 `if currentDocument != nil` 切换显示 `DocumentView` / 空状态，而 `PreviewScreen` / `SourceEditorScreen` 的 toolbar 里没有"关闭"按钮。用户打开一份 HTML 后，没有任何方法回到首页或最近列表。

**影响**　功能性 dead-end。用户必须杀掉 App 才能换一份文档。

**修复**

- [PreviewScreen.swift:31-37](../HtmlFoxIOS/Views/PreviewScreen.swift#L31-L37)　navigationBarLeading 新增 Close 按钮，调用 `closeDocument()` 私有方法。
- [PreviewScreen.swift:75-77](../HtmlFoxIOS/Views/PreviewScreen.swift#L75-L77)　`closeDocument()` 走 `flushEditsAndCommit { appState.closeDocument() }`：如果当前在 edit-preview 模式，会先把 DOM 的编辑结果提取并落盘到 AppState，再清空 `currentDocument`，避免静默丢失最后一次输入。
- [SourceEditorScreen.swift:23-29](../HtmlFoxIOS/Views/SourceEditorScreen.swift#L23-L29)　同步在源码编辑界面加 Close。点击时先 `commitDraft()` 落盘，再 `appState.closeDocument()`。

### 2. 缺少 `onOpenURL`，外部入口失效

**问题**　[Info.plist](../HtmlFoxIOS/Resources/Info.plist#L9-L23) 声明了 `public.html` / `public.xhtml` 作为 Editor 类型；这是告诉系统"用 HtmlFox 打开"是合法操作。但 [HtmlFoxIOSApp.swift](../HtmlFoxIOS/HtmlFoxIOSApp.swift) 没有挂 `.onOpenURL`，从 iOS 文件 App 长按"用 HtmlFox 打开"、或从邮件附件点开 .html 时，App 会启动但不会自动加载这份文件，用户得再手动通过应用内 picker 找一遍。

**影响**　核心入口体验断裂，App 看起来"无视"用户的打开请求。

**修复**　[HtmlFoxIOSApp.swift:14-16](../HtmlFoxIOS/HtmlFoxIOSApp.swift)

```swift
.onOpenURL { url in
    Task { await appState.importDocument(from: url) }
}
```

直接复用现有的 `importDocument` 链路（安全作用域 → sandbox 拷贝 → recent 入库 → 设置为当前文档）。

### 3. `.fileImporter` 类型与 Info.plist 声明不一致

**问题**　[HomeView.swift](../HtmlFoxIOS/Views/HomeView.swift)（旧）`allowedContentTypes: [.html, .text]`，但 [README.md](../README.md) 与 [Info.plist](../HtmlFoxIOS/Resources/Info.plist) 都声明支持 `public.xhtml`。导致从应用内 picker 看不到 `.xhtml` 文件。

**修复**　[HomeView.swift:42, 146-153](../HtmlFoxIOS/Views/HomeView.swift)　抽出静态 `importContentTypes`：以 `.html` 为基础，若 `UTType("public.xhtml")` 可被识别则附加，再 fallback `.text`。用静态计算属性避免每次 view 重建都重新构造数组。

### 4. 退出预览编辑模式时整页 `loadHTMLString` 重载

**问题**　原 [WebPreview.updateUIView](../HtmlFoxIOS/Components/WebPreview.swift#L186-L207) 的逻辑：

```swift
if context.coordinator.loadedHTML != html && mode != .editPreview {
    webView.loadHTMLString(html, baseURL: nil)
    return
}
```

调用链：用户点 Done → `webViewController.finishEditing` → JS 返回新 HTML → `appState.updateCurrentHTML(html)` → `setMode(.read)` → SwiftUI 重渲染 → `updateUIView` 看到 `html` 变了 + `mode == .read`，整页重载。导致：

1. WKWebView 重新解析 + 重新渲染，明显白屏闪烁。
2. 用户在长文档中的滚动位置丢失。
3. 紧接着 `applyMode(.read)` 又会再跑一次 `disableScript` + `onHTMLChanged`，触发第二次 commit；虽然不会死循环（loadedHTML 已对齐），但浪费一次 JS 调用。

**影响**　付费功能（编辑）退出后立刻给用户一次"App 卡了一下"的观感，专业度受损。

**修复方案**　引入 controller 侧的"自报家门"标记：

- [WebPreview.swift:9-23](../HtmlFoxIOS/Components/WebPreview.swift#L9-L23)　`WebPreviewController` 新增 `pendingSelfEmittedHTML: String?` 与 `consumePendingSelfEmittedHTML(_:) -> Bool`。
- [WebPreview.swift:122-130](../HtmlFoxIOS/Components/WebPreview.swift#L122-L130)　`finishEditing` 在拿到 JS 返回值后立即把它写入 `pendingSelfEmittedHTML`，再回调外部 completion。
- [WebPreview.swift:186-207](../HtmlFoxIOS/Components/WebPreview.swift#L186-L207)　`updateUIView` 第一步先问 controller：这份 `html` 是不是刚刚从我自己提取出来的？是 → 直接同步 coordinator 状态、跳过重载。

收益：编辑→Done 后视图不闪屏、滚动位置保留；同时 `applyMode` 被精简到只处理 `editPreview` 一种 case（见第六节）。

### 5. SourceEditor 系统返回手势丢失草稿

**问题**　[SourceEditorScreen.swift](../HtmlFoxIOS/Views/SourceEditorScreen.swift)（旧）只有 "Preview" / "Export HTML" 两个按钮会调 `appState.updateCurrentHTML(draftHTML)`。但 SourceEditor 是从 PreviewScreen 通过 `setMode(.editSource)` 切过来的——更准确地说，[DocumentView](../HtmlFoxIOS/Views/DocumentView.swift) 根据 mode 直接 swap view，不存在 NavigationStack push 关系。但理论上如果有任何途径让 view 消失（mode 被外部改变、close、scene 退出），draft 会无声蒸发。

**影响**　付费用户在源码模式里输入了一段时间，意外退出后什么都没保存。

**修复**　[SourceEditorScreen.swift:44-50, 53-56](../HtmlFoxIOS/Views/SourceEditorScreen.swift)

```swift
.onDisappear {
    commitDraft()
}

private func commitDraft() {
    guard draftHTML != document.html else { return }
    appState.updateCurrentHTML(draftHTML)
}
```

`commitDraft` 等幂——如果草稿与当前文档相同则什么都不做，避免在"先按 Preview 提交，再 onDisappear 又跑一次"的链路上多做一次无意义写入。

### 6. 付费门控有缺口（SourceEditor 的 Export HTML 没校验）

**问题**　[PreviewScreen](../HtmlFoxIOS/Views/PreviewScreen.swift) 工具栏的 Source / Edit / Export 都走 `requirePro { ... }`，但 [SourceEditorScreen](../HtmlFoxIOS/Views/SourceEditorScreen.swift)（旧）的 "Export HTML" 直接调 `appState.exportHTML()`。结果：试用过期用户只要绕道 "Source" 模式（其实进入 Source 模式本身有门控，但门控失效或试用刚过期那一刻已在 Source 内）就能继续导出。

**影响**　付费策略不一致，可能被理解为 bug 而不是优惠。

**修复**　[SourceEditorScreen.swift:31-42](../HtmlFoxIOS/Views/SourceEditorScreen.swift)　Export 按钮在 `commitDraft` 之后判断 `purchases.canUseProFeatures`：通过则导出，否则 `showPaywall = true`。SourceEditor 自带一份 `.sheet(isPresented: $showPaywall) { PaywallView() }`。

### 7. `baseURL: nil` 让相对资源全军覆没

**问题**　[WebPreview.swift](../HtmlFoxIOS/Components/WebPreview.swift)（旧）`webView.loadHTMLString(html, baseURL: nil)`——HTML 中的 `<img src="logo.png">`、相对 CSS、相对 JS 全部加载失败。但用户的真实场景就是把"做好的网页"（含资源的整目录）拷进来预览。

**影响**　声称"HTML 预览器"，但只能预览裸的单文件 HTML。

**修复**

- [WebPreview.swift:170](../HtmlFoxIOS/Components/WebPreview.swift#L170)　`WebPreview` 增加 `baseURL: URL?` 字段。
- [WebPreview.swift:213-216](../HtmlFoxIOS/Components/WebPreview.swift#L213-L216)　`load(_:into:coordinator:)` 用 `baseURL` 调用 `loadHTMLString`。
- [PreviewScreen.swift:142-151](../HtmlFoxIOS/Views/PreviewScreen.swift#L142-L151)　调用方传入 `document.sandboxURL?.deletingLastPathComponent()`——即导入文件在沙箱里的父目录。

由于文件已经被拷进 sandbox（见 [DocumentImporter.copyIntoSandbox](../HtmlFoxIOS/Services/DocumentImporter.swift#L74-L82)），用户原目录下的兄弟文件不会自动跟着复制。这是一个有意保留的限制（导入是单文件，不是整目录）。如果要支持整目录导入，需要扩展 `DocumentImporter` 让用户选目录并整体拷贝，超出本次修复范围。

---

## 二、可靠性/正确性问题（P1）

### 8. 试用期可通过卸载重装无限延长

**问题**　[PurchaseManager.swift](../HtmlFoxIOS/Services/PurchaseManager.swift)（旧）`firstLaunchDate` 存 `UserDefaults`：卸载即丢失，重装得到新试用。

**修复**　将试用锚点迁移到 Keychain。Keychain 数据在 App 卸载后默认保留（受 `kSecAttrAccessibleAfterFirstUnlock` 控制）。具体实现见 [PurchaseManager.swift:164-235 (TrialAnchorStore)](../HtmlFoxIOS/Services/PurchaseManager.swift#L161-L235)：

- `loadOrCreate()` 先尝试读 Keychain，失败时尝试从 UserDefaults 迁移（兼容老用户），都没有就写入当前时间。
- `writeToKeychain` 先 `SecItemUpdate`，若 `errSecItemNotFound` 则 `SecItemAdd`，保证幂等。
- 同时写一份到 UserDefaults，作为 Keychain 不可用时的降级路径（例如模拟器某些配置下）。

**权衡**　Keychain 在 iCloud Keychain 启用的情况下可能跨设备同步——这意味着用户在 A 设备启动过的试用，到 B 设备会接着算同一段试用期。考虑到本 App 不依赖 Keychain 同步任何其它身份信息，且这本来就是合理的"用户视角下的同一份试用"，未对 `kSecAttrSynchronizable` 做显式设置（默认不同步）。

### 9. 试用倒计时不会自动刷新

**问题**　`isInTrial` / `trialDaysRemaining` 是计算属性，依赖 `Date()`。App 在前台运行期间穿过试用到期时刻 / 跨过午夜，UI 不会更新。

**修复**

- [PurchaseManager.swift:17-20, 66-70](../HtmlFoxIOS/Services/PurchaseManager.swift)　新增 `@Published private(set) var trialTick: Int` 和 `refreshTrialState()`。后者只把 `trialTick &+= 1`——通过 `@Published` 自动发布 `objectWillChange`，让所有观察 `purchases` 的视图重渲染、重读 `isInTrial`。
- [HtmlFoxIOSApp.swift:17-22](../HtmlFoxIOS/HtmlFoxIOSApp.swift)　监听 `@Environment(\.scenePhase)`，每当 `.active` 时调一次 `purchases.refreshTrialState()`。这覆盖了"App 回到前台"和"应用刚启动"两种时机，足够日常使用。

如果将来要支持"App 一直在前台过午夜也要刷新"，可以再加个 `Timer.publish(every: 60)`，本次未做（边际收益太低）。

### 10. `purchase()` 的递归回退路径

**问题**　[PurchaseManager.swift](../HtmlFoxIOS/Services/PurchaseManager.swift)（旧）

```swift
func purchase() async -> Bool {
    guard let product else {
        await loadProduct()
        guard product != nil else { ... ; return false }
        return await purchase()   // 递归
    }
    ...
}
```

逻辑上没问题，但读起来要绕一下：先 fail-fast 再 fail-loud，再递归走一遍。维护性差。

**修复**　[PurchaseManager.swift:85-116](../HtmlFoxIOS/Services/PurchaseManager.swift#L85-L116)　拍平为线性流程：

```swift
if product == nil { await loadProduct() }
guard let product else { ...错误...; return false }
// 进入真正的 purchase 逻辑
```

行为等价，但少一层递归、少一次条件分支。

### 11. `WebPreviewController` 缺少 actor 隔离声明

**问题**　[WebPreview.swift](../HtmlFoxIOS/Components/WebPreview.swift)（旧）`final class WebPreviewController: ObservableObject`，所有方法操作 `WKWebView`。`WKWebView` 是主线程绑定的 UIKit 类型。当前所有调用点都从主线程发起，运行时没问题，但编译期不会拦截未来误用。

**修复**　[WebPreview.swift:5-13](../HtmlFoxIOS/Components/WebPreview.swift)　标 `@MainActor`，并将旧的 `fileprivate weak var webView` 改为 `private(set)` + 配套 `func attach(_ webView: WKWebView)` 接口，由 `WebPreview.makeUIView` 显式调用。`fileprivate` 反向写入本来就靠 "Coordinator 和 Controller 在同一 file" 的耦合，新方式更清晰。

### 12. PreviewScreen 在小屏 landscape 下卡片溢出

**问题**　[PreviewScreen.swift](../HtmlFoxIOS/Views/PreviewScreen.swift)（旧）`let cardHeight = max(geometry.size.height - 32, 360)`。iPhone SE landscape 下 height ≈ 320pt，强制下限 360pt 让卡片高于 canvas，阴影被裁。

**修复**　[PreviewScreen.swift:97-108](../HtmlFoxIOS/Views/PreviewScreen.swift#L97-L108)　去掉 360 下限，HTML 内容本身就是可滚动的，卡片高度跟着 geometry 走即可。同时把 `webHeight = webDisplayHeight / max(webScale, 0.01)` 加了个除零保护，防止极端 zoom 值导致 NaN（虽然 slider 范围是 0.4~1.25，但留个底）。

### 13. `editButtonTitle` 没被本地化

**问题**　[PreviewScreen.swift](../HtmlFoxIOS/Views/PreviewScreen.swift)（旧）

```swift
private var editButtonTitle: String {
    document.mode == .editPreview ? "Done" : "Edit"
}
```

返回类型是 `String`。`Label(editButtonTitle, systemImage:)` 会匹配到 `Label(_ title: S, systemImage:) where S: StringProtocol` 这个 **不本地化** 的初始化器。结果 zh-Hans 用户看到的也是 "Done" / "Edit"，尽管 [Localizable.xcstrings](../HtmlFoxIOS/Resources/Localizable.xcstrings) 里早就有了中文翻译。

**修复**　[PreviewScreen.swift:181-183](../HtmlFoxIOS/Views/PreviewScreen.swift#L181-L183)　返回类型改成 `LocalizedStringKey`：

```swift
private var editButtonTitle: LocalizedStringKey {
    document.mode == .editPreview ? "Done" : "Edit"
}
```

Swift 类型推断会把字面量解释为 `LocalizedStringKey`，匹配 `Label` 的本地化重载。

---

## 三、可维护性（P2）

### 14. 死代码清理

**问题**　

- [PreviewEditScriptStore.extractScript()](../HtmlFoxIOS/Services/PreviewEditScriptStore.swift) 全代码库无调用方。
- 对应的 [extractEditedHTML.js](../HtmlFoxIOS/Scripts/) 也无人加载。
- `WebPreview.applyMode` 中 `case .editSource:` 永远不会触发（切到 editSource 时整个 `PreviewScreen` 已被 `DocumentView` 替换为 `SourceEditorScreen`）。

**修复**

- 删除 `extractScript()` 方法 + `extractEditedHTML.js` 文件 + [project.pbxproj](../HtmlFox.xcodeproj/project.pbxproj) 中的 PBXBuildFile / PBXFileReference / PBXGroup.children / PBXResourcesBuildPhase 四处引用。
- [WebPreview.swift:218-225](../HtmlFoxIOS/Components/WebPreview.swift#L218-L225)　`applyMode` 简化为 `if mode == .editPreview { 启用编辑 }`，其它分支由 `finishEditing` 流程或 view unmount 自然处理。

### 15. PreviewScreen 工具栏动作集中化

**问题**　原代码里 `toggleEditMode` / `exportPDF` 各自手写了"如果在 editPreview 就先 finishEditing 再做事"的样板；Source / Export HTML 菜单项则完全没做这件事，等于偷偷丢用户编辑。

**修复**　[PreviewScreen.swift:79-95](../HtmlFoxIOS/Views/PreviewScreen.swift#L79-L95)　抽出 `flushEditsAndCommit(_ action:)`：

```swift
private func flushEditsAndCommit(_ action: @escaping () -> Void) {
    guard document.mode == .editPreview else {
        action()
        return
    }
    webViewController.finishEditing { html in
        if let html { appState.updateCurrentHTML(html) }
        appState.setMode(.read)
        action()
    }
}
```

调用点：

- [PreviewScreen.swift:76](../HtmlFoxIOS/Views/PreviewScreen.swift#L76)　`closeDocument` → `flushEditsAndCommit { appState.closeDocument() }`
- [PreviewScreen.swift:48-50](../HtmlFoxIOS/Views/PreviewScreen.swift#L48-L50)　Source 菜单 → `flushEditsAndCommit { appState.setMode(.editSource) }`
- [PreviewScreen.swift:61-64](../HtmlFoxIOS/Views/PreviewScreen.swift#L61-L64)　Export HTML 菜单 → `flushEditsAndCommit { appState.exportHTML() }`
- [PreviewScreen.swift:406-412](../HtmlFoxIOS/Views/PreviewScreen.swift#L406-L412)　`toggleEditMode` / `exportPDF` 同样化

任何"离开编辑模式去做别的事"都走同一条路，行为一致。

---

## 四、有意保留的限制

### 16. Recent 文件同名碰撞

**问题**　[RecentDocumentStore.upsert](../HtmlFoxIOS/Services/RecentDocumentStore.swift#L13) 用 `fileName` 做唯一键；[DocumentImporter.copyIntoSandbox](../HtmlFoxIOS/Services/DocumentImporter.swift#L74-L82) 在 sandbox 中也是同名覆盖。从不同目录打开两份都叫 `index.html` 的文件：第二份覆盖第一份。

**为什么没在代码里修**　考虑过两种方案：

1. **碰撞时给 sandbox 加序号后缀**（"index (1).html"）。问题：用户**重复打开同一份文件**（常见的"重新加载"场景）会被认成新文件，Recent 列表分裂，反而怪。
2. **按源 URL 路径 hash 作为 sandbox 名**。问题：iOS 安全作用域 URL 的路径不稳定，跨启动可能不同；要用 bookmark data 才稳，工程复杂度显著上升。

权衡之后采用**文档化**——在 [README.md](../README.md#L57) 加了一段说明，告诉用户"想同时保留两份同名文件的话请先重命名"。绝大多数用户不会撞这个 case；撞到的也有明确解释。

如果将来发现实际用户经常踩坑，再做方案 1 的精细化版本（按内容 hash 判断是同文件还是新文件）。

---

## 五、回归测试建议

代码改动跨 SwiftUI 视图层 / WebKit 集成 / StoreKit / Keychain，未自动化。手动验证清单：

- **首页**
  - 空状态点 Open → 选 HTML → 预览展示，文件名在导航标题
  - 选 .xhtml 文件能在 picker 看到并打开
- **外部入口**
  - 在 iOS 文件 App 长按一个 .html → "用 HtmlFox 打开" → App 自动跳到预览
- **预览/编辑**
  - 进入 Edit → 修改文字 → Done → 不闪屏、滚动位置保留、星号出现在标题
  - 进入 Edit → 改一两个字 → 直接点 Close → 退回首页，再点 Recent 同一文件 → 之前的修改仍在
  - 进入 Edit → 改字 → 菜单 Source → 进源码模式，原编辑结果应该已在源码中
  - 预览引用相对图片的 HTML（在打开前把图放在源文件同目录）→ 图能显示
- **源码模式**
  - 改一些内容 → 系统返回手势（如果可触发）/ Close → 草稿应被保存（再开同文件能看到）
  - 试用过期态下 Export HTML → 弹付费墙而不是导出
- **付费/试用**
  - 删 App → 重装 → 试用天数没有重置（与卸载前同一段窗口）
  - 试用期内可编辑/导出；过期后 Edit / Source / Export PDF / Export HTML 都弹付费墙
  - 购买后所有功能解锁；卸载重装后 Restore 能恢复
- **多语言**
  - 切系统语言到简中 → 工具栏 Edit/Done、菜单项、付费墙文案均为中文

---

## 六、未做但建议未来跟进的事

1. **WebView 编辑模式下的 HTML 实时同步**　目前 `updateCurrentHTML` 只在 finishEditing 时调用一次。中间过程若用户切到后台/锁屏导致 App 被回收，未提交的编辑会丢。可以考虑节流式（如失焦时）调一次 disableScript 提取快照。
2. **目录导入**　如上文 §7，要让相对资源真正可用，理想方案是支持选目录而非单文件。
3. **iCloud / Files 集成**　考虑直接在 iCloud Drive 编辑而非 import 到 sandbox。涉及 UIDocument / DocumentBrowser 改造，工作量较大。
4. **更强的内容嗅探**　目前 `DocumentImporter.decodeHTML` 只尝试 UTF-8 / Unicode 两种编码，对 GB18030 / Shift-JIS 的 HTML 会乱码。可以借鉴浏览器的字符集嗅探（meta charset / BOM / 启发式）。

---

修复 commit 范围：未提交，工作区状态见 `git status`。涉及文件 11 个（10 个 Swift/Plist/MD + 1 个 pbxproj，外加删除 1 个 JS）。
