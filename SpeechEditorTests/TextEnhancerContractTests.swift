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
    @Test("EditorAction includes the core set plus the v0.2 presets")
    func actions() {
        let all = Set(EditorAction.allCases)
        #expect(all.isSuperset(of: [.rewrite, .summarize, .changeTone, .translate, .fixGrammar]))
        #expect(all.contains(.emailReply))
        #expect(all.contains(.cleanUpMessage))
        #expect(all.contains(.meetingNotes))
        #expect(EditorAction.allCases.filter(\.isPrimary).count == 4)
    }
}
