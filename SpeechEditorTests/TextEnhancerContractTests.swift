import Testing
@testable import SpeechEditor

@Suite("TextEnhancer contract")
struct TextEnhancerContractTests {
    @Test("clean returns enhanced text")
    func clean() async throws {
        let e = FakeTextEnhancer(); e.cleanResult = "Hello, world."
        #expect(try await e.clean("helo wrld", vocabulary: []) == "Hello, world.")
    }
    @Test("apply maps each action")
    func apply() async throws {
        let e = FakeTextEnhancer(); e.applyResult = "summary"
        let out = try await e.apply(.summarize, to: "long text")
        #expect(out == "summary")
        #expect(e.lastAction == .summarize)
    }
    @Test("EditorAction covers the MVP set")
    func actions() {
        #expect(Set(EditorAction.allCases) ==
                [.rewrite, .summarize, .changeTone, .translate, .fixGrammar])
    }
}
