# AURA — Turn voice into a living fingerprint

<p align="center">
  <strong>Give voice a body.</strong>
</p>

---

## What is AURA?

AURA is a macOS and iOS app that transforms voice into a living visual fingerprint. Not a waveform. Not a visualization. A presence.

Voice drives a calm, embodied orb — in real time or playback. Record. Replay. Export. Local. Private. Yours.

## Philosophy

- **Tools over hype** — No flashy features, no marketing gimmicks
- **Precision** — Every constant specified, no guessing
- **Voice as memory** — Recordings are presence, not content
- **Calm > Expressive** — UI recedes, orb primary
- **Local-first** — Privacy absolute, no network
- **Reversibility** — All actions undoable or recoverable

## Features

### Core Capabilities

- **Real-Time Presence**: Microphone input drives a single orb in real time
- **Voice Recording**: Record voice to canonical WAV format (48kHz, 16-bit, mono)
- **Playback**: Re-embody recorded voice — same mapping, same inertia, same silence
- **Export**: MP4 video (H.264, 1080p60) with muxed audio for sharing

### The Orb

- Single object, central presence
- Size mostly constant, motion driven by force
- Surface behaves like a tense membrane
- Deformation ≤ 3% of radius (hard clamp)
- Color: bone/off-white (#E6E7E9) on near-black (#0E0F12)

### Audio to Physics Mapping

| Audio Feature | Physical Effect |
|---------------|-----------------|
| RMS Energy | Radial expansion (0-3%) |
| Spectral Centroid | Surface tension (spring constant) |
| Zero-Crossing Rate | Micro-ripples |
| Onset Detection | Impulse forces |

### Privacy

- Local-first — no cloud, no accounts
- No analytics, no telemetry
- Voice is treated as personal matter

## Technical Specifications

### Platform Support
- **macOS**: 12.0+ (Apple Silicon + Intel)
- **iOS**: 15.0+

### Audio Pipeline
- Sample Rate: 48 kHz
- Bit Depth: 16-bit
- Channels: Mono
- Buffer Size: 2048 samples (~43ms)

### Rendering
- Framework: Metal
- Frame Rate: 60fps
- Mesh: Icosphere (2562 vertices)
- Lighting: Simplified Phong (rim light only)

### Export
- Codec: H.264
- Resolution: 1920×1080 @ 60fps
- Video Bitrate: 8 Mbps
- Audio: AAC 128kbps mono

## Architecture

```
AURA/
├── Shared/
│   ├── Audio/               # Audio capture, recording, playback
│   │   ├── AudioDeviceRegistry.swift
│   │   ├── AudioCaptureEngine.swift
│   │   ├── AudioFeatureExtractor.swift
│   │   ├── WavRecorder.swift
│   │   └── AudioPlayer.swift
│   ├── Rendering/           # Physics, Metal, export
│   │   ├── OrbPhysics.swift
│   │   ├── OrbRenderer.swift
│   │   ├── OrbShaders.metal
│   │   └── OrbExporter.swift
│   ├── State/               # State machine, manager
│   │   ├── AppState.swift
│   │   └── StateManager.swift
│   ├── Coordination/        # Glue logic
│   │   └── AuraCoordinator.swift
│   └── Utilities/           # Shared protocols
├── iOS/                     # UIKit views, app delegate
├── macOS/                   # AppKit views, menu bar
└── Tests/                   # Unit tests
```

### Thread Model

| Thread | Priority | Purpose |
|--------|----------|---------|
| Audio | Real-time | Never blocked, buffer processing |
| Physics | High | 60Hz simulation, independent |
| Render | Normal | Can drop frames if needed |
| Main | Normal | UI only |

**Priority Chain**: Audio > Rendering > UI

## Keyboard Shortcuts (macOS)

### Recording
| Shortcut | Action |
|----------|--------|
| Space / R | Start/Stop Recording |
| Esc | Cancel Recording |

### Playback
| Shortcut | Action |
|----------|--------|
| Space | Play/Pause |
| Esc / S | Stop Playback |
| ⌘E | Export Video |

### General
| Shortcut | Action |
|----------|--------|
| ⌘O | Open File |
| ⌘D | Input Device |
| ⌘? | Show Help |
| ⌘Q | Quit |

## Building

### Requirements
- Xcode 15+
- macOS 14+ (for development)
- No third-party dependencies (system frameworks only)

### Build Steps

1. Open `AURA.xcodeproj` in Xcode
2. Select target (macOS or iOS)
3. Build and Run (⌘R)

## Testing

Run the test suite:
```bash
xcodebuild test -scheme AURA -destination 'platform=macOS'
```

### Test Coverage
- Audio feature extraction
- Physics simulation determinism
- State machine transitions
- Silence behavior

## File Management

Recordings are saved to:
- **macOS**: `~/Documents/AURA/Recordings/`
- **iOS**: App Documents folder

File naming: `Voice_YYYYMMDD_HHMMSS.wav`

## Success Criteria

AURA succeeds if:
- Two people saying "hello" produce visibly different orbs
- 5 seconds of silence feels calm and intentional
- Muted video still communicates presence
- Exports feel meaningful, not gimmicky
- Users trust AURA with private voice moments

## Anti-Patterns (What AURA is NOT)

AURA is not:
- A DAW
- A podcast editor
- A music visualizer
- A voice changer
- A transcription tool
- A social network
- A cloud platform

If it makes AURA louder, busier, or performative, it is rejected.

## Documentation

Complete specification in `./work/`:
- 19 documents
- ~25,000 words
- Zero ambiguity
- Implementation-level detail

Start with `HANDOFF-PACKAGE.md` for an index.

---

## License

MIT License

---

**AURA does not visualize sound. AURA gives voice a body.**

---

Built with Dr. X protocol (inner-loop-os)
Version 1.0 — January 2026
