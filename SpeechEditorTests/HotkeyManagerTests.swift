import Testing
@testable import SpeechEditor

@Suite("HotkeyStateMachine")
struct HotkeyStateMachineTests {
    @Test("hold then release fires start then stop exactly once")
    func holdRelease() {
        var events: [String] = []
        let sm = HotkeyStateMachine(onStart: { events.append("start") },
                                    onStop: { events.append("stop") })
        sm.keyChanged(isControlDown: true)
        sm.keyChanged(isControlDown: true)  // repeat key-down must not re-fire start
        sm.keyChanged(isControlDown: false)
        #expect(events == ["start", "stop"])
    }
    @Test("release without prior press does nothing")
    func releaseOnly() {
        var events: [String] = []
        let sm = HotkeyStateMachine(onStart: { events.append("start") },
                                    onStop: { events.append("stop") })
        sm.keyChanged(isControlDown: false)
        #expect(events.isEmpty)
    }
}
