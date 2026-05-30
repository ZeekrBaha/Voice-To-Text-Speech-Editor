import AppKit
import Foundation
import Observation

enum ExportFormat: String, CaseIterable, Identifiable {
    case markdown, plainText, rtf
    var id: String { rawValue }
    var label: String {
        switch self {
        case .markdown:  return "Markdown (.md)"
        case .plainText: return "Plain Text (.txt)"
        case .rtf:       return "Rich Text (.rtf)"
        }
    }
    var fileExtension: String {
        switch self {
        case .markdown: return "md"
        case .plainText: return "txt"
        case .rtf: return "rtf"
        }
    }
}

@MainActor
@Observable
final class EditorStore {
    private(set) var transcripts: [Transcript] = []
    var currentText: String = ""
    private var undoStack: [String] = []
    private var redoStack: [String] = []
    private let store: TranscriptStore

    /// Loads the persisted transcript library on creation. The working `currentText`
    /// starts at the most recent transcript so reopening the app shows where you left off.
    init(store: TranscriptStore = JSONTranscriptStore()) {
        self.store = store
        let loaded = store.load()
        transcripts = loaded
        currentText = loaded.last?.displayText ?? ""
    }

    func add(_ t: Transcript) {
        transcripts.append(t)
        pushUndo()
        currentText = t.displayText
        persist()
    }

    func replaceCurrent(with text: String) {
        pushUndo()
        currentText = text
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(currentText)
        currentText = previous
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(currentText)
        currentText = next
    }

    func delete(_ transcript: Transcript) {
        transcripts.removeAll { $0.id == transcript.id }
        persist()
    }

    /// Case-insensitive substring match over raw + enhanced text. Empty query → all.
    func search(_ query: String) -> [Transcript] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return transcripts }
        return transcripts.filter {
            $0.rawText.lowercased().contains(q)
                || ($0.enhancedText?.lowercased().contains(q) ?? false)
        }
    }

    /// Load a past transcript back into the editing buffer (undoable).
    func restore(_ transcript: Transcript) {
        replaceCurrent(with: transcript.displayText)
    }

    private func pushUndo() {
        undoStack.append(currentText)
        redoStack.removeAll()  // a fresh edit invalidates the redo trail
    }

    private func persist() { store.save(transcripts) }

    func exportMarkdown() -> String {
        let fmt = ISO8601DateFormatter()
        return transcripts.map { "### \(fmt.string(from: $0.createdAt))\n\n\($0.displayText)" }
            .joined(separator: "\n\n")
    }

    /// Render all transcripts in the requested format.
    func exportText(_ format: ExportFormat) -> String {
        switch format {
        case .markdown:
            return exportMarkdown()
        case .plainText:
            return transcripts.map(\.displayText).joined(separator: "\n\n")
        case .rtf:
            let plain = transcripts.map(\.displayText).joined(separator: "\n\n")
            let attr = NSAttributedString(string: plain)
            let data = (try? attr.data(
                from: NSRange(location: 0, length: attr.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])) ?? Data()
            return String(data: data, encoding: .utf8) ?? plain
        }
    }

    /// Write the rendered export to disk (testable seam; the save panel calls this).
    func exportText(_ format: ExportFormat, to url: URL) throws {
        try exportText(format).write(to: url, atomically: true, encoding: .utf8)
    }
}
