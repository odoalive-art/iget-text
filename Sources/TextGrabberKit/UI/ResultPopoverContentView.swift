import AppKit
import SwiftUI

enum ResultPopoverDisplayState {
    case result
    case recognizing
    case permission
    case error
}

private enum ResultPopoverSectionStyle {
    static let cornerRadius: CGFloat = 14
}

struct ResultPopoverContentView: View {
    let displayState: ResultPopoverDisplayState
    let placementMode: ResultPanelPlacementMode
    @Binding var outputMode: OCRTextOutputMode
    @Binding var recognizedText: String
    let capturedPreviewImage: NSImage?
    let lastErrorMessage: String?
    let onRetry: () -> Void
    let onCopy: () -> Void
    let onShowSettings: () -> Void
    let onClose: () -> Void
    let onOpenScreenRecordingPreferences: () -> Void

    var body: some View {
        LiquidGlassSurface(cornerRadius: ResultPopoverLayout.cornerRadius) {
            VStack(alignment: .leading, spacing: 16) {
                header

                Group {
                    switch displayState {
                    case .result:
                        resultEditor
                    case .recognizing:
                        recognizingView
                    case .permission:
                        permissionView
                    case .error:
                        errorView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                footer
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .overlay(
            RoundedRectangle(cornerRadius: ResultPopoverLayout.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.8), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "text.viewfinder")
                .font(.system(size: 20))
                .foregroundStyle(Color.accentColor)

            Text("截图文本识别")
                .font(.title3.weight(.semibold))

            Spacer()

            Button {
                onShowSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.body.weight(.medium))
            }
            .popoverSecondaryButtonStyle()
        }
    }

    private var resultEditor: some View {
        Group {
            if usesCompactTextLayout {
                textPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 18) {
                    previewPane
                        .frame(maxWidth: .infinity)

                    textPane
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private var recognizingView: some View {
        VStack(spacing: 18) {
            previewPane
                .frame(maxWidth: .infinity)

            sectionCard(title: "识别状态") {
                VStack(alignment: .leading, spacing: 12) {
                    ProgressView("正在识别所选区域中的文本...")
                        .controlSize(.small)
                    Text("识别完成后会自动显示文本结果，你可以直接复制或编辑。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var permissionView: some View {
        sectionCard(title: "权限提示") {
            VStack(alignment: .leading, spacing: 12) {
                Text("需要屏幕录制权限")
                    .font(.title3.weight(.semibold))
                Text("请在“系统设置 -> 隐私与安全性 -> 屏幕录制”中允许本应用，然后重新触发快捷键。")
                    .foregroundStyle(.secondary)
                HStack {
                    Button("打开系统设置") {
                        onOpenScreenRecordingPreferences()
                    }
                    Button("关闭") {
                        onClose()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var errorView: some View {
        sectionCard(title: "错误信息") {
            VStack(alignment: .leading, spacing: 12) {
                Text("本次识别没有成功")
                    .font(.title3.weight(.semibold))
                Text(lastErrorMessage ?? "请重新尝试。")
                    .foregroundStyle(.secondary)
                HStack {
                    Button("重新识别") {
                        onRetry()
                    }
                    Button("关闭") {
                        onClose()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var footer: some View {
        HStack {
            Button("重新识别") {
                onRetry()
            }
            .disabled(displayState == .recognizing)
            .popoverSecondaryButtonStyle()

            Spacer()

            Button("复制文本") {
                onCopy()
            }
            .disabled(recognizedText.isEmpty)
            .popoverPrimaryButtonStyle()

            Button("关闭") {
                onClose()
            }
            .popoverSecondaryButtonStyle()
        }
    }

    private var previewPane: some View {
        sectionCard(title: "截图预览", contentPadding: 0) {
            ZStack {
                if let image = capturedPreviewImage {
                    GeometryReader { proxy in
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .frame(
                                width: proxy.size.width - 16,
                                height: proxy.size.height - 16,
                                alignment: .center
                            )
                            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    }
                } else {
                    ContentUnavailableView(
                        "暂无截图",
                        systemImage: "photo",
                        description: Text("完成一次截图后，这里会显示实际识别区域。")
                    )
                    .padding(.horizontal, 12)
                    .font(.subheadline)
                }
            }
            .frame(height: 210)
        }
    }

    private var textPane: some View {
        sectionCard(title: "识别文本", contentPadding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Picker("输出模式", selection: $outputMode) {
                    ForEach(OCRTextOutputMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(12)

                Divider()

                TextEditor(text: $recognizedText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(12)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var usesCompactTextLayout: Bool {
        placementMode == .followMouse && displayState == .result
    }

    private func sectionCard<Content: View>(
        title: String,
        contentPadding: CGFloat = 12,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            content()
                .padding(contentPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(sectionBackground)
        }
    }

    private var sectionBackground: some View {
        RoundedRectangle(cornerRadius: ResultPopoverSectionStyle.cornerRadius, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: ResultPopoverSectionStyle.cornerRadius, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
            )
    }
}
