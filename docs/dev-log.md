# Development Log

## Entry Template

```md
## YYYY-MM-DD

Author: <name>

Summary:
- ...

Changes:
- ...

Files Modified:
- ...

Notes:
- ...
```

## Entries

## 2026-07-17

Author: Claude

Summary:
- 修复两个可确定性验证的翻译 Bug：中英混排误判「不支持」、译文按 OCR 换行被拆段
- 重构结果面板翻译会话链路，针对下载弹窗常驻、翻译偶发卡死做结构性修复，待真机验证
- 新增设置页「翻译语言包」区块：可视化中↔英语言包安装状态、下载、跳转系统设置删除
- 新增「Apple 在线翻译（快捷指令）」翻译来源：经 `shortcuts run` 借道系统翻译拿到在线结果

Changes（快捷指令在线翻译）:
- 核实 `Translation.framework` 公开接口仅设备端（无 server/cloud/online 任何 API，`LanguageAvailability.Status` 只有 installed/supported/unsupported），第三方 app 无法直接调用 Apple 在线翻译
- 改走「快捷指令」方案：`ShortcutsTranslationService` 用 `/usr/bin/shortcuts run <名称> -i -o` 调用用户安装的翻译快捷指令，异步 Process 封装 + 60s 超时（首次冷启动可达 ~47s，热调用 ~0.3s）
- `TranslationProviderMode` 新增 `.appleShortcut`；`AppSettings` 新增可持久化的 `translationShortcutName`（默认 `TextGrabber Translate`）
- 结果面板在 `.appleShortcut` 下走 `beginShortcutTranslation`（不占用系统 translationTask）；设置页新增 `ShortcutTranslationConfigView`（名称输入、已安装/未安装状态、打开快捷指令 App）
- 方向判断放在快捷指令内部（检测语言→中译英/英译中），app 侧只负责喂文本、取结果

Changes（翻译版式修正）:
- 真机对比发现系统翻译把标题与正文并成一句（如「我的错题本」+ 正文 → 一整句），而在线/快捷指令保留了两行版式
- 根因是先前的 `normalizedSourceText` 在翻译层按 CJK 合并单换行，越权处理了本属独立的行；改为逐行去首尾空白、丢空行但**保留换行结构**，折行合并只交由 OCR 阅读优化阶段的版面几何判断
- 更新对应单测（改为断言换行被保留、空行被丢弃）

Changes（自动模式纳入快捷指令）:
- 此前 `.automatic` 的"在线"仅指环境变量配置的 HTTP `OnlineTranslationService`，与用户配置的快捷指令无关，导致选「自动」仍走本地
- 重构 `presentSystemTranslation`：`.automatic` 改为快捷指令优先（`beginShortcutTranslation(fallBackToSystemOnFailure: true)`），未安装/失败/超时时静默回退系统翻译；抽出 `beginResolvedTranslation(provider:)` 与 `beginOnlineHTTPTranslation`
- 更新 `.automatic` 说明文案；设置页在 `.automatic` 与 `.appleShortcut` 下都展示 `ShortcutTranslationConfigView`（名称/安装状态）

Changes（语言包管理）:
- 新增 `TranslationLanguagePackManager`：用 `LanguageAvailability` 查询中↔英两个方向的安装状态并合并为单一 `PackStatus`，暴露 `refresh`/`requestDownload`/`finishDownload`
- 新增 `LanguagePackSettingsSection` + `LanguagePackDownloadBridge`：设置页展示「已安装/未安装/检测中/不可用」状态徽标；未安装时「下载」按钮经 `.translationTask` 依次为两个方向调 `prepareTranslation()`（唤起系统下载弹窗）；「在系统设置中管理」深链到语言与地区面板供手动删除
- 受 Apple `Translation` 框架限制：无删除 API、无法自绘下载进度、下载只能走系统弹窗，故删除采用深链、进度交给系统；范围仅限应用实际使用的中↔英
- 设置窗口高度随新增区块从 488 调整到 568

Changes（会话链路重构）:
- 将「预热会话」和「正式翻译会话」两个 `.translationTask` 桥合并为单桥，由单一 `translationTaskRequest`（含 `performsTranslation` 标记）驱动，并用 `.id(requestToken)` 让每次请求重建桥，保证同一时刻只有一个 `TranslationSession`，消除同语言对会话并发导致的偶发卡死
- 预热改为异步先查 `LanguageAvailability().status(from:to:) == .installed`，仅在语言包已安装时预热，不再在未安装时主动触发系统下载弹窗；预热进行中若文本变化或已进入正式翻译则放弃，避免抢占会话
- `TranslationTaskBridge` 在 `performTranslation == false`（预热）时吞掉失败，不再把预热错误当作翻译错误弹给用户
- 移除 `prewarmPlan`/`prewarmRequestToken`/`translationPlan` 等分裂状态，统一到 `translationTaskRequest` + `translationRequestToken`

Changes:
- `SystemTranslationService` 新增 `normalizedSourceText`：按空行拆真实段落，段内 OCR 换行按 CJK 感知合并为一行，`makePlan`/`validationMessage` 统一走此规范化，避免系统翻译逐行翻译把译文拆成多段
- `scriptPreferredSourceLanguageIdentifier` 在两种文字并存时不再于 hanShare 0.1–0.25 区间返回 nil 回落通用识别器，改为一律解析为受支持语言（汉字≥¼按中文，否则按英文），消除中英混排被误判为不支持语言
- 为上述修复补 4 项单元测试（换行合并、空行段落保留、少量中文的英文句仍可翻译）
Files Modified:
- `Sources/TextGrabberKit/Models/AppSettings.swift`
- `Sources/TextGrabberKit/Services/SystemTranslationService.swift`
- `Sources/TextGrabberKit/Services/TranslationLanguagePackManager.swift`（新增）
- `Sources/TextGrabberKit/Services/ShortcutsTranslationService.swift`（新增）
- `Sources/TextGrabberKit/UI/ResultPopoverContentView.swift`
- `Sources/TextGrabberKit/UI/ResultPopoverView.swift`
- `Sources/TextGrabberKit/UI/LanguagePackSettingsSection.swift`（新增）
- `Sources/TextGrabberKit/UI/SettingsComponents.swift`
- `Sources/TextGrabberKit/UI/SettingsView.swift`
- `Sources/TextGrabberKit/UI/SettingsWindowController.swift`
- `Tests/TextGrabberTests/SystemTranslationServiceTests.swift`
- `docs/todo.md`
- `docs/dev-log.md`

