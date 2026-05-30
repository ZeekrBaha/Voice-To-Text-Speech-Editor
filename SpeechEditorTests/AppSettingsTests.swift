import Testing
import Foundation
@testable import SpeechEditor

@Suite("AppSettings")
struct AppSettingsTests {
    @Test("has sane defaults")
    func defaults() {
        let s = AppSettings.default
        #expect(s.enhancementEnabled == true)
        #expect(s.aiProvider == .ollama)
        #expect(s.modelName == "ggml-small.en")
    }
    @Test("round-trips through Codable")
    func codable() throws {
        let data = try JSONEncoder().encode(AppSettings.default)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        #expect(decoded == .default)
    }
}
