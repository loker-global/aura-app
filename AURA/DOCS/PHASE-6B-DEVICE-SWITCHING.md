# Phase 6B: Audio Device Switching - IN PROGRESS

**Date:** January 21, 2026  
**Status:** 🔨 **IN PROGRESS**  
**Build:** ✅ Success

---

## Progress Summary

### ✅ Completed
1. **AudioDeviceManager.swift** - Core device management system
   - CoreAudio device enumeration
   - Device property detection (name, sample rate, transport type)
   - Device list monitoring and hot-plug detection
   - User preference persistence
   - Automatic fallback to default device

2. **AudioCaptureEngine Enhancements**
   - Device selection support
   - Device switching capability
   - CoreAudio device ID integration

### 🔨 In Progress
3. Device Picker UI (next)
4. Integration with Coordinator
5. UI testing and refinement

### ⏳ Remaining
- Export Presets
- Settings Panel
- App Icon & Branding

---

## What Was Built

### 1. AudioDeviceManager System

**File:** `Shared/Audio/AudioDeviceManager.swift` (500+ lines)

**Core Features:**
- ✅ Enumerate all audio input devices via CoreAudio
- ✅ Detect device properties (name, sample rate, channels, transport type)
- ✅ Monitor device connections/disconnections
- ✅ Persist user device preference
- ✅ Auto-select default device on first launch
- ✅ Fall back to default if preferred device unavailable

**Architecture:**
```swift
class AudioDeviceManager {
    static let shared: AudioDeviceManager
    
    var availableDevices: [AudioDeviceInfo]
    var selectedDevice: AudioDeviceInfo?
    
    var onDevicesChanged: (() -> Void)?
    var onSelectedDeviceChanged: ((AudioDeviceInfo?) -> Void)?
    
    func refreshDeviceList()
    func selectDevice(_ device: AudioDeviceInfo)
    func selectDefaultDevice()
}

struct AudioDeviceInfo {
    let id: AudioDeviceID
    let name: String
    let manufacturer: String
    let sampleRate: Double
    let channelCount: UInt32
    let transportType: TransportType
    
    func toAudioDevice() -> AudioDevice  // Convert to AppState model
}
```

**Device Transport Types:**
- 🎤 Built-in (internal microphone)
- 🔌 USB (external USB mics)
- 📡 Bluetooth (wireless devices)
- 🔗 Aggregate (multi-device setups)
- 💻 Virtual (software devices)

**Device Information Displayed:**
```
🎤 Built-in Microphone
🔌 Blue Yeti USB (USB)
📡 AirPods Pro (Bluetooth)
```

---

### 2. AudioCaptureEngine Enhancements

**File:** `Shared/Audio/AudioCaptureEngine.swift`

**New Capabilities:**
```swift
// Start capture with specific device
func startCapture(deviceID: AudioDeviceID? = nil) -> Result<Void, AudioError>

// Switch device (stops and restarts with new device)
func switchDevice(_ deviceID: AudioDeviceID) -> Result<Void, AudioError>

// Set input device on AVAudioEngine
private func setInputDevice(_ deviceID: AudioDeviceID, for engine: AVAudioEngine)
```

**How It Works:**
1. User selects device from picker
2. AudioDeviceManager updates selection
3. AudioCaptureEngine switches to new device
4. Audio processing continues with new input

---

## Device Lifecycle

### First Launch
```
1. AudioDeviceManager initializes
2. Enumerates all input devices
3. Selects system default device
4. Saves preference
```

### Subsequent Launch
```
1. AudioDeviceManager initializes
2. Loads last used device ID
3. Checks if device still exists
4. If yes: select it
5. If no: fall back to default + notify user
```

### Device Disconnect (Mid-Idle)
```
1. CoreAudio fires notification
2. AudioDeviceManager detects change
3. Removes device from list
4. If was selected: switch to default
5. Notify user: "Blue Yeti disconnected. Switched to Built-in Mic"
```

### Device Disconnect (Mid-Recording)
```
1. CoreAudio fires notification
2. Recording stops gracefully
3. Partial file saved
4. User notified: "Blue Yeti disconnected. Recording stopped."
```

---

## Technical Implementation

