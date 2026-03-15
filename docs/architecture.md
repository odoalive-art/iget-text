# Project Architecture

## Directory Structure

```text
.
├── Package.swift
├── AGENTS.md
├── PROJECT_RULES.md
├── AI_COMMANDS.md
├── README.md
├── templates
│   └── collaboration-starter
│       ├── AGENTS.md
│       ├── PROJECT_RULES.md
│       ├── AI_COMMANDS.md
│       ├── README.md
│       └── docs
│           ├── ai-context.md
│           ├── architecture.md
│           ├── dev-log.md
│           ├── git-workflow.md
│           ├── regression-cases.md
│           └── todo.md
├── docs
│   ├── ai-context.md
│   ├── architecture.md
│   ├── collaboration-template.md
│   ├── dev-log.md
│   ├── git-workflow.md
│   ├── regression-cases.md
│   └── todo.md
├── Sources
│   ├── TextGrabberApp
│   │   ├── AppDelegate.swift
│   │   └── TextGrabberApp.swift
│   ├── TextGrabberKit
│   │   ├── AppCoordinator.swift
│   │   ├── Models
│   │   │   ├── AppSettings.swift
│   │   │   └── OCRResult.swift
│   │   │   └── RecognitionResultState.swift
│   │   ├── Services
│   │   │   ├── CaptureTriggerController.swift
│   │   │   ├── CaptureService.swift
│   │   │   ├── HotkeyController.swift
│   │   │   └── OCRService.swift
│   │   │   └── RecognitionWorkflow.swift
│   │   └── UI
│   │       ├── ResultPopoverController.swift
│   │       ├── ResultPopoverContentView.swift
│   │       ├── ResultPopoverPreviewSupport.swift
│   │       ├── ResultPopoverStyles.swift
│   │       ├── ResultPopoverView.swift
│   │       ├── SettingsView.swift
│   │       └── SettingsWindowController.swift
│   └── TextGrabberPreviewApp
│       └── TextGrabberPreviewApp.swift
└── Tests
    └── TextGrabberTests
        └── SelectionSessionTests.swift
```

## Modules

### `TextGrabberApp`

真实应用入口。

- 设置应用为菜单栏辅助应用（`accessory`）
- 创建 `AppSettings`
- 初始化并启动 `AppCoordinator`

### `TextGrabberKit`

核心业务模块。

#### `AppCoordinator`

整个识别流程的编排中心，负责：

- 管理工作流状态
- 连接快捷键回调
- 发起截图与 OCR
- 驱动结果面板内容状态
- 转发复制、重试、打开设置等操作

#### `Models`

- `AppSettings`：持久化用户设置，当前主要是快捷键
- `OCRResult` / `OCRLine`：OCR 输出结果模型
- `RecognitionResultState`：识别结果、输出模式、预览图和错误信息状态

#### `Services`

- `CaptureTriggerController`：管理快捷键注册、设置联动和选择阶段的 `Fn` 释放监测
- `CaptureService`：屏幕录制权限、系统截图
- `HotkeyController`：全局快捷键注册、纯修饰键监听和 `Fn` 激活监听
- `OCRService`：Vision 文本识别与图像增强
- `RecognitionWorkflow`：串联权限检查、截图、OCR 和取消等主流程动作
- `SystemTranslationService`：系统翻译计划生成、语种推断、超时与错误映射，为后续在线翻译留出统一入口
- `OnlineTranslationService`：基于环境变量配置的通用 HTTP 在线翻译 provider，请求成功后可直接回填结果面板

#### `UI`

- `ResultPopoverController`：菜单栏图标、右键菜单、自定义浮动面板管理
- `ResultPopoverController` 支持按菜单栏图标或鼠标位置显示结果面板
- `ResultPopoverView`：结果面板入口包装，连接 `AppCoordinator`
- `ResultPopoverContentView`：结果面板主内容和各状态切换，并承接系统翻译入口
- `ResultPopoverStyles`：面板布局、玻璃容器和按钮样式
- `ResultPopoverPreviewSupport`：预览宿主和预览工厂
- `SettingsWindowController` / `SettingsView`：设置窗口与快捷键编辑 UI
- `AppSettings` 现已持久化翻译来源策略，为后续“在线优先、系统回退”预留开关

