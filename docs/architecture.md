# Project Architecture

## Directory Structure

```text
.
├── Package.swift
├── AGENTS.md
├── PROJECT_RULES.md
├── AI_COMMANDS.md
├── README.md
├── .codex
│   └── environments
│       └── environment.toml
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
│   ├── dev-log.md
│   ├── packaging.md
│   ├── git-workflow.md
│   ├── regression-cases.md
│   ├── xcode-preview-playbook.md
│   └── todo.md
├── scripts
│   ├── build-app.sh
│   ├── codex-run.sh
│   ├── generate-app-icon.swift
│   ├── install-local.sh
│   └── package-local.command
├── Sources
│   ├── TextGrabberApp
│   │   ├── AppDelegate.swift
│   │   └── TextGrabberApp.swift
│   ├── TextGrabberKit
│   │   ├── AppCoordinator.swift
│   │   ├── Models
│   │   │   ├── AppSettings.swift
│   │   │   ├── OCRResult.swift
│   │   │   └── RecognitionResultState.swift
│   │   ├── Services
│   │   │   ├── CaptureTriggerController.swift
│   │   │   ├── CaptureService.swift
│   │   │   ├── HotkeyController.swift
│   │   │   ├── OCRService.swift
│   │   │   ├── OCRTextLayoutRules.swift
│   │   │   ├── RecognitionWorkflow.swift
│   │   │   ├── ShortcutsTranslationService.swift
│   │   │   ├── SystemTranslationService.swift
│   │   │   └── TranslationLanguagePackManager.swift
│   │   └── UI
│   │       ├── BlockEditingSelection.swift
│   │       ├── LanguagePackSettingsSection.swift
│   │       ├── ResultPopoverController.swift
│   │       ├── ResultPopoverContentView.swift
│   │       ├── ResultPopoverDebugWindowController.swift
│   │       ├── ResultPopoverPreviewHost.swift
│   │       ├── ResultPopoverStyles.swift
│   │       ├── ResultPopoverView.swift
│   │       ├── SettingsComponents.swift
│   │       ├── SettingsView.swift
│   │       └── SettingsWindowController.swift
└── Tests
    └── TextGrabberTests
        ├── AppSettingsTests.swift
        ├── BlockEditingSelectionTests.swift
        ├── CaptureServiceTests.swift
        ├── OCRServiceFormattingTests.swift
        ├── RecognitionResultStateTests.swift
        ├── ResultPopoverLayoutTests.swift
        ├── SelectionSessionTests.swift
        └── SystemTranslationServiceTests.swift
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

- `AppSettings`：持久化截图激活、快捷键、结果窗口位置、翻译来源和块编辑设置
- `OCRResult` / `OCRLine`：OCR 输出结果模型
- `RecognitionResultState`：识别结果、输出模式、预览图和错误信息状态

#### `Services`

- `CaptureTriggerController`：管理快捷键注册、设置联动和选择阶段的 `Fn` 释放监测
- `CaptureService`：屏幕录制权限、系统截图
- `HotkeyController`：全局快捷键注册、纯修饰键监听和 `Fn` 激活监听
- `OCRService`：Vision 文本识别、图像增强与候选质量选择
- `OCRTextLayoutRules`：OCR 文本清洗、图标噪声过滤、列表符号还原、段落合并与中英文空格规则
- `RecognitionWorkflow`：串联权限检查、截图、OCR 和取消等主流程动作
- `SystemTranslationService`：系统翻译计划生成、语种推断、超时与错误映射，为后续在线翻译留出统一入口；`normalizedSourceText` 按空行拆真实段落、段内换行按 CJK 感知合并，避免逐行翻译拆段
- `OnlineTranslationService`：基于环境变量配置的通用 HTTP 在线翻译 provider，请求成功后可直接回填结果面板
- `ShortcutsTranslationService`：经 `/usr/bin/shortcuts run` 调用用户安装的翻译快捷指令，借道系统翻译拿到（关闭「设备端模式」时的）Apple 在线翻译结果；异步 Process 封装含 60s 超时
- `TranslationLanguagePackManager`：用 `LanguageAvailability` 查询中↔英语言包安装状态并驱动设置页语言包区块（受框架限制无删除/进度 API）

#### `UI`

- `ResultPopoverController`：菜单栏图标、右键菜单、自定义浮动面板管理
- `ResultPopoverController` 支持按菜单栏图标或鼠标位置显示结果面板，并会在结果内容变化时重新计算面板尺寸
- `ResultPopoverView`：结果面板入口包装，连接 `AppCoordinator`
- `ResultPopoverContentView`：结果面板主内容和各状态切换，并承接翻译入口、预览/文本自适应布局及 `NSTextView` 键盘桥接
- `BlockEditingSelection`：纯范围计算器，负责首次全选当前段落、再次全选全文
- `ResultPopoverDebugWindowController`：`DEBUG` 构建下的 UI 调试面板，可在主程序内切换假数据场景和布局
- `ResultPopoverStyles`：面板布局、玻璃容器、按钮样式和结果面板自适应尺寸规则
- `SettingsWindowController` / `SettingsView`：仿 macOS 系统设置的标准窗口，`NavigationSplitView` 左侧边栏分类（截图识别 / 结果面板 / 翻译 / 文本编辑），右侧对应分组表单；翻译分类含翻译来源、快捷指令配置与语言包区块
- `SettingsComponents`：设置页可复用控件（只读信息行、说明文本、权限提示、快捷键录制器 `ShortcutRecorderControl`）
- `LanguagePackSettingsSection`：翻译语言包区块与 `LanguagePackDownloadBridge` 下载桥接（`.translationTask` 依次准备中↔英两个方向）
- `AppSettings` 现已持久化翻译来源策略，支持“自动（在线优先，失败/超时后回退系统）”“仅系统翻译”和“Apple 在线翻译（快捷指令）”（含可配置的快捷指令名称）
- `ShortcutTranslationConfigView`：选中快捷指令来源时的配置行（名称输入、已安装状态、打开快捷指令 App）

### `TextGrabberTests`

当前测试覆盖：

- 快捷键显示字符串
- 纯修饰键快捷键的显示与判定
- 快捷键事件到模型的解析逻辑
- `AppSettings` 的默认值、持久化与旧快捷键迁移逻辑
- 块编辑的段落/全文两阶段范围计算
- OCR 阅读优化、列表符号和段落合并规则
- 结果面板尺寸、窗口固定与焦点请求
- 截图取消分类和系统/在线翻译的语言策略

## Data Flow

### 主流程

1. 用户按下全局快捷键
2. `HotkeyController` 或 `Fn` 激活监听回调 `AppCoordinator.handleHotkeyPressed()`
3. `AppCoordinator` 检查屏幕录制权限
4. `CaptureService` 调用 `screencapture -i -x` 进行系统截图
5. 截图结果传入 `OCRService`
6. `OCRService` 分别识别原图与增强图，并按质量分选择候选
7. `OCRTextLayoutRules` 生成默认展示的阅读优化文本
8. `AppCoordinator` 更新识别文本、预览图、界面状态
9. `ResultPopoverController` 展示结果浮动面板

在 `Fn` 模式或纯修饰键模式下，释放激活键会中断交互式截图并退出框选。

### 设置流

1. 用户打开设置窗口
2. 修改快捷键、激活模式、识别窗口位置、翻译来源或块编辑
3. `AppSettings` 持久化新的设置
4. `CaptureTriggerController` 监听触发相关设置，并更新系统级快捷键或 `Fn` 监听方式
5. 结果面板直接观察窗口位置、翻译来源和块编辑设置

### 翻译入口

1. 用户在结果面板点击“系统翻译”
2. `SystemTranslationService` 根据当前文本生成翻译计划，决定源语言、目标语言和错误提示策略
3. `ResultPopoverContentView` 在 `macOS 15+` 上通过 SwiftUI 的 `translationTask` 驱动系统翻译会话
4. 翻译结果继续显示在应用自己的结果面板中，失败则展示统一错误文案
5. 在更低系统版本上显示兼容性提示，不影响 OCR 主流程

### 块编辑

1. `AppSettings.isBlockEditingEnabled` 控制功能是否启用，默认开启
2. `FocusableResultTextView` 在 AppKit 响应链中接管 `⌘A` 与 `⌃A`
3. `BlockEditingSelection` 根据光标位置返回当前段落范围；若当前选择已是该段落，则返回全文范围
4. 文本视图仅为块选择补齐整行背景，真实字符范围保持不变，复制不会引入填充字符
5. 鼠标选择或其他键盘移动会恢复系统原生选择外观

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
- `xcrun swift-stdlib-tool`
- `/usr/bin/iconutil`
- `/usr/bin/codesign`
- `/usr/bin/ditto`

## Packaging Flow

本机打包以 `scripts/build-app.sh` 为底层入口，并提供更短的一键入口：

- `scripts/codex-run.sh`：Codex 预览入口，构建 debug 版菜单栏 `.app` 到本机临时目录并启动，避免 iCloud Drive 扩展属性影响本地预览
- `.codex/environments/environment.toml`：将 Codex app 的 `Run` action 指向 `./scripts/codex-run.sh`
- `scripts/package-local.command`：可在 Finder 双击运行，清理旧产物后生成 `.app` 和 zip，并打开 `dist/`
- `scripts/install-local.sh`：将 `dist/TextGrabber.app` 安装到 `/Applications/TextGrabber.app`
- `Makefile`：提供 `make app`、`make package`、`make install`、`make icon` 等短命令
- `docs/packaging.md`：记录完整打包、安装、验证和注意事项

`scripts/build-app.sh` 会执行以下步骤：

1. 通过 `swift build -c release --product TextGrabber` 构建真实菜单栏应用
2. 在 `dist/TextGrabber.app` 下创建标准 macOS App Bundle 目录结构
3. 写入 `Info.plist`，声明菜单栏应用、图标、版本、权限文案等 bundle 元信息
4. 复制主可执行文件到 `Contents/MacOS`，并复制 `Resources/TextGrabber.icns` 到 `Contents/Resources`
5. 使用 `swift-stdlib-tool` 将 Swift 运行库拷贝到 `Contents/Frameworks`
6. 使用 `codesign` 做 ad-hoc 或指定身份签名
7. 按需用 `ditto` 额外产出 zip 归档包

## Architectural Notes

1. 当前架构已经从单协调器模式开始向“协调器 + 触发控制 + workflow + 结果状态”拆分。
2. `AppCoordinator` 已将识别结果相关状态下沉到 `RecognitionResultState`，将权限检查、截图、OCR 等动作下沉到 `RecognitionWorkflow`，并将快捷键与选择阶段控制下沉到 `CaptureTriggerController`。
3. 结果面板 UI 已拆成入口、内容和样式三层，后续调整某一层时更不容易波及已稳定部分。
4. `templates/collaboration-starter` 提供了一套可复制到新仓库的协作初始化包。
5. `TranslationServiceResolver` 会根据设置和环境变量决定走在线翻译还是系统翻译；当前“自动”策略在检测到在线 provider 配置时会优先在线，失败后再回退系统。
6. 当前分发层仍以脚本打包为主，已支持本机一键 `.app` / zip / `/Applications` 安装；正式对外分发仍需后续补充 Developer ID 签名与 notarization。
7. OCR 的 Vision 执行与文本版式规则保持分离；新增清洗规则应优先进入 `OCRTextLayoutRules` 并补充格式化测试。
