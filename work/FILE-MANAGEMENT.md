# FILE-MANAGEMENT — Recording Storage Specification

⸻

## 0. PURPOSE

Define how AURA manages recorded voice files.

This ensures:
- Deterministic file creation
- No accidental overwrites
- Easy discovery of recordings
- Clean file organization

⸻

## 1. SAVE LOCATION

### macOS
**Primary:** `~/Documents/AURA/Recordings/`

**Fallback (if Documents inaccessible):** `~/Library/Application Support/AURA/Recordings/`

### iOS
**Primary:** App Documents directory
- Accessible via Files app
- Shareable via AirDrop/Files sharing

**Path:**
```swift
let documentsPath = FileManager.default.urls(for: .documentDirectory, 
                                             in: .userDomainMask).first
let recordingsPath = documentsPath.appendingPathComponent("Recordings")
```

### Directory Creation
- Created on first launch if missing
- Permissions: user read/write only (0700)
- No iCloud sync by default (future: user opt-in)

---

## 2. FILE NAMING CONVENTION

### Format
```
Voice_YYYYMMDD_HHMMSS.wav
```

### Examples
- `Voice_20260121_143022.wav` (Jan 21, 2026 at 2:30:22 PM)
- `Voice_20260121_143025.wav` (3 seconds later)

### Rationale
- **Timestamp-based:** Natural chronological sorting
- **No user input required:** Minimal friction, no modal dialogs
- **No spaces:** Cross-platform compatibility
- **Underscore separators:** Visual clarity
- **ISO 8601 date format:** International standard

---

## 3. COLLISION HANDLING

### Scenario
User starts two recordings within the same second (unlikely but possible).

### Strategy
**Append counter if file exists:**

```swift
var filename = "Voice_20260121_143022.wav"
var counter = 1
while fileExists(filename) {
    filename = "Voice_20260121_143022_\(counter).wav"
    counter += 1
}
```

### Example
- First recording: `Voice_20260121_143022.wav`
- Second (same second): `Voice_20260121_143022_1.wav`
- Third (same second): `Voice_20260121_143022_2.wav`

### Max Counter
100 (prevents infinite loop if filesystem issues)

---

## 4. FILE FORMAT

### Container
**WAV (RIFF WAVE)**

### Audio Spec
```
Sample Rate: 48 kHz (preferred) or 44.1 kHz (fallback)
Bit Depth: 16-bit PCM (uncompressed)
Channels: 1 (mono)
Byte Order: Little-endian
```

### Why WAV?
- Lossless (preserves true fingerprint)
- Simple format (deterministic writing)
- Universal compatibility (macOS, iOS, all players)
- No codec dependencies

### Why Mono?
- Voice is single source
- Reduces file size by 50% vs stereo
- Simplifies audio analysis (no channel mixing)

---

## 5. PARTIAL FILE HANDLING

### Scenario
Recording interrupted (app crashes, device sleeps, user kills app).

### Strategy
**Write valid WAV header on file close:**

```swift
// During recording
1. Open file, write placeholder header (duration = 0)
2. Stream PCM data chunks
3. On stop (or crash):
   - Seek to header position
   - Update duration field with actual sample count
   - Close file properly
```

### Result
- Partial recordings are valid WAV files
- Duration matches actual captured audio
- No corrupt files

### Edge Case: Forced Termination
If app killed before header update:
- File exists with placeholder header (duration = 0)
- Most players will attempt to play until EOF
- Not ideal, but recoverable (user can see file, developer can fix header manually if critical)

**Prevention:**
- Flush audio buffer to disk every 2 seconds
- Update header every 10 seconds during recording (background task)

---

## 6. METADATA

### Embedded in WAV
**INFO chunk (optional, future enhancement):**
```
INAM: "Voice Recording"
ICRD: 2026-01-21 (creation date)
ISFT: "AURA v1.0"
```

**Not included in v1:**
- No EXIF-style metadata
- No custom tags
- Keep format minimal

### External Metadata
**None.** Filename encodes timestamp (sufficient for v1).

**Future (if justified):**
- Sidecar JSON files (optional user notes)
- Playlist/collection files

---

## 7. FILE SIZE ESTIMATES

### Calculation
```
File Size = (Sample Rate × Bit Depth × Channels × Duration) / 8
```

### Examples (mono, 16-bit, 48 kHz)
- 1 minute: ~5.5 MB
- 5 minutes: ~27.5 MB
- 10 minutes: ~55 MB

### Warnings
**Low disk space threshold:** 100 MB free
- Show warning before recording if <100 MB available
- Stop recording gracefully if <10 MB during capture

---

## 8. FILE OPERATIONS

### Recording Start
1. Create filename with current timestamp
2. Check collision, append counter if needed
3. Open file handle (write-only, exclusive lock)
4. Write WAV header (placeholder duration)
5. Begin streaming PCM data

### Recording Stop
1. Flush remaining audio buffer
2. Calculate total sample count
3. Seek to header, update duration
4. Close file handle
5. Transition to idle state

### Recording Cancel
1. Stop audio stream
2. Close file handle
3. **Delete file** (user explicitly canceled)
4. Transition to idle state

---

## 9. PLAYBACK FILE SELECTION

### File Picker (macOS)
- Use `NSOpenPanel`
- File types: `.wav`, `.mp3`
- Default location: `~/Documents/AURA/Recordings/`

### File Picker (iOS)
- Use `UIDocumentPickerViewController`
- File types: `.wav`, `.mp3`
- Default location: App Documents/Recordings

### Recently Recorded
**Future enhancement (v1.1):**
- Show list of recent recordings in app
- Quick-play without file picker

**V1:** File picker only (keeps UI minimal)

---

## 10. EXPORT NAMING

### Audio Export
**Same filename as source:**
```
Voice_20260121_143022.wav → Voice_20260121_143022.mp3
```

**Save location:**
- User-selected (via save panel)
- Default suggestion: source file location

### Video Export
**Same filename, different extension:**
```
Voice_20260121_143022.wav → Voice_20260121_143022.mp4
```

**Save location:**
- User-selected (via save panel)
- Default suggestion: Desktop (macOS) or Photos (iOS)

### Collision Handling
- Ask user to overwrite or rename
- Default button: "Rename" (safe choice)
- No silent overwrites

---

## 11. FILE PERMISSIONS

### Recording Files
```
chmod 600 (user read/write only)
```

### Recordings Directory
```
chmod 700 (user read/write/execute only)
```

### Rationale
- Voice is private material
- No other users should access files
- No group/world permissions

---

## 12. CLEANUP POLICY

### Automatic Deletion
**None.** AURA never deletes user recordings without explicit action.

### User-Initiated Deletion
**Future enhancement (v1.1):**
- In-app file management
- Move to trash (recoverable)

**V1:** Use Finder/Files app to delete

---

## 13. IMPLEMENTATION NOTES

### Thread Safety
- File I/O on dedicated background queue
- Never block audio thread
- Never block UI thread

### Error Handling
Errors during recording:
- Disk full → stop recording gracefully, save partial file, show error
- Permission denied → transition to error state, explain issue
- File system error → attempt recovery, fall back to safe location

### Testing Scenarios
1. Record 3 files in rapid succession → check numbering
2. Fill disk to <10 MB during recording → graceful stop
3. Force-quit app mid-recording → file recoverable
4. Rename recording location → create new directory, continue

---

## FINAL PRINCIPLE

File management must be invisible and trustworthy.

User should never worry about losing recordings or finding them.

⸻

**Status:** File management spec locked
