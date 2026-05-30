import Testing
import Foundation
@testable import SpeechEditor

@Suite("ModelManager")
struct ModelManagerTests {
    @Test("catalog includes default model with a download URL")
    func catalog() {
        let m = ModelManager.catalog.first { $0.stem == "ggml-small.en" }
        #expect(m != nil)
        #expect(m?.downloadURL.absoluteString.contains("ggml-small.en.bin") == true)
    }
    @Test("isInstalled false when file absent")
    func notInstalled() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let mm = ModelManager(modelsDirectory: dir)
        #expect(mm.isInstalled(stem: "ggml-small.en") == false)
        #expect(mm.fileURL(for: "ggml-small.en").lastPathComponent == "ggml-small.en.bin")
    }
}
