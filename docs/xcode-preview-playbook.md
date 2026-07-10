# Xcode Canvas Preview Playbook

## 适用范围

当在 Xcode 预览正式结果页（`ResultPopoverContentView`）时，出现以下报错：

- `Cannot preview in this file`
- `Active scheme does not build this file`
- `... not found in any targets`
- `The executable target "TextGrabber" needs ... ENABLE_DEBUG_DYLIB ...`

## 稳定流程（默认执行）

1. 打开整个 Swift Package（`Package.swift`），不要只打开单个 `.swift` 文件。
2. 打开专用预览宿主文件：`Sources/TextGrabberKit/UI/ResultPopoverPreviewHost.swift`。
3. 将 Scheme 切到 `TextGrabberKit`（不要用可执行 Scheme `TextGrabber` 做 Canvas）。
4. 运行目标使用 `My Mac`。
5. 先 `Cmd+B` 构建一次，再执行 `Editor > Canvas > Resume`。

## 常见报错与处理

### 1) `Active scheme does not build this file`

原因：当前 Scheme 与文件所属 target 不一致。  
处理：切回 `TextGrabberKit`，然后 `Cmd+B` 一次再 `Resume`。

### 2) `... not found in any targets`

原因：Xcode 当前只把文件当普通文本，或索引状态漂移。  
处理：

1. 重新从 `Package.swift` 打开仓库。
2. 回到 `ResultPopoverPreviewHost.swift`。
3. `Product > Clean Build Folder` 后再 `Resume`。

### 3) `The executable target "TextGrabber" needs ENABLE_DEBUG_DYLIB ...`

原因：当前在可执行 target 上直接做 Canvas 预览。  
处理：不要用 `TextGrabber` scheme 做预览，改用 `TextGrabberKit`。

## 一键预热（可选）

在终端执行：

```bash
swift build --target TextGrabberKit
```

用于提前稳定索引和模块编译，再回 Xcode 打开 Canvas。

## 维护约定

- 正式结果页预览统一在 `ResultPopoverPreviewHost.swift` 完成。
- 业务大文件（如 `ResultPopoverContentView.swift`）尽量不直接作为第一预览入口。
- 若再次出现同类问题，优先更新本文件，而不是仅在会话中口头说明。
