# AURA MANIFEST

Turn voice into a living fingerprint.

---

## WHAT THIS IS

AURA is a macOS and iOS app that gives voice a body.

Not a waveform.
Not a visualization.
A presence.

Voice drives a calm, embodied orb — in real time or playback.
Record. Replay. Export. Local. Private. Yours.

---

## WHAT THIS IS NOT

- Not a DAW
- Not a podcast editor
- Not a music visualizer
- Not a transcription tool
- Not a social network
- Not a cloud platform

If it makes AURA louder, busier, or performative, it is rejected.

---

## CORE PRINCIPLE

**Silence has weight.**

Two people saying the same word produce different orbs.
Silence feels intentional, not broken.
Muted video still feels complete.

Voice is not signal.
Voice is memory.

---

## PHILOSOPHY

- Tools over hype
- Precision over persuasion
- Ownership over convenience
- Calm over expressive
- Local over cloud
- Presence over content

---

## TECHNICAL

**Platform:** Universal (macOS 12+ / iOS 15+)
**Audio:** 48kHz WAV (canonical), real-time capture
**Rendering:** Metal (60fps, 3% deformation max)
**Export:** MP4 (H.264, 1080p60) + MP3
**Dependencies:** Zero (system frameworks only)

**Priority chain:** Audio > Rendering > UI

If audio fails, everything stops.
If rendering fails, audio continues.
If UI fails, nothing breaks.

---

## ARCHITECTURE

5 layers. Strict separation.

1. **Audio Core** (AudioCaptureEngine, WavRecorder, AudioPlayer)
2. **Rendering Core** (OrbPhysics, OrbRenderer, OrbShaders.metal)
3. **State Management** (AppState enum, StateManager)
4. **Platform Views** (UIKit/AppKit, keyboard-first)
5. **Coordination** (AuraCoordinator)

Thread model:
- Audio thread: real-time priority, never blocked
- Physics thread: 60Hz, independent
- Render thread: can drop frames
- Main thread: UI only

---

## THE ORB

Single object. Central presence.

- Motion is 3× slower than literal audio
- Deformation ≤ 3% of radius
- Silence creates calm, not absence
- Color: bone/off-white on near-black

**Physics:**
- Mass-spring-damper (60Hz)
- RMS → radial expansion
- Spectral centroid → surface tension
- Zero-crossing rate → micro-ripples
- Onset detection → impulse forces

**Not allowed:**
- Beat syncing
- Jitter
- Particles
- Camera movement
- Rainbow effects

If someone can lip-read from the motion, it failed.

---

## PRIVACY

- Local-first
- No accounts
- No cloud sync
- No analytics
- No telemetry
- No network dependency

Voice is personal matter.

---

## SUCCESS CRITERIA

AURA succeeds if:
- Two people saying "hello" produce visibly different orbs
- 5 seconds of silence feels calm and intentional
- Muted video still communicates presence
- Exports feel meaningful, not gimmicky
- Users trust AURA with private voice moments

---

## CONSTRAINTS

**Non-negotiable:**
- Audio never drops buffers
- Recording survives UI crashes
- Partial files are recoverable
- Keyboard-first on macOS
- No third-party dependencies

**Acceptable degradation:**
- 30fps on Intel Macs (vs 60fps target)
- Bluetooth latency ~100ms (user aware)
- Export at 2× real-time

---

## FILE STRUCTURE

```
AURA/
├── Shared/
│   ├── Audio/          (capture, recording, playback)
│   ├── Rendering/      (physics, Metal, export)
│   ├── State/          (state machine, manager)
│   └── Coordination/   (glue logic)
├── iOS/                (UIKit views, app delegate)
├── macOS/              (AppKit views, menu bar)
└── Tests/              (unit, integration)
```

---

## IMPLEMENTATION PHASES

1. Audio + Physics (no rendering)
2. Metal + Integration
3. Platform Views (iOS/macOS)
4. Coordination + State
5. Export Pipeline
6. Polish + Error States

---

## DOCUMENTATION

Complete specification in `./work/`:
- 19 documents
- ~25,000 words
- Zero ambiguity
- Implementation-level detail

Read `HANDOFF-PACKAGE.md` first.

---

## ANTI-PATTERNS

**Reject these:**
- Audio-reactive motion (too fast)
- Impressive visuals (attention-seeking)
- Hidden behavior (magic)
- Complex UI (cognitive load)
- Data extraction (surveillance)
- Cloud lock-in (rent-seeking)

If it violates "tools over hype, precision, voice as memory," it is wrong.

---

## TESTING

**Must pass before v1:**
- Zero audio dropouts in 10-minute recording
- Partial file recovery (forced termination)
- Disk full handled gracefully
- Two people → different orbs
- Silence feels calm (not frozen)
- Keyboard shortcuts 100% reliable
- Export plays on iPhone

---

## FINAL STATEMENT

AURA does not visualize sound.

AURA gives voice a body.

---

**Version:** 1.0
**Status:** Production specification complete
**Date:** January 21, 2026
**Built with:** Dr. X protocol (inner-loop-os)
