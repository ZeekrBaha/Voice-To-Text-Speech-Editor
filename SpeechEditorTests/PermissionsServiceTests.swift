import Testing
@testable import SpeechEditor

@Suite("PermissionsService")
struct PermissionsServiceTests {
    @Test("ready only when mic, accessibility, and speech all granted")
    func readiness() {
        #expect(PermissionsService(micGranted: { false }, axTrusted: { true }, speechGranted: { true }).isReady == false)
        #expect(PermissionsService(micGranted: { true }, axTrusted: { false }, speechGranted: { true }).isReady == false)
        #expect(PermissionsService(micGranted: { true }, axTrusted: { true }, speechGranted: { false }).isReady == false)
        #expect(PermissionsService(micGranted: { true }, axTrusted: { true }, speechGranted: { true }).isReady == true)
    }
}
