import Foundation

enum AIProvider: String, Codable, CaseIterable { case ollama, openai }

struct AppSettings: Codable, Equatable {
    var enhancementEnabled: Bool
    var aiProvider: AIProvider
    var ollamaModel: String
    var openAIModel: String

    static let `default` = AppSettings(
        enhancementEnabled: true,
        aiProvider: .ollama,
        ollamaModel: "qwen2.5:7b-instruct",
        openAIModel: "gpt-4o-mini"
    )
}
