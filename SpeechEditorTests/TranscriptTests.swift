import Testing
import Foundation
@testable import SpeechEditor

@Suite("Transcript")
struct TranscriptTests {
    @Test("preserves raw and enhanced text")
    func preservesText() {
        let t = Transcript(id: UUID(), createdAt: Date(timeIntervalSince1970: 0),
                           rawText: "helo wrld", enhancedText: "Hello, world.")
        #expect(t.rawText == "helo wrld")
        #expect(t.enhancedText == "Hello, world.")
        #expect(t.displayText == "Hello, world.")
    }
    @Test("displayText falls back to raw when no enhancement")
    func fallback() {
        let t = Transcript(id: UUID(), createdAt: Date(), rawText: "raw only", enhancedText: nil)
        #expect(t.displayText == "raw only")
    }
}
