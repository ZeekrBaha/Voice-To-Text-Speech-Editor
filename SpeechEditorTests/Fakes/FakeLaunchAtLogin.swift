@testable import SpeechEditor

final class FakeLaunchAtLogin: LaunchAtLoginManaging {
    var enabled = false
    var isEnabled: Bool { enabled }
    func setEnabled(_ enabled: Bool) { self.enabled = enabled }
}
