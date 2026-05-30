import Foundation

final class OllamaEnhancer: TextEnhancer {
    typealias Transport = (URLRequest) async throws -> (Data, URLResponse)
    private let model: String
    private let translationLanguage: String
    private let baseURL: URL
    private let transport: Transport

    init(model: String, translationLanguage: String = "Spanish",
         baseURL: URL = URL(string: "http://localhost:11434")!,
         transport: @escaping Transport = { try await URLSession.shared.data(for: $0) }) {
        self.model = model; self.translationLanguage = translationLanguage
        self.baseURL = baseURL; self.transport = transport
    }

    func clean(_ text: String, vocabulary: [String]) async throws -> String {
        try await generate(PromptLibrary.clean(text: text, vocabulary: vocabulary))
    }
    func apply(_ action: EditorAction, to text: String) async throws -> String {
        try await generate(PromptLibrary.action(action, text: text, translationLanguage: translationLanguage))
    }

    private func generate(_ prompt: String) async throws -> String {
        var req = URLRequest(url: baseURL.appendingPathComponent("api/generate"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model, "prompt": prompt, "stream": false
        ])
        let (data, response) = try await transport(req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw AppError.enhancementFailed("Ollama HTTP error")
        }
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let text = obj?["response"] as? String else {
            throw AppError.enhancementFailed("bad Ollama response")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
