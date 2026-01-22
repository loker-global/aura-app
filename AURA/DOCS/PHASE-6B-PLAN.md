# Phase 6B Plan: Device Switching & Settings

**Date:** January 21, 2026  
**Status:** 🎯 **READY TO START**  
**Previous:** Phase 6A Complete ✅

---

## Overview

Phase 6A is complete with all production polish features:
- ✅ Video Export (H.264, Metal rendering)
- ✅ Audio Feature Timeline (record/replay)
- ✅ Camera/POV Fixes
- ✅ Silence Handling (3-phase system)
- ✅ Error UI Polish

**Phase 6B** focuses on user control and customization:

---

## Phase 6B Features

### 1. Audio Device Switching 🎤

**Goal:** Let users select their audio input device.

**Spec:** `work/DEVICE-SWITCHING-UX.md`

**Implementation:**
- `AudioDeviceManager.swift` - Enumerate devices, handle changes
- Device picker in menu bar or toolbar
- Auto-select default device on launch
- Handle device connect/disconnect gracefully
- Persist device preference

**UI Elements:**
```
┌────────────────────────────────┐
│  Microphone: [Built-in    ▼]  │
└────────────────────────────────┘
```

**States:**
- Show current device name
- Dropdown with available devices
- "No device" fallback state
- Live switching during recording (if safe)

---

### 2. Settings Panel ⚙️

**Goal:** Centralized settings interface.

**Features:**
- Audio device selection
- Export quality presets
- Keyboard shortcuts reference
- About/version info

**UI Design:**
```
┌─────────────────────────────────────┐
│          AURA Settings              │
├─────────────────────────────────────┤
│  Audio                              │
│    Microphone: [Built-in    ▼]     │
│    Sample Rate: [48000 Hz   ▼]     │
│                                     │
│  Export                             │
│    Quality: [High (1080p60)  ▼]    │
│    Codec: [H.264             ▼]    │
│                                     │
│  Keyboard Shortcuts                 │
│    [View Shortcuts...]              │
│                                     │
│  About                              │
│    Version: 1.0.0                   │
│    Phase: 6B                        │
│                                     │
│           [Close]                   │
└─────────────────────────────────────┘
```

**Access:**
- Menu: AURA → Settings... (⌘,)
- Keyboard shortcut: ⌘,

---

### 3. Export Presets 📦

**Goal:** Quick quality/size tradeoffs.

**Presets:**

| Preset | Resolution | FPS | Bitrate | Size (1 min) |
|--------|-----------|-----|---------|--------------|
| High   | 1920×1080 | 60  | 8 Mbps  | ~60 MB |
| Medium | 1280×720  | 60  | 4 Mbps  | ~30 MB |
| Low    | 1280×720  | 30  | 2 Mbps  | ~15 MB |

**Implementation:**
```swift
enum ExportPreset {
    case high    // 1080p60, 8Mbps
    case medium  // 720p60, 4Mbps
    case low     // 720p30, 2Mbps
    
    var settings: VideoExportSettings {
        // Returns appropriate settings
    }
}
```

**UI:**
- Preset selector in export dialog
- Show estimated file size
- Save preference per-user

---

### 4. App Icon & Branding 🎨

**Goal:** Professional appearance.

**Tasks:**
- Design app icon (orb-inspired)
- Create app icon set (.appiconset)
- Update bundle display name
- About window with branding
- Menu bar icon (if using status bar)

**Icon Concept:**
- Centered orb/sphere
- Gradient (blue → purple)
- Sound waves emanating
- Clean, modern aesthetic

---

## Implementation Order

1. **Audio Device Switching** (1-2 hours)
   - AudioDeviceManager.swift
   - Device picker UI
   - State integration

2. **Export Presets** (30 min)
   - Preset enum
   - Settings integration
   - UI selector

3. **Settings Panel** (1 hour)
   - Settings window
   - Preference storage
   - Menu integration

4. **App Icon** (1 hour)
   - Icon design
   - Asset integration
   - About window

---

## Files to Create

1. `Shared/Audio/AudioDeviceManager.swift` - Device enumeration
2. `Shared/Settings/SettingsManager.swift` - Preference storage
3. `Shared/Settings/ExportPreset.swift` - Export presets
4. `macOS/Views/SettingsWindow.swift` - Settings UI
5. `macOS/Views/AboutWindow.swift` - About dialog

---

## Testing Checklist

### Device Switching
- [ ] List all available audio devices
- [ ] Switch between devices
- [ ] Handle device disconnection
- [ ] Persist device preference
- [ ] Fallback to default if preferred unavailable

### Export Presets
- [ ] High preset (1080p60)
- [ ] Medium preset (720p60)
- [ ] Low preset (720p30)
- [ ] File size estimates accurate
- [ ] Quality differences visible

### Settings Panel
- [ ] Opens with ⌘,
- [ ] Shows current settings
- [ ] Changes persist
- [ ] Keyboard shortcuts reference
- [ ] About info correct

---

## Success Criteria

✅ Users can select their audio input device  
✅ Device changes are handled gracefully  
✅ Multiple export quality presets available  
✅ Settings panel accessible and intuitive  
✅ App has professional icon and branding  
✅ All preferences persist across sessions  

---

## Future (Phase 6C+)

- [ ] Advanced export options (frame rate, codec)
- [ ] Timeline compression for large files
- [ ] Binary timeline format
- [ ] Deformation map in timeline
- [ ] Export profiles (YouTube, Twitter, etc.)
- [ ] Batch export
- [ ] Custom keyboard shortcuts

---

## Next Steps

1. Read `work/DEVICE-SWITCHING-UX.md` for detailed spec
2. Implement `AudioDeviceManager.swift`
3. Create device picker UI
4. Test with multiple audio devices
5. Document changes

Ready to start Phase 6B! 🚀
