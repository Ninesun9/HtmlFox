# HtmlFox

HtmlFox 是一款原生 SwiftUI 应用，用于打开 HTML 文件、以渲染后的文档形式阅读、在预览中搜索内容、切换移动端和网页端预览尺寸、直接在预览中进行简单文本编辑，并将结果导出为 HTML 或 PDF。

应用完全在设备本地运行：不会收集数据、不会跟踪用户，只有当打开的文档本身引用远程资源时才会访问网络。

## 功能特性

- 通过 iOS 文档选择器打开 `.html` / `.htm` / `.xhtml` 文件
- 使用 `WKWebView` 渲染 HTML，并支持移动端和网页端（桌面宽度）预览模式
- 支持网页端预览缩放调节
- 支持页内搜索、匹配数量显示以及上一项/下一项跳转
- 预览编辑模式：可直接在渲染后的页面中编辑可见文本
- 高级源码编辑器，使用等宽字体编辑
- 主页面显示最近打开文档列表
- 通过 iOS 分享面板导出当前 HTML
- 将渲染后的预览导出为 PDF
- 支持英文和简体中文本地化

## 运行要求

- iOS 16.0 或更高版本（支持 iPhone 和 iPad）
- Xcode 16 或更高版本

## 构建方式

项目已包含生成好的 `HtmlFox.xcodeproj`，也可以通过 [XcodeGen](https://github.com/yonyz/XcodeGen) 基于 `project.yml` 重新生成。

### 使用现有工程

1. 在 Xcode 中打开 `HtmlFox.xcodeproj`。
2. 选择 `HtmlFox` target -> Signing & Capabilities，并设置你的开发团队。
3. 在 iPhone 或 iPad 模拟器、真机上构建并运行。

### 使用 XcodeGen 重新生成

1. 安装 XcodeGen：`brew install xcodegen`。
2. 在项目目录执行 `xcodegen generate`。
3. 打开 `HtmlFox.xcodeproj` 并设置开发团队。

## 项目配置

- 产品名称：`HtmlFox`
- Bundle Identifier：`com.htmlfox.ios`
- 界面框架：SwiftUI
- 最低 iOS 版本：16.0
- 支持设备：iPhone 和 iPad
- 应用图标：`Assets.xcassets/AppIcon`
- 隐私清单：`HtmlFoxIOS/Resources/PrivacyInfo.xcprivacy`
- 本地化资源：`HtmlFoxIOS/Resources/Localizable.xcstrings`（en、zh-Hans）

## 文档类型

应用会将自己注册为 HTML 文档的打开方式：

- `public.html`
- `public.xhtml`

导入的文件会被复制到应用沙盒中，原始文件不会被修改。当前如果两个文件同名（例如来自不同文件夹的 `index.html`），它们会共用同一个沙盒槽位，因此打开第二个文件后会替换最近列表中的第一个。如果你需要同时保留多个副本，请在导入前先重命名其中一个文件。

## App Store 提交检查清单

- [ ] 设置 `DEVELOPMENT_TEAM`（Signing & Capabilities）—— 归档前必需。
- [ ] 每次发布时更新 `Info.plist` 中的 `CFBundleShortVersionString` / `CFBundleVersion`。
- [ ] 使用 Release 配置归档，并在 Organizer 中完成校验。
- [ ] 在 App Store Connect 中填写 App 隐私信息：**Data Not Collected**。
- [ ] 准备英文和简体中文的 iPhone / iPad 截图。
