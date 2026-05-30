import Foundation

enum AIProvider: String, Codable, CaseIterable { case ollama, openai }

/// Where a finished dictation goes: pasted at the cursor, kept only in the Editor, or both.
enum PasteMode: String, Codable, CaseIterable {
    case pasteOnly, editorOnly, both
    var label: String {
        switch self {
        case .pasteOnly:  return "Paste at cursor only"
        case .editorOnly: return "Editor only"
        case .both:       return "Paste and add to Editor"
        }
    }
}

struct AppSettings: Codable, Equatable {
    var enhancementEnabled: Bool
    var aiProvider: AIProvider
    var ollamaModel: String
    var openAIModel: String
    var localeIdentifier: String
    var translationLanguage: String
    var hotkeyModifier: HotkeyModifier
    var pasteDelayMs: Int
    var pasteMode: PasteMode
    var launchAtLogin: Bool
    var vocabulary: [VocabularyEntry]

    static let `default` = AppSettings(
        enhancementEnabled: true,
        aiProvider: .ollama,
        ollamaModel: "qwen2.5:7b-instruct",
        openAIModel: "gpt-4o-mini",
        localeIdentifier: "en-US",
        translationLanguage: "Spanish",
        hotkeyModifier: .rightControl,
        pasteDelayMs: 120,
        pasteMode: .both,
        launchAtLogin: false,
        vocabulary: []
    )

    /// Decodes leniently: settings saved by an older build (missing the v0.2 fields)
    /// still load, falling back to defaults for anything absent.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings.default
        enhancementEnabled  = try c.decodeIfPresent(Bool.self, forKey: .enhancementEnabled) ?? d.enhancementEnabled
        aiProvider          = try c.decodeIfPresent(AIProvider.self, forKey: .aiProvider) ?? d.aiProvider
        ollamaModel         = try c.decodeIfPresent(String.self, forKey: .ollamaModel) ?? d.ollamaModel
        openAIModel         = try c.decodeIfPresent(String.self, forKey: .openAIModel) ?? d.openAIModel
        localeIdentifier    = try c.decodeIfPresent(String.self, forKey: .localeIdentifier) ?? d.localeIdentifier
        translationLanguage = try c.decodeIfPresent(String.self, forKey: .translationLanguage) ?? d.translationLanguage
        hotkeyModifier      = try c.decodeIfPresent(HotkeyModifier.self, forKey: .hotkeyModifier) ?? d.hotkeyModifier
        pasteDelayMs        = try c.decodeIfPresent(Int.self, forKey: .pasteDelayMs) ?? d.pasteDelayMs
        pasteMode           = try c.decodeIfPresent(PasteMode.self, forKey: .pasteMode) ?? d.pasteMode
        launchAtLogin       = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? d.launchAtLogin
        vocabulary          = try c.decodeIfPresent([VocabularyEntry].self, forKey: .vocabulary) ?? d.vocabulary
    }

    private init(enhancementEnabled: Bool, aiProvider: AIProvider, ollamaModel: String,
                 openAIModel: String, localeIdentifier: String, translationLanguage: String,
                 hotkeyModifier: HotkeyModifier, pasteDelayMs: Int, pasteMode: PasteMode,
                 launchAtLogin: Bool, vocabulary: [VocabularyEntry]) {
        self.enhancementEnabled = enhancementEnabled
        self.aiProvider = aiProvider
        self.ollamaModel = ollamaModel
        self.openAIModel = openAIModel
        self.localeIdentifier = localeIdentifier
        self.translationLanguage = translationLanguage
        self.hotkeyModifier = hotkeyModifier
        self.pasteDelayMs = pasteDelayMs
        self.pasteMode = pasteMode
        self.launchAtLogin = launchAtLogin
        self.vocabulary = vocabulary
    }
}
