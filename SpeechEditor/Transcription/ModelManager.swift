import Foundation

struct WhisperModel: Equatable {
    let stem: String
    let displayName: String
    let downloadURL: URL
    let approxSizeMB: Int
}

final class ModelManager {
    static let catalog: [WhisperModel] = [
        WhisperModel(stem: "ggml-base.en", displayName: "Base (English, fast)",
            downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin")!, approxSizeMB: 142),
        WhisperModel(stem: "ggml-small.en", displayName: "Small (English, balanced)",
            downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin")!, approxSizeMB: 466),
        WhisperModel(stem: "ggml-large-v3-turbo", displayName: "Large v3 Turbo (best)",
            downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin")!, approxSizeMB: 1600),
    ]

    private let modelsDirectory: URL
    private let fm = FileManager.default

    init(modelsDirectory: URL? = nil) {
        self.modelsDirectory = modelsDirectory ?? fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SpeechEditor/Models", isDirectory: true)
    }

    func fileURL(for stem: String) -> URL { modelsDirectory.appendingPathComponent("\(stem).bin") }
    func isInstalled(stem: String) -> Bool { fm.fileExists(atPath: fileURL(for: stem).path) }

    func download(_ model: WhisperModel, progress: @escaping (Double) -> Void) async throws {
        try fm.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        let (tempURL, response) = try await URLSession.shared.download(from: model.downloadURL)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw AppError.modelMissing }
        let dest = fileURL(for: model.stem)
        try? fm.removeItem(at: dest)
        try fm.moveItem(at: tempURL, to: dest)
        progress(1.0)
    }
}
