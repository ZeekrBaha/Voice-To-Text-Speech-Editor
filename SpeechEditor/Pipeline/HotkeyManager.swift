import AppKit

/// The push-to-talk modifier the user holds to dictate. Each case maps to the
/// right-hand modifier's hardware keyCode and its event flag.
enum HotkeyModifier: String, Codable, CaseIterable, Equatable {
    case rightControl, rightOption, rightCommand

    var keyCode: UInt16 {
        switch self {
        case .rightControl: return 0x3E
        case .rightOption:  return 0x3D
        case .rightCommand: return 0x36
        }
    }

    var flag: NSEvent.ModifierFlags {
        switch self {
        case .rightControl: return .control
        case .rightOption:  return .option
        case .rightCommand: return .command
        }
    }

    var label: String {
        switch self {
        case .rightControl: return "⌃ Right Control"
        case .rightOption:  return "⌥ Right Option"
        case .rightCommand: return "⌘ Right Command"
        }
    }
}

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

/// Wires a global modifier-flags monitor for the chosen right-hand modifier to the
/// state machine. The modifier is read live, so changing it in Settings takes effect
/// on the next key event without a relaunch.
final class HotkeyManager {
    private let machine: HotkeyStateMachine
    private var monitor: Any?
    private let modifierProvider: () -> HotkeyModifier

    init(modifierProvider: @escaping () -> HotkeyModifier = { .rightControl },
         onStart: @escaping () -> Void, onStop: @escaping () -> Void) {
        self.modifierProvider = modifierProvider
        machine = HotkeyStateMachine(onStart: onStart, onStop: onStop)
    }

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self else { return }
            let modifier = self.modifierProvider()
            guard event.keyCode == modifier.keyCode else { return }
            let down = event.modifierFlags.contains(modifier.flag)
            self.machine.keyChanged(isControlDown: down)
        }
    }
    func stop() { if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil }
}