Notes:
- `swift build` 通过，`swift test` 57 项全绿（新增 4 项）
- 会话链路重构与预热门控只在本机做了编译 + 单测 + 竞态审查；下载弹窗常驻、偶发卡死属系统 `Translation` 框架运行时行为，须在真机上分别用「已装/未装语言包」两种状态回归，本机无法复现验证
- 待真机验证的点：①未装语言包时打开面板不再自动弹下载框 ②装好语言包后点翻译仍能秒回（预热生效）③重复翻译同一词不再卡住转圈 ④语言包区块的「未安装→下载→已安装」流程与「在系统设置中管理」深链落点（本机中↔英已安装，无法复现下载态）
- 已用小脚本探明 `LanguageAvailability.supportedLanguages` 返回 21 种语言、`status(from:to:)` 可用，本机中↔英均为 installed；删除深链 `com.apple.Localization-Settings.extension` 可打开语言与地区面板
- 快捷指令方案已本机验证：命令行往返成功（中→英译文质量佳），热调用 0.26–0.49s、首次冷启动 ~47s；异步 Process 封装（任务组+超时+终止回调）独立验证 0.62s 无死锁
- 待你真机验证：①快捷指令改双向后中/英各译一次 ②关闭系统「设备端模式」确认译文变为在线结果 ③设置页选中该来源后名称/状态/翻译全链路
- 打包注意：仓库在 iCloud 目录，iCloud 附加的扩展属性会破坏 codesign。改用 `scripts/build-app.sh --clean --output-dir /tmp/tg-dist` 在本地目录签名，再 `ditto` 到 `/Applications`（不要在已签名 bundle 上跑 `xattr -cr`）

## 2026-07-13

Author: Codex

Summary:
- 完成结果面板视觉、OCR 文本规则、块编辑与设置页的阶段性收敛
- 将本轮最终状态同步到 README、架构、回归清单和任务列表

Changes:
- 结果面板固定为 400pt 宽，顶/底工具栏统一为 44pt，正文与译文统一为 14pt 一级字色
- 统一角落工具按钮、Tooltip、hover/选中反馈、卡片背景、滚动条和窗口阴影/描边细节
- 将 OCR 后处理拆入 `OCRTextLayoutRules.swift`，补强图标噪声过滤、列表符号还原和段落合并测试
- 新增可持久化的块编辑设置，通过 AppKit 响应链实现“当前段落 → 全文”两阶段全选，并补齐连续行选中背景
- 将设置窗口重做为单页三分区、固定标签列的 macOS 布局，移除无效预留项和不必要的多面板导航

Files Modified:
- `Sources/TextGrabberKit/Models/AppSettings.swift`
- `Sources/TextGrabberKit/Services/OCRService.swift`
- `Sources/TextGrabberKit/Services/OCRTextLayoutRules.swift`
- `Sources/TextGrabberKit/UI/BlockEditingSelection.swift`
- `Sources/TextGrabberKit/UI/ResultPopoverContentView.swift`
- `Sources/TextGrabberKit/UI/ResultPopoverStyles.swift`
- `Sources/TextGrabberKit/UI/SettingsView.swift`
- `Sources/TextGrabberKit/UI/SettingsWindowController.swift`
- `Tests/TextGrabberTests/AppSettingsTests.swift`
- `Tests/TextGrabberTests/BlockEditingSelectionTests.swift`
- `Tests/TextGrabberTests/OCRServiceFormattingTests.swift`
- `README.md`
- `docs/ai-context.md`
- `docs/architecture.md`
- `docs/git-workflow.md`
- `docs/regression-cases.md`
- `docs/todo.md`
- `docs/dev-log.md`

Notes:
- 已验证 `swift test`（47 项）和 `./scripts/codex-run.sh --verify`
- 设置窗口已通过真实窗口截图校对；块编辑的 AppKit 键盘分发和视觉选择仍建议纳入人工回归

## 2026-07-10

Author: Claude

Summary:
- 新增第三种截图激活方式「双击修饰键」
- 将结果面板视觉全面系统化，去品牌色、让系统玻璃透出、改用原生控件与语义色

