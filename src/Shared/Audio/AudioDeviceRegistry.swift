// SPDX-License-Identifier: MIT
// AURA — Turn voice into a living fingerprint
// AudioDeviceRegistry.swift — CoreAudio input device enumeration

import AVFoundation
#if os(macOS)
import CoreAudio
#endif

// MARK: - AudioDevice Model

/// Represents an audio input device with its properties.
/// This model is platform-independent and used across iOS and macOS.
public struct AudioDevice: Identifiable, Equatable, Hashable {
    /// Unique identifier for the device
    public let id: String
    
    /// Human-readable name of the device
    public let name: String
    
    /// Supported sample rate (preferred: 48000)
    public let sampleRate: Double
    
    /// Number of input channels
    public let channelCount: Int
    
    /// Device type for UI display
    public let deviceType: DeviceType
    
    /// Whether this is the system default device
    public let isDefault: Bool
    
    public enum DeviceType: String, CaseIterable {
        case builtIn = "Built-in"
        case usb = "USB"
        case bluetooth = "Bluetooth"
        case external = "External"
        case unknown = "Unknown"
    }
    
    public init(
        id: String,
        name: String,
        sampleRate: Double,
        channelCount: Int,
        deviceType: DeviceType,
        isDefault: Bool
    ) {
        self.id = id
        self.name = name
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.deviceType = deviceType
        self.isDefault = isDefault
    }
}

// MARK: - AudioDeviceRegistry Protocol

/// Protocol defining the interface for audio device enumeration.
/// Implementations are platform-specific (macOS via CoreAudio, iOS via AVAudioSession).
public protocol AudioDeviceRegistryProtocol {
    /// Returns all available audio input devices
    func enumerateInputDevices() -> [AudioDevice]
    
    /// Returns the current system default input device
    func defaultInputDevice() -> AudioDevice?
    
    /// Observes device list changes
    func startObservingDeviceChanges(callback: @escaping ([AudioDevice]) -> Void)
    
    /// Stops observing device changes
    func stopObservingDeviceChanges()
}

// MARK: - macOS Implementation

#if os(macOS)

/// macOS implementation using CoreAudio for device enumeration.
/// Zero state, pure enumeration as per ARCHITECTURE.md.
public final class AudioDeviceRegistry: AudioDeviceRegistryProtocol {
    
    // MARK: - Properties
    
    private var deviceChangeCallback: (([AudioDevice]) -> Void)?
    private var listenerBlock: AudioObjectPropertyListenerBlock?
    
    // MARK: - Initialization
    
    public init() {}
    
    deinit {
        stopObservingDeviceChanges()
    }
    
    // MARK: - Public Methods
    
    /// Enumerates all audio input devices using CoreAudio.
    /// Returns device list with IDs, names, sample rates.
    public func enumerateInputDevices() -> [AudioDevice] {
        var devices: [AudioDevice] = []
        
        // Get all audio devices
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var propertySize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize
        )
        
