# TESTING-SCENARIOS — Edge Case Coverage

⸻

## 0. PURPOSE

Expand ARCHITECTURE.md testing section with concrete scenarios.

This ensures:
- Critical edge cases documented
- Failure modes tested before production
- Developer knows what "works" means
- No assumptions about "obvious" behavior

⸻

## 1. TESTING PHILOSOPHY

### Test Categories
1. **Unit Tests** — Isolated module behavior (deterministic)
2. **Integration Tests** — Cross-module workflows (audio → physics → render)
3. **Manual Tests** — Human-observed behavior (feel, UX, edge cases)
4. **Stress Tests** — Limits and degradation (long recordings, low resources)

### Priority
**Audio safety > Visual quality > UX polish**

If forced to choose, test audio correctness first.

---

## 2. UNIT TESTS (AUTOMATED)

### OrbPhysics

**Test: Silence Returns to Rest**
```swift
func testSilenceReturnsToRest() {
    let physics = OrbPhysics()
    physics.applyForce(radial: 0.0, ripple: 0.0, impulse: 0.0)
    
    // Run physics for 3 seconds (180 frames @ 60Hz)
    for _ in 0..<180 {
        physics.update(deltaTime: 1.0/60.0)
    }
    
    // All vertices should be at base radius ±0.1%
    for vertex in physics.vertices {
        XCTAssertEqual(vertex.distance, physics.baseRadius, accuracy: 0.001)
    }
}
```

---

**Test: Impulse Decays to Rest**
```swift
func testImpulseDecay() {
    let physics = OrbPhysics()
    physics.applyImpulse(magnitude: 0.5, direction: .radial)
    
    let initialEnergy = physics.kineticEnergy
    
    // Run for 2 seconds
    for _ in 0..<120 {
        physics.update(deltaTime: 1.0/60.0)
    }
    
    let finalEnergy = physics.kineticEnergy
    
    // Energy should decay by >95%
    XCTAssertLessThan(finalEnergy, initialEnergy * 0.05)
}
```

---

**Test: Max Deformation Clamp**
```swift
func testMaxDeformationClamp() {
    let physics = OrbPhysics()
    
    // Apply massive force (should clamp at 3%)
    physics.applyForce(radial: 10.0, ripple: 0.0, impulse: 0.0)
    physics.update(deltaTime: 1.0/60.0)
    
    for vertex in physics.vertices {
        let deformation = abs(vertex.distance - physics.baseRadius)
        XCTAssertLessThanOrEqual(deformation, physics.baseRadius * 0.03)
    }
}
```

---

**Test: Determinism (Same Input → Same Output)**
```swift
func testDeterminism() {
    let physics1 = OrbPhysics()
    let physics2 = OrbPhysics()
    
    let forces = [(0.3, 0.1), (0.5, 0.2), (0.2, 0.05)] // (radial, ripple)
    
    for (radial, ripple) in forces {
        physics1.applyForce(radial: radial, ripple: ripple, impulse: 0.0)
        physics2.applyForce(radial: radial, ripple: ripple, impulse: 0.0)
        
        physics1.update(deltaTime: 1.0/60.0)
        physics2.update(deltaTime: 1.0/60.0)
    }
    
    // Vertices should match exactly
    for (v1, v2) in zip(physics1.vertices, physics2.vertices) {
        XCTAssertEqual(v1.position, v2.position, accuracy: 0.0001)
    }
}
```

---

### StateManager

**Test: Invalid State Transitions Rejected**
```swift
func testInvalidStateTransitions() {
    let stateManager = StateManager()
    
    stateManager.transition(to: .recording(device: testDevice, startTime: Date()))
    
    // Cannot switch device while recording
    let result = stateManager.canSwitchDevice()
    XCTAssertFalse(result)
    
    // Cannot start playback while recording
    XCTAssertThrows(stateManager.transition(to: .playback(file: testFile, position: 0.0)))
}
```

---

**Test: Cancellation Cleanup**
```swift
func testCancellationCleanup() {
    let stateManager = StateManager()
    let tempFile = createTempWAVFile()
    
    stateManager.transition(to: .recording(device: testDevice, startTime: Date()))
    stateManager.cancelRecording(deleteFile: true)
    
    // State returns to idle
    XCTAssertEqual(stateManager.currentState, .idle)
    
    // File deleted
    XCTAssertFalse(FileManager.default.fileExists(atPath: tempFile.path))
}
```

---

### WavRecorder

