import AppKit
import SwiftUI

@MainActor
final class WindowManager {
    private var editorWindow: NSWindow?

    func showEditor(store: EditorStore, enhancer: TextEnhancer, vocabulary: [String]) {
        if let w = editorWindow {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = EditorWindow(store: store, enhancer: enhancer, vocabulary: vocabulary)
        let hosting = NSHostingController(rootView: view)
        let w = NSWindow(contentViewController: hosting)
        w.title = "Speech Editor"
        w.setContentSize(NSSize(width: 560, height: 400))
        w.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        w.isReleasedWhenClosed = false
        editorWindow = w
        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
