import AVFoundation

final class AVAudioCaptureService: AudioCapturing {
    private let engine = AVAudioEngine()
    private var samples: [Float] = []
    private let targetRate: Double = 16000
    private let lock = NSLock()

    func start() throws {
        samples.removeAll(keepingCapacity: true)
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        let outFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                      sampleRate: targetRate, channels: 1, interleaved: false)!
        let converter = AVAudioConverter(from: inputFormat, to: outFormat)!

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            let cap = AVAudioFrameCount(outFormat.sampleRate * Double(buffer.frameLength) / inputFormat.sampleRate) + 16
            guard let converted = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: cap) else { return }
            var error: NSError?
            var fed = false
            converter.convert(to: converted, error: &error) { _, status in
                if fed { status.pointee = .noDataNow; return nil }
                fed = true; status.pointee = .haveData; return buffer
            }
            if let ch = converted.floatChannelData {
                let frames = Int(converted.frameLength)
                self.lock.lock()
                self.samples.append(contentsOf: UnsafeBufferPointer(start: ch[0], count: frames))
                self.lock.unlock()
            }
        }
        engine.prepare()
        try engine.start()
    }

    func stop() -> AudioBuffer {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        lock.lock(); let s = samples; lock.unlock()
        return AudioBuffer(samples: s, sampleRate: Int(targetRate))
    }
}
