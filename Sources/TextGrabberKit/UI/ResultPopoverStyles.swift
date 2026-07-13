import AppKit
import SwiftUI

enum ResultPopoverLayout {
    static let width: CGFloat = 400
    static let height: CGFloat = 483
    static let compactHeight: CGFloat = 360
    static let cornerRadius: CGFloat = 24
    static let contentCardCornerRadius: CGFloat = 12
    static let headerHeight: CGFloat = 48
    static let horizontalInset: CGFloat = 14
    static let headerTrailingInset: CGFloat = horizontalInset
    static let previewCornerRadius: CGFloat = 12
    static let contentCardHeight: CGFloat = 200
    static let topContentPadding: CGFloat = 0
    static let bottomContentPadding: CGFloat = 12
    static let sectionSpacing: CGFloat = 10
    static let footerHeight: CGFloat = 32
    static let previewVerticalPadding: CGFloat = 0
    static let previewWidthRatio: CGFloat = 1.0
    static let previewMaxHeight: CGFloat = 180
    static let previewPlaceholderHeight: CGFloat = 110
    static let contentCardTopPadding: CGFloat = 10
    static let contentCardBottomPadding: CGFloat = 10
    static let contentCardInnerHorizontalPadding: CGFloat = 10
    static let resultTextFontSize: CGFloat = 13
    static let translationTextFontSize: CGFloat = 13
    static let resultLineHeight: CGFloat = 19
    static let translationLineHeight: CGFloat = 16
    static let minimumTextLines: CGFloat = 8
    static let maximumTextLines: CGFloat = 24
    static let minimumTranslationLines: CGFloat = 3
    static let maximumTranslationLines: CGFloat = 12
    static let translationCardSpacing: CGFloat = 10
    static let translationCardTopPadding: CGFloat = 10
    static let translationCardBottomPadding: CGFloat = 10
    static let translationCardHorizontalPadding: CGFloat = 10
    static let translationHeaderHeight: CGFloat = 16
    static let bodyParagraphSpacing: CGFloat = 6
    static let readingOptimizedParagraphSpacing: CGFloat = 6
    static let translationParagraphSpacing: CGFloat = 6

    static var contentWidth: CGFloat {
        width - (horizontalInset * 2)
    }

    static var previewWidth: CGFloat {
        floor(contentWidth * previewWidthRatio)
    }

    static var textContentWidth: CGFloat {
        contentWidth - (contentCardInnerHorizontalPadding * 2)
    }

    static var translationTextWidth: CGFloat {
        textContentWidth -
            (translationCardHorizontalPadding * 2)
    }

    static func previewHeight(for image: NSImage?) -> CGFloat {
        guard let image, image.size.width > 0, image.size.height > 0 else {
            return previewPlaceholderHeight
        }

        return round((previewWidth * image.size.height) / image.size.width)
    }

    /// 预览视口高度：按自然宽高比高度，但封顶到 `previewMaxHeight`；
    /// 超出封顶的长截图会在视口内部纵向滚动，用于逐段比对识别准确性。
    static func previewViewportHeight(for image: NSImage?) -> CGFloat {
        guard let image, image.size.width > 0, image.size.height > 0 else {
            return previewPlaceholderHeight
        }

        return min(previewMaxHeight, previewHeight(for: image))
    }

    static func previewIsScrollable(for image: NSImage?) -> Bool {
        guard let image, image.size.width > 0, image.size.height > 0 else {
            return false
        }

        return previewHeight(for: image) > previewMaxHeight + 0.5
    }

    static func previewSectionHeight(for image: NSImage?) -> CGFloat {
        previewViewportHeight(for: image) + previewVerticalPadding
    }

    static func measuredLineCount(for text: String, width: CGFloat = textContentWidth) -> CGFloat {
        let measuredHeight = measuredTextHeight(for: text, width: width, fontSize: resultTextFontSize)
        return max(minimumTextLines, ceil(measuredHeight / resultLineHeight))
    }

