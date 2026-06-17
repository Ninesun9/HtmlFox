# HtmlFox 上架清单（美区 + 中国区）

本文件是可勾选的上架清单。已按 HtmlFox 实际参数填好，照做即可。

**关键参数速查**

| 项 | 值 |
| --- | --- |
| App 名称 | HtmlFox |
| Bundle ID | `com.htmlfox.ios` |
| 内购产品 ID | `com.htmlfox.ios.pro`（非消耗型 Non-Consumable） |
| 价格 | 美区 US$2.99 / 中国区约 ¥18 |
| 隐私 | Data Not Collected（不收集数据） |
| 隐私政策 URL | https://ninesun9.github.io/htmlfox-privacy/ |
| 最低系统 | iOS 16.0（iPhone + iPad） |
| 分类 | Productivity（副：Developer Tools / Utilities） |
| 年龄分级 | 4+ |
| 出口加密 | 豁免（`ITSAppUsesNonExemptEncryption=false` 已设） |
| 成本 | $99/年（全区通用）+ 内购抽成 15%（已申请 Small Business Program） |

---

## 🇺🇸 美区 App Store 上架清单

### A. 一次性账号设置
- [ ] Apple Developer Program 已付费生效（$99/年）
- [ ] 同意 **Paid Applications Agreement**（卖内购必须）
- [ ] 填 **Tax 表**：非美国个人填 W-8BEN；美国身份填 W-9
- [ ] 绑定可收美元的**银行账户**
- [ ] **申请 App Store Small Business Program**（抽成 30%→15%）
  - 路径：App Store Connect → Business（Agreements, Tax, and Banking）→ Small Business Program → Enroll
  - 资格：上一自然年总收入 ≤ 100 万美元（新开发者天然符合）
  - 同意条款后提交，**次月 1 日生效**；建议首次提交前就申请
- [ ] Xcode → Settings → Accounts 登录开发者 Apple ID

### B. 工程签名（Xcode）
- [ ] `HtmlFox` target → Signing & Capabilities → 勾 Automatically manage signing
- [ ] Team 选你的开发者账号（自动填 `DEVELOPMENT_TEAM` 并注册 bundle id）
- [ ] 确认 Info.plist：`CFBundleShortVersionString = 1.0`、`CFBundleVersion = 1`

### C. 创建 App 记录
- [ ] My Apps → ➕ → New App：iOS / 名称 HtmlFox / 语言 English (U.S.) / Bundle ID `com.htmlfox.ios` / SKU `htmlfox-ios-001`
- [ ] Category：主 Productivity（副可选 Developer Tools / Utilities）

### D. 内购配置
- [ ] Features → In-App Purchases → ➕：类型 Non-Consumable，Product ID `com.htmlfox.ios.pro`
- [ ] Reference Name：HtmlFox Pro Lifetime；价格 US$2.99
- [ ] 本地化显示名/描述（英文，可加中文）
- [ ] 上传审核截图（付费墙界面）
- [ ] 状态 “Ready to Submit”，**与 App 版本同捆提交**（首次必须）

### E. 商店元数据（English）
- [ ] Name（≤30）/ Subtitle（≤30）/ Promotional Text / Description
- [ ] Keywords（≤100，逗号分隔，如 `html,editor,viewer,pdf,export,source,web,preview`）
- [ ] Support URL（必填）/ Marketing URL（选填）
- [ ] Privacy Policy URL：https://ninesun9.github.io/htmlfox-privacy/

### F. 隐私
- [ ] App Privacy → **Data Not Collected**
- [ ] 隐私清单 PrivacyInfo.xcprivacy 已随构建打包（已在工程内）

### G. 截图
- [ ] iPhone 6.9"（或 6.7"）一组（2–10 张）
- [ ] iPad 13"（或 12.9"）一组（支持 iPad，必传）

### H. 评级与合规
- [ ] Age Rating 问卷 → 4+
- [ ] Export Compliance：已设豁免，不再弹问
- [ ] Content Rights：确认图标等为自有/授权

### I. 构建上传
- [ ] Xcode 选 Any iOS Device (arm64) → Product → Archive（Release）
- [ ] Organizer → Distribute App → App Store Connect → Upload
- [ ] 等构建处理完成（几分钟～十几分钟）
- [ ]（建议）先用 `HtmlFox.storekit` 在本地跑通购买/恢复

### J. 审核信息 & 提交
- [ ] App Review Notes 写明：打开/预览/搜索免费；编辑与导出为 $2.99 一次性解锁（`com.htmlfox.ios.pro`），含 3 天试用，有“恢复购买”。可用「文件」App 打开任意 .html 测试。
- [ ] 无需 demo 账号（无登录）
- [ ] 选 Build → 选发布方式 → Add for Review → Submit for Review

> ⚠️ 美区两个常见拒因：
> 1. Guideline 4.2 最小功能性——描述里突出「源码编辑 + 分页 PDF 导出 + 页内搜索 + 双语」。
> 2. 内购首次必须与 App 同捆提交，否则因“引用不存在的内购”被拒。

---

## 🇨🇳 中国区 App Store 上架清单（美区稳定后再做）

> 同一个 App、同一套代码；下面只列中国区额外/不同项。

### A. 前置合规（最关键）
- [ ] ICP 备案主体与开发者账号一致
- [ ] APP 备案（移动应用备案）：在云服务商后台基于现有 ICP 给 HtmlFox 新增，分发平台选 Apple App Store，填 bundle id `com.htmlfox.ios`
- [ ] 拿到 App 对应备案号备用

### B. 账号 / 收款
- [ ] 主体对应中国大陆身份证/营业执照
- [ ] 绑定中国大陆银行账户 + 中国税务信息

### C. App Store Connect（中国大陆区）
- [ ] Availability 勾选中国大陆
- [ ] 填写 ICP / 备案号
- [ ] 内购价格设人民币价格点（约 ¥18）

### D. 元数据与截图（简体中文）
- [ ] 简体中文 Name/Subtitle/Description/Keywords（应用内已中文本地化）
- [ ] 简体中文 iPhone + iPad 截图
- [ ] 隐私政策 URL 在中国大陆可访问（GitHub Pages 可能不稳，建议另存一份到境内备案域名）

### E. 内容审核（更严）
- [ ] App Review Notes（中文）：本应用为本地 HTML 文档查看/编辑工具，仅打开用户自有 .html；不内置浏览功能，外链跳系统 Safari；自身不联网、不收集数据。

### F. 提交
- [ ] 选 Build → Submit for Review（中国大陆区）
