import Testing
@testable import SpeechEditor

@Suite("PromptLibrary")
struct PromptLibraryTests {
    @Test("clean prompt injects vocabulary and text")
    func cleanPrompt() {
        let p = PromptLibrary.clean(text: "helo", vocabulary: ["Xcode"])
        #expect(p.contains("helo"))
        #expect(p.contains("Xcode"))
    }
    @Test("each action yields a distinct instruction")
    func actionPrompts() {
        let prompts = EditorAction.allCases.map { PromptLibrary.action($0, text: "x") }
        #expect(Set(prompts).count == EditorAction.allCases.count)
        #expect(prompts.allSatisfy { $0.contains("x") })
    }

    @Test("translate uses the configured language")
    func translateLanguage() {
        let p = PromptLibrary.action(.translate, text: "hi", translationLanguage: "French")
        #expect(p.contains("French"))
        #expect(!p.contains("Spanish"))
    }
}
