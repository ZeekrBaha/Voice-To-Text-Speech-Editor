@testable import SpeechEditor

final class FakeTextEnhancer: TextEnhancer {
    var cleanResult = ""
    var applyResult = ""
    var errorToThrow: Error?
    private(set) var lastAction: EditorAction?
    func clean(_ text: String, vocabulary: [String]) async throws -> String {
        if let e = errorToThrow { throw e }; return cleanResult.isEmpty ? text : cleanResult
    }
    func apply(_ action: EditorAction, to text: String) async throws -> String {
        lastAction = action
        if let e = errorToThrow { throw e }; return applyResult
    }
}
