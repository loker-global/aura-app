# AURA — Technical Architecture

⸻

## 0. ARCHITECTURE PHILOSOPHY

**Separation of concerns is survival.**

If the UI crashes, audio must continue.
If rendering stalls, recording must not stop.
If export fails, source files must be safe.

⸻

## 1. CORE PRINCIPLE

**Audio > Rendering > UI**

Priority order (non-negotiable):
1. Audio capture/playback (never drops buffers)
2. Metal rendering (60fps minimum)
3. UI state updates (can lag if necessary)

⸻

## 2. MODULE STRUCTURE

### Layer 1: Audio Core (Platform-Independent)

**AudioDeviceRegistry**
- Enumerates CoreAudio input devices
- Returns device list with IDs, names, sample rates
- Zero state, pure enumeration

**AudioCaptureEngine**
- Wraps AVAudioEngine
- Manages audio input tap
- Provides real-time metering (RMS, peak)
- Delivers audio buffers to recorder + orb
- Runs on dedicated audio thread

**WavRecorder**
- Deterministic WAV file writer
- Receives PCM buffers from AudioCaptureEngine
- Handles partial file safety (write header on close)
- Single responsibility: audio → disk

**AudioPlayer**
- Wraps AVAudioPlayerNode
- Loads WAV/MP3 for playback
- Provides real-time metering during playback
- Delivers audio analysis to orb during replay

---

### Layer 2: Rendering Core (Platform-Independent)

**OrbPhysics**
- Physics simulation (mass, inertia, damping)
- Audio features → force application
- No direct volume-to-size mapping
- Updates at fixed timestep (60Hz or 120Hz)
- Pure Swift, no rendering dependency

**OrbRenderer**
- Metal-based real-time renderer
- Receives orb state from OrbPhysics
- Renders single deformable sphere
- Shader-based surface deformation (≤3% radius)
- Minimal lighting (soft rim, no neon)
- MTKView integration

**OrbExporter**
- Offline video renderer
- Replays audio → physics → rendering
- Muxes video + audio to MP4
- Uses AVAssetWriter + Metal headless rendering
- Cancellable, progress-reportable

---

### Layer 3: State Management (Platform-Independent)

**AppState (enum)**
```swift
enum AppState {
    case idle(selectedDevice: AudioDevice?)
    case recording(device: AudioDevice, startTime: Date)
    case playback(file: URL, position: TimeInterval)
    case exporting(file: URL, progress: Float)
    case error(String)
}
```

