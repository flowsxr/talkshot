import AppKit
import Combine
import CoreGraphics
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var isListening = true
    @Published private(set) var isRecording = false
    @Published private(set) var noteCount = 0
    @Published private(set) var statusText = "Ready"
    @Published private(set) var micName = AudioDeviceSelector.currentInputName()

    private(set) var sessionID: String
    private(set) var sessionFolder: URL

    private var entries: [SessionEntry] = []
    private var pending: PendingCapture?
    private var captureIndex = 0
    private let hotkeys = HotkeyService()
    private let recorder = AudioRecorder()

    var menuBarIcon: String {
        if isRecording { return "mic.fill" }
        if isListening { return "camera.on.rectangle" }
        return "camera.on.rectangle.fill"
    }

    @Published private(set) var hasGlobalHotkeys = false

    @Published private(set) var hasScreenRecording = false

    var hotkeyHint: String {
        "\(HotkeyConfig.note.label) note  •  \(HotkeyConfig.finish.label) finish"
    }

    init() {
        (sessionID, sessionFolder) = Self.makeSession()

        hotkeys.onHotkey = { [weak self] in
            Task { @MainActor in await self?.toggleCapture() }
        }
        hotkeys.onQuitKey = { [weak self] in
            Task { @MainActor in await self?.finishSession() }
        }
        hotkeys.isListening = true
        refreshPermissions()

        Task {
            _ = await TranscriptionService.requestAuthorization()
        }
    }

    private static func makeSession() -> (id: String, folder: URL) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let id = formatter.string(from: Date())
        let folder = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/talkshot-session-\(id)", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return (id, folder)
    }

    func refreshPermissions() {
        hasGlobalHotkeys = hotkeys.hasGlobalAccess
        hasScreenRecording = CaptureService.hasScreenRecordingAccess()
        updateStatusMessage()
    }

    private func updateStatusMessage() {
        if !hasScreenRecording {
            statusText = "Enable Screen Recording, then quit & reopen Talkshot"
        } else if !hasGlobalHotkeys {
            statusText = "Ready — use menu, or grant Accessibility for hotkeys"
        } else if !isRecording {
            statusText = "Ready"
        }
    }

    func requestAccessibility() {
        _ = PermissionsService.requestAccessibility()
        hotkeys.isListening = isListening
        refreshPermissions()
    }

    func openScreenRecordingSettings() {
        PermissionsService.openScreenRecordingSettings()
        statusText = "Remove Talkshot, reopen app, re-enable, then quit & reopen"
    }

    func toggleListening() {
        isListening.toggle()
        hotkeys.isListening = isListening
        statusText = isListening
            ? (hasGlobalHotkeys ? "Ready" : "Hotkeys paused — use menu or grant Accessibility")
            : "Hotkeys paused"
    }

    func openSessionFolder() {
        NSWorkspace.shared.open(sessionFolder)
    }

    func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private var isTransitioningCapture = false

    func toggleCapture() async {
        guard !isTransitioningCapture else { return }
        isTransitioningCapture = true
        defer { isTransitioningCapture = false }

        if isRecording {
            await stopCapture()
        } else {
            await startCapture()
        }
    }

    private func startCapture() async {
        refreshPermissions()

        captureIndex += 1
        let index = captureIndex
        let mouse = CaptureService.mousePosition()

        let shotName = String(format: "shot_%03d.png", index)
        let cropName = String(format: "crop_%03d.png", index)
        let shotPath = sessionFolder.appendingPathComponent(shotName)
        let cropPath = sessionFolder.appendingPathComponent(cropName)

        statusText = "Taking screenshot..."
        do {
            try await CaptureService.captureAndSave(
                shotPath: shotPath,
                cropPath: cropPath,
                mousePoints: mouse
            )
        } catch {
            statusText = error.localizedDescription
            captureIndex -= 1
            return
        }

        let bounds = CGDisplayBounds(CGMainDisplayID())
        let pixelWidth = NSImage(contentsOf: shotPath)?
            .cgImage(forProposedRect: nil, context: nil, hints: nil)?.width ?? Int(bounds.width)
        let scaleFactor = CGFloat(pixelWidth) / bounds.width
        let px = mouse.x * scaleFactor
        let py = mouse.y * scaleFactor

        pending = PendingCapture(
            index: index,
            time: ISO8601DateFormatter().string(from: Date()),
            mousePoints: [Int(mouse.x.rounded()), Int(mouse.y.rounded())],
            mousePixels: [Int(px.rounded()), Int(py.rounded())],
            screenshot: shotName,
            crop: cropName
        )

        do {
            try await recorder.start()
            isRecording = true
            statusText = "Recording note \(index)..."
        } catch {
            statusText = "Mic error: \(error.localizedDescription)"
            pending = nil
            captureIndex -= 1
        }
    }

    private func stopCapture() async {
        guard isRecording else { return }
        isRecording = false
        statusText = "Transcribing..."

        let audioURL = recorder.stop()
        guard var pending else {
            statusText = "Ready"
            return
        }

        var note = ""
        if let audioURL {
            do {
                note = try await TranscriptionService.transcribe(audioURL: audioURL)
                try? FileManager.default.removeItem(at: audioURL)
            } catch {
                note = ""
                statusText = "Transcription failed"
                NSLog("Talkshot transcription error: \(error)")
            }
        }

        let entry = SessionEntry(
            id: pending.index,
            time: pending.time,
            mousePoints: pending.mousePoints,
            mousePixels: pending.mousePixels,
            screenshot: pending.screenshot,
            crop: pending.crop,
            note: note
        )
        entries.append(entry)
        self.pending = nil
        noteCount = entries.count
        writeSessionFiles()
        statusText = note.isEmpty ? "Saved (no speech detected)" : "Saved note \(entry.id)"
    }

    func finishSession() async {
        if isRecording {
            await stopCapture()
        }
        writeSessionFiles()
        let finishedFolder = sessionFolder
        let finishedCount = entries.count
        NSWorkspace.shared.open(finishedFolder)

        (sessionID, sessionFolder) = Self.makeSession()
        entries = []
        pending = nil
        captureIndex = 0
        noteCount = 0
        statusText = "Saved \(finishedCount) notes — ready for a new session"
    }

    private func writeSessionFiles() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(entries) {
            try? data.write(to: sessionFolder.appendingPathComponent("notes.json"))
        }

        var markdown = "# Session \(sessionID)\n\n"
        for entry in entries {
            markdown += """
            ## Note \(entry.id) (\(entry.time))
            Cursor at \(entry.mousePoints) (screen points)

            ![full](\(entry.screenshot))

            ![zoom](\(entry.crop))

            > \(entry.note)

            """
        }
        try? markdown.write(
            to: sessionFolder.appendingPathComponent("notes.md"),
            atomically: true,
            encoding: .utf8
        )
    }
}
