# INSTRUCTIONS — Xcode Project Setup for AURA (macOS)

**Date:** January 21, 2026
**Platform:** macOS-only (iOS deferred)
**Target:** macOS 12.0+

---

## 0. OVERVIEW

This document provides step-by-step instructions for creating the Xcode project structure for AURA.

**What you're building:**
- macOS native application (AppKit)
- Metal-based real-time rendering
- CoreAudio for audio capture/playback
- CoreMediaIO for virtual camera output
- Zero third-party dependencies

**Implementation order:**
1. Phase 1: Audio + Physics Foundation
2. Phase 2: Metal + Integration
3. Phase 3: Platform Views (macOS)
4. Phase 4: Coordination + State
5. Phase 5: Export Pipeline
6. Phase 6: Virtual Camera Output
7. Phase 7: Polish + Error States

---

## 1. XCODE PROJECT CREATION

### Step 1: Create New Project
```
File → New → Project
Choose: macOS → App
Product Name: AURA
Team: [Your Team]
Organization Identifier: [Your Domain]
Interface: AppKit (NOT SwiftUI)
Language: Swift
```

**Critical:**
- Select **AppKit**, not SwiftUI
- Minimum deployment: macOS 12.0

### Step 2: Project Structure
Create the following folder structure in Xcode:

```
AURA/
├── AURA.xcodeproj
├── AURA/
│   ├── AppDelegate.swift
│   ├── Info.plist
│   ├── Assets.xcassets
│   │
│   ├── Core/
│   │   ├── Audio/
│   │   │   ├── AudioDeviceRegistry.swift
│   │   │   ├── AudioCaptureEngine.swift
│   │   │   ├── WavRecorder.swift
│   │   │   └── AudioPlayer.swift
│   │   │
│   │   ├── Rendering/
│   │   │   ├── OrbPhysics.swift
│   │   │   ├── OrbRenderer.swift
│   │   │   ├── OrbShaders.metal
│   │   │   ├── OrbExporter.swift
│   │   │   └── VirtualCameraOutput.swift
│   │   │
│   │   ├── State/
│   │   │   ├── AppState.swift
│   │   │   └── StateManager.swift
│   │   │
│   │   └── Coordination/
│   │       └── AuraCoordinator.swift
│   │
│   ├── macOS/
│   │   ├── Views/
│   │   │   ├── AuraViewController.swift
│   │   │   ├── MetalView.swift
│   │   │   └── DevicePickerView.swift
│   │   │
│   │   └── WindowController.swift
│   │
│   └── Resources/
│       └── [Audio samples for testing]
│
└── Tests/
    ├── AudioTests/
    ├── PhysicsTests/
    ├── RenderingTests/
    └── IntegrationTests/
```

### Step 3: Add Frameworks
**Required frameworks (link in project settings):**
- AVFoundation.framework
- CoreAudio.framework
- AudioToolbox.framework
- Metal.framework
- MetalKit.framework
- CoreMediaIO.framework (for virtual camera)
- CoreMedia.framework
- VideoToolbox.framework

**To add:**
1. Select project in navigator
2. Select AURA target
3. General tab → Frameworks, Libraries, and Embedded Content
4. Click + and add each framework

---

## 2. PROJECT SETTINGS

### Build Settings

**Deployment Target:**
```
macOS Deployment Target: 12.0
```

**Swift Language Version:**
```
Swift 5.9 or later
```

**Optimization Level:**
```
Debug: None [-Onone]
Release: Optimize for Speed [-O]
```

**Metal Compiler:**
```
Metal Language Version: Metal 2.4
Enable Metal Validation: Yes (Debug only)
```

**Code Signing:**
```
Development Team: [Your Team]
Signing Certificate: Development
Hardened Runtime: Yes
```

### Capabilities (Required)

Enable these in Signing & Capabilities:

1. **Hardened Runtime**
   - Audio Input: ✓
   - Camera: ✓ (for virtual camera output)

2. **App Sandbox** (if distributing via Mac App Store)
   - Audio Input: ✓
   - Camera: ✓
   - User Selected Files: Read/Write ✓

### Info.plist Additions

Add these keys to Info.plist:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>AURA captures audio to create your voice presence orb.</string>

<key>NSCameraUsageDescription</key>
<string>AURA provides a virtual camera that streams your orb to other applications.</string>

<key>LSMinimumSystemVersion</key>
<string>12.0</string>

<key>NSSupportsAutomaticTermination</key>
<true/>

