# ERROR-MESSAGES — User-Facing Copy

⸻

## 0. PURPOSE

Define error message tone and content.

This ensures:
- Calm, non-alarming communication (per DESIGN.md)
- Clear explanation without technical jargon
- Safe exit paths always offered
- Consistency across all error states

⸻

## 1. TONE PRINCIPLES

### Core Philosophy
Errors should feel like:

**"Something didn't work. You're safe."**

### Rules
- **No panic language** ("Error!", "Failed!", "Critical!")
- **No blame** ("You did X wrong")
- **No jargon** ("kAudioHardwareNoError")
- **No ALL CAPS**
- **Offer next step** (what user can do now)

### Voice
- Calm, direct, concise
- 1-2 sentences max
- Plain language
- Neutral (not overly friendly, not cold)

---

## 2. ERROR CATEGORIES

### Category 1: Recoverable (User Action Available)
**Characteristics:**
- User can fix immediately
- Clear action offered
- No data loss

**Examples:**
- Microphone permission denied
- Disk space low
- Device disconnected

---

### Category 2: Transient (Retry Possible)
**Characteristics:**
- Temporary system issue
- May resolve on retry
- No permanent failure

**Examples:**
- File system busy
- Device in use by another app
- Export timeout

---

### Category 3: Blocking (Cannot Proceed)
**Characteristics:**
- User cannot continue current action
- Must return to safe state
- Data preserved if possible

**Examples:**
- Disk full mid-recording
- Audio engine crashed
- Export codec unavailable

---

## 3. COMMON ERROR MESSAGES

### Microphone Permission Denied

**Message:**
```
Microphone access is required to record.
```

**Action Button:**
- macOS: "Open System Settings"
- iOS: "Open Settings"

**Secondary Button:** "Cancel"

**Behavior:**
- Opens system settings to privacy/microphone
- Returns to IDLE state

---

### Disk Space Low (Warning)

**Message:**
```
Low disk space. Recording may stop if space runs out.
```

**Action Button:** "Record Anyway"

**Secondary Button:** "Cancel"

**Behavior:**
- User acknowledges risk
- Recording proceeds
- If disk fills: stop gracefully (see below)

---

### Disk Full (During Recording)

**Message:**
```
Recording stopped. Disk is full.
```

**Subtext:**
```
Partial recording saved: Voice_20260121_143022.wav
```

**Action Button:** "OK"

**Behavior:**
- Recording stopped
- Partial file saved (valid WAV)
- Returns to IDLE state

---

### Audio Device Disconnected (Mid-Recording)

**Message:**
```
Microphone disconnected. Recording stopped.
```

**Subtext:**
```
Partial recording saved: Voice_20260121_143022.wav
```

**Action Button:** "OK"

**Behavior:**
- Recording stopped
- Partial file saved
- Falls back to system default device (if available)

---

### Audio Device Disconnected (Idle)

**Message (Banner, Auto-Dismiss):**
```
Blue Yeti disconnected. Switched to built-in microphone.
```

**No Buttons** (informational only)

**Behavior:**
- Automatically switches to system default
- User can continue without interruption

---

### Audio Device In Use

**Message:**
```
Could not access [Device Name]. It may be in use by another app.
```

**Action Button:** "Try Again"

**Secondary Button:** "Use Built-in Mic"

**Behavior:**
- Retry device initialization
- Or fall back to system default

---

### File Not Found (Playback)

**Message:**
```
Could not open file. It may have been moved or deleted.
```

**Action Button:** "Choose Another File"

**Secondary Button:** "Cancel"

**Behavior:**
- Opens file picker
- Or returns to IDLE state

---

### File Format Unsupported

**Message:**
```
This file format is not supported. Use WAV or MP3.
```

**Action Button:** "Choose Another File"

**Secondary Button:** "Cancel"

**Behavior:**
- Opens file picker
- Or returns to IDLE state

---

### Export Failed (Disk Full)

**Message:**
```
Export canceled. Not enough disk space.
```

**Action Button:** "OK"

**Behavior:**
- Delete partial export file
- Return to playback state

---

### Export Failed (Generic)

**Message:**
```
Export could not complete. Try again or choose a different location.
```

**Action Button:** "Try Again"

**Secondary Button:** "Cancel"

**Behavior:**
- Opens save dialog again
- Or returns to playback state

---

### Export Canceled (User)

**Message (Optional Confirmation):**
```
Export canceled.
```

**No Buttons** (brief banner, auto-dismiss)

**Behavior:**
- Delete partial export file
- Return to playback state

---

### File Already Exists (Export)

**Message:**
```
A file with this name already exists.
```

**Action Button:** "Replace"

**Secondary Button:** "Rename"

