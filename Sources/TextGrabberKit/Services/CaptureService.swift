import AppKit
import Foundation

enum CaptureError: LocalizedError, Equatable {
    case permissionDenied
    case displayNotFound
    case imageUnavailable
    case cancelled

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "没有拿到屏幕录制权限。"
        case .displayNotFound:
            "未找到对应的显示器内容。"
        case .imageUnavailable:
            "截图失败，请重试。"
        case .cancelled:
            "已取消截图。"
        }
    }
}

@MainActor
final class CaptureService {
    private var interactiveCaptureProcess: Process?

    func ensureScreenCapturePermission() -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        }

        return CGRequestScreenCaptureAccess()
    }

    func openScreenRecordingPreferences() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    func captureInteractiveSelection() async throws -> CGImage {
        guard CGPreflightScreenCaptureAccess() else {
            throw CaptureError.permissionDenied
        }

        let temporaryURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("textgrabber-\(UUID().uuidString).png")

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-i", "-x", temporaryURL.path]
            process.terminationHandler = { [weak self] process in
                defer {
                    try? FileManager.default.removeItem(at: temporaryURL)
                }

                let terminationStatus = process.terminationStatus
                let image = NSImage(contentsOf: temporaryURL)?
                    .cgImage(forProposedRect: nil, context: nil, hints: nil)

                Task { @MainActor [weak self] in
                    if self?.interactiveCaptureProcess === process {
                        self?.interactiveCaptureProcess = nil
                    }

                    if terminationStatus != 0 {
                        continuation.resume(throwing: CaptureError.cancelled)
                        return
                    }

                    guard let image else {
                        continuation.resume(throwing: CaptureError.imageUnavailable)
                        return
                    }

                    continuation.resume(returning: image)
                }
            }

            do {
                try process.run()
                interactiveCaptureProcess = process
            } catch {
                try? FileManager.default.removeItem(at: temporaryURL)
                continuation.resume(throwing: error)
            }
        }
    }

    func cancelInteractiveSelection() {
        interactiveCaptureProcess?.interrupt()
    }
}