<key>NSSupportsSuddenTermination</key>
<false/>
```

**Important:** NSSupportsSuddenTermination is false because we need to safely close WAV files.

---

## 3. IMPLEMENTATION ORDER

### Phase 1: Audio + Physics Foundation

**Goal:** Get audio capture working and physics simulation running independently.

**Files to create first:**
1. `AudioDeviceRegistry.swift`
2. `AudioCaptureEngine.swift`
3. `WavRecorder.swift`
4. `OrbPhysics.swift`

**Validation:**
- Audio captures without dropouts
- WAV files write correctly
- Physics runs at 60Hz deterministically
- Unit tests pass (silence, impulse, determinism)

**See:**
- AUDIO-MAPPING.md for feature extraction
- PHYSICS-SPEC.md for constants
- FILE-MANAGEMENT.md for WAV recording

---

### Phase 2: Metal + Integration

**Goal:** Render the orb in real-time driven by physics.

**Files to create:**
1. `OrbRenderer.swift`
2. `OrbShaders.metal`
3. `MetalView.swift` (NSView subclass with MTKView)

**Validation:**
- Orb renders at 60fps
- Physics drives deformation
- No rendering blocks audio thread
- Silence produces calm motion

**See:**
- SHADER-SPEC.md for Metal pipeline
- PHYSICS-SPEC.md for motion constraints

---

### Phase 3: Platform Views (macOS)

**Goal:** Complete macOS UI with keyboard shortcuts and controls.

**Files to create:**
1. `AuraViewController.swift` (main controller)
2. `WindowController.swift`
3. `DevicePickerView.swift`
4. Update `AppDelegate.swift`

**Validation:**
- Keyboard shortcuts work (Space, Esc, Cmd+R, etc.)
- Device switching UI functional
- Window management correct
- Recording state visible

**See:**
- KEYBOARD-SHORTCUTS.md for shortcut mapping
- DEVICE-SWITCHING-UX.md for picker UI
- DESIGN.md for visual constraints

---

### Phase 4: Coordination + State

**Goal:** Connect all modules with proper state management.

**Files to create:**
1. `AppState.swift` (enum-based state machine)
2. `StateManager.swift` (state transitions)
3. `AuraCoordinator.swift` (glue logic)

**Validation:**
- State transitions enforced
- No invalid operations allowed
- Recording survives UI freezes
- Error states handled gracefully

**See:**
- ARCHITECTURE.md Section 9 for state machine
- ERROR-MESSAGES.md for error handling

---

### Phase 5: Export Pipeline

**Goal:** Export recordings as MP4 video with orb + audio.

**Files to create:**
1. `OrbExporter.swift`
2. `AudioPlayer.swift` (for playback during export)

**Validation:**
- MP4 exports at correct quality
- Video + audio muxed correctly
- Progress reporting works
- Cancellation works safely
- Files play on iPhone

**See:**
- EXPORT-SPEC.md for codec settings
- FILE-MANAGEMENT.md for export naming

---

### Phase 6: Virtual Camera Output

**Goal:** Stream orb in real-time to other applications.

**Files to create:**
1. `VirtualCameraOutput.swift`
2. CoreMediaIO extension configuration
3. Virtual camera toggle UI

**Validation:**
- Camera appears in Zoom/FaceTime/OBS
- Maintains 60fps or degrades gracefully
- Does not impact audio recording
- Clear indicator when active
- Works alongside recording

**See:**
- ARCHITECTURE.md Section 14 for module design
- EXPORT-SPEC.md Section 12 for technical specs
- DESIGN.md Section 11 for UI constraints

**Technical Notes:**
- Use CMIOExtension APIs (macOS 12.3+)
- No separate driver installation
- Bundle extension with main app
- Register camera on app launch

---

### Phase 7: Polish + Error States

**Goal:** Handle edge cases, error messages, and final UX polish.

**Tasks:**
1. Implement all error messages from ERROR-MESSAGES.md
2. Add device switching error handling
3. Disk full detection
4. Partial file recovery
5. Performance warnings
6. Silence handling refinement

**Validation:**
- All testing scenarios from TESTING-SCENARIOS.md pass
- Error messages feel calm and clear
- Recovery paths work correctly
- Performance acceptable on older Macs

---

## 4. CRITICAL CONSTRAINTS

### Thread Model (MUST ENFORCE)

**Audio Thread:**
- Real-time priority
- NEVER block or wait
- No memory allocation in callback
- No mutex locks

**Physics Thread:**
- 60Hz update loop
- Independent from rendering
- Can drop frames if needed

**Render Thread:**
- Metal command queue
- Can drop frames
- Never blocks audio or physics

**Main Thread:**
- UI updates only
- State management
- File operations

**Violation = Architecture Failure**

---

### Performance Requirements

**Audio:**
- Zero buffer drops in 10-minute recording
- Maximum latency: 50ms (recording)
- Sample rate: 48kHz, 16-bit, mono

**Rendering:**
- 60fps target
- 30fps acceptable on Intel Macs
- 3% maximum deformation (hard clamp)

**Export:**
- 2× real-time acceptable
- Cancellable at any time
- Progress reporting every 100ms

**Virtual Camera:**
- 60fps preferred, 30fps fallback
- <50ms latency (audio → frame output)
- Cannot block recording or export

---

## 5. TESTING REQUIREMENTS

### Unit Tests (XCTest)

**Audio Tests:**
```swift
testAudioCaptureNoDropouts()
testWavFileWriting()
testSilenceHandling()
testDeviceEnumeration()
```

**Physics Tests:**
```swift
testImpulseDecay()
testSilenceStability()
testDeformationClamping()
testDeterminism()
```

**Rendering Tests:**
```swift
testMetalPipelineCreation()
testFrameRendering()
testDeformationApplication()
```

### Integration Tests

**Recording Flow:**
```swift
testRecordToWav()
testRecordingSurvivesUIFreeze()
testDiskFullHandling()
testPartialFileRecovery()
```

**Export Flow:**
```swift
testMP4Export()
testExportCancellation()
testExportQuality()
```

**Virtual Camera:**
```swift
testCameraRegistration()
testCameraFrameOutput()
testCameraPerformance()
```

### Manual Testing

**Must pass before v1:**
- [ ] Zero audio dropouts in 10-minute recording
- [ ] Partial file recovery (forced termination)
- [ ] Disk full handled gracefully
- [ ] Two people saying "hello" → different orbs
- [ ] Silence feels calm (not frozen, not jittery)
- [ ] Keyboard shortcuts 100% reliable
- [ ] Export plays on iPhone (AirDrop test)
- [ ] Virtual camera works in Zoom/FaceTime
- [ ] Recording continues while camera is active

**See:** TESTING-SCENARIOS.md for complete list

---

## 6. BUILD CONFIGURATIONS

### Debug Configuration
```
Optimization: None
Metal Validation: Enabled
Assertions: Enabled
Logging: Verbose
Code Signing: Development
```

### Release Configuration
```
Optimization: Speed
Metal Validation: Disabled
Assertions: Disabled
Logging: Errors only
Code Signing: Distribution
Strip Debug Symbols: Yes
```

---

## 7. COMMON MISTAKES TO AVOID

### ❌ DON'T:
- Use SwiftUI (requirement is AppKit)
- Add third-party dependencies
- Block the audio thread
- Skip unit tests
- Violate 3% deformation limit
- Make design decisions (all locked in specs)
- Add features not in PRD
- Use bright colors or "LIVE" indicators
- Make orb motion reactive/fast

### ✓ DO:
- Follow specs exactly
- Maintain thread priorities
- Test on older Intel Macs
- Validate WAV file integrity
- Handle errors calmly
- Keep UI minimal and calm
- Preserve silence weight
- Test virtual camera with real apps

---

## 8. DEBUGGING TIPS

### Audio Issues
```swift
// Enable CoreAudio logging
defaults write com.apple.coreaudio DiagnosticOutput 1

