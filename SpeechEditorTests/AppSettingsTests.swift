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
        #expect(s.ollamaModel == "qwen2.5:7b-instruct")
        #expect(s.localeIdentifier == "en-US")
        #expect(s.hotkeyModifier == .rightControl)
        #expect(s.pasteDelayMs == 120)
        #expect(s.pasteMode == .both)
        #expect(s.launchAtLogin == false)
        #expect(s.vocabulary.isEmpty)
    }

    @Test("round-trips through Codable including the v0.2 fields")
    func codable() throws {
        var s = AppSettings.default
        s.localeIdentifier = "fr-FR"
        s.hotkeyModifier = .rightOption
        s.pasteMode = .editorOnly
        s.vocabulary = [VocabularyEntry(term: "Kubernetes")!]
        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        #expect(decoded == s)
    }

    @Test("decodes leniently when older settings are missing the v0.2 fields")
    func lenientDecode() throws {
        // JSON saved by the v0.1 build — only the original four keys.
        let legacy = """
        {"enhancementEnabled": false, "aiProvider": "openai",
         "ollamaModel": "x", "openAIModel": "y"}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AppSettings.self, from: legacy)
        #expect(decoded.enhancementEnabled == false)
        #expect(decoded.aiProvider == .openai)
        #expect(decoded.hotkeyModifier == .rightControl)  // filled from defaults
        #expect(decoded.pasteMode == .both)
        #expect(decoded.localeIdentifier == "en-US")
    }
}

@Suite("HotkeyModifier")
struct HotkeyModifierTests {
    @Test("each modifier maps to a distinct keyCode")
    func distinctKeyCodes() {
        let codes = Set(HotkeyModifier.allCases.map(\.keyCode))
        #expect(codes.count == HotkeyModifier.allCases.count)
    }
}

@Suite("LaunchAtLogin seam")
struct LaunchAtLoginTests {
    @Test("setEnabled reflects in isEnabled (the binding SettingsView uses)")
    func toggle() {
        let manager: LaunchAtLoginManaging = FakeLaunchAtLogin()
        #expect(manager.isEnabled == false)
        manager.setEnabled(true)
        #expect(manager.isEnabled == true)
    }
}
