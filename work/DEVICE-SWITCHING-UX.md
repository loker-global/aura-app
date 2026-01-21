# DEVICE-SWITCHING-UX — Audio Input Selection

⸻

## 0. PURPOSE

Define how users select and switch audio input devices.

This ensures:
- Clear device discovery
- Safe switching (no mid-recording changes)
- Default device intelligence
- No hidden complexity

⸻

## 1. DEVICE SELECTION RULES

### When Can User Switch?
**IDLE state only** (per ARCHITECTURE.md)

**Blocked during:**
- Recording (must stop first)
- Playback (device locked to playback engine)
- Export (irrelevant, uses file audio)

**Rationale:**
- Switching mid-recording causes buffer discontinuity
- Audio engine restart required (risky during capture)

---

## 2. DEFAULT DEVICE SELECTION

### First Launch
**Use system default input device**

**macOS:** Query CoreAudio for `kAudioHardwarePropertyDefaultInputDevice`

**iOS:** Query AVAudioSession for default input

**Rationale:**
- User expectation (built-in mic "just works")
- No modal on first launch (reduces friction)

---

### Subsequent Launches
**Remember last used device**

**Storage:**
```swift
UserDefaults.standard.set(deviceID, forKey: "lastSelectedAudioDevice")
```

**Validation:**
- On launch, check if last device still exists
- If missing (USB mic unplugged): fall back to system default
- Show subtle notification: "Using built-in microphone"

---

## 3. DEVICE PICKER UI

### macOS

**UI Component:** Dropdown menu (NSPopUpButton) or dedicated panel

**Location:** 
- **Option A (Minimal):** Menu bar → "Input Device" submenu
- **Option B (Visible):** Top-right corner of main window (always visible)

**Recommendation:** Option B (visible, no hidden menu)

**Design:**
```
┌─────────────────────────────┐
│  [🎤 Built-in Microphone ▼] │ ← Dropdown
└─────────────────────────────┘
```

**Expanded:**
```
┌─────────────────────────────┐
│ ✓ Built-in Microphone        │ ← Current selection
│   Blue Yeti USB              │
│   AirPods Pro                │
│   ────────────────────────   │
│   Refresh Device List        │
└─────────────────────────────┘
```

---

### iOS

**UI Component:** Action sheet or modal picker

**Trigger:** Tap microphone icon or "Input Device" button

**Design (Action Sheet):**
```
┌─────────────────────────────┐
│  Select Microphone           │
│  ═══════════════════════     │
│  ✓ iPhone Microphone         │ ← Current
│    AirPods Pro               │
│    Wired Headset             │
│  ─────────────────────────   │
│  Cancel                      │
└─────────────────────────────┘
```

**iOS Specifics:**
- No USB mic support (iOS limitation)
- Show: built-in mic, wired headset, Bluetooth devices

---

## 4. DEVICE LIST CONTENTS

### Information Displayed
```
[Icon] Device Name
       └─ Sample Rate (if non-standard)
```

**Example:**
```
🎤 Built-in Microphone
   48 kHz

🎧 AirPods Pro
   48 kHz (Bluetooth)

🔌 Blue Yeti USB
   44.1 kHz
```

### Icons
- 🎤 Built-in mic
- 🎧 Headset/earbuds
- 🔌 USB mic
- 📡 Bluetooth device

---

## 5. DEVICE LIST REFRESH

### Automatic Refresh
**Trigger:** Device added/removed (CoreAudio notification)

**Behavior:**
- Update list immediately
- If current device removed mid-idle: switch to system default + notify user

**Notification (macOS):**
```
┌─────────────────────────────┐
│ ⚠️ Blue Yeti disconnected    │
│ Switched to Built-in Mic     │
└─────────────────────────────┘
```
- Auto-dismiss after 3 seconds
- Non-blocking (banner style)

---

### Manual Refresh
**Trigger:** "Refresh Device List" button in dropdown

**Use Case:** CoreAudio notification missed, user wants to force rescan

**Behavior:**
- Re-enumerate devices
- Update list
- Maintain current selection if device still exists

---

## 6. DEVICE SWITCHING FLOW

### User Workflow
1. User in IDLE state
2. Opens device dropdown
3. Selects new device
4. Dropdown closes
5. AudioCaptureEngine restarts with new device
6. Orb continues (live input from new device)

