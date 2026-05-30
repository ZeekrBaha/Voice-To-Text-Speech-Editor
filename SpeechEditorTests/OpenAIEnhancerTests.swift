import Testing
import Foundation
@testable import SpeechEditor

@Suite("OpenAIEnhancer")
struct OpenAIEnhancerTests {
    @Test("parses chat completion and sets auth header")
    func cleans() async throws {
        var authHeader: String?
        let e = OpenAIEnhancer(apiKey: "sk-test", model: "gpt-4o-mini") { req in
            authHeader = req.value(forHTTPHeaderField: "Authorization")
            let json = #"{"choices":[{"message":{"content":"Hello."}}]}"#.data(using: .utf8)!
            return (json, HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        #expect(try await e.clean("helo", vocabulary: []) == "Hello.")
        #expect(authHeader == "Bearer sk-test")
    }
}
