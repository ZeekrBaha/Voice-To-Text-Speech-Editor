@testable import SpeechEditor

final class FakeOutputSink: OutputSink {
    private(set) var delivered: [String] = []
    var errorToThrow: Error?

    func deliver(_ text: String) throws {
        if let e = errorToThrow { throw e }
        delivered.append(text)
    }
}