    static func measuredTextHeight(
        for text: String,
        width: CGFloat,
        paragraphSpacing: CGFloat = 0,
        fontSize: CGFloat = translationTextFontSize
    ) -> CGFloat {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return minimumTextLines * resultLineHeight
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.paragraphSpacing = paragraphSpacing

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .regular),
            .paragraphStyle: paragraphStyle
        ]

        let rect = NSString(string: trimmed).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )

        return ceil(rect.height)
    }

    static func normalizedParagraphText(_ text: String) -> String {
        text.replacingOccurrences(of: "\n{2,}", with: "\n", options: .regularExpression)
    }

    static func paragraphDisplayLines(from text: String) -> [String] {
        normalizedParagraphText(text)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    static func resultTextHeight(for text: String, outputMode: OCRTextOutputMode) -> CGFloat {
        let measuredHeight: CGFloat
        switch outputMode {
        case .readingOptimized:
            measuredHeight = measuredTextHeight(
                for: normalizedParagraphText(text),
                width: textContentWidth,
                paragraphSpacing: readingOptimizedParagraphSpacing,
                fontSize: resultTextFontSize
            )
        case .sourceLayout:
            measuredHeight = measuredTextHeight(for: text, width: textContentWidth, fontSize: resultTextFontSize)
        }

        let minimumHeight = minimumTextLines * resultLineHeight
        let maximumHeight = maximumTextLines * resultLineHeight
        return min(maximumHeight, max(minimumHeight, measuredHeight))
    }

    static func visibleResultTextHeight(for text: String, outputMode: OCRTextOutputMode) -> CGFloat {
        let measuredHeight: CGFloat
        switch outputMode {
        case .readingOptimized:
            measuredHeight = measuredTextHeight(
                for: normalizedParagraphText(text),
                width: textContentWidth,
                paragraphSpacing: readingOptimizedParagraphSpacing,
                fontSize: resultTextFontSize
            )
        case .sourceLayout:
            measuredHeight = measuredTextHeight(for: text, width: textContentWidth, fontSize: resultTextFontSize)
        }

        let minimumHeight = minimumTextLines * resultLineHeight
        let maximumHeight = maximumTextLines * resultLineHeight
        return min(maximumHeight, max(minimumHeight, measuredHeight))
    }

    static func resultPrimaryCardHeight(for text: String, outputMode: OCRTextOutputMode = .readingOptimized) -> CGFloat {
        let textHeight = visibleResultTextHeight(for: text, outputMode: outputMode)
        return contentCardTopPadding +
            textHeight +
            contentCardBottomPadding
    }

    static func visibleTranslationTextHeight(for text: String?) -> CGFloat {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return 0
        }

        let measuredHeight = measuredTextHeight(
            for: normalizedParagraphText(text),
            width: translationTextWidth,
            paragraphSpacing: translationParagraphSpacing
        )
        let minimumHeight = minimumTranslationLines * translationLineHeight
        let maximumHeight = maximumTranslationLines * translationLineHeight
        let textHeight = min(maximumHeight, max(minimumHeight, measuredHeight))

        return textHeight
    }

    static func translationSectionHeight(for text: String?) -> CGFloat {
        let textHeight = visibleTranslationTextHeight(for: text)
        guard textHeight > 0 else {
            return 0
        }

        return translationCardTopPadding +
            translationHeaderHeight +
            translationCardSpacing +
            textHeight +
            translationCardBottomPadding
    }

    static func resultCardHeight(
        for text: String,
        translationText: String? = nil,
        showsTranslationPane: Bool = false,
        outputMode: OCRTextOutputMode = .readingOptimized
    ) -> CGFloat {
        let primaryCardHeight = resultPrimaryCardHeight(for: text, outputMode: outputMode)

        guard showsTranslationPane else {
            return primaryCardHeight
        }

        return primaryCardHeight +
            sectionSpacing +
            translationSectionHeight(for: translationText)
    }

    static func resultPanelHeight(
        text: String,
        translationText: String? = nil,
        showsTranslationPane: Bool = false,
        outputMode: OCRTextOutputMode = .readingOptimized,
        image: NSImage?,
        includePreview: Bool
    ) -> CGFloat {
        let previewSection = includePreview ? previewSectionHeight(for: image) + sectionSpacing : 0
        return headerHeight +
            topContentPadding +
            previewSection +
            resultCardHeight(
                for: text,
                translationText: translationText,
                showsTranslationPane: showsTranslationPane,
                outputMode: outputMode
            ) +
            sectionSpacing +
            footerHeight +
            bottomContentPadding
    }
}

