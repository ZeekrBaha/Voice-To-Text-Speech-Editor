import Foundation

struct Transcript: Identifiable, Equatable, Codable {
    let id: UUID
    let createdAt: Date
    var rawText: String
    var enhancedText: String?

    var displayText: String { enhancedText ?? rawText }
}
