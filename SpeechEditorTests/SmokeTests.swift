import Testing
@testable import SpeechEditor

@Suite("Smoke")
struct SmokeTests {
    @Test("test harness runs")
    func harnessRuns() {
        #expect(1 + 1 == 2)
    }
}
