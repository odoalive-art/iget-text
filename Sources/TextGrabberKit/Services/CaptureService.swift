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

enum CaptureResultClassifier {
    static func classify(
        terminationStatus: Int32,
        fileExists: Bool,
        fileSize: UInt64,
        hasImage: Bool
    ) -> Result<Void, CaptureError> {
        if terminationStatus != 0 {
            return .failure(.cancelled)
        }

        if hasImage {
            return .success(())
        }

        if !fileExists || fileSize == 0 {
            return .failure(.cancelled)
        }

        return .failure(.imageUnavailable)
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
                let fileExists = FileManager.default.fileExists(atPath: temporaryURL.path)
                let fileSize = (try? temporaryURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(UInt64.init) ?? 0
                let image = NSImage(contentsOf: temporaryURL)?
                    .cgImage(forProposedRect: nil, context: nil, hints: nil)

                Task { @MainActor [weak self] in
                    if self?.interactiveCaptureProcess === process {
                        self?.interactiveCaptureProcess = nil
                    }

                    switch CaptureResultClassifier.classify(
                    terminationStatus: terminationStatus,
                    fileExists: fileExists,
                    fileSize: fileSize,
                    hasImage: image != nil
                    ) {
                    case .success:
                        guard let image else {
                            continuation.resume(throwing: CaptureError.imageUnavailable)
                            return
                        }
                        continuation.resume(returning: image)
                    case let .failure(error):
                        continuation.resume(throwing: error)
                        return
                    }
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
