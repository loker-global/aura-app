# EXPORT-SPEC — Video & Audio Export Settings

⸻

## 0. PURPOSE

Define export quality settings for audio and video output.

This ensures:
- Shareable file sizes (AirDrop, iMessage, WhatsApp)
- High quality without bloat
- Cross-platform compatibility
- Consistent output regardless of source

⸻

## 1. AUDIO EXPORT

### Format 1: WAV (Truth)
**Purpose:** Lossless archive, maximum quality

**Specification:**
```
Container: WAV (RIFF WAVE)
Codec: PCM (uncompressed)
Sample Rate: 48 kHz (or source rate if different)
Bit Depth: 16-bit
Channels: 1 (mono)
Byte Order: Little-endian
```

**File Size (estimated):**
- 1 minute: ~5.5 MB
- 5 minutes: ~27.5 MB
- 10 minutes: ~55 MB

**Use Case:**
- Archival
- Further processing in DAW
- Maximum fidelity

---

### Format 2: MP3 (Transport)
**Purpose:** Shareable compressed audio

**Specification:**
```
Container: MP3
Codec: MPEG-1 Audio Layer 3
Sample Rate: 48 kHz
Bit Rate: 128 kbps (CBR - Constant Bit Rate)
Channels: 1 (mono)
Quality: High
```

