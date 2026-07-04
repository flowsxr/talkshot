import AppKit
import AVFoundation
import ApplicationServices

enum PermissionsService {
    static func hasAccessibility() -> Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func requestAccessibility() -> Bool {
        if AXIsProcessTrusted() { return true }
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func hasScreenRecording() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    static func hasMicrophone() async -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    static func requestMicrophone() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    static func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }

    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    static func missingPermissions() async -> [String] {
        var missing: [String] = []
        if !hasScreenRecording() { missing.append("Screen Recording") }
        if !hasAccessibility() { missing.append("Accessibility") }
        if await !hasMicrophone() { missing.append("Microphone") }
        return missing
    }
}
