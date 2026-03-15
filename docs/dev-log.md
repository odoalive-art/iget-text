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
