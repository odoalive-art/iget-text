# TextGrabber

一个 macOS 菜单栏截图 OCR 小工具。

## 当前能力

- 全局快捷键触发截图识别
- 调用系统原生截图交互完成区域框选
- 调用 Apple `Vision` 做本地中文/英文 OCR
- 识别结果通过状态栏浮窗展示，并支持截图与文本对照
- 支持复制、简单编辑、重新识别，以及固定结果窗口继续跨应用对照
- 设置面板支持修改快捷键

## 运行方式

### 命令行

```bash
swift run
```

### 打包成应用

```bash
scripts/build-app.sh
```

默认会在 `dist/TextGrabber.app` 产出可双击启动的 macOS 应用包，并自动嵌入 Swift 运行库和做一次 ad-hoc 签名。

如果希望顺手产出一个压缩包：

```bash
scripts/build-app.sh --archive
```

常用可选参数：

```bash
scripts/build-app.sh --version 0.1.0 --build-number 12
scripts/build-app.sh --sign-identity "Developer ID Application: Your Name (TEAMID)"
```

当前脚本已经能完成本地分发所需的 `.app` 打包；如果要正式对外分发，下一步仍建议补充 Developer ID 签名与 notarization 流程。

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
