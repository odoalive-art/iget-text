# AI Context

## Project Overview

`TextGrabber` 是一个 macOS 菜单栏截图 OCR 小工具。

当前仓库使用 Swift Package 管理，核心代码位于 `TextGrabberKit`，并通过 `TextGrabber` 可执行目标提供真实菜单栏工具。

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
- 支持「双击修饰键」激活模式（在设置里选 `⌘/⌥/⌃/⇧`，短时间内连按两次触发）
- 支持识别结果窗口按菜单栏或鼠标位置显示
- 纯修饰键和 `Fn` 激活模式下，松开按键会退出截图
- 结果面板视觉已全面系统化：去掉橙色品牌、让系统玻璃透出、改用语义色/系统强调色与原生控件，并支持预览区与文本区自适应高度

## Current Features

- 默认快捷键为 `Control + Option`
- 支持纯修饰键快捷键，也支持带按键组合
- 设置窗口可切换“组合键”“双击修饰键”与 `Fn` 三种激活模式；双击修饰键需在 0.4s 内连按且不夹带其他修饰键，默认 `⌘`
- 当缺少屏幕录制权限时，显示权限提示并可跳转系统设置
- 识别中、识别结果、权限错误、一般错误均有独立 UI 状态
- 结果面板内可同时查看截图预览与识别文本
- 文本可直接在结果面板中查看、选择、复制和简单编辑
- 结果面板支持一键调用系统翻译能力进行文本翻译（`macOS 15+`）
- 已将翻译逻辑抽成独立服务接口，便于后续接入在线或 AI 翻译
- 设置窗口已增加翻译来源策略，当前支持“自动（在线优先，失败/超时后回退系统翻译）”和“仅系统翻译”
- 若配置 `TEXTGRABBER_TRANSLATION_API_URL` 等环境变量，“自动”策略会优先走在线翻译；请求失败或超时后会自动回退系统翻译
- 已开始沉淀真实用户反馈清单，当前重点包括翻译语言包下载弹窗异常、识别后焦点流、序列符号识别稳定性、预览区高度限制、窗口 Pin，以及快捷指令翻译可行性
- 设置窗口支持修改快捷键
- 设置窗口支持切换识别窗口定位方式
- 结果面板在菜单栏模式下优先按图标中心对齐显示
- 截图预览区域会按截图比例自适应高度，宽度固定为文本区域宽度的 `80%`
- 文本识别区域按内容高度在 `8` 到 `24` 行之间伸缩，超出后在区域内部滚动
- 识别完成后会自动将焦点定位到结果文本区域末尾，并显示主题橙色输入光标，方便直接键盘全选 / 复制 / 编辑
- 结果面板支持头部 `Pin` 按钮；固定后窗口不会因失焦自动关闭，方便跨应用对照内容
- 手工编辑过的结果文本会按 `阅读优化 / 原始文本` 两个模式分别保留，切换模式时不会再覆盖当前草稿
- 结果面板的文本区已收敛成“分段切换 + 可编辑正文 + 独立翻译结果卡片”的结构；分段切换用原生 `Picker(.segmented)`，翻译结果显示在系统强调色描边卡片中并保持独立滚动
- 系统翻译在处理中英混排且夹带命令/路径的文本时，现已优先参考中英字符占比来判定源语言，避免整段被误判成英文后又“翻译回中文”
- 当前已记录一个新的编辑体验问题：在 `阅读优化` 中修改文本后切到 `原始文本` 仍会看到初始 OCR 内容，双草稿模型会带来模式割裂感；当前倾向「单一编辑源」，并计划与「功能 toolbar」重设计一并推进（详见 `docs/todo.md`）
- `DEBUG` 构建下可从菜单栏右键打开“UI 调试面板”，用假数据快速切换结果面板状态和布局
- 已新增正式结果页专用预览宿主 `ResultPopoverPreviewHost`，并将 Canvas 常见报错沉淀为 `docs/xcode-preview-playbook.md`
- 结果面板样式参数当前主要收在 `ResultPopoverContentView` 和 `ResultPopoverStyles` 附近，便于边看边直接微调
- 真实结果面板已先整合一处低风险改动：不同状态下显示不同 footer 操作，避免权限 / 错误态底部仍出现无关按钮
- 已修复一组 Swift 6 并发隔离兼容问题：`@MainActor` 类型不再通过默认参数直接实例化同属主线程隔离的依赖，避免 `swift build` 在 `TextGrabberKit` 编译阶段异常卡住
- 当前已重新验证 `swift build`、`swift build --target TextGrabberKit` 和 `swift test`
- 已提供本机一键打包链路：`scripts/package-local.command` 可双击生成 `.app` 和 zip，`scripts/install-local.sh` 可安装到 `/Applications`
- `scripts/build-app.sh` 已支持应用图标、版本/版权信息、中文屏幕录制权限文案、可选清理旧产物和 ad-hoc 签名
- 已新增 Codex app 内预览入口：`scripts/codex-run.sh` 会构建 debug 版真实菜单栏 `.app` 到本机临时目录并启动，`.codex/environments/environment.toml` 已将 `Run` action 指向该脚本
- 已为 `AppSettings` 补充快捷键默认值、持久化与旧配置迁移测试
- 已为 `KeyboardShortcut` 补充按键事件解析与纯修饰键判定测试
- 已补齐一套可用于后续 AI 协作和跨项目复用的文档体系
- 新线程默认只做轻量上下文恢复，`执行【上下文同步】` 主要用于跨设备接力、长时间中断后的完整恢复
- 已沉淀 `templates/collaboration-starter`，可直接复制到新项目作为协作初始化包
- `Pin`、自动聚焦、橙色光标、编辑后复制和截图取消不唤窗这几条真实交互已经验收通过
- 当前文本区与翻译结果块的基础结构已经按设计稿落地；后续更适合继续打磨真实运行态下的留白、滚动条可见性和 hover 反馈

