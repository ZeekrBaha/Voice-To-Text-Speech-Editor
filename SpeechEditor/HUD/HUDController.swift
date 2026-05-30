import AppKit
import SwiftUI

@MainActor
final class HUDController {
    private var panel: NSPanel?

    func show() {
        guard panel == nil else { return }
        let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 140, height: 48),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.isFloatingPanel = true
        p.level = .floating
        p.backgroundColor = .clear
        p.hasShadow = true
        p.contentView = NSHostingView(rootView: MiniRecorderHUD())
        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            p.setFrameOrigin(NSPoint(x: f.midX - 70, y: f.minY + 80))
        }
        p.orderFrontRegardless()
        panel = p
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }

    /// Briefly show a transient message HUD (e.g. a dictation error) so the user sees
    /// it even when the Editor window is closed. Auto-dismisses.
    func flash(_ text: String, seconds: Double = 3.0) {
        hide()
        let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 280, height: 48),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.isFloatingPanel = true
        p.level = .floating
        p.backgroundColor = .clear
        p.hasShadow = true
        p.contentView = NSHostingView(rootView: StatusFlashHUD(text: text))
        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            p.setFrameOrigin(NSPoint(x: f.midX - 140, y: f.minY + 80))
        }
        p.orderFrontRegardless()
        panel = p
        let generation = UUID()
        flashGeneration = generation
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard let self, self.flashGeneration == generation else { return }
            self.hide()
        }
    }

    private var flashGeneration = UUID()
}