**Test: Partial File Valid WAV**
```swift
func testPartialFileValidWAV() {
    let recorder = WavRecorder(destination: tempFile)
    recorder.start()
    
    // Write 10 buffers
    for _ in 0..<10 {
        recorder.write(buffer: testAudioBuffer)
    }
    
    // Force close without proper finalization
    recorder.forceClose()
    
    // File should still be readable
    let audioFile = try? AVAudioFile(forReading: tempFile)
    XCTAssertNotNil(audioFile)
    XCTAssertGreaterThan(audioFile?.length ?? 0, 0)
}
```

---

## 3. INTEGRATION TESTS

### Audio → Physics Pipeline

**Test: Audio RMS Drives Orb Expansion**
```swift
func testAudioToPhysics() {
    let audioEngine = AudioCaptureEngine()
    let physics = OrbPhysics()
    
    // Inject test audio (sine wave, known RMS)
    let testAudio = generateSineWave(frequency: 440, rms: 0.5, duration: 1.0)
    
    audioEngine.processBuffer(testAudio) { features in
        physics.applyForce(radial: features.rms * 0.03, ripple: 0.0, impulse: 0.0)
    }
    
    physics.update(deltaTime: 1.0/60.0)
    
    // Orb should expand (average radius > baseRadius)
    let avgRadius = physics.vertices.map { $0.distance }.reduce(0, +) / Float(physics.vertices.count)
    XCTAssertGreaterThan(avgRadius, physics.baseRadius)
}
```

---

### Playback → Export Pipeline

**Test: Export Matches Playback**
```swift
func testExportMatchesPlayback() {
    let audioFile = loadTestAudioFile() // Known audio
    
    // Run playback physics
    let playbackPhysics = OrbPhysics()
    let playbackFrames = simulatePlayback(audioFile: audioFile, physics: playbackPhysics)
    
    // Run export physics (same audio)
    let exportPhysics = OrbPhysics()
    let exportFrames = simulateExport(audioFile: audioFile, physics: exportPhysics)
    
    // Frame-by-frame comparison
    XCTAssertEqual(playbackFrames.count, exportFrames.count)
    
    for (playbackFrame, exportFrame) in zip(playbackFrames, exportFrames) {
        XCTAssertEqual(playbackFrame.vertices, exportFrame.vertices, accuracy: 0.001)
    }
}
```

---

## 4. MANUAL TESTS (HUMAN-OBSERVED)

### Audio Quality

**Test: No Dropped Buffers (Normal Load)**
1. Start recording
2. Speak continuously for 5 minutes
3. Monitor console for buffer warnings
4. **Expected:** Zero "buffer dropped" logs

---

**Test: Recording Survives UI Freeze**
1. Start recording
2. Speak for 10 seconds
3. Trigger intentional UI freeze (blocking main thread for 2 seconds)
4. Stop recording
5. **Expected:** Audio file complete, no gaps

---

### Orb Behavior

**Test: Silence Feels Intentional**
1. Start live orb (idle mode)
2. Remain silent for 10 seconds
3. **Expected:** Orb returns to rest, no jitter, no "dead" feel

---

**Test: Two People Saying "Hello" Produce Different Orbs**
1. Person A says "hello" (record)
2. Person B says "hello" (record)
3. Play back both recordings side-by-side
4. **Expected:** Visibly different orb motion (timing, deformation, ripples)

---

**Test: Muted Video Still Feels Complete**
1. Export video of 1-minute recording
2. Play video with audio muted
3. **Expected:** Orb motion feels like presence, not random noise

---

**Test: Orb Motion 3× Slower Than Literal Audio**
1. Play recording of clapping (sharp transients)
2. Observe orb response time
3. **Expected:** Orb reacts over ~300-500ms, not instantly

---

### Keyboard Shortcuts

**Test: Space Key Context-Dependent**
1. Idle → press Space → starts recording
2. Recording → press Space → stops recording
3. Playback → press Space → pauses playback
4. **Expected:** No mode confusion, behavior obvious from context

---

**Test: Rapid Space Presses No Double-Trigger**
1. Idle → press Space rapidly 5 times
2. **Expected:** Only one recording starts (debouncing works)

---

## 5. STRESS TESTS

### Long Recording

**Test: 1-Hour Recording**
1. Start recording
2. Leave running for 1 hour (continuous input or silence)
3. Stop recording
4. **Expected:**
   - File size: ~330 MB (48kHz, 16-bit, mono)
   - File valid and playable
   - No memory leaks (monitor Activity Monitor)
   - No buffer overruns

---

### Disk Full During Recording

**Test: Graceful Stop on Disk Full**
1. Create test volume with 50 MB free space
2. Start recording to that volume
3. Record until disk fills
4. **Expected:**
   - Recording stops gracefully
   - Partial file saved (valid WAV)
   - Error message shown: "Disk full. Recording stopped."
   - No crash