Changes:
- 在 `AppSettings` 中新增 `CaptureActivationMode.doubleModifierTap`、`DoubleTapModifier` 枚举，以及可持久化的 `doubleTapModifier` 设置（默认 `⌘ Command`）
- 在 `HotkeyController` 中复用现有全局 `flagsChanged` 监听，新增 `.doubleModifierTap` 模式与按下/松开边沿检测：0.4s 窗口内、不夹带其他修饰键连按两次即触发
- `CaptureTriggerController` 改为 `combineLatest` 三参数，联动 `hotkey / activationMode / doubleTapModifier`，`updateActivation` 增加 `doubleTapModifier` 入参
- `SettingsView` 在「双击修饰键」模式下新增修饰键 Picker 与辅助功能权限说明
- 结果面板重构：移除白色蒙层让 `LiquidGlassSurface` 透出；标题栏去掉橙色 `iGET！`，改为中性 `text.viewfinder + 文字识别`；所有硬编码 `Color.white/black.opacity` 与橙色 RGB 换成 `.tint / .secondary / .quaternary / .separator` 等语义色与系统强调色
- 排版切换与 footer 操作经过多轮迭代，最终定型为：`阅读优化 / 原始版面` 收成 footer 里的一个开关图标（激活=优化），与 `翻译 / 拷贝` 一起放进 macOS 26 `.glassEffect(in: Capsule())` 玻璃胶囊按钮组，`重新识别` 单独成一个玻璃胶囊；所有图标统一为线性描边、纯黑、`.medium` 字重、30×30 圆形 hover/选中热区，复制点击带 `.symbolEffect(.bounce)`
- 顶栏去掉分隔线，左侧「截图识别」弱化色标题 + 右侧 pin/设置图标；顶栏高度 48，预览图上缘直接贴住顶栏
- 截图预览改为全宽、高度封顶 180pt，超出在预览区内部纵向滚动以便逐段比对；预览描边改为随外观切换的纯黑/纯白 0.2 内描边、去投影
- 识别正文字号 12→14pt（`resultTextFontSize` 常量，行高 19；翻译保持 12pt，拆出 `translationLineHeight`）
- 主色收敛为黑白灰：移除橙色品牌与蓝色系统强调色，文本光标改 `.labelColor`
- 边距体系：`horizontalInset` 10→14、顶栏非对称内边距（左 14/右 6）
- 修复再次点击菜单栏图标时因 `resignKey` 自动隐藏与 `toggle` 抢先导致的「闪一下又出现」，改为 0.25s 内的 resign 隐藏不再重新弹出
- 为 `AppSettings` 补充双击修饰键持久化/恢复与 `DoubleTapModifier.modifierFlag` 映射测试

Files Modified:
- `Sources/TextGrabberKit/Models/AppSettings.swift`
- `Sources/TextGrabberKit/Services/HotkeyController.swift`
- `Sources/TextGrabberKit/Services/CaptureTriggerController.swift`
- `Sources/TextGrabberKit/UI/SettingsView.swift`
- `Sources/TextGrabberKit/UI/ResultPopoverContentView.swift`
- `Tests/TextGrabberTests/AppSettingsTests.swift`
- `docs/ai-context.md`
- `docs/todo.md`
- `docs/dev-log.md`

Notes:
- 已验证 `swift build`、`swift test`（38 通过）和 `./scripts/codex-run.sh --verify`（构建/签名/启动成功）
- 双击修饰键与纯修饰键模式一样需要「辅助功能」权限；默认 `⌘` 便于发现，但高频使用时可在设置里换成更不易误触的修饰键
- 视觉改版最终外观仍建议在真机菜单栏运行态下人工校对，重点看玻璃透出后的文本对比度与深浅色模式表现

## 2026-06-19

Author: Codex

Summary:
- 收敛项目文件命名与文档边界，移除历史辅助文档

Changes:
- 将 Codex 运行入口从 `script/build_and_run.sh` 统一移动到 `scripts/codex-run.sh`
- 将正式结果页预览宿主从 `ResultPopoverFormalPreviewHost.swift` 重命名为 `ResultPopoverPreviewHost.swift`
- 删除重复的协作模板说明和个人开发日记文档，保留 `templates/collaboration-starter` 与项目级 `docs/dev-log.md`
- 更新 `.codex` Run action、架构文档、AI 上下文和 Xcode 预览手册中的引用

Files Modified:
- `.codex/environments/environment.toml`
- `scripts/codex-run.sh`
- `Sources/TextGrabberKit/UI/ResultPopoverPreviewHost.swift`
- `docs/ai-context.md`
- `docs/architecture.md`
- `docs/xcode-preview-playbook.md`
- `docs/dev-log.md`

Notes:
- 本次仍不改动 OCR、翻译或结果面板运行逻辑，只整理文件布局和命名

## 2026-06-19

Author: Codex

Summary:
- 梳理项目文件并清理非必要本地产物，保持仓库轻量

Changes:
- 删除 SwiftPM 构建缓存、本地打包产物、Finder 元数据、空临时目录和空占位文件
- 扩充 `.gitignore`，避免 `.DS_Store`、Swift 构建缓存、`dist/` 和 `scratch/` 再进入工作区
- 保留 `.codex/`、`scripts/codex-run.sh` 和 `templates/collaboration-starter`，它们分别是 Codex 运行入口和已文档化的协作模板资产

Files Modified:
- `.gitignore`
- `docs/dev-log.md`

Notes:
- 本次未改动源码逻辑；`dist/` 和 `.build/` 后续可通过打包或构建命令重新生成

## 2026-06-19

Author: Codex

Summary:
- 新增 Codex app 内预览入口，用于一键构建并启动真实 macOS 菜单栏应用
- 避开 iCloud Drive 路径下 `xattr -cr` 可能触发的扩展属性问题，将 Codex 预览产物输出到本机临时目录

Changes:
- 新增 `scripts/codex-run.sh`，封装停止旧进程、debug 构建、启动、验证和日志模式
- 新增 `.codex/environments/environment.toml`，将 Codex `Run` action 指向预览脚本
- 更新架构和 AI 上下文文档，记录新的预览入口

Files Modified:
- `scripts/codex-run.sh`
- `.codex/environments/environment.toml`
- `docs/ai-context.md`
- `docs/architecture.md`
- `docs/dev-log.md`

Notes:
- 已通过 `./scripts/codex-run.sh --verify` 验证构建、签名、启动和进程检测
- `TextGrabber` 是 `LSUIElement` 菜单栏应用，不会自动出现普通前台窗口；预览时需从菜单栏图标或调试入口触发界面

## 2026-05-12

Author: Codex

Summary:
- 将本机打包流程升级为更接近原生应用的 `.app` / zip / `/Applications` 安装链路
- 新增可双击运行的一键打包入口，并补充初版应用图标

Changes:
- 增强 `scripts/build-app.sh`，支持应用图标、版本/版权字段、中文屏幕录制权限文案、清理旧产物和更清晰的输出路径
- 新增 `scripts/package-local.command`、`scripts/install-local.sh`、`Makefile` 和 `scripts/generate-app-icon.swift`
- 生成 `Resources/TextGrabber.icns`，并在打包时复制到 App Bundle
- 新增 `docs/packaging.md`，沉淀本机打包、安装、验证和 iCloud Drive 扩展属性注意事项
- 更新 README、架构文档、AI 上下文和待办状态

