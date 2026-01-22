# PHASE 6: POLISH & PRODUCTION FEATURES

## Status
**READY TO BEGIN** ✅

Phases 1-5 complete and fully functional.

---

## Overview

Phase 6 focuses on production polish, additional features, and preparing AURA for real-world use. All core functionality (audio, rendering, recording, keyboard control) is working.

---

## Objectives

### 1. Video Export 🎥
Implement H.264 video export as specified in `EXPORT-SPEC.md`

**Features:**
- Export orb visualization to video
- H.264 codec, 1080p60, 8Mbps
- AAC audio sync
- Progress indicator
- Export presets (quality/size tradeoffs)

**Implementation:**
- `VideoExporter.swift` using AVFoundation
- `AVAssetWriter` for video composition
- Metal texture → CVPixelBuffer pipeline
- Audio + video sync at 60fps

**UI:**
- Export button in main window
- Progress modal during export
- Success notification with file path

---

### 2. Audio Device Switching 🎤
Implement device picker as specified in `DEVICE-SWITCHING-UX.md`

**Features:**
- Dropdown menu to select audio input device
- Auto-select default device on launch
- Handle device connect/disconnect gracefully
- Show current device in UI

**Implementation:**
- `AudioDeviceManager.swift`
- Observe `AVCaptureDevice` notifications
- Update UI when devices change
- Persist device preference

**UI:**
- Device picker in menu bar or settings
- Current device indicator
- "No device" fallback state

---

### 3. Enhanced Silence Handling 🌊
Implement 3-phase silence behavior from `SILENCE-HANDLING.md`

**Features:**
- Phase 1: Active (voice present) - responsive
- Phase 2: Recent (< 2s) - gradual settling
- Phase 3: Ambient (> 2s) - slow breathing motion

**Implementation:**
- Enhance `OrbPhysics.swift` with silence states
- Add ambient motion oscillator
- Smooth transitions between states
- Configurable thresholds

---

### 4. Improved Error Handling ⚠️
Implement user-friendly errors from `ERROR-MESSAGES.md`

**Features:**
- Calm, helpful error messages
- Clear recovery actions
- No technical jargon
- Safe exit paths

**Implementation:**
- `ErrorPresenter.swift` for UI alerts
- Localized error strings
- Error recovery suggestions
- Graceful degradation

**UI:**
- Modal alerts with clear actions
- In-app error indicators
- Help/troubleshooting links

---

### 5. Settings & Preferences ⚙️
Add user preferences for customization

**Features:**
- Recording location preference
- Audio quality settings
- Orb appearance tweaks
- Keyboard shortcut customization

**Implementation:**
- `UserDefaults` for persistence
- Settings window/panel
- Live preview of changes
- Reset to defaults

**UI:**
- Settings window (Cmd+,)
- Organized sections
- Tooltips for clarity

---

### 6. Testing & QA 🧪
Comprehensive testing per `TESTING-SCENARIOS.md`

**Unit Tests:**
- Audio processing accuracy
- Physics determinism
- File handling edge cases
- State transitions

**Integration Tests:**
- Audio → Physics → Render pipeline
- Recording start/stop
- Device switching
- Export workflow

**Manual Tests:**
- Long recording sessions (> 10 min)
- Rapid start/stop cycles
- Device hotplug
- Low memory scenarios

**Performance:**
- 60fps sustained during recording
- Audio latency < 50ms
- Memory < 150MB typical usage
- CPU < 30% during active recording

---

### 7. Documentation 📚
User-facing documentation and guides

**Documents to Create:**
- `USER-GUIDE.md` - How to use AURA
- `SHORTCUTS.md` - Keyboard reference
- `FAQ-USER.md` - Common questions
- `RELEASE-NOTES.md` - Version history

**Content:**
- Getting started tutorial
- Recording workflow
- Export instructions
- Troubleshooting tips

---

### 8. App Icon & Branding 🎨
Professional app icon and visual identity

**Deliverables:**
- App icon (1024×1024 master)
- macOS icon set (.icns)
- About window graphics
- Launch screen (if needed)

**Design:**
- Reflects orb aesthetic
- Clean, minimal design
- Works at all sizes
- Follows macOS guidelines

---

### 9. Build & Distribution 📦
Prepare for distribution

**Tasks:**
- Release build configuration
- Code signing with production certificate
- Notarization for Gatekeeper
- DMG installer creation
- Version numbering strategy

**Targets:**
- Direct distribution (website)
- Mac App Store (optional)
- TestFlight beta (optional)

---

### 10. Performance Optimization 🚀
Profile and optimize critical paths

**Areas:**
- Metal rendering efficiency
- Audio buffer processing
- Memory allocations
- App launch time

