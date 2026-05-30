import Foundation
import ServiceManagement

/// Seam over the login-item registration so Settings can be tested without touching
/// the real ServiceManagement database.
protocol LaunchAtLoginManaging {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool)
}

/// Native launch-at-login via `SMAppService` (macOS 13+). No third-party dependency.
struct SMAppServiceLaunchAtLogin: LaunchAtLoginManaging {
    var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    func setEnabled(_ enabled: Bool) {
        // Best-effort: a failure here shouldn't crash settings. The toggle reflects the
        // real status on next read.
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            Log.app.error("launch-at-login update failed: \(error.localizedDescription)")
        }
    }
}
