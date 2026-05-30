import Foundation

final class OpenAIEnhancer: TextEnhancer {
    typealias Transport = (URLRequest) async throws -> (Data, URLResponse)
    private let apiKey: String
    private let model: String
    private let translationLanguage: String
    private let transport: Transport

    init(apiKey: String, model: String, translationLanguage: String = "Spanish",
         transport: @escaping Transport = { try await URLSession.shared.data(for: $0) }) {
        self.apiKey = apiKey; self.model = model
        self.translationLanguage = translationLanguage; self.transport = transport
    }

    func clean(_ text: String, vocabulary: [String]) async throws -> String {
        try await chat(PromptLibrary.clean(text: text, vocabulary: vocabulary))
    }
    func apply(_ action: EditorAction, to text: String) async throws -> String {
        try await chat(PromptLibrary.action(action, text: text, translationLanguage: translationLanguage))
    }

    private func chat(_ prompt: String) async throws -> String {
        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model,
            "messages": [["role": "user", "content": prompt]]
        ])
        let (data, response) = try await transport(req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw AppError.enhancementFailed("OpenAI HTTP error")
        }
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = obj?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        guard let content = message?["content"] as? String else {
            throw AppError.enhancementFailed("bad OpenAI response")
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