## Development Focus

当前开发重点建议围绕以下方向展开：

1. 稳定真实工具交互体验  
   重点关注快捷键、截图取消、权限失败和结果面板行为。

2. 打磨结果面板细节  
   当前真实界面已回退到较稳定版本，适合直接在正式结果页视图中小步迭代，并通过专用预览宿主快速校对。

3. 补充测试与回归用例  
   已开始补充设置与快捷键相关单测，但真实交互流程仍主要依赖人工验证。

4. 优化真实用户翻译体验  
   重点是语言包引导、失败提示，以及后续在线翻译兜底。

5. 整理并消化真实用户反馈  
   当前已记录翻译下载体验、焦点管理、OCR 稳定性和窗口行为等问题，适合按影响面做一轮分级和排期。

6. 完善交付能力  
   当前已补齐本机一键 `.app` 打包和安装链路，下一步更适合继续完善正式签名、公证和公开分发体验。

7. 沉淀跨项目协作资产  
   当前仓库已经包含一套可复用的协作文档模板，后续可以继续按使用反馈迭代。

## Next Session

下一次会话优先可以从这些任务中选择：

1. 补充真实流程相关回归清单并执行一轮检查
2. 针对结果面板做一轮真实交互验证，重点确认自适应高度、菜单栏居中弹出和按钮反馈
3. 对照真实 OCR/翻译结果做一轮视觉回归，重点确认正文区和翻译卡片在长短文本下的留白、滚动和分隔线表现
4. 为设置与快捷键行为增加更多测试覆盖
5. 为翻译能力预留可替换的服务接口，评估后续接入 AI 模型
6. 为真实用户设计翻译资源未就绪时的安装引导或在线回退方案
7. 梳理最新记录的 bug / 优化 / 想法，确定优先处理的真实用户反馈
8. 评估登录启动和分发方案
9. 补充 Developer ID 签名 / notarization 流程，完成正式分发准备
10. 推进结果面板「功能 toolbar」重设计（统一排版切换 / 翻译 / 拷贝 / 搜索 + 新增选词大爆炸，连带收敛双草稿模型）；已定决策与未决分叉见 `docs/todo.md`

## Key Files

- `Package.swift`  
  定义 `TextGrabberKit` 与 `TextGrabber` 两个主要产物。

- `scripts/build-app.sh`  
  将 `TextGrabber` 可执行产物封装成 `.app`，补齐 `Info.plist`、应用图标、Swift 运行库和签名。

- `scripts/package-local.command`  
  Finder 双击入口，用于清理旧产物并一键生成本机 `.app` 与 zip。

- `scripts/install-local.sh`  
  将打包产物安装到 `/Applications/TextGrabber.app`，可选安装后启动。

- `scripts/codex-run.sh`  
  Codex 预览入口，负责停止旧进程、调用 `scripts/build-app.sh --configuration debug` 构建临时 `.app`，再启动真实菜单栏应用；支持 `--verify`、`--logs`、`--telemetry` 和 `--debug`。

- `.codex/environments/environment.toml`  
  Codex app Run action 配置，指向 `./scripts/codex-run.sh`。

- `docs/packaging.md`  
  本机打包、安装、验证和 iCloud Drive 扩展属性注意事项的操作指南。

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

- `Sources/TextGrabberKit/UI/ResultPopoverDebugWindowController.swift`  
  `DEBUG` 构建下的 UI 调试面板入口，用假数据预览结果面板状态。

- `Sources/TextGrabberKit/UI/ResultPopoverPreviewHost.swift`  
  正式结果页专用预览宿主文件，建议优先在该文件中打开 Canvas，降低 scheme 漂移引发的报错概率。

- `Sources/TextGrabberKit/UI/ResultPopoverStyles.swift`  
  面板布局常量、玻璃效果和按钮样式。

- `Sources/TextGrabberKit/UI/SettingsView.swift`  
  快捷键设置界面。

- `Tests/TextGrabberTests/SelectionSessionTests.swift`  
  当前已有的基础测试，主要覆盖快捷键显示逻辑。

- `templates/collaboration-starter/`  
  可复制到其他仓库的协作文档初始化包。

- `docs/xcode-preview-playbook.md`  
  Xcode Canvas 预览稳定流程与常见报错排障手册，遇到预览异常优先按此文档处理。
