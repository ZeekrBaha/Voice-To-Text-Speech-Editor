import Testing
import Foundation
@testable import SpeechEditor

@Suite("EditorStore")
struct EditorStoreTests {
    @MainActor
    @Test("add appends and sets current text")
    func add() {
        let s = EditorStore(store: FakeTranscriptStore())
        s.add(Transcript(id: UUID(), createdAt: Date(), rawText: "a", enhancedText: "A."))
        #expect(s.transcripts.count == 1)
        #expect(s.currentText == "A.")
    }

    @MainActor
    @Test("applying an edit pushes history and updates current")
    func history() {
        let s = EditorStore(store: FakeTranscriptStore())
        s.add(Transcript(id: UUID(), createdAt: Date(), rawText: "a", enhancedText: "A."))
        s.replaceCurrent(with: "A summary.")
        #expect(s.currentText == "A summary.")
        s.undo()
        #expect(s.currentText == "A.")
    }

    @MainActor
    @Test("redo re-applies an undone edit")
    func redo() {
        let s = EditorStore(store: FakeTranscriptStore())
        s.add(Transcript(id: UUID(), createdAt: Date(), rawText: "a", enhancedText: "A."))
        s.replaceCurrent(with: "edited")
        s.undo()
        #expect(s.currentText == "A.")
        #expect(s.canRedo)
        s.redo()
        #expect(s.currentText == "edited")
        #expect(!s.canRedo)
    }

    @MainActor
    @Test("a fresh edit clears the redo trail")
    func redoInvalidatedByEdit() {
        let s = EditorStore(store: FakeTranscriptStore())
        s.add(Transcript(id: UUID(), createdAt: Date(), rawText: "a", enhancedText: "A."))
        s.replaceCurrent(with: "first")
        s.undo()
        s.replaceCurrent(with: "second")
        #expect(!s.canRedo)
    }

    @MainActor
    @Test("transcripts persist through the store and reload")
    func persistence() {
        let backing = FakeTranscriptStore()
        let first = EditorStore(store: backing)
        first.add(Transcript(id: UUID(), createdAt: Date(timeIntervalSince1970: 1),
                             rawText: "kept", enhancedText: nil))
        let reloaded = EditorStore(store: backing)
        #expect(reloaded.transcripts.count == 1)
        #expect(reloaded.transcripts.first?.rawText == "kept")
        #expect(reloaded.currentText == "kept")
    }

    @MainActor
    @Test("delete removes a transcript and persists")
    func delete() {
        let backing = FakeTranscriptStore()
        let s = EditorStore(store: backing)
        let t = Transcript(id: UUID(), createdAt: Date(), rawText: "gone", enhancedText: nil)
        s.add(t)
        s.delete(t)
        #expect(s.transcripts.isEmpty)
        #expect(backing.stored.isEmpty)
    }

    @MainActor
    @Test("search matches raw and enhanced text, case-insensitively")
    func search() {
        let s = EditorStore(store: FakeTranscriptStore())
        s.add(Transcript(id: UUID(), createdAt: Date(), rawText: "Hello world", enhancedText: nil))
        s.add(Transcript(id: UUID(), createdAt: Date(), rawText: "raw", enhancedText: "Polished note"))
        #expect(s.search("WORLD").count == 1)
        #expect(s.search("polished").count == 1)
        #expect(s.search("  ").count == 2)   // blank → all
        #expect(s.search("zzz").isEmpty)
    }

    @MainActor
    @Test("export produces text with all transcripts")
    func export() {
        let s = EditorStore(store: FakeTranscriptStore())
        s.add(Transcript(id: UUID(), createdAt: Date(timeIntervalSince1970: 0), rawText: "one", enhancedText: nil))
        s.add(Transcript(id: UUID(), createdAt: Date(timeIntervalSince1970: 60), rawText: "two", enhancedText: nil))
        let md = s.exportMarkdown()
        #expect(md.contains("one"))
        #expect(md.contains("two"))
    }

    @MainActor
    @Test("exportText renders markdown, plain text, and rtf")
    func exportFormats() {
        let s = EditorStore(store: FakeTranscriptStore())
        s.add(Transcript(id: UUID(), createdAt: Date(timeIntervalSince1970: 0), rawText: "hello", enhancedText: nil))
        #expect(s.exportText(.markdown).contains("###"))
        let plain = s.exportText(.plainText)
        #expect(plain.contains("hello"))
        #expect(!plain.contains("###"))
        #expect(s.exportText(.rtf).contains("rtf"))   // RTF header {\rtf1...
    }

    @MainActor
    @Test("exportText(to:) writes the rendered content to disk")
    func exportToFile() throws {
        let s = EditorStore(store: FakeTranscriptStore())
        s.add(Transcript(id: UUID(), createdAt: Date(timeIntervalSince1970: 0),
                         rawText: "diskcontent", enhancedText: nil))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-\(UUID().uuidString).txt")
        try s.exportText(.plainText, to: url)
        let read = try String(contentsOf: url, encoding: .utf8)
        #expect(read.contains("diskcontent"))
        try? FileManager.default.removeItem(at: url)
    }
}
