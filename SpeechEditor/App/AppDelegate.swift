import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let container = AppContainer()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // menu-bar agent
        container.start()

        if CommandLine.arguments.contains("-uiTestSeedEditor") {
            NSApp.setActivationPolicy(.regular)
            container.seedForUITest()
            container.showEditor()
        }

        if !CommandLine.arguments.contains("-uiTestSeedEditor"), !container.permissions.isReady {
            NSApp.setActivationPolicy(.regular) // ensure onboarding window comes to front
            container.showOnboarding()
        }
    }
}
