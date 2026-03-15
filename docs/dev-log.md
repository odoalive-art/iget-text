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
