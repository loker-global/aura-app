import Foundation
import CoreAudio
import AVFoundation

/// Represents an audio input device
struct AudioDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let name: String
    let manufacturer: String
    let sampleRate: Double
    let channelCount: Int
    let isDefault: Bool
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: AudioDevice, rhs: AudioDevice) -> Bool {
        lhs.id == rhs.id
    }
}

/// Enumerates CoreAudio input devices
/// Zero state, pure enumeration
final class AudioDeviceRegistry {
    
    // MARK: - Singleton
    
    static let shared = AudioDeviceRegistry()
    
    private init() {}
    
    // MARK: - Device Enumeration
    
    /// Returns list of all available audio input devices
    func availableInputDevices() -> [AudioDevice] {
        var devices: [AudioDevice] = []
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )
        
        guard status == noErr else { return devices }
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )
        
        guard status == noErr else { return devices }
        
        let defaultInputID = defaultInputDeviceID()
        
        for deviceID in deviceIDs {
            if hasInputChannels(deviceID: deviceID) {
                let device = AudioDevice(
                    id: deviceID,
                    name: deviceName(deviceID: deviceID),
                    manufacturer: deviceManufacturer(deviceID: deviceID),
                    sampleRate: deviceSampleRate(deviceID: deviceID),
                    channelCount: inputChannelCount(deviceID: deviceID),
                    isDefault: deviceID == defaultInputID
                )
                devices.append(device)
            }
        }
        
        return devices
    }
    
    /// Returns the default audio input device
    func defaultInputDevice() -> AudioDevice? {
        let devices = availableInputDevices()
        return devices.first { $0.isDefault } ?? devices.first
    }
    
    // MARK: - Private Helpers
    
    private func defaultInputDeviceID() -> AudioDeviceID {
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &size,
            &deviceID
        )
        
        return deviceID
    }
    
    private func hasInputChannels(deviceID: AudioDeviceID) -> Bool {
        return inputChannelCount(deviceID: deviceID) > 0
    }
    
    private func inputChannelCount(deviceID: AudioDeviceID) -> Int {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize
        )
        
        guard status == noErr else { return 0 }
        
        let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
        defer { bufferListPointer.deallocate() }
        
        let getStatus = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            bufferListPointer
        )
        
        guard getStatus == noErr else { return 0 }
        
        let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPointer)
        var channelCount = 0
        for buffer in bufferList {
            channelCount += Int(buffer.mNumberChannels)
        }
        
        return channelCount
    }
    
    private func deviceName(deviceID: AudioDeviceID) -> String {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var name: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        
        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &size,
            &name
        )
        
        return status == noErr ? name as String : "Unknown Device"
    }
    
    private func deviceManufacturer(deviceID: AudioDeviceID) -> String {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceManufacturerCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var manufacturer: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        
        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &size,
            &manufacturer
        )
        
        return status == noErr ? manufacturer as String : "Unknown"
    }
    
    private func deviceSampleRate(deviceID: AudioDeviceID) -> Double {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var sampleRate: Float64 = 0
        var size = UInt32(MemoryLayout<Float64>.size)
        
        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &size,
            &sampleRate
        )
        
        return status == noErr ? sampleRate : 48000.0
    }
}
