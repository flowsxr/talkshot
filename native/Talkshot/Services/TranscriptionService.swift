import Foundation
import Speech

enum TranscriptionService {
    static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    static func transcribe(audioURL: URL) async throws -> String {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable
        else {
            throw TranscriptionError.unavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let result, result.isFinal else { return }
                continuation.resume(returning: result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
    }

    enum TranscriptionError: LocalizedError {
        case unavailable

        var errorDescription: String? {
            "Speech recognition is not available on this Mac."
        }
    }
}
