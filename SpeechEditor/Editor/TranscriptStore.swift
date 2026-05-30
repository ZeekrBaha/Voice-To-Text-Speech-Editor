import Foundation

/// Persistence seam for the transcript library. Concrete impl writes JSON to disk;
/// tests inject an in-memory fake.
protocol TranscriptStore {
    func load() -> [Transcript]
    func save(_ transcripts: [Transcript])
}

/// Persists transcripts as a JSON array in Application Support
/// (`~/Library/Application Support/SpeechEditor/transcripts.json`), written atomically.
///
/// Best-effort by design: read/write errors are swallowed here so a corrupt or
/// unwritable file never crashes the app — the in-memory list stays authoritative.
final class JSONTranscriptStore: TranscriptStore {
    private let url: URL

    /// - Parameter url: override the file location (used by tests). When nil, resolves
    ///   the Application Support path and ensures the containing directory exists.
    init(url: URL? = nil) {
        if let url {
            self.url = url
        } else {
            let base = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            let dir = base.appendingPathComponent("SpeechEditor", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.url = dir.appendingPathComponent("transcripts.json")
        }
    }

    func load() -> [Transcript] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Transcript].self, from: data)) ?? []
    }

    func save(_ transcripts: [Transcript]) {
        guard let data = try? JSONEncoder().encode(transcripts) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
