# AURA Keyboard Shortcuts Reference

**Quick, intuitive controls for seamless workflow**

---

## Core Recording Controls

### Space Bar - Record/Stop Toggle
**State: Idle → Recording**
- **Action:** Start recording voice
- **Visual:** Status bar shows "Recording..."
- **Effect:** Orb begins responding to your voice in real-time
- **Output:** Audio saved to `~/Documents/AURA Recordings/`

**State: Recording → Idle**
- **Action:** Stop recording and save
- **Visual:** Brief confirmation message with filename
- **Effect:** WAV file saved with timestamp
- **Example:** `AURA Recording 2026-01-21 15.30.45.wav`

---

## Essential Actions

### E - Export to Video
**State: Must be Idle (not recording)**
- **Action:** Export most recent recording as MP4 video
- **Visual:** Confirmation dialog appears
- **Process:**
  1. Shows filename and estimated time
  2. Displays progress percentage in status bar
  3. Shows completion alert with "Show in Finder" option
- **Output:** `~/Documents/AURA Exports/{filename}.mp4`
- **Format:** 1080p @ 60fps, H.264, 8Mbps
- **Time:** Approximately 1:1 ratio (1 minute recording = 1 minute export)

### Escape (Esc) - Cancel/Stop
**State: Recording**
- **Action:** Cancel recording without saving
- **Visual:** "Recording cancelled" message
- **Effect:** Deletes partial recording file
- **Use Case:** Made a mistake, background noise, false start

**State: Other states**
- **Action:** Return to idle/stop current action
- **Visual:** Returns to default status bar
- **Effect:** Safe exit from any operation

---

## Alternative Controls

### R - Record (Alternative to Space)
**Same as Space Bar**
- **Action:** Start/stop recording
- **Why:** Alternative for those who prefer letter keys
- **Behavior:** Identical to Space bar

---

## Keyboard Shortcut Philosophy

AURA's keyboard controls follow these principles:

### 1. **Minimal & Memorable**
- Only essential actions have shortcuts
- Single-key commands (no Cmd/Ctrl modifiers needed)
- Letters match actions: **E**xport, **R**ecord

### 2. **Context-Aware**
- Shortcuts adapt based on app state
- Space bar is smart: starts or stops based on context
- Disabled shortcuts won't trigger accidental actions

### 3. **Safe by Default**
- Destructive actions (cancel) require confirmation via position (Escape)
- Export asks for confirmation before processing
- No shortcuts for dangerous operations without safeguards

### 4. **Discoverable**
- Status bar hints at available actions
- Example: "Press SPACE to start recording • E to export last recording"
- Clear feedback for every action

---

## State-Based Availability

### When IDLE (Not Recording)
| Key | Action | Effect |
|-----|--------|--------|
| **Space** | Start Recording | Begin capturing voice |
| **R** | Start Recording | (Alternative) Begin capturing voice |
| **E** | Export Video | Export most recent recording |

### When RECORDING (Active Recording)
| Key | Action | Effect |
|-----|--------|--------|
| **Space** | Stop Recording | Save and finish recording |
| **R** | Stop Recording | (Alternative) Save and finish |
| **Esc** | Cancel Recording | Discard recording without saving |

### When EXPORTING (Processing Video)
| Key | Action | Effect |
|-----|--------|--------|
| *(None)* | Please wait | Export must complete first |

**Note:** During export, keyboard shortcuts are temporarily disabled to prevent interruption of the encoding process.

---

## Status Bar Guide

The status bar at the bottom of the window shows available actions:

### Idle State
```
Press SPACE to start recording • E to export last recording
```

### Recording State
```
Recording... Press SPACE to stop • ESC to cancel
```

### Exporting State
```
Exporting video... 45%
```

---

## Quick Workflows

### 1. Record and Save
```
1. Press SPACE      → Start recording
2. Speak naturally  → Orb responds to your voice
3. Press SPACE      → Stop and auto-save
```
**Time:** Instant start/stop, no delays

---

### 2. Record and Export
```
1. Press SPACE      → Start recording
2. Speak naturally  → Orb visualizes your voice
3. Press SPACE      → Stop recording
4. Press E          → Export dialog appears
5. Click "Export"   → Video creation begins
6. Wait for 100%    → Progress shown in status bar
7. Click "Show in Finder" → Open exported video
```
**Time:** ~1 minute export per 1 minute of recording

---

### 3. Quick Re-record
```
1. Press SPACE      → Start recording
2. Made a mistake   → Oops!
3. Press ESC        → Cancel without saving
4. Press SPACE      → Start fresh recording
```
**Time:** Instant cancellation, no files left behind

---

## Advanced Tips

### Recording Best Practices
- **Space bar** is fastest for start/stop
- Wait for orb to appear before speaking (instant)
- Status bar confirms "Recording..." before you speak
- No need to wait for processing - stops instantly

