import AppKit

final class HotkeyStateMachine {
    private var isRecording = false
    private let onStart: () -> Void
    private let onStop: () -> Void
    init(onStart: @escaping () -> Void, onStop: @escaping () -> Void) {
        self.onStart = onStart; self.onStop = onStop
    }
    func keyChanged(isControlDown: Bool) {
        if isControlDown, !isRecording { isRecording = true; onStart() }
        else if !isControlDown, isRecording { isRecording = false; onStop() }
    }
}

/// Wires a global modifier-flags monitor for the Right-Control key to the state machine.
final class HotkeyManager {
    private let machine: HotkeyStateMachine
    private var monitor: Any?
    private let rightControlKeyCode: UInt16 = 0x3E  // Right Control

    init(onStart: @escaping () -> Void, onStop: @escaping () -> Void) {
        machine = HotkeyStateMachine(onStart: onStart, onStop: onStop)
    }

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self else { return }
            guard event.keyCode == self.rightControlKeyCode else { return }
            let down = event.modifierFlags.contains(.control)
            self.machine.keyChanged(isControlDown: down)
        }
    }
    func stop() { if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil }
}