Files Modified:
- `scripts/build-app.sh`
- `scripts/package-local.command`
- `scripts/install-local.sh`
- `scripts/generate-app-icon.swift`
- `Resources/TextGrabber.icns`
- `Makefile`
- `README.md`
- `docs/packaging.md`
- `docs/architecture.md`
- `docs/ai-context.md`
- `docs/todo.md`
- `docs/dev-log.md`

Notes:
- 当前仍按本机自用目标使用 ad-hoc 签名；正式对外分发仍需 Developer ID 签名与 notarization

## 2026-03-19

Author: Codex

Summary:
- 按“保留职责清晰 + 精简文件”的方向收敛结果面板相关结构
- 移除 UI 草稿 target，统一正式页预览入口
- 去掉结果页里的 token 式样式映射，改为更直观的直接参数

Changes:
- 从 `Package.swift` 中移除 `ResultPopoverUIDraftSupport` product/target
- 删除 `Sources/ResultPopoverUIDraftSupport/ResultPopoverUIDraft.swift`
- 清理 `ResultPopoverContentView.swift` 中 `ResultPopoverContentMetrics`，将间距/尺寸改为就地数值
- 清理 `ResultPopoverStyles.swift` 中 `ResultPopoverPalette` 和字体扩展，改为视图中直接样式值
- 移除 `ResultPopoverContentView.swift` 里重复的 DEBUG 预览块，保留独立 `ResultPopoverFormalPreviewHost` 作为正式预览入口
- 更新 `docs/ai-context.md`、`docs/todo.md`，移除草稿链路描述并同步当前约定

Files Modified:
- `Package.swift`
- `Sources/TextGrabberKit/UI/ResultPopoverContentView.swift`
- `Sources/TextGrabberKit/UI/ResultPopoverStyles.swift`
- `Sources/TextGrabberKit/UI/ResultPopoverFormalPreviewHost.swift`
- `Sources/ResultPopoverUIDraftSupport/ResultPopoverUIDraft.swift` (deleted)
- `docs/ai-context.md`
- `docs/todo.md`
- `docs/dev-log.md`

Notes:
- 这轮以“减少间接引用、提高微调直观度”为主，未改变核心识别/翻译业务流程

## 2026-03-19

Author: Codex

Summary:
- 将 Xcode Canvas 反复报错问题沉淀为固定排障手册，减少后续会话重复排查
- 新增正式结果页专用预览宿主，统一正式 UI 的预览入口

Changes:
- 新增 `docs/xcode-preview-playbook.md`，记录稳定预览流程、常见报错原因和处理步骤
- 在 `docs/ai-context.md` 增补正式预览宿主与排障手册入口
- 在 `docs/todo.md` Completed 中补充“预览排障经验已沉淀”
- 新增 `Sources/TextGrabberKit/UI/ResultPopoverFormalPreviewHost.swift`，作为正式结果页专用 Canvas 入口

Files Modified:
- `docs/xcode-preview-playbook.md`
- `docs/ai-context.md`
- `docs/todo.md`
- `docs/dev-log.md`
- `Sources/TextGrabberKit/UI/ResultPopoverFormalPreviewHost.swift`

Notes:
- 预览正式结果页时优先使用 `TextGrabberKit` scheme 与 `ResultPopoverFormalPreviewHost.swift`，避免落到可执行 scheme 导致 `ENABLE_DEBUG_DYLIB` 相关报错

## 2026-03-18

Author: Codex

Summary:
- 回撤了“正文区取消最低高度限制”的尝试，恢复结果面板原有的最小高度规则
- 修复系统翻译对“中文句子 + 英文命令/路径”混合文本的语言误判，避免译文与原文几乎相同

Changes:
- 将 `ResultPopoverStyles` 中正文区的最小行数恢复为 `8`
- 在 `SystemTranslationService` 中加入基于中英字符占比的源语言判断，优先修正混合文本被整体识别成英文的问题
- 新增 `SystemTranslationServiceTests`，覆盖纯中文、纯英文以及混合命令文本的目标语言决策
- 更新 `docs/ai-context.md`，记录新的翻译语言判定行为

Files Modified:
- `Sources/TextGrabberKit/UI/ResultPopoverStyles.swift`
- `Sources/TextGrabberKit/Services/SystemTranslationService.swift`
- `Tests/TextGrabberTests/SystemTranslationServiceTests.swift`
- `Tests/TextGrabberTests/ResultPopoverLayoutTests.swift`
- `docs/ai-context.md`
- `docs/dev-log.md`

Notes:
- 已重新验证 `swift build` 与 `swift test`
- 这次问题的直接根因是 `NLLanguageRecognizer` 会把含大量命令/路径的中英混排文本误判成英文，导致应用把目标语言错误设回中文

## 2026-03-18

Author: Codex

Summary:
- 按 Figma `55:469` 将结果面板中的文本识别与翻译分块重新实现为更贴近设计稿的结构
- 保留现有可编辑正文、翻译流程和自适应高度规则，并补齐与新布局一致的测试预期

Changes:
- 重写 `ResultPopoverContentView` 中结果文本区的层级，改为“分段切换 + 正文编辑区 + 分隔线 + 独立翻译结果卡片”
- 调整 `ResultPopoverStyles` 中翻译卡片和整体结果区的高度计算，使翻译结果拥有单独的卡片内边距、边框和滚动区域
- 将正文编辑字体和段落样式收敛到设计稿对应的 12pt 规格，并在切换输出模式时同步刷新段落样式
- 更新 `ResultPopoverLayoutTests` 以匹配新的独立翻译卡片高度规则
- 同步更新 `docs/ai-context.md` 与 `docs/todo.md`，移除已过期的“8 行文本区占位关系待调整”描述