/// 让无边框窗口能显示内容层的自定义投影，同时保持面板本身的定位不变。
enum ResultPopoverShadowCanvas {
    static let topInset: CGFloat = 36
    static let horizontalInset: CGFloat = 36
    static let bottomInset: CGFloat = 46

    static func size(for surfaceSize: NSSize) -> NSSize {
        NSSize(
            width: surfaceSize.width + horizontalInset * 2,
            height: surfaceSize.height + topInset + bottomInset
        )
    }

    static func frame(for surfaceFrame: NSRect) -> NSRect {
        NSRect(
            x: surfaceFrame.minX - horizontalInset,
            y: surfaceFrame.minY - bottomInset,
            width: surfaceFrame.width + horizontalInset * 2,
            height: surfaceFrame.height + topInset + bottomInset
        )
    }
}

struct LiquidGlassSurface<Content: View>: NSViewRepresentable {
    let cornerRadius: CGFloat
    let content: Content

    init(cornerRadius: CGFloat, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    func makeNSView(context: Context) -> LiquidGlassContainerView {
        let view = LiquidGlassContainerView(cornerRadius: cornerRadius)
        view.update(rootView: AnyView(content))
        return view
    }

    func updateNSView(_ nsView: LiquidGlassContainerView, context: Context) {
        nsView.cornerRadius = cornerRadius
        nsView.update(rootView: AnyView(content))
    }
}

final class LiquidGlassContainerView: NSView {
    private let hostingView = NSHostingView(rootView: AnyView(EmptyView()))
    private let effectView: NSView
    var cornerRadius: CGFloat {
        didSet {
            updateStyling()
        }
    }

    init(cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius

        if #available(macOS 26.0, *) {
            let glassView = NSGlassEffectView()
            glassView.style = .regular
            glassView.tintColor = nil
            effectView = glassView
        } else {
            let visualView = NSVisualEffectView()
            visualView.material = .popover
            visualView.blendingMode = .withinWindow
            visualView.state = .active
            effectView = visualView
        }

        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        effectView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(effectView)
        NSLayoutConstraint.activate([
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        if #available(macOS 26.0, *), let glassView = effectView as? NSGlassEffectView {
            glassView.contentView = hostingView
        } else {
            effectView.addSubview(hostingView)
            NSLayoutConstraint.activate([
                hostingView.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
                hostingView.topAnchor.constraint(equalTo: effectView.topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: effectView.bottomAnchor)
            ])
        }

        updateStyling()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(rootView: AnyView) {
        hostingView.rootView = rootView
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateStyling()
    }

    override func layout() {
        super.layout()
        updateShadowPath()
    }

    private func updateStyling() {
        wantsLayer = true
        layer?.cornerCurve = .continuous
        layer?.cornerRadius = cornerRadius
        layer?.masksToBounds = false
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.15
        layer?.shadowRadius = 10
        layer?.shadowOffset = CGSize(width: 0, height: -5)
        updateShadowPath()

        effectView.wantsLayer = true
        effectView.layer?.cornerCurve = .continuous
        effectView.layer?.cornerRadius = cornerRadius
        effectView.layer?.masksToBounds = true

        if #available(macOS 26.0, *), let glassView = effectView as? NSGlassEffectView {
            glassView.cornerRadius = cornerRadius
        }
    }

    private func updateShadowPath() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        layer?.shadowPath = CGPath(
            roundedRect: bounds,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
    }

}

extension View {
    @ViewBuilder
    func popoverSecondaryButtonStyle() -> some View {
        if #available(macOS 26.0, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    func popoverPrimaryButtonStyle() -> some View {
        if #available(macOS 26.0, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }
}
