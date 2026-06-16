# HtmlFox 代码审阅修复说明（2026-06-16）

本次针对“功能运行过程中可能出现的 bug”做了一轮全量审阅，重点是并发、WebKit 集成与文档生命周期的边界问题。审阅范围覆盖 [HtmlFoxIOSApp.swift](../HtmlFoxIOS/HtmlFoxIOSApp.swift)、[Views/](../HtmlFoxIOS/Views/)、[Components/](../HtmlFoxIOS/Components/)、[Services/](../HtmlFoxIOS/Services/)、[Models/](../HtmlFoxIOS/Models/)、[Scripts/](../HtmlFoxIOS/Scripts/)。

结论：**未发现会直接崩溃的 bug**。下列 9 项为已修复的真实运行期问题，另有 2 项经评估后有意保留。修复 commit：`0da47be`。

按 **问题 → 影响 → 修复** 组织。

---

## 一、性能 / 稳定性（P1）

### 1. 主线程同步文件 I/O，大文件会卡死甚至被系统杀

**问题**　[DocumentImporter](../HtmlFoxIOS/Services/DocumentImporter.swift)（旧）的 `Data(contentsOf:)`、`decodeHTML`、`data.write(...)` 都是同步阻塞调用，而 `AppState` 标了 `@MainActor`，`importDocument` / `openRecent` 在主线程执行——读盘、UTF-8 解码、写沙盒全压在主线程。

**影响**　打开几十 MB 的 HTML（常见于内联 base64 图片）时界面冻结数秒，超过看门狗阈值会被系统杀进程，表现为“闪退”。

**修复**

- [DocumentImporter.swift:17-25](../HtmlFoxIOS/Services/DocumentImporter.swift)　`importHTML` 把读盘 / 解码 / 拷贝包进 `Task.detached(priority: .userInitiated)`，只回传 Sendable 的 `(String, URL)`，回到主线程再构造 `HtmlDocument`。
- [DocumentImporter.swift:37-50](../HtmlFoxIOS/Services/DocumentImporter.swift)　`openSandboxDocument` 同样改为 `async` + 后台执行；`importsDirectory` / `copyIntoSandbox` / `decodeHTML` 改 `static` 以便在 detached 闭包内调用。
- [AppState.swift:35-44](../HtmlFoxIOS/AppState.swift)　`openRecent` 改为 `async`。
- [HomeView.swift](../HtmlFoxIOS/Views/HomeView.swift)　最近列表点击改为 `Task { await appState.openRecent(recent) }`。

### 2. 长页面导出 PDF 会被裁切 / 产出空白

**问题**　[WebPreview.exportPDF](../HtmlFoxIOS/Components/WebPreview.swift)（旧）用 `WKWebView.createPDF` + `config.rect = contentSize`，把整页渲染到**单页** PDF。

**影响**　很长的文档，`contentSize.height` 超过 PDF 单页上限（约 14400 pt）时会裁切或产出异常文件，用户拿到“只有前面一截”的 PDF。

**修复**　[WebPreview.swift:132-160](../HtmlFoxIOS/Components/WebPreview.swift)　改用 `UIPrintPageRenderer` + `webView.viewPrintFormatter()`，按 US-Letter（612×792 @72dpi、0.5" 边距）自动分页，逐页 `drawPage` 写入 PDF 上下文。短文档照常，长文档正确分多页。

---

## 二、搜索正确性 / 体验（P2）

### 3. “匹配数”与“可跳转数”对不上

**问题**　`countMatches`（[WebPreview.swift](../HtmlFoxIOS/Components/WebPreview.swift)）用 TreeWalker 统计所有文本节点，**包含 `display:none` 等隐藏元素**；而 `find` 用 `window.find` 只命中可见文本。

**影响**　页面含隐藏文本时，状态栏显示“共 5 个结果”，但箭头实际只能在其中可见的几个之间循环，“X / 5”不准。

**修复**　[WebPreview.swift](../HtmlFoxIOS/Components/WebPreview.swift)　`countMatches` 的 `acceptNode` 增加 `parent.getClientRects().length === 0 → FILTER_REJECT`，跳过未渲染文本，使计数与可导航命中一致。

### 4. 搜索每次按键都跑 JS，且无竞态保护

**问题**　[PreviewScreen](../HtmlFoxIOS/Views/PreviewScreen.swift) 的 `onChange(searchText)` 每个字符触发 `countMatches`+`find`；`find` 回调无 query 一致性校验。

**影响**　快速输入时旧 query 的 `find` 回调晚到，会把选区/滚动跳到上一个关键词位置。

**修复**

