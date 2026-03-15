import Foundation
import NaturalLanguage
#if canImport(Translation)
import Translation
#endif

struct TranslationPlan: Sendable, Equatable {
    let sourceText: String
    let sourceLanguageIdentifier: String?
    let targetLanguageIdentifier: String

#if canImport(Translation)
    @available(macOS 15.0, *)
    var sourceLanguage: Locale.Language? {
        sourceLanguageIdentifier.map(Locale.Language.init(identifier:))
    }

    @available(macOS 15.0, *)
    var targetLanguage: Locale.Language {
        Locale.Language(identifier: targetLanguageIdentifier)
    }
#endif
}

@MainActor
protocol TranslationServicing {
    func validationMessage(for text: String) -> String?
    func makePlan(for text: String) -> TranslationPlan?
    func timeoutMessage(for plan: TranslationPlan) -> String
    func message(for error: Error, plan: TranslationPlan) -> String
}

@MainActor
struct TranslationServiceResolver {
    private let systemService = SystemTranslationService()
    private let onlineService = OnlineTranslationService()

    func validationMessage(for text: String, provider: TranslationProviderMode) -> String? {
        switch provider {
        case .automatic:
            if onlineService != nil {
                return nil
            }
            return systemService.validationMessage(for: text)
        case .systemOnly:
            return systemService.validationMessage(for: text)
        }
    }

    func resolve(for text: String, provider: TranslationProviderMode) -> TranslationExecution? {
        switch provider {
        case .automatic:
            if let onlineService, let plan = onlineService.makePlan(for: text) {
                return .online(plan: plan, service: onlineService)
            }

            guard let plan = systemService.makePlan(for: text) else {
                return nil
            }

            return .system(plan: plan, service: systemService)
        case .systemOnly:
            guard let plan = systemService.makePlan(for: text) else {
                return nil
            }

            return .system(plan: plan, service: systemService)
        }
    }
}

enum TranslationExecution {
    case system(plan: TranslationPlan, service: SystemTranslationService)
    case online(plan: TranslationPlan, service: OnlineTranslationService)
}

@MainActor
struct SystemTranslationService: TranslationServicing {
    func validationMessage(for text: String) -> String? {
        let sourceText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sourceText.isEmpty, sourceText != "未识别到文本" else {
            return nil
        }

        guard let sourceLanguageIdentifier = detectSourceLanguageIdentifier(for: sourceText) else {
            return nil
        }

        guard isSupportedSourceLanguage(sourceLanguageIdentifier) else {
            return "当前版本的系统翻译优先支持中文和英文文本，其他语言暂不自动翻译。"
        }

        return nil
    }

    func makePlan(for text: String) -> TranslationPlan? {
        let sourceText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sourceText.isEmpty, sourceText != "未识别到文本" else {
            return nil
        }

        let sourceLanguageIdentifier = detectSourceLanguageIdentifier(for: sourceText)
        guard sourceLanguageIdentifier == nil || isSupportedSourceLanguage(sourceLanguageIdentifier ?? "") else {
            return nil
        }
        let targetLanguageIdentifier = targetLanguageIdentifier(for: sourceLanguageIdentifier)

        return TranslationPlan(
            sourceText: sourceText,
            sourceLanguageIdentifier: sourceLanguageIdentifier,
            targetLanguageIdentifier: targetLanguageIdentifier
        )
    }

    func timeoutMessage(for plan: TranslationPlan) -> String {
        "系统翻译准备时间较长，可能需要下载语言包，请稍后重试。"
    }

    func message(for error: Error, plan _: TranslationPlan) -> String {
        if error is CancellationError {
            return "系统翻译已取消，请重试一次。"
        }

#if canImport(Translation)
        if #available(macOS 15.0, *) {
            if TranslationError.unsupportedSourceLanguage ~= error {
                return "当前文本语言暂不支持系统翻译。"
            }

            if TranslationError.unsupportedTargetLanguage ~= error {
                return "当前目标语言暂不支持系统翻译。"
            }

            if TranslationError.unsupportedLanguagePairing ~= error {
                return "当前语言组合暂不支持系统翻译。"
            }

            if TranslationError.unableToIdentifyLanguage ~= error {
                return "系统无法识别当前文本语言，请换一段更完整的文本重试。"
            }

            if TranslationError.nothingToTranslate ~= error {
                return "当前没有可翻译的文本。"
            }

            if #available(macOS 26.0, *), TranslationError.notInstalled ~= error {
                return "系统翻译语言资源未安装，请先完成下载后再试。"
            }
        }
