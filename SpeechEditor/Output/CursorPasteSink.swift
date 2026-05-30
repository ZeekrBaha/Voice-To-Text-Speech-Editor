import AppKit
import ApplicationServices

/// A snapshot of the pasteboard across every item and type, so we can restore rich
/// clipboard contents (files, images, RTF, …) — not just plain text.
struct PasteboardSnapshot: Equatable {
    /// One entry per pasteboard item; each maps a type's raw value to its data.
    let items: [[String: Data]]
}

protocol PasteboardWriting {
    func snapshot() -> PasteboardSnapshot
    func write(_ text: String)
    func restore(_ snapshot: PasteboardSnapshot)
}

struct SystemPasteboard: PasteboardWriting {
    func snapshot() -> PasteboardSnapshot {
        let pb = NSPasteboard.general
        let items: [[String: Data]] = (pb.pasteboardItems ?? []).map { item in
            var map: [String: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { map[type.rawValue] = data }
            }
            return map
        }
        return PasteboardSnapshot(items: items)
    }

    func write(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    func restore(_ snapshot: PasteboardSnapshot) {
        let pb = NSPasteboard.general
        pb.clearContents()
        let items: [NSPasteboardItem] = snapshot.items.map { map in
            let item = NSPasteboardItem()
            for (raw, data) in map {
                item.setData(data, forType: NSPasteboard.PasteboardType(raw))
            }
            return item
        }
        if !items.isEmpty { pb.writeObjects(items) }
    }
}

/// Seam over AXIsProcessTrusted so the paste path can be tested without real permission.
protocol AccessibilityChecking {
    func isTrusted() -> Bool
}

struct SystemAccessibility: AccessibilityChecking {
    func isTrusted() -> Bool { AXIsProcessTrusted() }
}

final class CursorPasteSink: OutputSink {
    private let pasteboard: PasteboardWriting
    private let accessibility: AccessibilityChecking
    private let paste: () -> Void
    private let isUsingRealKeystroke: Bool
    private let restoreDelayMs: () -> Int

    init(pasteboard: PasteboardWriting = SystemPasteboard(),
         accessibility: AccessibilityChecking = SystemAccessibility(),
         restoreDelayMs: @escaping () -> Int = { 120 },
         paste: (() -> Void)? = nil) {
        self.pasteboard = pasteboard
        self.accessibility = accessibility
        self.restoreDelayMs = restoreDelayMs
        self.isUsingRealKeystroke = (paste == nil)
        self.paste = paste ?? CursorPasteSink.pressCmdV
    }

    func deliver(_ text: String) throws {
        // Synthetic Cmd+V and the global hotkey both need Accessibility. Without it the
        // paste would silently no-op, so fail loudly instead — the transcript is already
        // stored by the caller, so nothing is lost.
        guard accessibility.isTrusted() else {
            throw AppError.permissionDenied("Accessibility")
        }
        let saved = pasteboard.snapshot()
        pasteboard.write(text)
        paste()
        if isUsingRealKeystroke {
            // The real Cmd+V is delivered asynchronously by the OS; give the target app
            // time to consume the pasteboard before restoring the prior contents.
            let ms = max(0, restoreDelayMs())
            usleep(useconds_t(ms * 1000))
        }
        pasteboard.restore(saved)
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
