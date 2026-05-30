import Testing
@testable import SpeechEditor

@Suite("AppError")
struct AppErrorTests {
    @Test("has user-facing messages")
    func messages() {
        #expect(AppError.audioTooShort.userMessage.contains("short"))
        #expect(AppError.modelMissing.userMessage.contains("model"))
    }
}
