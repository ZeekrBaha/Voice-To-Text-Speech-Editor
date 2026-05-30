import Testing
import Foundation
@testable import SpeechEditor

@Suite("OllamaEnhancer")
struct OllamaEnhancerTests {
    @Test("parses Ollama response and sends the model")
    func cleans() async throws {
        var sentBody: Data?
        let enhancer = OllamaEnhancer(model: "qwen2.5:7b-instruct") { request in
            sentBody = request.httpBody
            let json = #"{"response":"Hello, world."}"#.data(using: .utf8)!
            return (json, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let out = try await enhancer.clean("helo wrld", vocabulary: [])
        #expect(out == "Hello, world.")
        let bodyString = String(data: sentBody!, encoding: .utf8)!
        #expect(bodyString.contains("qwen2.5:7b-instruct"))
    }
    @Test("throws enhancementFailed on non-200")
    func httpError() async {
        let enhancer = OllamaEnhancer(model: "m") { request in
            (Data(), HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!)
        }
        await #expect(throws: AppError.self) {
            _ = try await enhancer.clean("x", vocabulary: [])
        }
    }
}
