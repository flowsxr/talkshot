import AppKit
import ApplicationServices

struct HotkeyBinding {
    let label: String
    let required: NSEvent.ModifierFlags
    let key: String
}

enum HotkeyConfig {
    static let note = HotkeyBinding(
        label: "⌃⌥N",
        required: [.control, .option],
        key: "n"
    )
    static let finish = HotkeyBinding(
        label: "⌃⌥E",
        required: [.control, .option],
        key: "e"
    )
}

final class HotkeyService {
    var onHotkey: (() -> Void)?
    var onQuitKey: (() -> Void)?
    private(set) var hasGlobalAccess = false

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var lastFire: TimeInterval = 0
    private let debounce: TimeInterval = 0.35

    var isListening = false {
        didSet {
            if isListening {
                startMonitors()
            } else {
                stopMonitors()
            }
        }
    }

    deinit {
        stopMonitors()
    }

    static func requestAccessibility(prompt: Bool = true) -> Bool {
        PermissionsService.requestAccessibility()
    }

    private func startMonitors() {
        stopMonitors()
        hasGlobalAccess = PermissionsService.hasAccessibility()

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event)
            return event
        }

        if globalMonitor == nil {
            hasGlobalAccess = false
            NSLog("Talkshot: global hotkeys unavailable — grant Accessibility permission")
        }
    }

    private func stopMonitors() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    private func handle(_ event: NSEvent) {
        guard matches(event, binding: HotkeyConfig.note) else {
            if matches(event, binding: HotkeyConfig.finish) {
                fire(onQuitKey)
            }
            return
        }
        fire(onHotkey)
    }

    private func matches(_ event: NSEvent, binding: HotkeyBinding) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard binding.required.isSubset(of: flags),
              !flags.contains(.command),
              !flags.contains(.shift)
        else { return false }
        return event.charactersIgnoringModifiers?.lowercased() == binding.key
    }

    private func fire(_ action: (() -> Void)?) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastFire >= debounce else { return }
        lastFire = now
        action?()
    }
}
