# TextGrabber

一个 macOS 菜单栏截图 OCR 小工具。

## 当前能力

- 全局快捷键触发截图识别
- 调用系统原生截图交互完成区域框选
- 调用 Apple `Vision` 做本地中文/英文 OCR
- 识别结果通过状态栏浮窗展示，并支持截图与文本对照
- 支持复制、简单编辑、重新识别、系统/在线翻译，以及固定结果窗口继续跨应用对照
- 识别正文默认使用阅读优化结果，可还原常见列表符号并过滤装饰性图标噪声
- 支持可选的“块编辑”：第一次按 `⌘A` 或 `⌃A` 选择当前段落，再按一次选择全文
- 单页设置面板可配置截图激活方式、快捷键、结果窗口位置、翻译来源和块编辑

## 运行与打包

### 命令行

```bash
swift run
```

在 Codex 或本地开发中，需要构建、签名并启动真实菜单栏应用时，推荐：

```bash
./scripts/codex-run.sh --verify
```

### 一键打包成本机应用

在 Finder 中双击：

```text
scripts/package-local.command
```

它会生成本机可双击启动的 `dist/TextGrabber.app`，同时产出 `dist/TextGrabber-0.1.0-macos.zip`，结束后自动打开 `dist/` 文件夹。

也可以在终端中执行：

```bash
make package
```

### 安装到 Applications

如果希望像普通 macOS 应用一样放进 `/Applications`：

```bash
scripts/install-local.sh
```

安装后立刻启动：

```bash
scripts/install-local.sh --launch
```

### 打包脚本参数

底层脚本仍可直接调用：

```bash
scripts/build-app.sh
scripts/build-app.sh --archive
scripts/build-app.sh --clean --archive
scripts/build-app.sh --version 0.1.0 --build-number 12
scripts/build-app.sh --sign-identity "Developer ID Application: Your Name (TEAMID)"
```

当前默认使用 ad-hoc 签名，适合本机自用。若要正式对外分发，后续仍需要补充 Developer ID 签名与 notarization 流程。

完整打包、安装和验证步骤见 `docs/packaging.md`。

## 翻译来源

设置面板「翻译」分区可选择翻译来源：

- **自动**（默认）：优先走「快捷指令」调用 Apple 在线翻译，未安装或失败/超时时自动回退系统（设备端）翻译。
- **仅系统翻译**：只用系统设备端翻译，本地不出网。
- **Apple 在线翻译（快捷指令）**：始终走快捷指令。

其中「快捷指令」方案借道 macOS「快捷指令」App 调用系统翻译（App 无法直接调用 Apple 在线翻译服务器）。首次使用需：

1. 在设置的翻译分区点「获取快捷指令」，导入名为 `TextGrabber Translate` 的快捷指令（内含中↔英双向判断）。
2. 在系统设置关闭「设备端模式」，快捷指令才会走 Apple 在线翻译（更准）；不关则为离线翻译。

> 首次翻译可能有数十秒冷启动（快捷指令运行时预热），之后每次约 0.3 秒。

### 自定义 HTTP 在线 provider（进阶）

除快捷指令外，也可注入环境变量接入自建/兼容的 HTTP 翻译服务：

```bash
export TEXTGRABBER_TRANSLATION_API_URL="https://your-translation-service.example.com/translate"
export TEXTGRABBER_TRANSLATION_API_KEY="your-token"
export TEXTGRABBER_TRANSLATION_API_MODEL="optional-model-name"
swift run
```

请求体默认发送：

```json
{
  "text": "待翻译文本",
  "sourceLanguage": "zh-Hans",
  "targetLanguage": "en",
  "model": "optional-model-name"
}
```

返回体兼容以下任一字段：

```json
{ "translatedText": "..." }
```

```json
{ "translation": "..." }
```

```json
{ "text": "..." }
```

### Xcode

直接在 Xcode 中打开本目录下的 `Package.swift` 即可运行。

## 首次使用

首次触发截图识别时，系统会要求授予“屏幕录制”权限。

路径：

`系统设置 -> 隐私与安全性 -> 屏幕录制`

## 默认快捷键

默认值是 `^⌥`，可以在设置面板中修改。

如果使用纯修饰键组合，系统还需要为应用开启“辅助功能”权限。
