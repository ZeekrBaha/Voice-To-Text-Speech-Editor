import Testing
@testable import SpeechEditor

@Suite("VocabularyEntry")
struct VocabularyEntryTests {
    @Test("trims and ignores empty terms")
    func trims() {
        #expect(VocabularyEntry(term: "  Xcode  ")?.term == "Xcode")
        #expect(VocabularyEntry(term: "   ") == nil)
    }
}
