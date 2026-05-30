import Testing
@testable import SpeechEditor

final class SpyPasteboard: PasteboardWriting {
    var contents: String?
    func string() -> String? { contents }
    func setString(_ s: String) { contents = s }
}

@Suite("CursorPasteSink")
struct CursorPasteSinkTests {
    @Test("sets text, triggers paste, then restores prior clipboard")
    func restores() throws {
        let pb = SpyPasteboard(); pb.contents = "original"
        var pastedWhileSet: String?
        let sink = CursorPasteSink(pasteboard: pb, paste: { pastedWhileSet = pb.string() })
        try sink.deliver("new text")
        #expect(pastedWhileSet == "new text")
        #expect(pb.contents == "original")
    }
}
