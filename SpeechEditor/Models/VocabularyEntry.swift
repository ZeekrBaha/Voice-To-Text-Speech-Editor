import Foundation

struct VocabularyEntry: Equatable, Codable, Identifiable {
    let id: UUID
    let term: String

    init?(term: String, id: UUID = UUID()) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        self.id = id
        self.term = trimmed
    }
}
