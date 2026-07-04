import SwiftUI

@main
struct TalkshotApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("Talkshot", systemImage: appState.menuBarIcon) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Talkshot")
                    .font(.headline)
                Text(appState.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Mic: \(appState.micName)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Notes: \(appState.noteCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(appState.hotkeyHint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            Divider()

            Button(appState.isRecording ? "Stop Recording" : "Take Note") {
                Task { await appState.toggleCapture() }
            }

            Button(appState.isListening ? "Disable Hotkeys" : "Enable Hotkeys") {
                appState.toggleListening()
            }

            if !appState.hasScreenRecording {
                Button("Open Screen Recording Settings…") {
                    appState.openScreenRecordingSettings()
                }
            }

            if !appState.hasGlobalHotkeys {
                Button("Grant Accessibility Permission…") {
                    appState.requestAccessibility()
                }
            }

            Button("Finish Session") {
                Task { await appState.finishSession() }
            }

            Button("Open Session Folder") {
                appState.openSessionFolder()
            }

            Divider()

            Button("Quit Talkshot") {
                appState.quitApp()
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