Files Modified:
- `Sources/TextGrabberKit/UI/ResultPopoverContentView.swift`
- `Sources/TextGrabberKit/UI/ResultPopoverStyles.swift`
- `Tests/TextGrabberTests/ResultPopoverLayoutTests.swift`
- `docs/ai-context.md`
- `docs/todo.md`
- `docs/dev-log.md`

Notes:
- 已重新验证 `swift build` 与 `swift test`
- 当前更适合继续做一轮真实运行态回归，确认翻译中、翻译失败和超长文本下的卡片滚动表现

## 2026-03-17

Author: Codex

Summary:
- 完成结果面板这一轮真实交互打磨并做了一次小范围人工回归
- 补上正式结果面板的静态 `#Preview`，方便在 Xcode Canvas 中直接看真实视图
- 修复截图取消误入错误态的问题，并记录剩余的翻译块占位规则偏差

Changes:
- 为正式结果面板补回 `#Preview` 和预览假数据，方便直接在 `ResultPopoverContentView` 中做 Canvas 预览
- 让 `Pin`、自动聚焦、橙色光标、编辑后复制和截图取消不唤窗在真实运行态下完成验证
- 将 `screencapture` “退出码为 0 但没有产出有效图片文件”的情况归类为取消，而不是错误
- 补充 `CaptureServiceTests`，覆盖截图取消分类逻辑
- 更新 `docs/ai-context.md`、`docs/todo.md` 和 `docs/regression-cases.md`，记录已验收项与当前剩余布局问题

Files Modified:
- `Sources/TextGrabberKit/UI/ResultPopoverContentView.swift`
- `Sources/TextGrabberKit/Services/CaptureService.swift`
- `Tests/TextGrabberTests/CaptureServiceTests.swift`
- `docs/ai-context.md`
- `docs/todo.md`
- `docs/regression-cases.md`
- `docs/dev-log.md`

Notes:
- 当前剩余最主要的 UI 问题是：“最小 8 行文本区”与翻译结果模块的占位关系仍不符合预期；用户决定先结束会话，明天继续调整这条布局规则

## 2026-03-17

Author: Codex

Summary:
- 继续打磨结果文本编辑体验，补齐跨模式保留手工编辑
- 将自动聚焦光标调整到文本末尾，并改成主题橙色

Changes:
- 在 `RecognitionResultState` 中为 `阅读优化 / 原始文本` 分别保存可编辑草稿，切换模式时优先恢复对应草稿
- 将 `ResultPopoverView` 的文本绑定改为显式写回状态层，避免直接修改 `recognizedText` 绕过草稿管理
- 将 `ResultTextEditor` 的自动聚焦插入点调整到文本末尾，并把 `NSTextView` 的插入光标颜色改为主题橙色
- 为“跨模式保留手工编辑”和“清空文本后仍保留空草稿”新增测试
- 更新 `docs/ai-context.md` 记录当前编辑与聚焦行为
- 更新 `docs/regression-cases.md`，为结果面板新增 `Pin`、自动聚焦、跟随鼠标固定和编辑后复制等最小回归用例

Files Modified:
- `Sources/TextGrabberKit/Models/RecognitionResultState.swift`
- `Sources/TextGrabberKit/UI/ResultPopoverView.swift`
- `Sources/TextGrabberKit/UI/ResultPopoverContentView.swift`
- `Sources/TextGrabberKit/UI/ResultPopoverStyles.swift`
- `Tests/TextGrabberTests/RecognitionResultStateTests.swift`
- `docs/ai-context.md`
- `docs/regression-cases.md`
- `docs/dev-log.md`

Notes:
- 已重新验证 `swift build` 与 `swift test`；当前两种文本模式会分别保留用户编辑，但重新识别新截图时仍会用新的 OCR 结果重置草稿

## 2026-03-17

Author: Codex

Summary:
- 为真实结果面板补上 `Pin` 行为，让窗口可以在失焦后继续保留
- 将结果文本区改成可自动聚焦的编辑视图，打通纯键盘复制路径

Changes:
- 在 `AppCoordinator`、`ResultPopoverController` 和 `ResultPopoverView` 中新增结果窗口固定状态与切换逻辑
- 在 `ResultPopoverContentView` 头部接入 `Pin` 按钮，并把结果文本区替换为可聚焦的 `NSTextView` 桥接组件
- 在 `RecognitionResultState` 中增加文本聚焦请求 token，识别完成后自动请求焦点
- 为固定窗口失焦策略和聚焦 token 新增单元测试，并更新 `docs/ai-context.md` 与 `docs/todo.md`

Files Modified:
- `Sources/TextGrabberKit/AppCoordinator.swift`
- `Sources/TextGrabberKit/Models/RecognitionResultState.swift`
- `Sources/TextGrabberKit/UI/ResultPopoverController.swift`
- `Sources/TextGrabberKit/UI/ResultPopoverView.swift`
- `Sources/TextGrabberKit/UI/ResultPopoverContentView.swift`
- `Sources/TextGrabberKit/UI/ResultPopoverStyles.swift`
- `Sources/TextGrabberKit/UI/ResultPopoverDebugWindowController.swift`
- `Tests/TextGrabberTests/RecognitionResultStateTests.swift`
- `Tests/TextGrabberTests/ResultPopoverLayoutTests.swift`
- `docs/ai-context.md`
- `docs/todo.md`
- `docs/dev-log.md`

Notes:
- 已验证 `swift build` 与 `swift test`；当前文本区支持直接输入和键盘全选，但在切换“阅读优化 / 原始文本”时仍会回到 OCR 结果文本，后续如果要保留手工编辑需要再补更明确的数据模型

## 2026-03-17

Author: Codex

Summary:
- 修复 Swift 6 下几处 `@MainActor` 默认参数触发的并发隔离问题
- 恢复系统翻译条件编译后，重新跑通主模块、全量构建和测试