// Check for dropped buffers
print("Buffer dropouts: \(audioEngine.totalBufferDrops)")
```

### Metal Issues
```bash
# Enable Metal validation layers
Product → Scheme → Edit Scheme → Run → Diagnostics
✓ Metal API Validation
✓ Metal Shader Validation
```

### Virtual Camera Issues
```bash
# Check CoreMediaIO extensions
pluginkit -m -v -i com.apple.cmio-extension

# Reset camera permissions
tccutil reset Camera
```

### Performance Profiling
```
Instruments → Time Profiler (CPU usage)
Instruments → Metal System Trace (GPU usage)
Instruments → Leaks (memory leaks)
```

---

## 9. DISTRIBUTION PREPARATION

### App Bundle Structure
```
AURA.app/
├── Contents/
│   ├── Info.plist
│   ├── MacOS/
│   │   └── AURA
│   ├── Resources/
│   │   └── Assets.car
│   └── PlugIns/
│       └── AURACamera.plugin/ (CoreMediaIO extension)
```

### Code Signing
```bash
# Sign app bundle
codesign --deep --force --sign "Developer ID Application: [Name]" AURA.app

# Verify signature
codesign --verify --verbose=4 AURA.app
spctl --assess --verbose=4 AURA.app
```

### Notarization (for distribution outside App Store)
```bash
# Create archive
ditto -c -k --keepParent AURA.app AURA.zip

