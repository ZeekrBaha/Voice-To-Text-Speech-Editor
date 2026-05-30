import Foundation
import Observation

enum StatusSeverity: Equatable { case info, success, error }

struct StatusMessage: Equatable, Identifiable {
    let id: UUID
    let text: String
    let severity: StatusSeverity
}

/// App-wide channel for surfacing transient status: AI/export results, transcription,
/// paste, and permission failures. Drives the Editor banner and the HUD flash so
/// failures are never silent. One message at a time; auto-clears after a delay.
@MainActor
@Observable
final class StatusCenter {
    private(set) var current: StatusMessage?
    /// Seconds before an auto-clear; injectable so tests don't depend on wall-clock.
    var autoClearSeconds: Double = 4.0
    private var clearGeneration = 0

    func post(_ text: String, severity: StatusSeverity = .info) {
        current = StatusMessage(id: UUID(), text: text, severity: severity)
        scheduleClear()
    }

    func post(_ error: AppError) { post(error.userMessage, severity: .error) }

    func clear() {
        clearGeneration &+= 1   // invalidate any pending auto-clear
        current = nil
    }

    private func scheduleClear() {
        clearGeneration &+= 1
        let mine = clearGeneration
        let seconds = autoClearSeconds
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard let self, self.clearGeneration == mine else { return }
            self.current = nil
        }
    }
}
