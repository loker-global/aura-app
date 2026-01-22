# AURA Troubleshooting Guide

## Quick Diagnostics

### Check If App Is Running
```bash
ps aux | grep -i aura | grep -v grep
```

### View Real-time Logs
```bash
log stream --predicate 'process == "aura"' --style compact
```

### Check Build Status
```bash
cd /Users/lxps/Documents/GitHub/aura-app/AURA/aura
xcodebuild -project aura.xcodeproj -scheme aura -showBuildSettings | grep PRODUCT_NAME
```

---

## Common Issues & Solutions

### Metal Validation Errors

**Symptom:** 
```
Metal: argument has a length(XXX)
```

**Solution:**
Ensure Swift and Metal `Uniforms` structs match exactly:
```swift
// Swift
struct Uniforms {
    var mvpMatrix: matrix_float4x4      // 64 bytes
    var modelMatrix: matrix_float4x4    // 64 bytes
    var normalMatrix: matrix_float4x4   // 64 bytes
    var surfaceTension: Float           // 4 bytes
    var baseRadius: Float               // 4 bytes
}

// Metal
struct Uniforms {
    float4x4 mvpMatrix;
    float4x4 modelMatrix;
    float4x4 normalMatrix;
    float surfaceTension;
    float baseRadius;
};
```

**Verification:**
```bash
# Should show NO errors
log show --predicate 'process == "aura" AND category == "Metal"' --last 10s
```

---

### Audio Not Working

**Symptom:** No orb response when speaking

**Checks:**
1. **Microphone Permission**
   ```bash
   # Check permission status
   sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \
     "SELECT service, client, auth_value FROM access WHERE service='kTCCServiceMicrophone'"
   ```
   Should show `gold.ok.aura` with `auth_value=2` (allowed)

2. **Audio Device**
   ```bash
   # List audio input devices
   system_profiler SPAudioDataType | grep -A 5 "Input"
   ```

3. **Audio Engine Status**
   Check logs for:
   ```
   [AudioCaptureEngine] Started successfully at XXXXXHz
   ```

**Solution:**
- Open System Settings → Privacy & Security → Microphone
- Enable "aura"
- Restart app

---

### Recording Not Saving

**Symptom:** Press Space but no WAV file appears

**Checks:**
1. **Recording Directory Exists**
   ```bash
   ls -la ~/Desktop/aura-recordings/
   ```

2. **Disk Permissions**
   ```bash
   touch ~/Desktop/aura-recordings/test.txt
   rm ~/Desktop/aura-recordings/test.txt
   ```

3. **Check Logs**
   ```bash
   log show --predicate 'process == "aura"' --last 30s | grep WavRecorder
   ```

**Expected Output:**
```
[WavRecorder] Recording started: aura_YYYYMMDD_HHMMSS.wav
[WavRecorder] Recording saved: [path]
```

---

### Black Screen (No Orb)

**Symptom:** App launches but shows only black screen

**Checks:**
1. **Metal Device Available**
   ```bash
   system_profiler SPDisplaysDataType | grep -A 3 "Metal"
   ```

2. **Renderer Initialization**
   Check logs for:
   ```
   [OrbRenderer] Initialized successfully
   [OrbRenderer] Created sphere mesh: XXX vertices, XXX triangles
   ```

3. **View Setup**
   Check logs for:
   ```
   [ViewController] View loaded
   [AuraCoordinator] Initialized
   ```

**Solutions:**
- Ensure running on Mac with Metal support
- Check Console for shader compilation errors
- Verify OrbShaders.metal is included in build

---

### CoreAudio Warnings

**Symptom:** Console shows `AddInstanceForFactory` or `-10877` errors

**Status:** ⚠️ **HARMLESS** - These are system warnings, not errors

**What They Mean:**
- macOS audio plugin system is initializing
- Audio codec factories are being queried
- Normal behavior for AVFoundation apps

**Impact:** None - app functions normally

**When to Worry:**
Only if accompanied by actual audio failures (no sound capture)

**Verification:**
```bash
# App should still show successful audio start
log show --predicate 'process == "aura"' --last 10s | grep "Started successfully"
```

---

### Build Failures

**Symptom:** Xcode build fails

**Common Causes:**

1. **Derived Data Corruption**
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/aura-*
   cd /Users/lxps/Documents/GitHub/aura-app/AURA/aura
   xcodebuild clean build
   ```

2. **Project File Issues**
   ```bash
   cd /Users/lxps/Documents/GitHub/aura-app/AURA/aura
   git status
   # If project.pbxproj is modified unexpectedly:
   git checkout aura.xcodeproj/project.pbxproj
   ```

3. **Missing Files**
   ```bash
   # Verify all source files exist
   find AURA/aura/aura -name "*.swift" -type f
   find AURA/aura/aura -name "*.metal" -type f
   ```

---

## Performance Diagnostics

### Check Frame Rate
```bash
# Should show consistent 60fps rendering
log stream --predicate 'process == "aura"' | grep -i "frame\|fps"
```

### Audio Latency
Expected audio processing latency: < 50ms
```bash
# Look for timing info in logs
log stream --predicate 'process == "aura"' | grep -i "latency\|timing"
```

### Memory Usage
```bash
# Monitor memory while app is running
top -pid $(pgrep -x aura) -stats pid,command,mem,cpu -l 5
```

Expected:
- Memory: < 100 MB
- CPU: 5-15% idle, up to 30% when recording

---

## Reset Everything

If all else fails:

```bash
# 1. Stop app
killall aura

# 2. Clean build artifacts
rm -rf ~/Library/Developer/Xcode/DerivedData/aura-*

# 3. Reset app permissions
tccutil reset Microphone gold.ok.aura

# 4. Rebuild
cd /Users/lxps/Documents/GitHub/aura-app/AURA/aura
xcodebuild clean build

# 5. Launch fresh
open /Users/lxps/Library/Developer/Xcode/DerivedData/aura-*/Build/Products/Debug/aura.app
```

---

## Useful Commands

### Build & Run
```bash
cd /Users/lxps/Documents/GitHub/aura-app/AURA/aura
xcodebuild -project aura.xcodeproj -scheme aura build && \
open /Users/lxps/Library/Developer/Xcode/DerivedData/aura-*/Build/Products/Debug/aura.app
```

### Watch Logs Live
```bash
log stream --predicate 'process == "aura"' --style compact --color always
```

### Check All Recordings
```bash
ls -lh ~/Desktop/aura-recordings/*.wav
```

### Play Recording
```bash
afplay ~/Desktop/aura-recordings/aura_*.wav
```

### Audio File Info
```bash
afinfo ~/Desktop/aura-recordings/aura_*.wav
```

---

## Debug Symbols

To enable verbose Metal debugging:

1. Edit scheme in Xcode
2. Run → Arguments → Environment Variables
3. Add:
   - `MTL_DEBUG_LAYER` = `1`
   - `MTL_SHADER_VALIDATION` = `1`

---

## Getting Help

### Check Documentation
- `/docs/README.md` - Architecture overview
- `/AURA-MANIFEST.md` - Project philosophy
- `/QUICKSTART.md` - Getting started
- `/FIXES-APPLIED.md` - Recent fixes

### Console Filtering
```bash
# Only errors
log show --predicate 'process == "aura" AND messageType == 16' --last 1m

# Metal only
log show --predicate 'process == "aura" AND subsystem CONTAINS "Metal"' --last 1m

# Audio only  
log show --predicate 'process == "aura" AND message CONTAINS "Audio"' --last 1m
```

---

**Last Updated:** 2024
**App Version:** Phase 5 Complete
**Status:** Production Ready ✅