---

### Low Memory

**Test: Rendering Degrades, Audio Continues**
1. Start recording
2. Open memory-intensive apps (fill RAM)
3. Continue recording
4. **Expected:**
   - Audio recording continues (priority thread)
   - Orb rendering may drop frames (acceptable)
   - No audio dropouts

---

### Rapid State Changes

**Test: Record → Cancel → Playback → Export → Cancel**
1. Start recording → cancel after 2 seconds
2. Open file for playback → cancel load mid-way
3. Load different file → start export → cancel export
4. **Expected:**
   - No crashes
   - Temp files cleaned up
   - State always returns to IDLE or valid state

---

## 6. EDGE CASE SCENARIOS

### Bluetooth Mic Disconnect Mid-Recording

**Test:**
1. Start recording with Bluetooth mic
2. Turn off Bluetooth mid-recording
3. **Expected:**
   - Recording stops gracefully
   - Partial file saved
   - Error shown: "Microphone disconnected. Recording stopped."
   - Falls back to built-in mic for future recordings

---

### Mac Sleep During Recording

**Test:**
1. Start recording
2. Force Mac to sleep (close laptop lid or System Sleep)
3. Wake Mac after 10 seconds
4. **Expected:**
   - Recording stopped automatically
   - Partial file saved
   - Message on wake: "Recording paused while device was locked."

---

### USB Mic Plugged In Mid-Idle

**Test:**
1. Start in idle with built-in mic
2. Plug in USB mic
3. **Expected:**
   - Device list updates automatically
   - Built-in mic remains selected (no auto-switch)
   - User can manually switch to USB mic via device picker

---

### File Renamed During Playback

**Test:**
1. Start playback of `Voice_20260121.wav`
2. While playing, rename file in Finder to `Test.wav`
3. **Expected:**
   - Playback continues (file handle remains valid)
   - Or: Playback stops with error "File moved or renamed"

---

### Export While System Time Changes

**Test:**
1. Start export
2. Change system time (forward 1 hour)
3. **Expected:**
   - Export continues normally
   - Timestamp in exported file reflects original recording time

---

### Zero-Length Recording

**Test:**
1. Start recording
2. Immediately stop (no audio captured)
3. **Expected:**
   - File created with valid WAV header, duration = 0
   - Or: File deleted automatically (empty recording)

---

### Audio Device Supports Only 44.1 kHz

**Test:**
1. Select device that only supports 44.1 kHz (not 48 kHz)
2. Start recording
3. **Expected:**
   - Recording works at 44.1 kHz
   - File metadata shows 44.1 kHz
   - Orb physics unaffected (sample rate independent)

---

## 7. PLATFORM-SPECIFIC TESTS

### macOS: Menu Bar Shortcuts

**Test:**
1. Verify all keyboard shortcuts appear in menu bar
2. Verify menu items enable/disable based on state
3. **Expected:** Grayed-out items when actions unavailable

---

### iOS: Background Behavior

**Test:**
1. Start recording
2. Switch to another app (AURA backgrounds)
3. **Expected:**
   - Recording continues in background
   - Or: Recording stops gracefully (if background mode not enabled)

---

### iOS: AirDrop Video

**Test:**
1. Export video (MP4)
2. Share via AirDrop to iPhone
3. Open on iPhone
4. **Expected:** Video plays smoothly, audio synced

---

## 8. REGRESSION TESTS (AFTER CHANGES)

### After Audio Engine Changes
- [ ] Run "No Dropped Buffers" test
- [ ] Run "Recording Survives UI Freeze" test
- [ ] Run "1-Hour Recording" test

### After Physics Changes
- [ ] Run all OrbPhysics unit tests
- [ ] Run "Determinism" test
- [ ] Manual test: "Silence Feels Intentional"

### After Rendering Changes
- [ ] Run "Export Matches Playback" test
- [ ] Visual test: No jitter or artifacts
- [ ] Performance test: 60 fps on Apple Silicon

---

## 9. ACCEPTANCE CRITERIA (SHIP BLOCKERS)

### Must Pass Before V1
- [ ] Zero audio dropouts in 10-minute recording
- [ ] Partial file recovery works (forced app termination)
- [ ] Disk full handled gracefully (no data loss)
- [ ] Two people saying same word → different orbs
- [ ] Silence feels calm (not frozen, not jittery)
- [ ] Keyboard shortcuts work 100% reliably (macOS)
- [ ] Export video plays on iPhone (AirDrop test)

---

## FINAL PRINCIPLE

Tests must validate philosophy, not just functionality.

If orb feels reactive instead of present, tests have passed but product has failed.

⸻

**Status:** Testing scenarios locked