#endif

        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if description.isEmpty {
            return "系统翻译暂时不可用，请稍后重试。"
        }

        return description
    }

    private func detectSourceLanguageIdentifier(for text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        guard let dominantLanguage = recognizer.dominantLanguage?.rawValue, !dominantLanguage.isEmpty else {
            return nil
        }

        return dominantLanguage
    }

    private func targetLanguageIdentifier(for sourceLanguageIdentifier: String?) -> String {
        if sourceLanguageIdentifier?.hasPrefix("zh") == true {
            return "en"
        }

        return "zh-Hans"
    }

    private func isSupportedSourceLanguage(_ identifier: String) -> Bool {
        identifier.hasPrefix("zh") || identifier.hasPrefix("en")
    }
}

@MainActor
struct OnlineTranslationService: TranslationServicing {
    struct Configuration {
        let endpointURL: URL
        let apiKey: String?
        let model: String?
    }

    private let configuration: Configuration
    private let planner = SystemTranslationService()

    init?(processInfo: ProcessInfo = .processInfo) {
        let environment = processInfo.environment
        guard let rawURL = environment["TEXTGRABBER_TRANSLATION_API_URL"],
              let endpointURL = URL(string: rawURL) else {
            return nil
        }

        configuration = Configuration(
            endpointURL: endpointURL,
            apiKey: environment["TEXTGRABBER_TRANSLATION_API_KEY"],
            model: environment["TEXTGRABBER_TRANSLATION_API_MODEL"]
        )
    }

    func makePlan(for text: String) -> TranslationPlan? {
        planner.makePlan(for: text)
    }

    func validationMessage(for _: String) -> String? {
        nil
    }

    func timeoutMessage(for _: TranslationPlan) -> String {
        "在线翻译响应超时，请检查网络后重试。"
    }

    func message(for error: Error, plan _: TranslationPlan) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "当前网络不可用，已回退到系统翻译或请稍后重试。"
            case .timedOut:
                return "在线翻译请求超时，请稍后重试。"
            default:
                break
            }
        }

        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if description.isEmpty {
            return "在线翻译暂时不可用，请稍后重试。"
        }

        return description
    }

    func translate(_ plan: TranslationPlan) async throws -> String {
        var request = URLRequest(url: configuration.endpointURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        if let apiKey = configuration.apiKey, !apiKey.isEmpty {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONEncoder().encode(
            RequestBody(
                text: plan.sourceText,
                sourceLanguage: plan.sourceLanguageIdentifier,
                targetLanguage: plan.targetLanguageIdentifier,
                model: configuration.model
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let errorMessage = parseErrorMessage(from: data) ?? "在线翻译请求失败（\(httpResponse.statusCode)）。"
            throw NSError(domain: "OnlineTranslationService", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: errorMessage
            ])
        }

        let payload = try JSONDecoder().decode(ResponseBody.self, from: data)
        let text = payload.translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw NSError(domain: "OnlineTranslationService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "在线翻译未返回内容，请检查服务端响应格式。"
            ])
        }

        return text
    }

    private func parseErrorMessage(from data: Data) -> String? {
        if let payload = try? JSONDecoder().decode(ErrorBody.self, from: data) {
            return payload.resolvedMessage
        }

        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }
}

private struct RequestBody: Encodable {
    let text: String
    let sourceLanguage: String?
    let targetLanguage: String
    let model: String?
}

private struct ResponseBody: Decodable {
    let translatedText: String

    private enum CodingKeys: String, CodingKey {
        case translatedText
        case translation
        case text
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let translatedText = try container.decodeIfPresent(String.self, forKey: .translatedText) {
            self.translatedText = translatedText
            return
        }

        if let translatedText = try container.decodeIfPresent(String.self, forKey: .translation) {
            self.translatedText = translatedText
            return
        }

        if let translatedText = try container.decodeIfPresent(String.self, forKey: .text) {
            self.translatedText = translatedText
            return
        }

        throw DecodingError.dataCorruptedError(forKey: .translatedText, in: container, debugDescription: "Missing translated text field.")
    }
}

private struct ErrorBody: Decodable {
    let message: String?
    let error: String?

    var resolvedMessage: String? {
        message ?? error
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
