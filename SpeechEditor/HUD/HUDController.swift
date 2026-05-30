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
}
