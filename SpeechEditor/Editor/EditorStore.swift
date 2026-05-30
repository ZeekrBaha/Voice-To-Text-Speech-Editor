import Foundation
import Observation

@MainActor
@Observable
final class EditorStore {
    private(set) var transcripts: [Transcript] = []
    var currentText: String = ""
    private var history: [String] = []

    nonisolated init() {}

    func add(_ t: Transcript) {
        transcripts.append(t)
        pushHistory()
        currentText = t.displayText
    }

    func replaceCurrent(with text: String) {
        pushHistory()
        currentText = text
    }

    func undo() {
        guard let last = history.popLast() else { return }
        currentText = last
    }

    private func pushHistory() { history.append(currentText) }

    func exportMarkdown() -> String {
        let fmt = ISO8601DateFormatter()
        return transcripts.map { "### \(fmt.string(from: $0.createdAt))\n\n\($0.displayText)" }
            .joined(separator: "\n\n")
    }
}
