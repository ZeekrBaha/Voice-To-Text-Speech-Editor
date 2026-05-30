import Testing
@testable import SpeechEditor

@Suite("OutputSink contract")
struct OutputSinkContractTests {
    @Test("records delivered text")
    func delivers() throws {
        let sink = FakeOutputSink()
        try sink.deliver("hello")
        #expect(sink.delivered == ["hello"])
    }
}
