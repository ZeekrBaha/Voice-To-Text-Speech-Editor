import AppKit
import SwiftUI

@MainActor
final class WindowManager {
    private var editorWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    func showOnboarding(permissions: PermissionsService) {
        if let w = onboardingWindow {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = OnboardingView(permissions: permissions) { [weak self] in
            self?.onboardingWindow?.close()
            self?.onboardingWindow = nil
        }
        let hosting = NSHostingController(rootView: view)
        let w = NSWindow(contentViewController: hosting)
        w.title = "Welcome"
        w.styleMask = [.titled, .closable]
        w.isReleasedWhenClosed = false
        onboardingWindow = w
        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showEditor(store: EditorStore, enhancer: TextEnhancer, vocabulary: [String],
                    status: StatusCenter) {
        if let w = editorWindow {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = EditorWindow(store: store, enhancer: enhancer, vocabulary: vocabulary,
                                status: status)
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