### CoreAudio Device Enumeration
```swift
// Get all devices
var propertyAddress = AudioObjectPropertyAddress(
    mSelector: kAudioHardwarePropertyDevices,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain
)

AudioObjectGetPropertyData(
    AudioObjectID(kAudioObjectSystemObject),
    &propertyAddress,
    0, nil,
    &propertySize,
    &deviceIDs
)

// Filter for input devices
for deviceID in deviceIDs {
    guard hasInputChannels(deviceID) else { continue }
    // ... extract device info
}
```

### Device Property Queries
```swift
// Name
kAudioObjectPropertyName

// Sample Rate
kAudioDevicePropertyNominalSampleRate

// Transport Type  
kAudioDevicePropertyTransportType

// Channel Count
kAudioDevicePropertyStreamConfiguration
```

### Hot-Plug Detection
```swift
AudioObjectAddPropertyListenerBlock(
    AudioObjectID(kAudioObjectSystemObject),
    &propertyAddress,
    nil
) { [weak self] _, _ in
    DispatchQueue.main.async {
        self?.handleDeviceListChanged()
    }
}
```

---

## Integration Points

### With AppState
- `AudioDeviceInfo.toAudioDevice()` converts to existing `AudioDevice` model
- Preserves existing state machine integration
- No breaking changes to current architecture

### With AudioCaptureEngine
- Engine now accepts optional `deviceID` parameter
- Switches device by restarting engine
- Safe during IDLE state only

### With UserDefaults
```swift
// Save preference
UserDefaults.standard.set(deviceID, forKey: "lastSelectedAudioDevice")

// Restore preference
if let lastDeviceID = UserDefaults.standard.object(forKey: ...) as? AudioDeviceID {
    selectDevice(byID: lastDeviceID)
}
```

---

## Next Steps

### 1. Device Picker UI (Next Task)
**Goal:** Visual dropdown for device selection

**Implementation:**
- `NSPopUpButton` with device list
- Display device icons + names
- Checkmark for current device
- "Refresh Device List" option
- Position: Top-right of main window

**Mockup:**
```
┌─────────────────────────────┐
│  [🎤 Built-in Microphone ▼] │
└─────────────────────────────┘

Expanded:
┌─────────────────────────────┐
│ ✓ Built-in Microphone        │
│   Blue Yeti USB              │
│   AirPods Pro                │
│   ────────────────────────   │
│   Refresh Device List        │
└─────────────────────────────┘
```

### 2. Coordinator Integration
- Connect AudioDeviceManager to AuraCoordinator
- Handle device changes during different states
- Update error handling for device failures

### 3. Testing
- [ ] List all devices correctly
- [ ] Switch between devices
- [ ] Handle device disconnect gracefully
- [ ] Persist preference across sessions
- [ ] Fall back to default when needed

---

## Files Created/Modified

**Created:**
- ✅ `Shared/Audio/AudioDeviceManager.swift` (500+ lines)

**Modified:**
- ✅ `Shared/Audio/AudioCaptureEngine.swift`
  - Added `deviceID` parameter to `startCapture()`
  - Added `switchDevice()` method
  - Added `setInputDevice()` helper

**Build Status:** ✅ Success, no errors

---

## Design Decisions

### Why Separate AudioDeviceInfo?
- Existing `AudioDevice` in `AppState.swift` is simple (id, name, sampleRate)
- `AudioDeviceInfo` adds CoreAudio-specific data (transport type, channels, manufacturer)
- Clean conversion via `toAudioDevice()` maintains compatibility
- No breaking changes to existing code

### Why Singleton Pattern?
- Single source of truth for device state
- Centralized notification handling
- Easy access from any component
- Matches AudioCaptureEngine pattern

### Why CoreAudio Instead of AVFoundation?
- AVFoundation device enumeration is limited on macOS
- CoreAudio provides full device metadata
- Needed for USB/Bluetooth device detection
- Required for hot-plug monitoring

---

## References

- Spec: `work/DEVICE-SWITCHING-UX.md`
- Phase Plan: `PHASE-6B-PLAN.md`
- Previous: `ERROR-UI-COMPLETE.md`

---

**Status:** Core device management complete, UI integration next! 🎤
