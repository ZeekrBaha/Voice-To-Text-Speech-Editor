import Testing
@testable import SpeechEditor

@Suite("StatusCenter")
struct StatusCenterTests {
    @MainActor
    @Test("post sets the current message with its severity")
    func post() {
        let s = StatusCenter()
        s.post("hello", severity: .success)
        #expect(s.current?.text == "hello")
        #expect(s.current?.severity == .success)
    }

    @MainActor
    @Test("posting an AppError surfaces its userMessage as an error")
    func postError() {
        let s = StatusCenter()
        s.post(AppError.pasteFailed)
        #expect(s.current?.severity == .error)
        #expect(s.current?.text == AppError.pasteFailed.userMessage)
    }

    @MainActor
    @Test("clear removes the current message")
    func clear() {
        let s = StatusCenter()
        s.post("x")
        s.clear()
        #expect(s.current == nil)
    }
}
