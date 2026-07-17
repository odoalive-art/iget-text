import Foundation

/// 通过 macOS 「快捷指令」命令行(`shortcuts run`)调用一个用户安装的翻译快捷指令,
/// 借道系统翻译获得(在关闭「设备端模式」时的)Apple 在线翻译结果。
///
/// 快捷指令契约:接收文本输入 → 翻译 → 输出翻译后的文本。方向判断放在快捷指令内部。
struct ShortcutsTranslationService: Sendable {
    enum ServiceError: LocalizedError {
        case notFound(String)
        case timedOut
        case emptyOutput
        case failed(String)

        var errorDescription: String? {
            switch self {
            case let .notFound(name):
                return "未找到名为「\(name)」的快捷指令,请在「快捷指令」App 中创建或检查设置里的名称。"
            case .timedOut:
                return "快捷指令翻译超时,首次调用可能较慢,请重试一次。"
            case .emptyOutput:
                return "快捷指令没有返回翻译结果,请检查它是否输出了翻译后的文本。"
            case let .failed(message):
                return message.isEmpty ? "快捷指令翻译失败,请重试。" : message
            }
        }
    }

    static let executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")

    let shortcutName: String
    /// 首次调用会触发快捷指令运行时冷启动(可能数十秒),超时给足余量。
    var timeout: Duration = .seconds(60)

    /// 查询当前已安装的快捷指令名称(用于设置页展示"已安装/未安装")。
    static func installedShortcutNames() -> [String] {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = ["list"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard let output = String(data: data, encoding: .utf8) else { return [] }
        return output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    func isInstalled() -> Bool {
        Self.installedShortcutNames().contains(shortcutName)
    }

    func translate(_ text: String) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ServiceError.emptyOutput
        }

        // 提前判断是否安装,给出更清晰的错误而不是让 `shortcuts run` 失败。
        guard isInstalled() else {
            throw ServiceError.notFound(shortcutName)
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("textgrabber-shortcut-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let inputURL = directory.appendingPathComponent("input.txt")
        let outputURL = directory.appendingPathComponent("output.txt")
        try trimmed.write(to: inputURL, atomically: true, encoding: .utf8)

        try await runShortcut(inputURL: inputURL, outputURL: outputURL)

        guard let data = try? Data(contentsOf: outputURL),
              let output = String(data: data, encoding: .utf8) else {
            throw ServiceError.emptyOutput
        }

        let result = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else {
            throw ServiceError.emptyOutput
        }
        return result
    }

    private func runShortcut(inputURL: URL, outputURL: URL) async throws {
        let process = Process()
        process.executableURL = Self.executableURL
        process.arguments = [
            "run", shortcutName,
            "-i", inputURL.path,
            "-o", outputURL.path
        ]
        let errorPipe = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errorPipe

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await Self.waitForExit(of: process, errorPipe: errorPipe)
            }
            group.addTask { [timeout] in
                try await Task.sleep(for: timeout)
                if process.isRunning {
                    process.terminate()
                }
                throw ServiceError.timedOut
            }

            // 任一任务先返回即代表结果确定(正常退出或超时),取消其余任务。
            defer { group.cancelAll() }
            try await group.next()
        }
    }

    private static func waitForExit(of process: Process, errorPipe: Pipe) async throws {
        try process.run()

        await withCheckedContinuation { continuation in
            process.terminationHandler = { _ in
                continuation.resume()
            }
        }

        guard process.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw ServiceError.failed(message)
        }
    }
}