Changes:
- 将 `CaptureTriggerController`、`RecognitionWorkflow`、`AppCoordinator` 中主线程隔离依赖的默认参数实例化改为在初始化函数体内完成
- 恢复 `SystemTranslationService` 与 `ResultPopoverContentView` 里临时用于诊断的 `Translation` 条件编译
- 重新验证 `swift build --target TextGrabberKit`、`swift build`、`swift build --target ResultPopoverUIDraftSupport` 与 `swift test`
- 更新 `docs/ai-context.md`，记录本轮编译诊断结论和当前可用的验证命令

Files Modified:
- `Sources/TextGrabberKit/Services/CaptureTriggerController.swift`
- `Sources/TextGrabberKit/Services/RecognitionWorkflow.swift`
- `Sources/TextGrabberKit/AppCoordinator.swift`
- `Sources/TextGrabberKit/Services/SystemTranslationService.swift`
- `Sources/TextGrabberKit/UI/ResultPopoverContentView.swift`
- `docs/ai-context.md`
- `docs/dev-log.md`

Notes:
- 此前 `swift build` 在 `TextGrabberKit` 编译阶段长时间无输出，根因之一是 Swift 6 对 actor 隔离默认参数的诊断；修复后在 `/tmp/textgrabber-ascii` 软链接路径和仓库原路径下均可正常构建

## 2026-03-17

Author: Codex

Summary:
- 继续增强独立结果面板草稿 target，补齐更接近设计稿的状态化交互骨架
- 将一处低风险的状态化 footer 交互整合回真实结果面板

Changes:
- 重写 `Sources/ResultPopoverUIDraftSupport/ResultPopoverUIDraft.swift`，为草稿 target 增加 Pin 视觉占位、状态化 footer、阅读优化 / 原始文本排版差异、翻译结果分层和更完整的宿主控制项
- 调整 `Sources/TextGrabberKit/UI/ResultPopoverContentView.swift` 的 footer 逻辑，让结果 / 识别中 / 权限 / 错误四种状态显示不同操作按钮
- 更新 `docs/ai-context.md`，记录草稿 target 当前可承载的试验范围和已整合的低风险 UI 改动

Files Modified:
- `Sources/ResultPopoverUIDraftSupport/ResultPopoverUIDraft.swift`
- `Sources/TextGrabberKit/UI/ResultPopoverContentView.swift`
- `docs/ai-context.md`
- `docs/dev-log.md`

Notes:
- 本次尝试执行 `swift build` 与 `swift build --target ResultPopoverUIDraftSupport`，但被本机 Xcode license 未同意阻塞；错误信息提示需先在终端执行 `xcodebuild -license`

## 2026-03-16

Author: Codex

Summary:
- 将真实结果面板回退到较稳定的原生样式
- 保留近期已修复的翻译回退、鼠标跟随锚点和 `DEBUG` 调试入口
- 新增独立的结果面板草稿 target，并让 Xcode Canvas 可以单独预览

Changes:
- 回退 `ResultPopoverContentView`、`ResultPopoverStyles` 和结果面板尺寸逻辑中的激进样式调整，恢复真实运行态界面的上一版外观
- 保留“自动翻译失败/超时回退系统翻译”、跟随鼠标定位锚点稳定和 `UI 调试面板` 入口
- 新增 `Sources/ResultPopoverUIDraftSupport/ResultPopoverUIDraft.swift`，并在 `Package.swift` 中注册独立的 `ResultPopoverUIDraftSupport` target / product
- 将草稿文件放到标准 `Sources/...` 目录，解决最初放在 `scratch/` 时 Xcode Canvas 无法识别 target 归属的问题
- 更新 `docs/ai-context.md` 与 `docs/todo.md`，记录当前真实 UI 状态和后续建议

Files Modified:
- `Package.swift`
- `Sources/TextGrabberKit/UI/ResultPopoverContentView.swift`
- `Sources/TextGrabberKit/UI/ResultPopoverController.swift`
- `Sources/TextGrabberKit/UI/ResultPopoverStyles.swift`
- `Sources/TextGrabberKit/UI/ResultPopoverDebugWindowController.swift`
- `Sources/ResultPopoverUIDraftSupport/ResultPopoverUIDraft.swift`
- `Tests/TextGrabberTests/ResultPopoverLayoutTests.swift`
- `docs/ai-context.md`
- `docs/todo.md`
- `docs/dev-log.md`

Notes:
- 已验证 `swift test`、`swift build` 和 `swift build --target ResultPopoverUIDraftSupport`
- 当前结果面板样式建议优先在独立草稿 target 中迭代，确认后再整合回主工程

## 2026-03-16

Author: Codex

Summary:
- 将当前线程中记录的 bug、优化项和产品想法正式归档到项目文档
- 为后续会话补充一份可直接接手的用户反馈摘要

Changes:
- 在 `docs/todo.md` 中新增反馈收件区，分别记录翻译弹窗异常、焦点流优化、序列符号识别稳定性、预览区高度限制、窗口 Pin 和快捷指令翻译想法
- 在 `docs/ai-context.md` 中补充当前用户反馈方向，并将“消化真实用户反馈”加入开发重点和下一次会话建议

Files Modified:
- `docs/todo.md`
- `docs/ai-context.md`
- `docs/dev-log.md`

Notes:
- 本次仅做文档归档，不涉及任何功能代码修改或验证

## 2026-03-16

Author: Codex

Summary:
- 修复 `release` 构建被结果面板预览代码阻塞的问题
- 为项目补齐基础 macOS `.app` 打包链路
- 同步更新 README 与协作文档中的交付说明

Changes:
- 将结果面板预览支撑从 `DEBUG` 条件编译中拆出来，仅保留 `#Preview` 宏在调试构建中生效
- 新增 `scripts/build-app.sh`，支持构建 `TextGrabber.app`、嵌入 Swift 运行库、codesign 签名与可选 zip 归档
- 更新 `.gitignore`、`README.md`、`docs/ai-context.md`、`docs/architecture.md`、`docs/todo.md`