- [PreviewScreen.swift](../HtmlFoxIOS/Views/PreviewScreen.swift)　新增 `scheduleSearchUpdate()`：用 `@State searchTask` 做 250ms 防抖，可取消；离开界面时 `onDisappear` 取消。
- `runSearch` 的 `find` 回调中加 `guard searchText.trimmed == query`，丢弃过期查询结果。

### 5. 编辑后搜索计数不刷新

**问题**　编辑文本或从源码模式返回后 DOM 变了，但 `searchMatchCount` / `searchCurrentIndex` 不会重算。

**修复**　[PreviewScreen.swift](../HtmlFoxIOS/Views/PreviewScreen.swift)　`.onChange(of: document.html) { scheduleSearchUpdate() }`，内容变化后按防抖重新计算。

---

## 三、文档生命周期（P2）

### 6. 旧编辑器的 `onDisappear` 会把内容串写进新文档

**问题**　通过“用 HtmlFox 打开”切换文档时，`currentDocument` 先被替换为新文档，随后旧 `SourceEditorScreen` 的 `onDisappear → commitDraft()` 才触发——此时 `appState.updateCurrentHTML(draftHTML)` 会把**旧草稿写进新文档**，造成内容污染。

**影响**　在 A 文档编辑中途从外部打开 B，B 的内容可能被 A 的草稿覆盖。

**修复**　[AppState.swift:55-64](../HtmlFoxIOS/AppState.swift)　`updateCurrentHTML(_:for:)` 增加可选 `id` 参数：`if let id, document.id != id { return }`，来源文档已不是当前文档时直接丢弃。各调用点（[PreviewScreen](../HtmlFoxIOS/Views/PreviewScreen.swift) 的 `onHTMLChanged` / `finishEditing`、[SourceEditorScreen.commitDraft](../HtmlFoxIOS/Views/SourceEditorScreen.swift)）均传入 `document.id`。

### 7. 切换文档后残留旧界面状态

**问题**　[DocumentView](../HtmlFoxIOS/Views/DocumentView.swift) 没有给子界面设置稳定 id，切换文档时复用同一视图实例，`searchText`、搜索计数、源码 `draftHTML` 等 `@State` 不会重置。

**影响**　在 A 里搜了词/编辑了源码，打开 B 后仍残留 A 的搜索词、过期计数或草稿。

**修复**　[DocumentView.swift](../HtmlFoxIOS/Views/DocumentView.swift)　`PreviewScreen` / `SourceEditorScreen` 各加 `.id(document.id)`。同一文档内 read↔editPreview 切换 id 不变（`WebPreviewController` 得以保留），换文档则 id 变化、视图与状态全部重建。

---

## 四、边界 / 一致性（P3）

### 8. 极小高度下预览卡片高度可能为 0

**问题**　[PreviewScreen.swift](../HtmlFoxIOS/Views/PreviewScreen.swift) `cardHeight = max(geometry.size.height - 32, 0)`，极窄分屏下可能得到 0，WebView 拿到零高度 frame。

**修复**　下限钳到 `max(..., 1)`，避免零尺寸 frame（真机正常尺寸不受影响、也不会溢出）。

### 9. 文件选择器类型与 Info.plist 声明不一致

**问题**　[HomeView](../HtmlFoxIOS/Views/HomeView.swift)（旧）`importContentTypes` 含 `.text`，而 [Info.plist](../HtmlFoxIOS/Resources/Info.plist) 只声明 `public.html` / `public.xhtml`。

**修复**　[HomeView.swift](../HtmlFoxIOS/Views/HomeView.swift)　移除 `.text`，只保留 html / xhtml（`.html` 已覆盖 `.htm` 扩展名），与 Info.plist 对齐。

---

## 五、有意保留（附理由）

### 10. Web 缩放模式下 `find` 居中略有偏移

`find` 的滚动在 WebView 自身坐标系内完成，外层又被 `scaleEffect` 缩放。命中项仍在卡片内按比例居中，仅纯视觉偏差。彻底修复需穿透 `scaleEffect` 做坐标换算，收益低且易引入新问题——保留现状。

### 11. `onChange(of:)` 旧版 API 的弃用警告

新签名（`onChange(of:initial:_:)`）需 **iOS 17+**，而本项目最低支持 **iOS 16**。改用新 API 会抬高最低系统版本，不划算。保留旧 API（仅编译期警告，不影响运行）。

---

## 六、验证

- iOS 26.5 模拟器 `xcodebuild ... build` → **BUILD SUCCEEDED**，无 error、无相关并发/未用警告。
- 模拟器安装启动正常、无崩溃日志。
- 建议在真机按上一份 [2026-06-15 审阅文档](2026-06-15-review-fixes.md#五回归测试建议) 的回归清单复测，尤其：打开大文件、长页导出 PDF、快速连续搜索、编辑中途从外部打开另一文件。
