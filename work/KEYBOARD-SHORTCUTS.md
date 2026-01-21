# KEYBOARD-SHORTCUTS — Platform Keyboard Map

⸻

## 0. PURPOSE

Define consistent keyboard shortcuts across macOS and iOS.

This ensures:
- Keyboard-first workflow (per DESIGN.md)
- No mode confusion
- Predictable behavior
- Platform conventions respected

⸻

## 1. PHILOSOPHY

### Design Constraints
- **Primary actions accessible via keyboard** (record, playback, export)
- **No hidden gestures** (all shortcuts documented in app)
- **State-aware** (shortcuts change based on app state)
- **No conflicts** (shortcuts unique per state)

### Platform Differences
- **macOS:** Full keyboard support (Command key primary)
- **iOS:** External keyboard support (iPad focus, optional iPhone)

---

## 2. PRIMARY SHORTCUTS (STATE-AWARE)

### State: IDLE (no recording, no playback)

| Action | macOS | iOS | Notes |
|--------|-------|-----|-------|
| Start Recording | `Space` or `R` | `Space` | Primary action |
| Open File | `Cmd+O` | `Cmd+O` | Load audio for playback |
| Device Settings | `Cmd+D` | `Cmd+D` | Audio input picker |
| Quit | `Cmd+Q` | — | macOS standard |

---

### State: RECORDING

| Action | macOS | iOS | Notes |
|--------|-------|-----|-------|
| Stop Recording | `Space` or `R` | `Space` | Toggle behavior |
| Cancel Recording | `Esc` | `Esc` | Discard file |

**Note:** No other actions available while recording (state enforcement).

---

### State: PLAYBACK

| Action | macOS | iOS | Notes |
|--------|-------|-----|-------|
| Pause/Resume | `Space` | `Space` | Toggle playback |
| Stop Playback | `Esc` or `S` | `Esc` | Return to idle |
| Export Video | `Cmd+E` | `Cmd+E` | While paused or playing |
| Export Audio | `Cmd+Shift+E` | `Cmd+Shift+E` | MP3 export |

---

### State: EXPORTING

| Action | macOS | iOS | Notes |
|--------|-------|-----|-------|
| Cancel Export | `Esc` or `Cmd+.` | `Esc` | Stop rendering |

**Note:** No other actions available while exporting.

---

## 3. SECONDARY SHORTCUTS (AVAILABLE ALWAYS)

| Action | macOS | iOS | Notes |
|--------|-------|-----|-------|
| Show Help | `Cmd+?` or `F1` | `Cmd+?` | Keyboard shortcut overlay |
| Toggle Fullscreen | `Cmd+Ctrl+F` | — | macOS only |
| Minimize | `Cmd+M` | — | macOS only |
| Hide | `Cmd+H` | — | macOS only |

---

## 4. SPACE KEY BEHAVIOR (STATE-DEPENDENT)

### Rationale
`Space` is most accessible key. Behavior must be obvious from context.

### State Machine
```
IDLE:
  Space → Start Recording

RECORDING:
  Space → Stop Recording (save file)

PLAYBACK:
  Space → Pause/Resume (toggle)

EXPORTING:
  Space → (no action, export must complete or be canceled)
```

### Conflict Resolution
**Q:** What if user presses Space during playback-to-idle transition?
**A:** Debounce 200ms after state change (ignore rapid presses)

---

## 5. ESC KEY BEHAVIOR (STATE-DEPENDENT)

### Rationale
`Esc` is universal "cancel" or "exit" key.

### State Machine
```
IDLE:
  Esc → (no action, already at rest state)

RECORDING:
  Esc → Cancel Recording (delete file, return to idle)

PLAYBACK:
  Esc → Stop Playback (return to idle)

EXPORTING:
  Esc → Cancel Export (delete partial file, return to idle)
```

---

## 6. EXPORT SHORTCUTS (CMD+E VARIANTS)

### Primary Export (Cmd+E)
**Action:** Export video (MP4)
**Availability:** During playback only (paused or playing)

### Secondary Export (Cmd+Shift+E)
**Action:** Export audio (MP3)
**Availability:** During playback only (paused or playing)

### Rationale
- Video export is primary use case (orb + audio)
- Audio export is secondary (audio-only fallback)
- Shift modifier indicates "alternate export"

---