**Tertiary Button:** "Cancel"

**Behavior:**
- Replace: overwrite existing file
- Rename: append counter or let user edit name
- Cancel: return to playback

---

### Audio Engine Crashed

**Message:**
```
Audio stopped unexpectedly. Restart the app to continue.
```

**Action Button:** "Quit"

**Behavior:**
- Save any in-progress recording (if possible)
- Exit app (user restarts manually)
- No auto-restart (avoids crash loop)

---

### Recording Interrupted (Sleep/Lock)

**Message (on wake):**
```
Recording paused while device was locked.
```

**Subtext:**
```
Partial recording saved: Voice_20260121_143022.wav
```

**Action Button:** "OK"

**Behavior:**
- Partial recording saved
- Return to IDLE state

---

### No Input Devices Found

**Message:**
```
No microphone found. Connect a microphone to record.
```

**Action Button:** "OK"

**Behavior:**
- Recording disabled (button grayed out)
- User must connect device

---

### Permission Denied (File System)

**Message:**
```
Cannot save to this location. Choose a different folder.
```

**Action Button:** "Choose Folder"

**Secondary Button:** "Cancel"

**Behavior:**
- Opens save dialog
- Or returns to previous state

---

## 4. ERROR UI DESIGN

### Modal Dialog (Blocking)
**Use when:** User must acknowledge before continuing

**Style:**
```
┌─────────────────────────────────────┐
│                                     │
│  [Icon]  Message text here.         │
│                                     │
│  Optional subtext or detail.        │
│                                     │
│         [Secondary]  [Primary]      │
└─────────────────────────────────────┘
```

**Colors:**
- Background: `#181B22` (panel color)
- Text: `#E6E7E9` (white)
- Buttons: low-contrast (not bright red)

**Icons:**
- ⚠️ Warning (yellow, low saturation)
- ℹ️ Info (blue, low saturation)
- ❌ Error (red, only for destructive/critical)

---

### Banner (Non-Blocking)
**Use when:** Informational, user can continue

**Style:**
```
┌─────────────────────────────────────┐
│ [Icon] Message text here.      [×]  │
└─────────────────────────────────────┘
```

**Position:**
- Top of window (below title bar)
- Auto-dismiss after 3-5 seconds

**Colors:**
- Background: `#12141A` (secondary background)
- Text: `#E6E7E9`

---

## 5. BUTTON LABELS

### Preferred Labels (Specific Actions)
- "Open Settings"
- "Try Again"
- "Choose File"
- "OK"

### Avoid Generic Labels
- ❌ "Yes" / "No" (ambiguous)
- ❌ "Confirm" (what am I confirming?)
- ✓ "Replace File" / "Cancel" (clear)

---

## 6. ERROR LOGGING (DEVELOPER)

### User-Facing vs. Internal

**User sees:**
```
Could not access Blue Yeti. It may be in use.
```

**Console logs (debug):**
```
[AudioEngine] Failed to initialize device 'Blue Yeti' (ID: 0x1a2b3c4d)
Error: kAudioDeviceUnsupportedFormatError (-10868)
```

**Rationale:**
- User doesn't need technical details
- Developer needs full error for debugging
- Logs never shown in production UI

---

## 7. ERROR PREVENTION (BETTER THAN MESSAGES)

### Proactive Strategies
- **Disable actions** when invalid (gray out "Record" if no mic)
- **Validate before acting** (check disk space before recording)
- **Graceful degradation** (fall back to default device automatically)

**Goal:** Fewer error messages = better UX

---

## 8. ACCESSIBILITY

### VoiceOver
- Error messages announced immediately
- Button roles clear ("Open Settings" = button, not just text)

### Keyboard
- Default button focused (Enter = primary action)
- Esc = secondary/cancel action
- Tab cycles through buttons

---

## 9. LOCALIZATION NOTES (FUTURE)

### Strings to Localize
- All error message bodies
- All button labels
- Device names (if possible)

### Keep English Keys
```swift
NSLocalizedString("error.microphone.permission.denied", 
                  comment: "Microphone access required")
```

**V1:** English only (simplifies launch)

---

## 10. TESTING CHECKLIST

### Trigger Each Error
- [ ] Deny microphone permission → message shown
- [ ] Fill disk during recording → partial file saved
- [ ] Unplug USB mic mid-recording → graceful stop
- [ ] Export with no disk space → clean error
- [ ] Try to open corrupt file → clear message

### Tone Check
- [ ] No message uses "Error!" or "Failed!"
- [ ] All messages offer next step
- [ ] No technical jargon shown to user

---

## FINAL PRINCIPLE

Errors must reduce anxiety, not increase it.

User should always know what happened and what to do next.

⸻

**Status:** Error messages locked