# Submit for notarization
xcrun notarytool submit AURA.zip --keychain-profile "AC_PASSWORD"

# Staple ticket
xcrun stapler staple AURA.app
```

---

## 10. DOCUMENTATION REFERENCE

Read these documents in order:

**Start here:**
1. HANDOFF-PACKAGE.md — Complete index and overview
2. GOAL.md — North star and success criteria
3. PRD.md — Requirements and philosophy
4. ARCHITECTURE.md — Module structure and data flow

**Implementation specs:**
5. AUDIO-MAPPING.md — Audio features → physics forces
6. PHYSICS-SPEC.md — Constants and simulation
7. SHADER-SPEC.md — Metal rendering pipeline
8. EXPORT-SPEC.md — Video/audio export settings
9. FILE-MANAGEMENT.md — Recording and export naming

**UX and polish:**
10. DESIGN.md — Visual constraints and color system
11. KEYBOARD-SHORTCUTS.md — Shortcut mapping
12. DEVICE-SWITCHING-UX.md — Input picker UI
13. ERROR-MESSAGES.md — Error copy and handling
14. SILENCE-HANDLING.md — Silence motion states

**Testing:**
15. TESTING-SCENARIOS.md — Test cases and acceptance criteria

**Decisions:**
16. DECISION-UI-FRAMEWORK.md — Why AppKit
17. DECISION-MACOS-FOCUS.md — Platform and virtual camera

---

## 11. DEVELOPMENT WORKFLOW

### Typical Development Session
```bash
# 1. Pull latest
git pull origin main

# 2. Create feature branch
git checkout -b phase-1-audio-core

# 3. Implement module
# (Write code, following specs exactly)

# 4. Run tests
Cmd+U (Run all tests)

# 5. Manual validation
# (Test recording, check audio quality, etc.)

# 6. Commit
git add .
git commit -m "Phase 1: Implement AudioCaptureEngine"

# 7. Push and merge
git push origin phase-1-audio-core
```

### When You're Stuck
1. Re-read the relevant spec document
2. Search all docs for relevant keywords
3. Check if DECISION.md protocol applies
4. Document the issue with proposed solution
5. Don't guess — ask for clarification if truly ambiguous

---

## 12. SUPPORT & QUESTIONS

### If Specification is Ambiguous
1. Check if it's documented in another spec file
2. Use grep to search all .md files for keywords
3. Document the ambiguity clearly
4. Propose a solution that aligns with philosophy
5. Get approval before implementing

### If Specification is Wrong
1. Document the error with evidence
2. Propose a correction
3. Update spec first, then implement
4. **Specs are truth, code follows**

### If Performance Issue Found
1. Profile with Instruments
2. Identify bottleneck
3. Check if optimization violates constraints
4. Audio priority must never be compromised
5. Document trade-off if degradation needed

---

## FINAL CHECKLIST

Before starting implementation:
- [ ] Xcode project created (AppKit, macOS 12.0+)
- [ ] All frameworks linked
- [ ] Info.plist permissions added
- [ ] Folder structure matches specification
- [ ] Build settings configured correctly
- [ ] Unit test targets created
- [ ] All 18 spec documents read
- [ ] Philosophy understood (tools over hype, precision, calm)
- [ ] Thread model clear (Audio > Rendering > UI)
- [ ] Virtual camera requirements understood

Before shipping v1:
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] All manual scenarios pass (TESTING-SCENARIOS.md)
- [ ] Runs on Intel Mac (performance acceptable)
- [ ] Runs on Apple Silicon (full performance)
- [ ] Virtual camera works in Zoom, FaceTime, OBS
- [ ] Export plays on iPhone
- [ ] No audio dropouts in 10-minute recording
- [ ] Error messages feel calm and helpful
- [ ] Design matches DESIGN.md constraints
- [ ] Code signed and ready for distribution

---

**FINAL STATEMENT**

This is a macOS-native application built with AppKit, Metal, and CoreAudio.

Follow the specs exactly. Don't add features. Don't skip phases.

Audio never compromises. Rendering never blocks audio. State always knowable.

AURA is calm, precise, and trustworthy.

**Build phase by phase. Test continuously. Ship complete.**

---

**Status:** Implementation instructions complete
**Date:** January 21, 2026
**Platform:** macOS 12.0+ (iOS deferred)
