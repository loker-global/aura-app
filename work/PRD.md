# AURA — Turn voice into a living fingerprint

⸻

## 0. SUMMARY

AURA is a macOS application that captures voice and gives it a persistent visual body.

It allows users to:
- see their voice as a calm, embodied orb in real time
- record voice to WAV (source of truth)
- replay recordings as a voice fingerprint (orb re-embodiment)
- export voice as audio or as a shareable MP4 video (orb + audio muxed)

AURA is not a content tool.
It is a presence tool.

⸻

## 1. PROBLEM

Voice is deeply personal, but modern tools treat it as:
- signal levels
- waveforms
- content to edit or publish

These representations lose what matters most:
- rhythm
- pauses
- breath
- timing
- silence

There is no simple way to:

**capture how a voice exists in time.**

⸻

## 2. GOAL

Create a minimal, trustworthy tool that:
- captures voice faithfully
- visualizes voice as presence, not activity
- allows replay and export without distortion
- keeps the experience calm, private, and local

Success is not measured by engagement.
Success is measured by trust.

⸻

## 3. NON-GOALS (HARD BOUNDARIES)

AURA will not:
- become a DAW
- provide editing timelines
- perform transcription
- alter voices
- add AI personalities
- include social features
- require accounts or cloud sync

If a feature increases noise, speed, or performance pressure, it is rejected.

⸻

## 4. TARGET USER

Primary users:
- creators who think out loud
- founders recording messages
- designers, writers, researchers
- anyone who values voice as presence, not content

Secondary users:
- people creating personal voice artifacts
- users sharing calm voice moments

AURA is not optimized for mass audiences.

⸻

## 5. CORE FEATURES (MVP)

### 5.1 Live Presence Mode
- Microphone input drives a single orb in real time
- Orb motion uses inertia and damping (no direct volume-to-size mapping)
- Silence produces calm, stable presence
- USB microphones supported

**Purpose:** To feel voice existing now.

⸻

### 5.2 Voice Recording
- Record voice to WAV (canonical)
- Deterministic file creation and closure
- Partial recordings saved safely
- Local-only storage

**Purpose:** To preserve the true fingerprint.

⸻

### 5.3 Playback / Fingerprint Replay
- Load WAV or MP3
- Orb replays voice using the same motion model
- No visual shortcuts or simplification

Playback equals re-embodiment, not visualization.

**Purpose:** To let voice live again.

⸻

### 5.4 Export

**Audio Export**
- WAV (truth)
- MP3 (transport)

**Video Export**
- MP4 (orb + audio muxed)
- Clean framing, no UI
- Phone-ready (AirDrop, iMessage, WhatsApp)

**Purpose:** To carry voice beyond the app.

⸻

## 6. UX & DESIGN CONSTRAINTS

(See DESIGN.md — required reading)

Key points:
- Dark mode preferred
- Orb is primary visual element
- UI is structural, not expressive
- Motion is slow and intentional

⸻

## 7. ORB CONTRACT
- Single orb, centered
- Mostly constant size
- Voice applies force, not direct control
- Surface deformation ≤ 3%
- Silence feels intentional

If the orb feels reactive, the design has failed.

⸻

## 8. TECHNICAL ARCHITECTURE

**Modules**
- AudioDeviceRegistry — CoreAudio input enumeration
- AudioCaptureEngine — AVAudioEngine + metering
- WavRecorder — deterministic WAV writer
- OrbRenderer — Metal-based real-time renderer
- OrbExporter — offline MP4 exporter (audio + video mux)

**Strict separation:**

Audio engine must survive UI failure.

⸻

## 9. STATE MODEL
- **idle** — live orb, not recording
- **recording** — WAV writer active
- **playback** — orb driven by file
- **exporting** — offline render
- **error** — safe failure state

Input switching allowed only in idle.

⸻

## 10. PERFORMANCE REQUIREMENTS
- No dropped audio buffers
- Orb rendering never blocks audio thread
- Recording survives UI freezes
- Export is cancellable

**If forced to choose:**

Save audio. Kill visuals.

⸻

## 11. PRIVACY & TRUST
- Local-first
- No accounts
- No telemetry
- No analytics
- No network dependency

Voice is treated as personal material.

⸻

## 12. SUCCESS METRICS (QUALITATIVE)

AURA succeeds if:
- Two people saying the same words produce different orbs
- Silence feels calm, not broken
- Muted video still feels complete
- Exports feel intentional, not gimmicky
- Users trust AURA with private voice moments

⸻

## 13. OUT OF SCOPE (V1)
- iOS app (macOS-only for v1)
- Cloud sync
- Collaboration
- Advanced audio cleanup
- Visual themes

⸻

## 14. VIRTUAL CAMERA OUTPUT

### Live Presence Surface (MVP Feature)

AURA includes a virtual camera that streams the orb in real time to other applications.

**What It Does:**
- Makes the orb available as a system camera device
- Works with Zoom, FaceTime, OBS, Discord, etc.
- Same physics, rendering, and motion contract as MP4 exports
- Same calm, same damping, same deformation limits

**Technical Requirements:**
- Uses CoreMediaIO APIs on macOS (no driver or system extension installation)
- Appears as "AURA Orb" in camera selection menus
- 1080p or 720p output at 60fps (30fps fallback on older hardware)
- Video only (no audio routing through virtual camera)
- Must maintain same performance as export rendering

**Privacy & Trust:**
- Requires camera access permission (standard macOS security)
- Clear UI indicator when virtual camera is active and in use
- User sees which app is accessing the camera
- Can be disabled at any time
- No data leaves device without explicit user action

**Usage Modes:**
1. **Artifact mode:** Record → Replay → Export MP4
2. **Live mode:** Microphone → Orb → Virtual Camera (real-time)

Both modes use identical orb engine. Virtual camera is real-time rendering of what would be exported.

**UX Notes:**
- Toggle virtual camera on/off in main UI
- Status indicator when camera is active
- Performance warning if system struggles with real-time rendering

⸻

## 15. RELEASE PHILOSOPHY

Ship small.
Ship calm.
Do not rush features.

AURA should feel finished even at v1.

⸻

**FINAL STATEMENT**

AURA does not visualize sound.

AURA gives voice a body.

**AURA supports both durable artifacts and live presence.**

⸻

**Status:** PRD locked (macOS-only focus)