Files Modified:
- `Sources/TextGrabberKit/UI/ResultPopoverPreviewSupport.swift`
- `.gitignore`
- `scripts/build-app.sh`
- `README.md`
- `docs/ai-context.md`
- `docs/architecture.md`
- `docs/todo.md`
- `docs/dev-log.md`

Notes:
- 当前已经可以产出本地可运行的 `.app`，但若要正式对外分发，仍需后续补充应用图标、Developer ID 签名和 notarization

## 2026-03-16

Author: Codex

Summary:
- 调整协作规则，减少新线程里手动执行 `【上下文同步】` 的负担
- 将“自动上下文恢复”固化到当前仓库与模板文档
- 明确区分“轻量上下文恢复”和“完整上下文同步”的使用场景

Changes:
- 在 `AGENTS.md` 中新增新线程约定，要求 AI 首次进入仓库时默认先完成必读文档读取
- 调整 `AI_COMMANDS.md` 中 `上下文同步` 的定位，将其改为可选的显式摘要命令
- 同步更新 `docs/ai-context.md` 和模板文档，保持跨项目复用时的行为一致
- 将默认流程收敛为轻量恢复，仅在跨设备接力、长时间中断或需要摘要时执行完整 `上下文同步`

Files Modified:
- `AGENTS.md`
- `AI_COMMANDS.md`
- `docs/ai-context.md`
- `docs/dev-log.md`
- `templates/collaboration-starter/AGENTS.md`
- `templates/collaboration-starter/AI_COMMANDS.md`
- `templates/collaboration-starter/docs/ai-context.md`

Notes:
- 该调整只改变协作流程约定，不影响现有功能代码；后续新线程里可直接描述任务，由 AI 自动做轻量恢复，跨设备接力时再执行完整同步

## 2026-03-15

Author: Codex

Summary:
- 按设计稿重构结果面板的布局、按钮层级和视觉样式
- 为结果面板补充菜单栏居中弹出与内容驱动的自适应高度规则

Changes:
- 使用本地 Figma Desktop MCP 手动抓取设计上下文和截图，按设计稿改写 `ResultPopoverContentView`
- 调整 `ResultPopoverStyles` 中的面板常量和排版 token，使截图预览区与文本识别区按内容动态计算高度
- 让 `ResultPopoverController` 在菜单栏模式下优先按图标中心对齐显示，并在结果内容或位置模式变化时重算面板尺寸
- 更新预览宿主示例内容，便于后续继续对照设计稿调试
- 同步更新 AI 上下文、架构和待办文档，记录当前结果面板的交互状态

Files Modified:
- `Sources/TextGrabberKit/UI/ResultPopoverContentView.swift`
- `Sources/TextGrabberKit/UI/ResultPopoverController.swift`
- `Sources/TextGrabberKit/UI/ResultPopoverPreviewSupport.swift`
- `Sources/TextGrabberKit/UI/ResultPopoverStyles.swift`
- `docs/ai-context.md`
- `docs/architecture.md`
- `docs/todo.md`
- `docs/dev-log.md`

Notes:
- 当前已完成布局与基础交互对齐，下一步更适合做一轮真实菜单栏运行态验证，确认不同文本长度和截图比例下的弹窗高度是否稳定

## 2026-03-15

Author: Codex

Summary:
- 将翻译能力从结果面板视图中抽成独立服务接口
- 为后续在线翻译或 AI 翻译接入预留统一入口

Changes:
- 新增 `SystemTranslationService`，统一处理系统翻译的语种识别、目标语言策略、超时提示和错误映射
- 新增 `OnlineTranslationService` 和 `TranslationServiceResolver`，支持“自动”策略在检测到在线 provider 配置时优先在线翻译
- 将翻译状态下沉到 `RecognitionResultState`，减少视图内临时状态
- 让 `AppCoordinator` 注入翻译服务，结果面板改为消费服务层而不是内嵌翻译判断逻辑
- 为 `AppSettings` 和设置窗口增加翻译来源策略，预留“在线优先、系统回退”的后续接入点
- 同步更新 AI 上下文、架构和待办文档，补充真实用户语言包体验的后续方向

Files Modified:
- `Sources/TextGrabberKit/Services/SystemTranslationService.swift`
- `README.md`
- `Sources/TextGrabberKit/Models/RecognitionResultState.swift`
- `Sources/TextGrabberKit/AppCoordinator.swift`
- `Sources/TextGrabberKit/UI/ResultPopoverView.swift`
- `Sources/TextGrabberKit/UI/ResultPopoverContentView.swift`
- `Sources/TextGrabberKit/UI/ResultPopoverPreviewSupport.swift`
- `Sources/TextGrabberKit/Models/AppSettings.swift`
- `Sources/TextGrabberKit/UI/SettingsView.swift`
- `Sources/TextGrabberKit/UI/SettingsWindowController.swift`
- `Tests/TextGrabberTests/AppSettingsTests.swift`
- `docs/ai-context.md`
- `docs/architecture.md`
- `docs/todo.md`
- `docs/dev-log.md`

Notes:
- 当前系统翻译仍可能受语言资源准备状态影响，真实用户上线前建议增加安装引导或在线翻译回退

## 2026-03-15

Author: Codex

Summary:
- 为结果面板增加系统翻译入口，补齐 OCR 结果到系统翻译的最小闭环
- 保持当前包最低版本不变，并为低版本系统补充可用性提示

Changes:
- 在结果面板底部新增“系统翻译”按钮
- 通过 SwiftUI `translationPresentation` 调用系统翻译能力
- 在 `macOS 15` 以下显示兼容性提示，不影响现有 OCR 主流程
- 更新项目上下文、架构和待办文档，记录系统翻译现状与后续 AI 接入方向

Files Modified:
- `Sources/TextGrabberKit/UI/ResultPopoverContentView.swift`
- `docs/ai-context.md`
- `docs/architecture.md`
- `docs/todo.md`
- `docs/dev-log.md`