**StateManager**
- Single source of truth
- Enforces state transitions
- Validates operations (e.g., can't switch input while recording)
- Thread-safe (actor or lock-protected)
- Publishes state changes

---

### Layer 4: Platform-Specific Views

**iOS: AuraViewController (UIViewController)**
- UIKit-based view controller
- Wraps OrbRenderer in UIView
- Implements touch controls (if needed)
- Keyboard shortcuts via UIKeyCommand
- Manages UIDocumentPickerViewController for export

**macOS: AuraViewController (NSViewController)**
- AppKit-based view controller
- Wraps OrbRenderer in NSView
- Implements keyboard shortcuts via NSEvent
- Native menu bar integration
- Manages NSSavePanel for export

**Shared Interface: AuraViewControllerProtocol**
- Defines common methods both platforms must implement
- Allows shared coordinator logic

---

### Layer 5: Coordination

**AuraCoordinator**
- Connects audio engine → physics → renderer
- Listens to StateManager changes
- Routes audio buffers to recorder + orb
- Handles export workflow
- Platform-independent business logic

---

## 3. DATA FLOW

### Recording Flow
```
Microphone
  → AudioCaptureEngine (buffers + metering)
    → WavRecorder (disk write)
    → OrbPhysics (force application)
      → OrbRenderer (visual output)
        → MTKView (display)
```

### Playback Flow
```
Audio File
  → AudioPlayer (playback + metering)
    → OrbPhysics (force application)
      → OrbRenderer (visual output)
        → MTKView (display)
```

### Export Flow
```
Audio File
  → OrbExporter
    → Audio decode
    → OrbPhysics (offline replay)
    → OrbRenderer (headless frames)
    → AVAssetWriter (mux audio + video)
      → MP4 file
```

---

## 4. THREAD MODEL

**Main Thread**
- UI updates only
- State changes (via StateManager)
- User input

**Audio Thread (Real-Time)**
- AudioCaptureEngine buffer callbacks
- WavRecorder writes (async to disk)
- **Never blocked by UI or rendering**

**Physics Thread (High Priority)**
- OrbPhysics updates (60Hz or 120Hz)
- Can run independently of rendering
- Feeds rendering queue

**Render Thread**
- Metal command encoding
- MTKView drawable presentation
- Can drop frames if necessary (audio never affected)

---

## 5. FILE STRUCTURE

### Project Root
```
AURA/
├── Shared/
│   ├── Audio/
│   │   ├── AudioDeviceRegistry.swift
│   │   ├── AudioCaptureEngine.swift
│   │   ├── WavRecorder.swift
│   │   └── AudioPlayer.swift
│   ├── Rendering/
│   │   ├── OrbPhysics.swift
│   │   ├── OrbRenderer.swift
│   │   ├── OrbShaders.metal
│   │   └── OrbExporter.swift
│   ├── State/
│   │   ├── AppState.swift
│   │   └── StateManager.swift
│   └── Coordination/
│       └── AuraCoordinator.swift
├── iOS/
│   ├── AuraViewController.swift
│   ├── AppDelegate.swift
│   ├── Info.plist
│   └── Assets.xcassets
├── macOS/
│   ├── AuraViewController.swift
│   ├── AppDelegate.swift
│   ├── Info.plist
│   └── Assets.xcassets
├── Resources/
│   └── (fonts, icons if needed)
└── Tests/
    ├── AudioTests/
    ├── PhysicsTests/
    └── StateTests/
```

---

## 6. DEPENDENCIES

**System Frameworks Only**
- CoreAudio / AVFoundation (audio)
- Metal / MetalKit (rendering)
- AVFoundation (export)
- UIKit / AppKit (platform views)

**No third-party dependencies.**

Local-first means dependency-first risk.
Minimize external surface area.

---

## 7. BUILD CONFIGURATION

**Universal Target Strategy**
- Single Xcode project
- Two targets: AURA-iOS, AURA-macOS
- Shared code via folder references
- Conditional compilation minimal (`#if os(macOS)` only in view layer)

**Deployment Targets**
- iOS 15.0+ (UIKit mature, widespread)
- macOS 12.0+ (Metal stable, AppKit reliable)

---

## 8. SAFETY CONTRACTS

### Audio Safety
- Recording continues even if UI freezes
- Partial WAV files are recoverable
- Buffer overruns logged but do not crash

### Rendering Safety
- Dropped Metal frames do not affect audio
- Shader errors fall back to solid orb
- Physics runs independently of GPU

### Export Safety
- Cancellation is immediate
- Partial exports are deleted
- Original files never modified

---

## 9. ERROR HANDLING STRATEGY

**Errors must be quiet and clear.**

Categories:
- **Audio errors** (device unavailable, permission denied)
- **File errors** (disk full, read-only location)
- **Export errors** (codec unavailable, cancellation)

Response:
- Transition to `AppState.error`
- Display calm error message
- Preserve all user data
- Offer safe exit path

**No panic dialogs.**

---

## 10. TESTING STRATEGY

**Unit Tests**
- OrbPhysics (deterministic, no audio/rendering)
- StateManager (state transition validation)
- WavRecorder (mock buffer writes)

**Integration Tests**
- AudioCaptureEngine → WavRecorder pipeline
- AudioPlayer → OrbPhysics pipeline
- OrbExporter end-to-end

**Manual Tests**
- Audio device switching
- Recording interruption (sleep, Bluetooth disconnect)
- Export cancellation
- Keyboard shortcuts (macOS)

---

## 11. PERFORMANCE TARGETS

**Audio**
- Zero dropped buffers under normal load
- <5ms latency for real-time orb response

**Rendering**
- 60fps minimum on Apple Silicon
- 30fps acceptable on Intel Macs (degraded but stable)

**Export**
- Real-time factor ≤2× (2min audio → 4min export max)
- Cancellation response <500ms

---

## 12. MIGRATION PATH

**Phase 1: Audio + Physics Foundation**
- AudioCaptureEngine + WavRecorder
- OrbPhysics standalone
- Unit tests

**Phase 2: Rendering Core**
- OrbRenderer + Metal shaders
- Physics → Rendering integration
- Visual validation

**Phase 3: Platform Views**
- iOS AuraViewController
- macOS AuraViewController
- Keyboard shortcuts

**Phase 4: Coordination + State**
- StateManager
- AuraCoordinator
- Full integration

**Phase 5: Export**
- OrbExporter
- MP4 generation
- Sharing integration

**Phase 6: Polish**
- Error states
- Device switching
- Partial file recovery

---

## 13. FUTURE EXTENSIBILITY

**What this architecture allows (later):**
- SwiftUI wrapper (if justified)
- Additional export formats (GIF, ProRes)
- Audio effects (gentle cleanup)
- Additional orb styles (if aligned with philosophy)

**What this architecture prevents:**
- Cloud sync (no server dependency)
- Real-time collaboration (local-first)
- Complex timelines (not a DAW)
- Social features (privacy violation)

---

## FINAL STATEMENT

This architecture enforces:
- Audio never compromised
- Rendering never blocks audio
- State always knowable
- Failures always safe

If a module violates these rules, the architecture has failed.

⸻

**Status:** Architecture locked
