import AVFoundation
import Foundation

final class AudioRecorder {
    private let engine = AVAudioEngine()
    private var outputFile: AVAudioFile?
    private var recordingURL: URL?
    private var framesWritten: AVAudioFramePosition = 0

    var isRecording: Bool { engine.isRunning }

    func start() async throws {
        if await !PermissionsService.requestMicrophone() {
            throw RecorderError.microphoneDenied
        }
        try AudioDeviceSelector.configureInput(for: engine)

        let input = engine.inputNode
        // Must match the input node's actual native format — installTap does not resample.
        let format = input.outputFormat(forBus: 0)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("talkshot-\(UUID().uuidString).wav")
        let file = try AVAudioFile(forWriting: tempURL, settings: format.settings)
        outputFile = file
        recordingURL = tempURL
        framesWritten = 0

        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            guard let self, let file = self.outputFile else { return }
            do {
                try file.write(from: buffer)
                self.framesWritten += AVAudioFramePosition(buffer.frameLength)
            } catch {
                NSLog("Talkshot: failed to write audio buffer: \(error)")
            }
        }

        engine.prepare()
        try engine.start()
    }

    func stop() -> URL? {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        outputFile = nil
        defer {
            recordingURL = nil
            framesWritten = 0
        }
        guard framesWritten > 0 else { return nil }
        return recordingURL
    }

    enum RecorderError: LocalizedError {
        case microphoneDenied

        var errorDescription: String? {
            "Microphone access not granted. Enable Talkshot in System Settings → Privacy → Microphone."
        }
    }
}
