import AppKit

protocol PasteboardWriting {
    func string() -> String?
    func setString(_ s: String)
}

struct SystemPasteboard: PasteboardWriting {
    func string() -> String? { NSPasteboard.general.string(forType: .string) }
    func setString(_ s: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }
}

final class CursorPasteSink: OutputSink {
    private let pasteboard: PasteboardWriting
    private let paste: () -> Void
    private let isUsingRealKeystroke: Bool

    init(pasteboard: PasteboardWriting = SystemPasteboard(), paste: (() -> Void)? = nil) {
        self.pasteboard = pasteboard
        self.isUsingRealKeystroke = (paste == nil)
        self.paste = paste ?? CursorPasteSink.pressCmdV
    }

    func deliver(_ text: String) throws {
        let saved = pasteboard.string()
        pasteboard.setString(text)
        paste()
        if let saved {
            if isUsingRealKeystroke {
                // The real Cmd+V is delivered asynchronously by the OS; give the
                // target app time to consume the pasteboard before restoring it.
                usleep(120_000) // 120ms
            }
            pasteboard.setString(saved)
        }
    }

    static func pressCmdV() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let v: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: false)
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
