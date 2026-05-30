@testable import SpeechEditor

/// In-memory TranscriptStore for tests — no disk I/O, no shared state.
final class FakeTranscriptStore: TranscriptStore {
    var stored: [Transcript]
    init(_ initial: [Transcript] = []) { stored = initial }
    func load() -> [Transcript] { stored }
    func save(_ transcripts: [Transcript]) { stored = transcripts }
}
