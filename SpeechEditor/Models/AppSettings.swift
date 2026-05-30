import Foundation

enum AIProvider: String, Codable, CaseIterable { case ollama, openai }

struct AppSettings: Codable, Equatable {
    var enhancementEnabled: Bool
    var aiProvider: AIProvider
    var modelName: String
    var ollamaModel: String
    var openAIModel: String

    static let `default` = AppSettings(
        enhancementEnabled: true,
        aiProvider: .ollama,
        modelName: "ggml-small.en",
        ollamaModel: "qwen2.5:7b-instruct",
        openAIModel: "gpt-4o-mini"
    )
}
