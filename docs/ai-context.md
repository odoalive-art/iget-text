# AI Context

## Project Overview

`TextGrabber` 是一个 macOS 菜单栏截图 OCR 小工具。

当前仓库使用 Swift Package 管理，核心代码位于 `TextGrabberKit`，并通过两个可执行目标提供：

- `TextGrabber`：真实菜单栏工具
- `TextGrabberPreview`：独立预览宿主，用于调试结果面板 UI

## Project Goal

构建一个轻量、原生、低打扰的文字识别工具，用户通过全局快捷键触发系统截图，再使用本地 OCR 将选区内容识别为可复制、可编辑的文本。

## Current Status

当前项目已经具备从截图到展示结果的完整主流程：

- 菜单栏常驻运行
- 支持全局快捷键触发截图识别
- 调用系统 `screencapture` 完成交互式框选
- 使用 Vision 完成本地中文/英文 OCR
- 识别结果通过自定义浮动面板展示
- 支持复制文本、重新识别、打开设置
- 支持 `Fn` 键作为截图激活模式
- 支持识别结果窗口按菜单栏或鼠标位置显示
- 纯修饰键和 `Fn` 激活模式下，松开按键会退出截图
- 提供独立预览宿主，降低 Xcode Canvas 不稳定带来的影响

## Current Features

- 默认快捷键为 `Control + Option`
- 支持纯修饰键快捷键，也支持带按键组合
- 设置窗口可切换“组合键”与 `Fn` 两种激活模式
- 当缺少屏幕录制权限时，显示权限提示并可跳转系统设置
- 识别中、识别结果、权限错误、一般错误均有独立 UI 状态
- 结果面板内可同时查看截图预览与识别文本
- 文本可直接在结果面板中编辑
- 结果面板支持一键调用系统翻译能力进行文本翻译（`macOS 15+`）
- 已将翻译逻辑抽成独立服务接口，便于后续接入在线或 AI 翻译
- 设置窗口已增加翻译来源策略，当前支持“自动（预留在线回退）”和“仅系统翻译”
- 若配置 `TEXTGRABBER_TRANSLATION_API_URL` 等环境变量，“自动”策略会优先走在线翻译，失败后再回退系统翻译
- 设置窗口支持修改快捷键
- 设置窗口支持切换识别窗口定位方式
- 已为 `AppSettings` 补充快捷键默认值、持久化与旧配置迁移测试
- 已为 `KeyboardShortcut` 补充按键事件解析与纯修饰键判定测试
- 已补齐一套可用于后续 AI 协作和跨项目复用的文档体系
- 已沉淀 `templates/collaboration-starter`，可直接复制到新项目作为协作初始化包

## Development Focus

当前开发重点建议围绕以下方向展开：

1. 稳定真实工具交互体验  
   重点关注快捷键、截图取消、权限失败和结果面板行为。

2. 打磨结果面板细节  
   包括层级、按钮反馈、窗口定位与样式一致性。

3. 补充测试与回归用例  
   已开始补充设置与快捷键相关单测，但真实交互流程仍主要依赖人工验证。

4. 优化真实用户翻译体验  
   重点是语言包引导、失败提示，以及后续在线翻译兜底。

5. 完善交付能力  
   如登录启动、打包分发、版本信息与安装体验。

6. 沉淀跨项目协作资产  
   当前仓库已经包含一套可复用的协作文档模板，后续可以继续按使用反馈迭代。

## Next Session

下一次会话优先可以从这些任务中选择：

1. 补充真实流程相关回归清单并执行一轮检查
2. 为设置与快捷键行为增加更多测试覆盖
3. 继续收敛结果面板的交互细节
4. 为翻译能力预留可替换的服务接口，评估后续接入 AI 模型
5. 为真实用户设计翻译资源未就绪时的安装引导或在线回退方案
6. 评估登录启动和分发方案
7. 如果跨项目复用频率变高，增加一键初始化脚本来自动替换模板占位符

## Key Files

- `Package.swift`  
  定义 `TextGrabberKit`、`TextGrabber`、`TextGrabberPreview` 三个主要产物。

- `Sources/TextGrabberApp/AppDelegate.swift`  
  菜单栏应用入口，负责初始化 `AppCoordinator`。

- `Sources/TextGrabberKit/AppCoordinator.swift`  
  主流程编排中心，串联快捷键、截图、OCR、弹窗状态与设置。

- `Sources/TextGrabberKit/Models/RecognitionResultState.swift`  
  管理识别结果文本、输出模式、截图预览和错误信息。

- `Sources/TextGrabberKit/Services/CaptureService.swift`  
  处理屏幕录制权限与系统截图调用。

- `Sources/TextGrabberKit/Services/CaptureTriggerController.swift`  
  管理快捷键注册、设置联动和选择阶段的触发控制。

- `Sources/TextGrabberKit/Services/OCRService.swift`  
  负责 Vision OCR 识别和简单图像增强。

- `Sources/TextGrabberKit/Services/SystemTranslationService.swift`  
  负责系统翻译的语言判断、目标语言策略和错误文案映射。

- `Sources/TextGrabberKit/Services/HotkeyController.swift`  
  管理全局快捷键注册及纯修饰键监听。

- `Sources/TextGrabberKit/Services/RecognitionWorkflow.swift`  
  串联权限检查、截图、OCR、取消等识别流程动作。

- `Sources/TextGrabberKit/UI/ResultPopoverController.swift`  
  管理菜单栏状态项与结果浮动面板。

- `Sources/TextGrabberKit/UI/ResultPopoverView.swift`  
  结果面板入口包装，连接协调器与内容视图。

- `Sources/TextGrabberKit/UI/ResultPopoverContentView.swift`  
  结果面板的主内容和状态切换。

- `Sources/TextGrabberKit/UI/ResultPopoverStyles.swift`  
  面板布局常量、玻璃效果和按钮样式。

- `Sources/TextGrabberKit/UI/SettingsView.swift`  
  快捷键设置界面。

- `Tests/TextGrabberTests/SelectionSessionTests.swift`  
  当前已有的基础测试，主要覆盖快捷键显示逻辑。

- `templates/collaboration-starter/`  
  可复制到其他仓库的协作文档初始化包。