**Tools:**
- Instruments (Time Profiler)
- Instruments (Allocations)
- Instruments (GPU Performance)
- Metal Debugger

---

## Priority Order

### HIGH PRIORITY (Core Features)
1. **Video Export** - Key feature for sharing
2. **Enhanced Silence Handling** - Better UX
3. **Error Handling** - Production stability

### MEDIUM PRIORITY (UX Polish)
4. **Audio Device Switching** - Flexibility
5. **Settings & Preferences** - Customization
6. **App Icon & Branding** - Professional look

### LOW PRIORITY (Nice to Have)
7. **Documentation** - Can be iterative
8. **Testing & QA** - Ongoing process
9. **Build & Distribution** - Final step
10. **Performance Optimization** - Measure first

---

## Implementation Phases

### Phase 6A: Core Features (Week 1-2)
- Video export implementation
- Enhanced silence handling
- Error handling framework

### Phase 6B: Polish (Week 3)
- Device switching
- Settings panel
- App icon

### Phase 6C: Release Prep (Week 4)
- Documentation
- Testing suite
- Build pipeline
- Performance tuning

---

## Success Criteria

- ✅ Video export works reliably at 1080p60
- ✅ Orb has 3-phase silence behavior
- ✅ All errors are user-friendly
- ✅ User can switch audio devices
- ✅ Settings persist across launches
- ✅ App passes all test scenarios
- ✅ Performance meets targets (60fps, <50ms latency)
- ✅ User documentation complete
- ✅ Ready for distribution

---

## Technical Debt

### Items to Address in Phase 6:
1. **Audio Format Handling**: Currently logs "throwing -10877" (harmless but noisy)
2. **Metal Shader Optimization**: Can reduce vertex count or optimize deformation
3. **Memory Management**: Add autorelease pool for recording buffers
4. **Error Recovery**: Handle audio engine interruptions gracefully

---

## Dependencies

### Required for Phase 6:
- ✅ Phases 1-5 complete
- ✅ Core rendering pipeline working
- ✅ Audio capture stable
- ✅ Recording functional

### External Requirements:
- Apple Developer account (for code signing)
- Design resources (for app icon)
- macOS 15.1+ for testing
- Physical Mac for performance testing

---

## Notes

### Design Philosophy (from AURA-MANIFEST.md)
- **Tools over hype**: Every feature must serve the user
- **Calm & embodied**: No aggressive UI, gentle interactions
- **Privacy-first**: All processing local, no telemetry

### Implementation Guidelines
- No third-party dependencies
- Swift + Metal + AVFoundation only
- Follow existing code patterns
- Maintain 60fps target
- Keep memory footprint low

---

## Quick Start for Phase 6

### To begin implementation:

```bash
# Ensure working tree is clean
cd /Users/lxps/Documents/GitHub/aura-app
git status

# Create feature branch
git checkout -b phase-6-video-export

# Start with video export (highest priority)
# Create new file: AURA/aura/aura/Shared/Export/VideoExporter.swift
```

### First Task: Video Export

1. Read `work/EXPORT-SPEC.md` thoroughly
2. Create `VideoExporter.swift` class
3. Implement Metal → CVPixelBuffer conversion
4. Add AVAssetWriter pipeline
5. Test with short recording
6. Add UI controls

---

## Resources

### Relevant Specifications:
- `work/EXPORT-SPEC.md` - Video export details
- `work/DEVICE-SWITCHING-UX.md` - Device picker UX
- `work/SILENCE-HANDLING.md` - Silence behavior
- `work/ERROR-MESSAGES.md` - Error copy guidelines
- `work/TESTING-SCENARIOS.md` - Test cases

### Apple Documentation:
- AVAssetWriter Guide
- Metal Best Practices
- CVPixelBuffer Reference
- App Distribution Guide

---

## Timeline Estimate

- **Phase 6A**: 2 weeks (video export, silence, errors)
- **Phase 6B**: 1 week (device switching, settings, icon)
- **Phase 6C**: 1 week (docs, testing, distribution)

**Total: ~4 weeks to production-ready 1.0 release**

---

## Current State Summary

### ✅ Working (Phases 1-5)
- Metal rendering at 60fps
- Real-time audio capture
- WAV recording to disk
- Keyboard shortcuts (Space/Esc)
- State management
- Orb physics simulation
- Feature extraction (RMS, pitch, centroid)

### 🚧 Pending (Phase 6)
- Video export
- Device switching
- Enhanced silence behavior
- Error UI
- Settings panel
- App icon
- Documentation
- Distribution build

---

**Last Updated:** January 21, 2026  
**Phase Status:** Ready to Begin  
**Next Action:** Implement VideoExporter.swift