### Export Optimization
- **Press E immediately** after stopping - export uses the last recording
- Export runs in background - you can launch another app
- **Don't minimize AURA** during export (may pause progress)
- Large recordings (>10 min) take proportionally longer

### Multi-Session Workflow
1. Record multiple short clips (Space → speak → Space)
2. Export each one (E → Export → E → Export)
3. All videos saved with timestamps in Exports folder
4. Import into video editor for final composition

---

## Keyboard Shortcut FAQ

### Q: Why no Cmd/Ctrl modifiers?
**A:** AURA follows the "calm tool" philosophy. Single keys are:
- Faster to press
- Less cognitive load
- More flow-friendly for creative work

### Q: Can I customize shortcuts?
**A:** Not yet. Phase 6 (Settings & Preferences) will add customization.
Target: Phase 6B (Week 3)

### Q: What if I press the wrong key?
**A:** Most actions are reversible:
- Recording → Press Esc to cancel
- Export → Confirmation dialog prevents accidents
- No destructive single-key shortcuts

### Q: Why is Space bar used for recording?
**A:** Space is:
- Largest key on keyboard (hard to miss)
- Natural "action" key (like push-to-talk)
- Works with one hand while gesturing/writing
- Universal (same on all keyboard layouts)

### Q: Can I use AURA while exporting?
**A:** Partially:
- Recording: ❌ Blocked (prevents conflicts)
- New export: ❌ Blocked (one export at a time)
- Viewing recordings: ✅ Possible (future feature)
- Quitting app: ⚠️ Will cancel export

---

## Accessibility Notes

### For Low Vision Users
- Status bar text is large (13pt font)
- High contrast (white text on dark background)
- Clear state feedback for every action

### For Motor Impairments
- Large target keys (Space bar)
- Single key presses (no chording required)
- No timing requirements (press at your own pace)

### For Screen Reader Users
- Status bar text is readable by VoiceOver
- State changes announced clearly
- (Full screen reader support planned for Phase 6)

---

## Troubleshooting

### "Nothing happens when I press Space"
**Check:**
1. Is AURA the active window? (Click window to focus)
2. Is microphone permission granted? (Check System Settings)
3. Is another recording in progress? (Look for "Recording..." status)

### "E key doesn't work"
**Check:**
1. Are you in Idle state? (Not while recording)
2. Do you have any recordings? (Record something first)
3. Is an export already in progress? (Wait for completion)

### "Recording cancelled accidentally"
**Solution:**
- Esc key is intentionally far from Space/R
- If you frequently press Esc accidentally, use mouse position to avoid
- Future: Phase 6 will add "Confirm Cancel" option

---

## Coming Soon (Phase 6)

### Planned Shortcuts
- **P** - Playback last recording (Phase 6B)
- **D** - Device selector (Phase 6B)  
- **Cmd+,** - Settings/Preferences (Phase 6B)
- **Cmd+?** - Help/Keyboard shortcuts reference (Phase 6C)

### Planned Improvements
- Customizable keyboard shortcuts
- Keyboard shortcut hints in UI
- Confirmation dialogs for all destructive actions
- Global hotkeys (record from any app)

---

## Current Limitations

### Not Yet Implemented
- ❌ Pause during recording (must stop and restart)
- ❌ Playback controls (play/pause/scrub)
- ❌ Device switching via keyboard
- ❌ Multiple simultaneous exports
- ❌ Export cancellation (once started, must complete)

### Workarounds
- **Need to pause?** Press Space to stop, Space again to resume (creates separate files)
- **Wrong device?** Must restart AURA (Phase 6 will add device picker)
- **Cancel export?** Quit app (will implement graceful cancel in Phase 6)

---

## Platform Differences

### macOS (Current)
- Space, E, R, Esc all work as documented
- Cmd+Q to quit (standard macOS)
- Cmd+W to close window

### iOS (Future)
- On-screen buttons replace keyboard shortcuts
- Tap = Space bar equivalent
- Swipe gestures for quick actions

### iPadOS (Future)
- Hardware keyboard: Same as macOS shortcuts
- Touch: Same as iOS gestures
- Apple Pencil: Double-tap to toggle recording

---

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────┐
│              AURA KEYBOARD SHORTCUTS                    │
├─────────────────────────────────────────────────────────┤
│  Space Bar  │  Record/Stop Recording                    │
│  E          │  Export to Video (1080p60 MP4)           │
│  R          │  Record/Stop (Alternative)                │
│  Esc        │  Cancel Recording / Stop                  │
├─────────────────────────────────────────────────────────┤
│  STATE: IDLE                                            │
│    • Space/R → Start recording                          │
│    • E → Export most recent                             │
│                                                          │
│  STATE: RECORDING                                       │
│    • Space/R → Stop and save                            │
│    • Esc → Cancel without saving                        │
└─────────────────────────────────────────────────────────┘
```

**Print this reference and keep it handy while learning AURA!**

---

**Last Updated:** January 21, 2026  
**AURA Version:** Phase 6A (Video Export Foundation)  
**Document Version:** 1.0
