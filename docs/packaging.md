# Packaging Guide

## 目标

当前打包流程面向本机自用：

- 产出可双击启动的 `TextGrabber.app`
- 可生成 zip 归档，便于保存或迁移
- 可安装到 `/Applications/TextGrabber.app`
- 默认使用 ad-hoc 签名，不做 Developer ID 签名或 notarization

正式对外分发仍需要后续补充 Developer ID 签名、公证和更完整的安装说明。

## 推荐流程

### 1. 一键打包

在 Finder 中双击：

```text
scripts/package-local.command
```

该入口会执行：

```bash
scripts/build-app.sh --clean --archive
```

完成后会打开 `dist/`，其中主要产物是：

- `dist/TextGrabber.app`
- `dist/TextGrabber-0.1.0-macos.zip`

### 2. 安装到 Applications

在终端执行：

```bash
scripts/install-local.sh
```

安装后立即启动：

```bash
scripts/install-local.sh --launch
```

安装后的日常使用版本是：

```text
/Applications/TextGrabber.app
```

如果 Finder 中同时看到 `dist/TextGrabber.app` 和 `/Applications/TextGrabber.app`，日常使用时保留 `/Applications/TextGrabber.app`；`dist/` 里的 app 只是打包产物。

## 命令速查

```bash
make app
make package
make install
make icon
```

等价底层命令：

```bash
scripts/build-app.sh
scripts/build-app.sh --clean --archive
scripts/install-local.sh
scripts/generate-app-icon.swift
```

常用版本参数：

```bash
scripts/build-app.sh --version 0.1.0 --build-number 12
```

如需指定签名身份：

```bash
scripts/build-app.sh --sign-identity "Developer ID Application: Your Name (TEAMID)"
```

当前未接入 notarization，因此即使指定 Developer ID，也还不是完整公开分发流程。

## 验证清单

基础验证：

```bash
swift test
scripts/build-app.sh --clean --archive
plutil -lint dist/TextGrabber.app/Contents/Info.plist
```

安装后签名验证：

```bash
scripts/install-local.sh
codesign --verify --deep --strict /Applications/TextGrabber.app
```

zip 验证：

```bash
tmpdir="$(mktemp -d)"
ditto -x -k dist/TextGrabber-0.1.0-macos.zip "$tmpdir"
codesign --verify --deep --strict "$tmpdir/TextGrabber.app"
rm -rf "$tmpdir"
```

## 当前产物内容

`scripts/build-app.sh` 会写入或复制：

- `Contents/Info.plist`
- `Contents/PkgInfo`
- `Contents/MacOS/TextGrabber`
- `Contents/Resources/TextGrabber.icns`
- `Contents/Frameworks/` 中的 Swift 运行库

关键 bundle 信息包括：

- `CFBundleIdentifier`: `com.textgrabber.app`
- `CFBundleIconFile`: `TextGrabber`
- `LSUIElement`: `true`
- `NSScreenCaptureUsageDescription`: 中文屏幕录制权限说明

## 已知注意事项

- 仓库位于 iCloud Drive 时，`dist/TextGrabber.app` 可能被文件提供器加上扩展属性，导致对 `dist/` 内 app 直接执行严格 codesign 校验时报 `resource fork, Finder information, or similar detritus not allowed`。
- `scripts/install-local.sh` 会在安装到 `/Applications` 后清理扩展属性；安装后的 `/Applications/TextGrabber.app` 应作为最终本机使用版本。
- `dist/TextGrabber-0.1.0-macos.zip` 解压后的 app 也应通过严格 codesign 校验。
- 如果改了图标生成逻辑，先运行 `make icon`，再运行 `make package`。

## 后续正式分发

公开分发前仍需补齐：

- Developer ID Application 证书配置
- `notarytool` 上传与 stapling
- 正式版本号策略
- 外部机器首次打开验证
- 面向用户的安装与权限说明