## 7. DEVICE SWITCHING (CMD+D)

### Action
Open audio device picker (input source selection)

### Availability
**IDLE only** (per ARCHITECTURE.md state constraints)

### Behavior
- macOS: Show dropdown or modal with device list
- iOS: Show action sheet with device list

### Conflict Prevention
If user presses Cmd+D during recording → ignored (state lock)

---

## 8. FILE OPERATIONS

| Action | macOS | iOS | Notes |
|--------|-------|-----|-------|
| Open File | `Cmd+O` | `Cmd+O` | Load audio for playback |
| Close File | `Cmd+W` | `Cmd+W` | Stop playback, return to idle |
| Show in Finder | `Cmd+Shift+R` | — | Reveal recording location (macOS) |

---

## 9. HELP & DISCOVERY

### Keyboard Shortcut Overlay
**Trigger:** `Cmd+?` or `F1` (macOS), `Cmd+?` (iOS)

**Content:**
- List of current shortcuts (filtered by state)
- Example: If in RECORDING state, show only recording-relevant shortcuts

**Dismissal:** `Esc` or click outside

**Design:**
- Minimal modal overlay
- Dark background (#181B22, 90% opacity)
- White text, monospaced for keys
- Auto-dismiss after 5 seconds of inactivity

---

## 10. PLATFORM-SPECIFIC NOTES

### macOS Menu Bar
All keyboard shortcuts must appear in menu bar:
- File → Open (Cmd+O)
- File → Close (Cmd+W)
- File → Export Video (Cmd+E)
- File → Export Audio (Cmd+Shift+E)
- Edit → Device Settings (Cmd+D)
- Help → Keyboard Shortcuts (Cmd+?)

### iOS Keyboard Discoverability
- Show keyboard icon in toolbar (indicates keyboard support)
- Long-press icon → show shortcut overlay
- No assumption of external keyboard (touch-first UI)

---

## 11. ACCESSIBILITY

### VoiceOver Integration (macOS/iOS)
- All shortcuts must have VoiceOver hints
- Example: "Press Space to start recording"

### Sticky Keys / Modifier Compatibility
- All shortcuts work with Sticky Keys enabled
- No complex chord sequences (max 2 modifiers)

---

## 12. IMPLEMENTATION NOTES

### macOS (AppKit)
```swift
override func keyDown(with event: NSEvent) {
    switch state {
    case .idle:
        if event.keyCode == 49 { // Space
            startRecording()
        } else if event.modifierFlags.contains(.command) && event.characters == "o" {
            openFile()
        }
    case .recording:
        if event.keyCode == 49 || event.characters == "r" {
            stopRecording()
        } else if event.keyCode == 53 { // Esc
            cancelRecording()
        }
    // ... other states
    }
}
```

### iOS (UIKit)
```swift
override var keyCommands: [UIKeyCommand]? {
    switch state {
    case .idle:
        return [
            UIKeyCommand(input: " ", modifierFlags: [], action: #selector(startRecording)),
            UIKeyCommand(input: "o", modifierFlags: .command, action: #selector(openFile))
        ]
    case .recording:
        return [
            UIKeyCommand(input: " ", modifierFlags: [], action: #selector(stopRecording)),
            UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(cancelRecording))
        ]
    // ... other states
    }
}
```

---

## 13. TESTING CHECKLIST

### State Transition Tests
- [ ] Space in IDLE → starts recording
- [ ] Space in RECORDING → stops recording
- [ ] Space in PLAYBACK → pauses/resumes
- [ ] Esc in RECORDING → cancels (file deleted)
- [ ] Esc in PLAYBACK → stops playback
- [ ] Cmd+E during playback → exports video
- [ ] Cmd+D during recording → ignored (no state change)

### Conflict Tests
- [ ] Rapid Space presses → no double-trigger
- [ ] Cmd+O during recording → ignored
- [ ] Cmd+E during idle → ignored (no file loaded)

### Platform Tests
- [ ] macOS menu bar reflects current state
- [ ] iOS VoiceOver announces shortcuts correctly
- [ ] External keyboard on iPad works identically to macOS

---

## FINAL PRINCIPLE

Keyboard shortcuts must reduce friction, not create complexity.

If a user needs to memorize more than 3 shortcuts, the design has failed.

⸻

**Status:** Keyboard shortcuts locked