### Engine Restart
```swift
func switchAudioDevice(to deviceID: String) {
    guard state == .idle else { 
        showError("Cannot switch device while recording")
        return 
    }
    
    audioEngine.stop()
    audioEngine.inputDevice = deviceID
    audioEngine.start()
    
    UserDefaults.standard.set(deviceID, forKey: "lastSelectedAudioDevice")
}
```

---

## 7. ERROR HANDLING

### Device Unavailable
**Scenario:** User selects device, but initialization fails

**Causes:**
- Device in use by another app
- Permission denied
- Hardware failure

**Behavior:**
- Show error: "Could not access [Device Name]"
- Revert to previous device (or system default)
- Do NOT crash or hang

---

### Permission Denied (First Time)
**macOS:** Show system permission dialog
**iOS:** Show system AVAudioSession permission dialog

**If user denies:**
- Show error: "Microphone access required"
- Provide "Open Settings" button
- Do NOT allow recording (state remains IDLE)

---

## 8. DEVICE METADATA

### Sample Rate Handling
**Preferred:** 48 kHz

**If device only supports 44.1 kHz:**
- Accept it (no resampling in AURA)
- Display sample rate in device list
- Record at native rate

**If device supports >48 kHz (96 kHz, 192 kHz):**
- Use 48 kHz (sufficient for voice, reduces file size)
- No benefit to higher rates for speech

---

### Channel Handling
**Preferred:** Mono (single channel)

**If device only supports stereo:**
- Use left channel only (discard right)
- Or: mix down to mono (average L+R)

**Rationale:** Voice is single source, stereo is wasted bandwidth

---

## 9. BLUETOOTH DEVICE CONSIDERATIONS

### Latency Warning
Bluetooth devices have ~100-200ms latency.

**UI Note:**
- Show "Bluetooth" badge next to device name
- Optional: Show tooltip "May have slight delay in orb response"

**No blocking:** User can still record, but aware of trade-off

---

### Connection Stability
**Scenario:** Bluetooth device disconnects mid-recording

**Behavior:**
- Continue recording if possible (fall back to built-in mic)
- Or: Stop recording gracefully, save partial file
- Notify user: "Bluetooth device disconnected. Recording stopped."

---

## 10. DEVICE-SPECIFIC SETTINGS (OUT OF SCOPE V1)

**Not included:**
- Gain control (use system settings)
- EQ / filters (violates "no voice alteration" rule)
- Monitoring (no headphone output routing)

**Rationale:** AURA trusts system audio config, doesn't duplicate settings

---

## 11. ACCESSIBILITY

### VoiceOver (macOS/iOS)
- Dropdown announces current device
- Device list items announced clearly
- Selection confirmed with audio feedback

### Keyboard Navigation (macOS)
- Cmd+D opens device dropdown
- Arrow keys navigate list
- Enter selects device
- Esc closes without changing

---

## 12. TESTING SCENARIOS

### Functional Tests
- [ ] Select device from list → audio switches
- [ ] Unplug USB mic mid-idle → falls back to built-in
- [ ] Unplug USB mic mid-recording → recording stops gracefully
- [ ] Bluetooth device disconnects → notification shown
- [ ] Permission denied → error shown, settings link works

### Edge Cases
- [ ] Zero input devices (headless Mac?) → show error, disable recording
- [ ] Device list changes while dropdown open → refresh list
- [ ] Rapidly switch devices → no crashes or audio glitches

---

## 13. IMPLEMENTATION NOTES

### macOS (CoreAudio)
```swift
import CoreAudio

func enumerateAudioDevices() -> [AudioDevice] {
    var propertySize: UInt32 = 0
    var propertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
    
    AudioObjectGetPropertyDataSize(
        AudioObjectID(kAudioObjectSystemObject),
        &propertyAddress,
        0, nil, &propertySize
    )
    
    // ... enumerate devices with input channels
}
```

### iOS (AVAudioSession)
```swift
import AVFoundation

func enumerateAudioDevices() -> [AVAudioSessionPortDescription] {
    let session = AVAudioSession.sharedInstance()
    return session.availableInputs ?? []
}
```

---

## FINAL PRINCIPLE

Device switching must be obvious and safe.

User should never lose audio or feel uncertain.

⸻

**Status:** Device switching UX locked
