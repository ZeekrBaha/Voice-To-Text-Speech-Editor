import Testing
import Foundation
@testable import SpeechEditor

@Suite("EditorStore")
struct EditorStoreTests {
    @MainActor
    @Test("add appends and sets current text")
    func add() {
        let s = EditorStore()
        s.add(Transcript(id: UUID(), createdAt: Date(), rawText: "a", enhancedText: "A."))
        #expect(s.transcripts.count == 1)
        #expect(s.currentText == "A.")
    }
    @MainActor
    @Test("applying an edit pushes history and updates current")
    func history() {
        let s = EditorStore()
        s.add(Transcript(id: UUID(), createdAt: Date(), rawText: "a", enhancedText: "A."))
        s.replaceCurrent(with: "A summary.")
        #expect(s.currentText == "A summary.")
        s.undo()
        #expect(s.currentText == "A.")
    }
    @MainActor
    @Test("export produces text with all transcripts")
    func export() {
        let s = EditorStore()
        s.add(Transcript(id: UUID(), createdAt: Date(timeIntervalSince1970: 0), rawText: "one", enhancedText: nil))
        s.add(Transcript(id: UUID(), createdAt: Date(timeIntervalSince1970: 60), rawText: "two", enhancedText: nil))
        let md = s.exportMarkdown()
        #expect(md.contains("one"))
        #expect(md.contains("two"))
    }
}