        guard status == noErr else { return devices }
        
        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceIDs
        )
        
        guard status == noErr else { return devices }
        
        let defaultDeviceID = getDefaultInputDeviceID()
        
        // Filter to input devices only
        for deviceID in deviceIDs {
            guard hasInputChannels(deviceID: deviceID) else { continue }
            
            if let device = createAudioDevice(
                deviceID: deviceID,
                isDefault: deviceID == defaultDeviceID
            ) {
                devices.append(device)
            }
        }
        
        return devices
    }
    
    /// Returns the current system default input device.
    public func defaultInputDevice() -> AudioDevice? {
        let deviceID = getDefaultInputDeviceID()
        guard deviceID != kAudioObjectUnknown else { return nil }
        return createAudioDevice(deviceID: deviceID, isDefault: true)
    }
    
    /// Starts observing device list changes.
    public func startObservingDeviceChanges(callback: @escaping ([AudioDevice]) -> Void) {
        self.deviceChangeCallback = callback
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        listenerBlock = { [weak self] _, _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                let devices = self.enumerateInputDevices()
                self.deviceChangeCallback?(devices)
            }
        }
        
        if let block = listenerBlock {
            AudioObjectAddPropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &propertyAddress,
                DispatchQueue.main,
                block
            )
        }
    }
    
    /// Stops observing device changes.
    public func stopObservingDeviceChanges() {
        guard let block = listenerBlock else { return }
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            DispatchQueue.main,
            block
        )
        
        listenerBlock = nil
        deviceChangeCallback = nil
    }
    
    // MARK: - Private Methods
    
    private func getDefaultInputDeviceID() -> AudioDeviceID {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceID
        )
        
        return deviceID
    }
    
    private func hasInputChannels(deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var propertySize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize
        )
        
        guard status == noErr, propertySize > 0 else { return false }
        
        let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(
            capacity: Int(propertySize) / MemoryLayout<AudioBufferList>.size + 1
        )
        defer { bufferListPointer.deallocate() }
        
        let result = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            bufferListPointer
        )
        
        guard result == noErr else { return false }
        
        let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPointer)
        return bufferList.reduce(0) { $0 + Int($1.mNumberChannels) } > 0
    }
    
    private func createAudioDevice(deviceID: AudioDeviceID, isDefault: Bool) -> AudioDevice? {
        // Get device name
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var name: CFString = "" as CFString
        var propertySize = UInt32(MemoryLayout<CFString>.size)
        
        AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &name
        )
        
        let deviceName = name as String
        
        // Get sample rate
        propertyAddress.mSelector = kAudioDevicePropertyNominalSampleRate
        var sampleRate: Float64 = 48000.0
        propertySize = UInt32(MemoryLayout<Float64>.size)
        
        AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &sampleRate
        )
        
        // Get channel count
        let channelCount = getInputChannelCount(deviceID: deviceID)
        
        // Determine device type
        let deviceType = inferDeviceType(name: deviceName, deviceID: deviceID)
        
        return AudioDevice(
            id: String(deviceID),
            name: deviceName,
            sampleRate: sampleRate,
            channelCount: channelCount,
            deviceType: deviceType,
            isDefault: isDefault
        )
    }
    
    private func getInputChannelCount(deviceID: AudioDeviceID) -> Int {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var propertySize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize
        ) == noErr else { return 0 }
        
        let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(
            capacity: Int(propertySize) / MemoryLayout<AudioBufferList>.size + 1
        )
        defer { bufferListPointer.deallocate() }
        
        guard AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            bufferListPointer
        ) == noErr else { return 0 }
        
        let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPointer)
        return bufferList.reduce(0) { $0 + Int($1.mNumberChannels) }
    }
    
    private func inferDeviceType(name: String, deviceID: AudioDeviceID) -> AudioDevice.DeviceType {
        let lowercaseName = name.lowercased()
        
        if lowercaseName.contains("built-in") || lowercaseName.contains("macbook") {
            return .builtIn
        } else if lowercaseName.contains("usb") || lowercaseName.contains("yeti") ||
                    lowercaseName.contains("blue") || lowercaseName.contains("rode") {
            return .usb
        } else if lowercaseName.contains("airpods") || lowercaseName.contains("bluetooth") {
            return .bluetooth
        } else {
            // Check transport type via CoreAudio
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyTransportType,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            
            var transportType: UInt32 = 0
            var propertySize = UInt32(MemoryLayout<UInt32>.size)
            
            if AudioObjectGetPropertyData(
                deviceID,
                &propertyAddress,
                0,
                nil,
                &propertySize,
                &transportType
            ) == noErr {
                switch transportType {
                case kAudioDeviceTransportTypeBuiltIn:
                    return .builtIn
                case kAudioDeviceTransportTypeUSB:
                    return .usb
                case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
                    return .bluetooth
                default:
                    return .external
                }
            }
            
            return .unknown
        }
    }
}

#endif

// MARK: - iOS Implementation

#if os(iOS)

/// iOS implementation using AVAudioSession for device enumeration.
public final class AudioDeviceRegistry: AudioDeviceRegistryProtocol {
    
    // MARK: - Properties
    
    private var deviceChangeCallback: (([AudioDevice]) -> Void)?
    private var routeChangeObserver: NSObjectProtocol?
    
    // MARK: - Initialization
    
    public init() {}
    
    deinit {
        stopObservingDeviceChanges()
    }
    
    // MARK: - Public Methods
    
    /// Enumerates all audio input devices using AVAudioSession.
    public func enumerateInputDevices() -> [AudioDevice] {
        let session = AVAudioSession.sharedInstance()
        guard let inputs = session.availableInputs else { return [] }
        
        let currentInput = session.currentRoute.inputs.first
        
        return inputs.map { port in
            AudioDevice(
                id: port.uid,
                name: port.portName,
                sampleRate: session.sampleRate,
                channelCount: port.channels?.count ?? 1,
                deviceType: mapPortType(port.portType),
                isDefault: port.uid == currentInput?.uid
            )
        }
    }
    
    /// Returns the current system default input device.
    public func defaultInputDevice() -> AudioDevice? {
        let session = AVAudioSession.sharedInstance()
        guard let currentInput = session.currentRoute.inputs.first else { return nil }
        
        return AudioDevice(
            id: currentInput.uid,
            name: currentInput.portName,
            sampleRate: session.sampleRate,
            channelCount: currentInput.channels?.count ?? 1,
            deviceType: mapPortType(currentInput.portType),
            isDefault: true
        )
    }
    
    /// Starts observing device list changes.
    public func startObservingDeviceChanges(callback: @escaping ([AudioDevice]) -> Void) {
        self.deviceChangeCallback = callback
        
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            let devices = self.enumerateInputDevices()
            self.deviceChangeCallback?(devices)
        }
    }
    
    /// Stops observing device changes.
    public func stopObservingDeviceChanges() {
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
            routeChangeObserver = nil
        }
        deviceChangeCallback = nil
    }
    
    // MARK: - Private Methods
    
    private func mapPortType(_ portType: AVAudioSession.Port) -> AudioDevice.DeviceType {
        switch portType {
        case .builtInMic:
            return .builtIn
        case .headsetMic:
            return .external
        case .bluetoothHFP, .bluetoothA2DP, .bluetoothLE:
            return .bluetooth
        default:
            return .unknown
        }
    }
}

#endif
