import AVFoundation
import CoreAudio

enum AudioDeviceSelector {
    /// Partial name match to force a specific mic. nil = respect the system default input
    /// (System Settings → Sound → Input), which follows whatever device (AirPods, etc.) is selected there.
    static let preferredDeviceName: String? = nil

    static func configureInput(for engine: AVAudioEngine) throws {
        guard let name = preferredDeviceName else { return }
        guard let deviceID = findInputDevice(matching: name) else {
            NSLog("Talkshot: preferred mic '\(name)' not found, using system default")
            return
        }
        let input = engine.inputNode
        guard let audioUnit = input.audioUnit else { return }
        var device = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &device,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        if status != noErr {
            NSLog("Talkshot: failed to set input device (status \(status))")
        }
    }

    static func currentInputName() -> String {
        if let name = preferredDeviceName,
           let id = findInputDevice(matching: name),
           let deviceName = deviceName(id) {
            return deviceName
        }
        return "System Default"
    }

    private static func findInputDevice(matching needle: String) -> AudioDeviceID? {
        let lower = needle.lowercased()
        for id in allInputDevices() {
            if let name = deviceName(id), name.lowercased().contains(lower) {
                return id
            }
        }
        return nil
    }

    private static func allInputDevices() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize
        ) == noErr else { return [] }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize,
            &ids
        ) == noErr else { return [] }

        return ids.filter { hasInputChannels($0) }
    }

    private static func hasInputChannels(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize) == noErr else {
            return false
        }
        let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
        defer { bufferList.deallocate() }
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, bufferList) == noErr else {
            return false
        }
        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        return buffers.reduce(0) { $0 + Int($1.mNumberChannels) } > 0
    }

    private static func deviceName(_ deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &name) == noErr else {
            return nil
        }
        return name as String
    }
}
