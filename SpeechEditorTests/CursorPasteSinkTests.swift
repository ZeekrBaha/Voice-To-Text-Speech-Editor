import Testing
import Foundation
@testable import SpeechEditor

/// In-memory pasteboard: tracks the current snapshot and what text was written.
final class SpyPasteboard: PasteboardWriting {
    var current: PasteboardSnapshot
    private(set) var writtenText: String?
    init(_ snapshot: PasteboardSnapshot = .init(items: [])) { current = snapshot }
    func snapshot() -> PasteboardSnapshot { current }
    func write(_ text: String) {
        writtenText = text
        current = PasteboardSnapshot(items: [["public.utf8-plain-text": Data(text.utf8)]])
    }
    func restore(_ snapshot: PasteboardSnapshot) { current = snapshot }
}

struct StubAccessibility: AccessibilityChecking {
    let trusted: Bool
    func isTrusted() -> Bool { trusted }
}

@Suite("CursorPasteSink")
struct CursorPasteSinkTests {
    @Test("sets text, triggers paste, then restores the prior clipboard")
    func restores() throws {
        let original = PasteboardSnapshot(items: [["public.utf8-plain-text": Data("original".utf8)]])
        let pb = SpyPasteboard(original)
        var pastedWhileSet: String?
        let sink = CursorPasteSink(pasteboard: pb, accessibility: StubAccessibility(trusted: true),
                                   paste: { pastedWhileSet = pb.writtenText })
        try sink.deliver("new text")
        #expect(pastedWhileSet == "new text")
        #expect(pb.current == original)   // full prior snapshot restored
    }

    @Test("preserves all pasteboard items/types, not just the string")
    func preservesRichClipboard() throws {
        let rich = PasteboardSnapshot(items: [
            ["public.utf8-plain-text": Data("hello".utf8)],
            ["public.tiff": Data([0x4D, 0x4D, 0x00, 0x2A])],
        ])
        let pb = SpyPasteboard(rich)
        let sink = CursorPasteSink(pasteboard: pb, accessibility: StubAccessibility(trusted: true),
                                   paste: {})
        try sink.deliver("typed")
        #expect(pb.current == rich)
    }

    @Test("without Accessibility, paste throws and the clipboard is untouched")
    func notTrusted() {
        let pb = SpyPasteboard(.init(items: [["public.utf8-plain-text": Data("keep".utf8)]]))
        let sink = CursorPasteSink(pasteboard: pb, accessibility: StubAccessibility(trusted: false),
                                   paste: {})
        #expect(throws: AppError.permissionDenied("Accessibility")) {
            try sink.deliver("nope")
        }
        #expect(pb.writtenText == nil)  // never wrote to the clipboard
    }
}