### `TextGrabberPreviewApp`

独立 UI 预览宿主。

用途：

- 在不依赖 Xcode Canvas 的情况下调试结果面板
- 快速切换结果、识别中、权限等状态
- 降低预览链路不稳定对开发效率的影响

### `TextGrabberTests`

当前测试较轻量，主要覆盖：

- 快捷键显示字符串
- 纯修饰键快捷键的显示与判定
- 快捷键事件到模型的解析逻辑
- `AppSettings` 的默认值、持久化与旧快捷键迁移逻辑

## Data Flow

### 主流程

1. 用户按下全局快捷键
2. `HotkeyController` 或 `Fn` 激活监听回调 `AppCoordinator.handleHotkeyPressed()`
3. `AppCoordinator` 检查屏幕录制权限
4. `CaptureService` 调用 `screencapture -i -x` 进行系统截图
5. 截图结果传入 `OCRService`
6. `OCRService` 使用 Vision 识别文本，并在必要时尝试增强图像后再次识别
7. `AppCoordinator` 更新识别文本、预览图、界面状态
8. `ResultPopoverController` 展示结果浮动面板

在 `Fn` 模式或纯修饰键模式下，释放激活键会中断交互式截图并退出框选。

### 设置流

1. 用户打开设置窗口
2. 修改快捷键、激活模式或识别窗口位置
3. `AppSettings` 持久化新的设置
4. `AppCoordinator` 监听设置变化
5. `HotkeyController` 更新系统级快捷键注册或 `Fn` 监听方式

### 翻译入口

1. 用户在结果面板点击“系统翻译”
2. `SystemTranslationService` 根据当前文本生成翻译计划，决定源语言、目标语言和错误提示策略
3. `ResultPopoverContentView` 在 `macOS 15+` 上通过 SwiftUI 的 `translationTask` 驱动系统翻译会话
4. 翻译结果继续显示在应用自己的结果面板中，失败则展示统一错误文案
5. 在更低系统版本上显示兼容性提示，不影响 OCR 主流程

## State Model

`AppCoordinator` 维护两套状态：

- `WorkflowState`
  - `idle`
  - `selecting`
  - `recognizing`
  - `resultVisible`

- `PopoverContentState`
  - `idle`
  - `recognizing`
  - `result`
  - `permission`
  - `error`

这种拆分方式让“流程状态”和“展示状态”可以分别演化，但后续如果状态继续增加，需要关注是否会出现重复表达。

## External Dependencies

项目目前没有第三方包依赖，主要依赖系统框架与工具：

- `AppKit`
- `SwiftUI`
- `Combine`
- `Vision`
- `CoreGraphics`
- `CoreImage`
- `ApplicationServices`
- `Carbon`
- `/usr/sbin/screencapture`

## Architectural Notes

1. 当前架构已经从单协调器模式开始向“协调器 + 触发控制 + workflow + 结果状态”拆分。
2. `AppCoordinator` 已将识别结果相关状态下沉到 `RecognitionResultState`，将权限检查、截图、OCR 等动作下沉到 `RecognitionWorkflow`，并将快捷键与选择阶段控制下沉到 `CaptureTriggerController`。
3. 结果面板 UI 已拆成入口、内容、样式和预览支撑四层，后续调整某一层时更不容易波及已稳定部分。
4. `templates/collaboration-starter` 提供了一套可复制到新仓库的协作初始化包。
5. `TranslationServiceResolver` 会根据设置和环境变量决定走在线翻译还是系统翻译；当前“自动”策略在检测到在线 provider 配置时会优先在线，失败后再回退系统。
