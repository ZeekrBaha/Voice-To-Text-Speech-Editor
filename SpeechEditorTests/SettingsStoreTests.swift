import Testing
import Foundation
@testable import SpeechEditor

@Suite("SettingsStore")
struct SettingsStoreTests {
    @Test("persists and reloads settings")
    func persists() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)
        var s = store.settings
        s.enhancementEnabled = false
        store.settings = s
        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.settings.enhancementEnabled == false)
    }
    @Test("returns defaults when nothing stored")
    func defaultsWhenEmpty() {
        let store = SettingsStore(defaults: UserDefaults(suiteName: "empty-\(UUID().uuidString)")!)
        #expect(store.settings == .default)
    }
}