**Why 128 kbps?**
- Voice-optimized (speech doesn't need 320 kbps)
- Balance quality vs. size
- Universal compatibility

**File Size (estimated):**
- 1 minute: ~960 KB
- 5 minutes: ~4.8 MB
- 10 minutes: ~9.6 MB

**Use Case:**
- Sharing via messaging apps
- Phone storage optimization
- Streaming playback

---

### Encoding (macOS/iOS)
**Use AVFoundation AVAssetExportSession**

```swift
// MP3 export
let exportSession = AVAssetExportSession(asset: audioAsset, 
                                        presetName: AVAssetExportPresetMediumQuality)
exportSession.outputFileType = .mp3
exportSession.audioTimePitchAlgorithm = .spectral
```

**No third-party encoders** (LAME, etc.)

---

## 2. VIDEO EXPORT

### Container
**MP4** (MPEG-4 Part 14)

**Why MP4?**
- Universal compatibility (iOS, macOS, WhatsApp, iMessage)
- Streamable (moov atom optimization)
- Supports both H.264 and HEVC

---

### Video Codec
**H.264 (AVC)** — default

**Specification:**
```
Codec: H.264 (AVC)
Profile: High
Level: 4.2
Bit Rate: 8 Mbps (VBR - Variable Bit Rate)
Frame Rate: 60 fps
Resolution: 1080p (1920×1080)
Color Space: sRGB
Pixel Format: YUV 4:2:0
```

**Why H.264 (not HEVC)?**
- Maximum compatibility (older devices, web, messaging apps)
- HEVC requires iOS 11+/macOS 10.13+ (H.264 works everywhere)
- File size difference minimal for orb content (low motion complexity)

**Optional: HEVC (future enhancement)**
- Enable if user opts in
- Reduces file size ~30% for same quality
- Requires: "Export for newer devices only?" prompt

---

### Resolution Options

**Default: Match Source**
- If live recording: match display resolution
- If playback: match window size at recording time

**Fallback resolutions:**
```
1080p (1920×1080) — recommended default
720p (1280×720)   — if source <1080p or device limited
4K (3840×2160)    — future enhancement (user opt-in)
```

**Why 1080p default?**
- Shareable via AirDrop/iMessage without downsizing
- Looks great on phone screens
- Balances quality vs. file size

---

### Frame Rate
**60 fps** — default

**Why 60 fps?**
- Orb motion is smooth (physics at 60 Hz)
- Modern devices support 60 fps playback
- Calm motion benefits from smoothness

**Fallback:**
- 30 fps if export performance struggles (Intel Macs)

---

### Bit Rate
**8 Mbps VBR** (H.264, 1080p60)

**Why 8 Mbps?**
- Orb content is low complexity (single object, simple background)
- Minimal temporal changes (slow motion)
- Higher bitrate wastes space without quality gain

**Adaptive:**
```
1080p60: 8 Mbps
720p60: 5 Mbps
1080p30: 5 Mbps
720p30: 3 Mbps
```

---

### Audio in Video
**AAC** (Advanced Audio Coding)

**Specification:**
```
Codec: AAC-LC (Low Complexity)
Sample Rate: 48 kHz
Bit Rate: 128 kbps
Channels: 1 (mono)
```

**Why AAC?**
- Standard for MP4 container
- Better quality than MP3 at same bitrate
- Native iOS/macOS support

---

### File Size Estimates (1080p60, H.264, 8 Mbps)
```
1 minute: ~60 MB
5 minutes: ~300 MB
10 minutes: ~600 MB
```

**Comparison to photos:**
- iPhone photo: ~2-5 MB
- AURA 1-minute video: ~60 MB (acceptable for sharing)

---

## 3. EXPORT QUALITY TIERS

### V1: Single Quality (Recommended)
**1080p60, H.264, 8 Mbps**
- No user choice (reduces complexity)
- Works for 95% of use cases
- Predictable file sizes

### Future (V1.1+): Quality Options
**High Quality**
- 1080p60, HEVC, 10 Mbps
- Larger files, best for archival

**Shareable**
- 1080p30, H.264, 5 Mbps
- Smaller files, iMessage-optimized

**Low Bandwidth**
- 720p30, H.264, 3 Mbps
- Minimal size, WhatsApp-friendly

**V1 recommendation:** Ship single quality, iterate based on feedback.

---

## 4. ENCODING PIPELINE

### Video Render Loop
```swift
// OrbExporter workflow
1. Load audio file
2. Extract audio features (offline analysis)
3. Run physics simulation (deterministic replay)
4. For each frame:
   a. Update physics (60 Hz)
   b. Render orb to Metal texture (headless)
   c. Read back pixel buffer
   d. Append to AVAssetWriterInput
5. Finalize video file (moov atom optimization)
```

### AVAssetWriter Configuration
```swift
let videoSettings: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: 1920,
    AVVideoHeightKey: 1080,
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: 8_000_000, // 8 Mbps
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        AVVideoExpectedSourceFrameRateKey: 60,
        AVVideoMaxKeyFrameIntervalKey: 120 // keyframe every 2 seconds
    ]
]

let audioSettings: [String: Any] = [
    AVFormatIDKey: kAudioFormatMPEG4AAC,
    AVSampleRateKey: 48000,
    AVNumberOfChannelsKey: 1,
    AVEncoderBitRateKey: 128_000 // 128 kbps
]
```

---

## 5. EXPORT PERFORMANCE

### Target Speed
**Real-time factor ≤ 2×**
- 2 minutes of audio → 4 minutes to export (max)
- Faster on Apple Silicon (often <1.5×)

### Optimization
- Metal headless rendering (no display overhead)
- Offline physics (no UI updates)
- Background priority (doesn't block UI)

### Progress Reporting
```swift
let progress: Float = currentFrame / totalFrames
```
- Update every 0.5 seconds
- Show estimated time remaining
- Cancellable at any point

---

## 6. EXPORT UI FLOW

### macOS
1. User clicks "Export Video"
2. Show NSSavePanel
   - Default name: `Voice_20260121_143022.mp4`
   - Default location: Desktop
   - Allowed types: `.mp4`
3. User confirms
4. Show progress indicator (non-modal window)
5. On completion: reveal in Finder

### iOS
1. User taps "Export Video"
2. Show activity indicator (no file picker)
3. On completion: show share sheet
   - Save to Photos
   - AirDrop
   - Messages
   - Files (user picks location)

---

## 7. FILE NAMING (EXPORT)

### Convention
**Match source filename, change extension**

**Examples:**
```
Voice_20260121_143022.wav → Voice_20260121_143022.mp3
Voice_20260121_143022.wav → Voice_20260121_143022.mp4
```

### Collision Handling
**macOS:**
- NSSavePanel shows overwrite dialog
- User chooses: Replace / Cancel / Rename

**iOS:**
- Photos app: auto-increment (Photos handles it)
- Files app: UIDocumentPicker handles collision

---

## 8. METADATA

### MP4 Metadata (iTunes-style tags)
```swift
// Embedded in MP4 container
let metadata: [AVMetadataItem] = [
    AVMetadataItem(key: AVMetadataCommonKeyTitle, value: "Voice Recording"),
    AVMetadataItem(key: AVMetadataCommonKeyCreationDate, value: recordingDate),
    AVMetadataItem(key: AVMetadataCommonKeySoftware, value: "AURA v1.0")
]
```

**No GPS, no device info** (privacy)

---

## 9. CANCELLATION

### User Cancels During Export
1. Stop rendering immediately
2. Close AVAssetWriter (finalize partial file)
3. **Delete partial file** (not usable, confusing)
4. Return to idle state

**No:** "Resume export" feature (complexity not justified)

---

## 10. ERROR HANDLING

### Disk Full
- Detect before export starts (<100 MB free → warn)
- If disk fills during export: stop gracefully, delete partial file

### Encoding Failure
- Codec unavailable (rare): show error, suggest system update
- File write error: check permissions, suggest alternate location

### Export Timeout
- If export takes >10× real-time: cancel with error
- Likely cause: system overload or hardware failure

---

## 11. VALIDATION

### Post-Export Checks
1. File exists and is >0 bytes
2. File duration matches source audio
3. File is playable (QuickTime / AVPlayer validation)

### Quality Check (Debug Mode)
- Compare exported video frame to reference render
- Flag if visual divergence >1% (physics determinism check)

---

## 12. VIRTUAL CAMERA OUTPUT (MVP FEATURE)

### Live Streaming (Not Export)

AURA provides real-time orb output as a system camera device for use in other applications.

**Key Differences from MP4 Export:**
- Live streaming (not file-based)
- Real-time rendering (no offline processing)
- No encoding to disk (direct frame buffer output)
- Lower latency (<50ms target)

**Technical Specification:**

```
Platform: macOS (CoreMediaIO APIs)
Camera Name: "AURA Orb"
Resolution: 1080p (1920×1080) preferred, 720p fallback
Frame Rate: 60 fps (30 fps fallback on older hardware)
Format: YUV 4:2:0 (kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
Color Space: sRGB
Latency Target: <50ms (audio input → camera frame output)
```

**Implementation:**
- Uses CoreMediaIO Extension APIs (macOS 12.3+)
- No separate driver installation
- Integrated into AURA app bundle
- Activated/deactivated from main UI

**Performance Requirements:**
- Must maintain frame rate (60fps or 30fps)
- Cannot drop audio buffers
- Should monitor system load
- Graceful degradation if overloaded

**Privacy & Security:**
- Requires camera permission in Info.plist
- Clear indicator when camera is in use
- Shows consuming applications (from system)
- User can toggle on/off at any time
- Video only (no audio routing)

**What This Does NOT Affect:**
- MP4 export quality or settings
- Audio recording pipeline
- WAV file creation
- Playback functionality

**Usage:**
```
1. User enables virtual camera in AURA
2. AURA appears as "AURA Orb" in Zoom/FaceTime/etc.
3. Other app receives real-time orb video
4. User disables when done
```

**Conceptual Framing:**
- MP4 export: Voice → Presence → Artifact (durable)
- Virtual camera: Voice → Presence → Live Stream (real-time)

Both use the same orb engine. Virtual camera is real-time version of what gets exported.

---

## FINAL PRINCIPLE

Exports must feel effortless and trustworthy.

User should never question quality or compatibility.

**AURA supports both durable artifacts and live presence.**

⸻

**Status:** Export spec locked (macOS-only focus)