Notes:
- 本次暂未抽出独立翻译服务，当前实现以最小可验证接入系统能力为主，后续可在此基础上替换为 AI 翻译服务

## 2026-03-15

Author: Codex

Summary:
- 将识别流程抽成独立 workflow 对象，降低 `AppCoordinator` 的流程耦合
- 将快捷键与选择阶段控制抽成独立触发控制对象
- 拆分结果面板 UI 结构，降低后续改动对已稳定界面的影响

Changes:
- 新增 `CaptureTriggerController`，承接快捷键注册、设置联动和 `Fn` 释放监测
- 新增 `RecognitionWorkflow`，承接权限检查、截图、OCR 和取消流程
- 新增 `RecognitionResultState`，承接结果展示相关状态
- 将 `ResultPopoverView` 拆为入口包装、内容视图、样式支撑和预览支撑四个文件
- 同步更新架构与 AI 上下文文档中的 UI 结构说明

Files Modified:
- `Sources/TextGrabberKit/AppCoordinator.swift`
- `Sources/TextGrabberKit/Services/CaptureTriggerController.swift`
- `Sources/TextGrabberKit/Models/RecognitionResultState.swift`
- `Sources/TextGrabberKit/Services/RecognitionWorkflow.swift`
- `Sources/TextGrabberKit/UI/ResultPopoverView.swift`
- `Sources/TextGrabberKit/UI/ResultPopoverContentView.swift`
- `Sources/TextGrabberKit/UI/ResultPopoverStyles.swift`
- `Sources/TextGrabberKit/UI/ResultPopoverPreviewSupport.swift`
- `docs/architecture.md`
- `docs/ai-context.md`
- `docs/dev-log.md`

Notes:
- 本次以结构拆分为主，功能行为保持不变，`swift test` 已通过

## 2026-03-15

Author: Codex

Summary:
- 按“开始开发”命令补充设置与快捷键相关测试
- 同步协作文档中的测试覆盖说明
- 继续补充快捷键事件解析与纯修饰键判定测试
- 增加 `Fn` 激活模式、鼠标定位模式与按住触发退出行为

Changes:
- 新增 `AppSettings` 默认值、持久化与旧快捷键迁移单测
- 为 `KeyboardShortcut` 增加按键事件解析测试
- 为设置新增激活模式和识别窗口位置模式
- 让纯修饰键和 `Fn` 模式在松开按键时退出交互式截图
- 让结果面板支持按菜单栏图标或鼠标位置显示
- 更新项目上下文、架构和待办文档中的测试覆盖描述

Files Modified:
- `Sources/TextGrabberKit/AppCoordinator.swift`
- `Sources/TextGrabberKit/Models/AppSettings.swift`
- `Sources/TextGrabberKit/Services/CaptureService.swift`
- `Sources/TextGrabberKit/Services/HotkeyController.swift`
- `Sources/TextGrabberKit/UI/ResultPopoverController.swift`
- `Sources/TextGrabberKit/UI/SettingsView.swift`
- `Sources/TextGrabberKit/UI/SettingsWindowController.swift`
- `Tests/TextGrabberTests/AppSettingsTests.swift`
- `Tests/TextGrabberTests/SelectionSessionTests.swift`
- `docs/ai-context.md`
- `docs/architecture.md`
- `docs/todo.md`
- `docs/dev-log.md`

Notes:
- 本次未改动主流程实现，重点是为后续快捷键与设置改动提供回归保护

## 2026-03-14

Author: Codex

Summary:
- 为当前仓库建立统一的 AI 协作文档结构
- 将外部项目中的协作规范模板提炼并复用到 `TextGrabber`

Changes:
- 新增 `AGENTS.md`、`PROJECT_RULES.md`、`AI_COMMANDS.md`
- 新增 `docs/ai-context.md`、`docs/architecture.md`、`docs/todo.md`
- 补充 `docs/git-workflow.md`、`docs/regression-cases.md`
- 整理跨项目可复用的协作模板说明
- 新增 `templates/collaboration-starter` 初始化包，便于后续新项目直接套用
- 记录当前 `TextGrabber` 的代码结构、主要流程与后续任务方向

Files Modified:
- `AGENTS.md`
- `PROJECT_RULES.md`
- `AI_COMMANDS.md`
- `docs/ai-context.md`
- `docs/architecture.md`
- `docs/todo.md`
- `docs/dev-log.md`
- `docs/git-workflow.md`
- `docs/regression-cases.md`
- `docs/collaboration-template.md`
- `templates/collaboration-starter/README.md`
- `templates/collaboration-starter/AGENTS.md`
- `templates/collaboration-starter/PROJECT_RULES.md`
- `templates/collaboration-starter/AI_COMMANDS.md`
- `templates/collaboration-starter/docs/ai-context.md`
- `templates/collaboration-starter/docs/architecture.md`
- `templates/collaboration-starter/docs/todo.md`
- `templates/collaboration-starter/docs/dev-log.md`
- `templates/collaboration-starter/docs/git-workflow.md`
- `templates/collaboration-starter/docs/regression-cases.md`

Notes:
- 当前文档以“可交接、可续做”为目标，后续若项目目标或结构变化，需要优先同步 `ai-context`、`architecture` 和 `todo`

## 2026-03-14

Author: Codex

Summary:
- 按“结束会话”命令完成本次协作收尾
- 同步当前项目状态、待办和下一次会话建议

Changes:
- 更新 `docs/ai-context.md`，记录协作文档体系与初始化包已就绪
- 更新 `docs/todo.md`，补充模板初始化脚本的后续建议，并将初始化包记入已完成项
- 保留当前会话可直接续做的下一步方向

Files Modified:
- `docs/ai-context.md`
- `docs/todo.md`
- `docs/dev-log.md`

Notes:
- 当前功能代码未改动，本次收尾以协作文档同步为主
