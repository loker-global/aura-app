# HANDOFF PACKAGE — Complete Documentation Index

⸻

## 0. HANDOFF STATUS

**Date:** January 21, 2026
**Status:** PRODUCTION READY (100% specification complete, macOS-only focus)
**Readiness:** Zero ambiguity, mechanica## 11. PHILOSOPHY CHECK

### Core Principles (Must Propagate to Code)
- **Tools over hype** — No flashy features, no marketing gimmicks
- **Precision** — Every constant specified, no guessing
- **Voice as memory** — Recordings are presence, not content
- **Calm > Expressive** — UI recedes, orb primary
- **Local-first** — Privacy absolute, no network
- **Reversibility** — All actions undoable or recoverable
- **Artifact-first** — Record → Replay → Export is the core workflow

### Anti-Patterns (Must Be Rejected)
- Audio reactive (too fast, feels like visualizer)
- Impressive motion (draws attention to itself)
- Complex UI (cognitive load)
- Hidden behavior (no magic)
- Data extraction (telemetry, analytics)
- Reframing as streaming/calling tool (not AURA's purpose)

---

## 12. HANDOFF CHECKLIST
**Platform:** macOS 12+ (iOS deferred to Phase 2)

---

## 1. FOUNDATION DOCUMENTS (6)

### Strategic Vision
1. **GOAL.md** — North star, success criteria, done state
2. **PRD.md** — Requirements, non-goals, features, philosophy
3. **DESIGN.md** — Visual constraints, color system, usability rules
4. **PREREQUISITES.md** — Core capabilities, orb contract, audio philosophy

### Decisions & Architecture
5. **DECISION-UI-FRAMEWORK.md** — AppKit chosen (justified via DECISION.md protocol)
6. **DECISION-MACOS-FOCUS.md** — Platform scope and virtual camera positioning
7. **ARCHITECTURE.md** — 5-layer module structure, thread model, state machine

---

## 3. IMPLEMENTATION SPECIFICATIONS (10)

### Critical (Block Development)
7. **AUDIO-MAPPING.md** — Audio features → physics forces (RMS, centroid, ZCR, onset)
8. **PHYSICS-SPEC.md** — Constants (mass, damping, springs, 60Hz, 3% deformation)
9. **FILE-MANAGEMENT.md** — Recording naming, save location, collision handling

### High Priority (Avoid Rework)
10. **SHADER-SPEC.md** — Metal pipeline, deformation algorithm, lighting model
11. **EXPORT-SPEC.md** — Video codec (H.264), resolution (1080p60), audio (AAC)
12. **KEYBOARD-SHORTCUTS.md** — State-aware shortcuts, Space/Esc behavior

### Medium Priority (UX Clarity)
13. **DEVICE-SWITCHING-UX.md** — Audio input picker, default selection, error handling
14. **ERROR-MESSAGES.md** — Calm tone, clear copy, safe exit paths

### Testing & Edge Cases
15. **TESTING-SCENARIOS.md** — Unit tests, integration tests, manual tests, stress tests
16. **SILENCE-HANDLING.md** — 3-phase silence, ambient motion, thresholds

---

## 4. META DOCUMENTS (3)

17. **INSTRUCTIONS.md** — Xcode project setup, implementation guide, testing checklist
18. **DECISION-HANDOFF-COMPLETENESS.md** — Option C chosen (complete all specs)
19. **HANDOFF-AUDIT.md** — Gap analysis, recommendations, readiness assessment

---

## 5. DOCUMENT STATISTICS

**Total Documents:** 19
**Total Word Count:** ~30,000 words
**Specification Depth:** Implementation-level (no guessing required)

**Coverage:**
- ✓ Philosophy & Vision
- ✓ Architecture & Modules
- ✓ Audio Processing Pipeline
- ✓ Physics Simulation
- ✓ Metal Rendering
- ✓ File Management
- ✓ Export Pipeline
- ✓ User Interactions (keyboard, device switching)
- ✓ Error Handling
- ✓ Testing Strategy
- ✓ Edge Cases
- ✓ Virtual Camera Output

---

## 6. KEY DECISIONS LOCKED

### Framework
**AppKit** (macOS-only for v1, no SwiftUI)
- Reason: Keyboard reliability, Metal control, reversibility
- Platform target: macOS 12.0+
- Note: iOS deferred to future phase

### Virtual Camera
**Core MVP feature** (Phase 6)
- Uses CoreMediaIO APIs (no driver installation)
- Same orb engine as exports (real-time version)
- 1080p/720p at 60fps (30fps fallback)
- Must not impact audio/recording performance

### Audio
**48 kHz, 16-bit, mono WAV** (canonical)
- Features: RMS, spectral centroid, ZCR, onset detection
- Buffer size: 2048 samples (~43ms)
- Smoothing: Exponential moving average

### Physics
**60 Hz mass-spring-damper**
- Mass: 1.0 kg (unit)
- Spring constant: 10.0 N/m (base), modulated by centroid
- Damping: 0.85 (spring), 0.75 (global)
- Max deformation: 3% radius

### Rendering
**Metal forward rendering**
- Mesh: Icosphere (2562 vertices, 5120 triangles)
- Lighting: Simplified Phong (rim light only)
- Colors: Bone (#E6E7E9) on near-black (#0E0F12)
- Deformation: Vertex displacement (physics-driven)

### Export
**H.264, 1080p60, 8 Mbps, AAC 128kbps**
- Container: MP4
- Frame rate: 60 fps
- Audio: Muxed AAC mono

---

## 6. IMPLEMENTATION PHASES

### Phase 1: Audio + Physics Foundation
- AudioCaptureEngine (AVAudioEngine wrapper)
- WavRecorder (deterministic WAV writer)
- OrbPhysics (standalone, no rendering)
- Unit tests (silence, impulse, determinism)

### Phase 2: Rendering Core
- OrbRenderer (Metal + MTKView)
- OrbShaders.metal (vertex displacement, Phong lighting)
- Physics → Rendering integration

### Phase 3: Platform Views
- macOS: NSViewController + menu bar integration
- Keyboard shortcuts implementation
- Device picker UI

### Phase 4: Coordination + State
- StateManager (enum-based state machine)
- AuraCoordinator (connects modules)

### Phase 5: Export
- OrbExporter (offline rendering + AVAssetWriter)
- MP4 mux (video + audio)

### Phase 6: Virtual Camera
- VirtualCameraOutput (CoreMediaIO integration)
- Real-time frame streaming
- System camera registration

### Phase 7: Polish
- Error states (see ERROR-MESSAGES.md)
- Device switching (see DEVICE-SWITCHING-UX.md)
- Keyboard shortcuts (see KEYBOARD-SHORTCUTS.md)

---

## 7. KNOWN CONSTRAINTS

### Non-Negotiables
- **Audio > Rendering > UI** (priority enforced at thread level)
- **No third-party dependencies** (system frameworks only)
- **Local-first** (no cloud, no accounts, no telemetry)
- **3% deformation max** (hard clamp in physics)
- **Keyboard-first** (macOS must have reliable shortcuts)

### Acceptable Trade-offs
- Intel Macs: 30 fps acceptable (degraded but stable)
- Bluetooth: ~100ms latency acceptable (user aware)
- Export time: 2× real-time acceptable

---

## 8. TESTING REQUIREMENTS (SHIP BLOCKERS)

### Must Pass Before V1
- [ ] Zero audio dropouts in 10-minute recording
- [ ] Partial file recovery works (forced termination test)
- [ ] Disk full handled gracefully (no data loss)
- [ ] Two people saying "hello" → different orbs
- [ ] Silence feels calm (not frozen, not jittery)
- [ ] Keyboard shortcuts 100% reliable (macOS)
- [ ] Export video plays on iPhone (AirDrop test)
- [ ] Virtual camera works in Zoom/FaceTime/OBS
- [ ] Recording continues while virtual camera is active

---

## 9. SUCCESS CRITERIA (FROM GOAL.md)

AURA succeeds if:
- Two people saying the same words produce different orbs
- Silence feels intentional and calm
- Muted video still feels complete
- Exports feel meaningful, not gimmicky
- Users trust AURA with private voice moments
- Works on macOS (v1 focus)

---

## 10. VIRTUAL CAMERA OUTPUT (MVP FEATURE)

### Live Presence Surface

AURA includes virtual camera output as a core feature for v1.

**What It Provides:**
- Real-time orb streaming as system camera device
- Available in Zoom, FaceTime, OBS, Discord, etc.
- Same orb engine, same motion contract as exports
- Same physics, rendering, and deformation limits

**Technical Implementation:**
- Uses CoreMediaIO APIs (macOS 12.3+)
- No driver or system extension installation
- Appears as "AURA Orb" in camera selection
- 1080p/720p at 60fps (30fps fallback)

**Implementation Priority:**
- Phase 5 (after export pipeline)
- Reuses OrbRenderer output
- Dedicated VirtualCameraOutput module
- Must not impact audio/rendering performance

**Documentation:**
- See ARCHITECTURE.md Section 14 for module design
- See EXPORT-SPEC.md Section 12 for technical specs
- See DESIGN.md Section 11 for UI constraints

**Privacy & Trust:**
- Requires camera permission (standard macOS flow)
- Clear indicator when camera is in use
- User can enable/disable at any time
- Video only (no audio routing)

**Conceptual Modes:**
- Artifact mode: Record → Replay → Export MP4
- Live mode: Microphone → Orb → Virtual Camera

Both modes use identical rendering pipeline.

---

## 11. PHILOSOPHY CHECK

### Core Principles (Must Propagate to Code)
- **Tools over hype** — No flashy features, no marketing gimmicks
- **Precision** — Every constant specified, no guessing
- **Voice as memory** — Recordings are presence, not content
- **Calm > Expressive** — UI recedes, orb primary
- **Local-first** — Privacy absolute, no network
- **Reversibility** — All actions undoable or recoverable

### Anti-Patterns (Must Be Rejected)
- Audio reactive (too fast, feels like visualizer)
- Impressive motion (draws attention to itself)
- Complex UI (cognitive load)
- Hidden behavior (no magic)
- Data extraction (telemetry, analytics)

---

## 11. HANDOFF CHECKLIST

### Developer Receives
- [x] All 18 documents in `./work/` folder
- [x] Clear implementation phases
- [x] Concrete constants (no TBD values)
- [x] Testing scenarios with acceptance criteria
- [x] Error copy written
- [x] Keyboard shortcuts mapped
- [x] Philosophy locked

### Developer Can
- [x] Execute Phase 1 without questions
- [x] Implement audio pipeline from spec
- [x] Build physics simulation from constants
- [x] Write Metal shaders from algorithm
- [x] Create file management from naming rules
- [x] Implement export from codec specs

### Developer Should NOT
- [ ] Make design decisions (all locked)
- [ ] Add features not in PRD (scope creep)
- [ ] Skip testing scenarios (quality gate)
- [ ] Violate philosophy (tools over hype)

---

## 13. CONTACT / QUESTIONS

### If Ambiguity Found
1. Check relevant spec first (likely documented)
2. Search for keywords across all 18 files
3. If truly missing: document question, propose solution, get approval

### If Spec Conflict Found
1. Document both specifications
2. Reference DECISION.md protocol
3. Get clarification before implementing

---

## FINAL STATEMENT

This handoff package represents complete planning for AURA v1 (macOS).

No guessing required.
No design decisions deferred.
No philosophy compromises hidden.

Developer can execute mechanically from these specifications.

If implementation deviates from spec, it is incorrect.
If spec is wrong, update spec first, then code.

**Specs are truth. Code follows.**

**AURA supports both durable artifacts and live presence.**

⸻

**Status:** Production handoff complete (macOS-only focus)
**Date:** January 21, 2026
**Approved by:** Dr. X
