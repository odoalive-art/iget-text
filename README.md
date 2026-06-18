# TextGrabber

一个 macOS 菜单栏截图 OCR 小工具。

## 当前能力

- 全局快捷键触发截图识别
- 调用系统原生截图交互完成区域框选
- 调用 Apple `Vision` 做本地中文/英文 OCR
- 识别结果通过状态栏浮窗展示，并支持截图与文本对照
- 支持复制、简单编辑、重新识别，以及固定结果窗口继续跨应用对照
- 设置面板支持修改快捷键

## 运行与打包

### 命令行

```bash
swift run
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

如需启用在线翻译 provider，可在运行前注入以下环境变量：

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
