# SILENCE-HANDLING — Quiet Presence Specification

⸻

## 0. PURPOSE

Define how the orb behaves during silence.

This ensures:
- Silence feels intentional (core philosophy)
- No "broken" or "frozen" perception
- Calm, stable presence maintained
- Clear distinction: active silence vs. deep rest

⸻

## 1. PHILOSOPHY

### Core Principle
**"Silence has weight."**

Silence is not the absence of presence.
Silence is a state with its own character.

### Anti-Goals
- Orb must NOT freeze instantly when audio stops
- Orb must NOT jitter or twitch in silence
- Orb must NOT feel "dead" after prolonged quiet

---

## 2. SILENCE DETECTION

### Threshold
Audio is considered "silent" when:

```swift
let silenceThreshold: Float = 0.02 // normalized RMS (0.0 to 1.0)

if smoothedRMS < silenceThreshold {
    // Audio is silent
}
```

### Why 0.02?
- Below typical ambient room noise (~-40 dBFS)
- Above ADC noise floor (~-60 dBFS)
- Prevents false triggering on quiet breaths or pauses

---

### Smoothing
RMS is smoothed with exponential moving average (α = 0.15).

This prevents rapid silence/sound transitions:
- Short pauses (<100ms) may not trigger silence state
- Continuous quiet speech maintains slight presence

---

## 3. SILENCE PHASES

### Phase 1: Active Silence (0–2 seconds)

**Characteristics:**
- Residual motion from previous audio
- Micro-ripples fade exponentially
- Radial expansion decays toward rest
- Surface tension returns to baseline

**Physics Behavior:**
```swift
// Continue physics simulation
// No new forces applied (RMS = 0)
// Damping dissipates remaining energy

velocity *= (1.0 - globalDamping * deltaTime)

// Micro-ripples fade
rippleAmplitude *= exp(-deltaTime / rippleDecayTime)
// where rippleDecayTime = 1.5 seconds
```

**Visual Feel:**
- Orb "settles" like a liquid surface after disturbance
- Slow, graceful return to rest
- No sudden stops

---

### Phase 2: Deep Silence (2–10 seconds)

**Characteristics:**
- Orb reaches rest state (velocity ≈ 0)
- All vertices at base radius (no deformation)
- Subtle ambient motion begins (very slow drift)

**Ambient Motion:**
```swift
let ambientFrequency: Float = 0.05 // Hz (20-second cycle)
let ambientAmplitude: Float = 0.001 * baseRadius // 0.1% drift

// Apply very slow sinusoidal drift
let ambientOffset = ambientAmplitude * sin(time * ambientFrequency * 2 * .pi)
```

**Purpose:**
- Prevents "frozen in time" feeling
- Maintains presence without activity
- So subtle user may not consciously notice
- Like watching a candle flame in still air

---

### Phase 3: Prolonged Silence (>10 seconds)

**Characteristics:**
- Identical to Phase 2 (no change)
- Ambient motion continues indefinitely
- Orb remains "alive" but calm

**No timeout behavior:**
- Orb does NOT disappear
- Orb does NOT go fully static
- Presence persists even in extended quiet

---

## 4. SILENCE → SOUND TRANSITION

### Resumption Behavior

When audio exceeds silence threshold again:

```swift
if smoothedRMS > silenceThreshold {
    // Resume force application immediately
    // No ramp-up needed (smoothing handles gradual increase)
}
```

**Smoothness:**
- Exponential smoothing prevents jarring jumps
- Orb responds over 300-500ms (per AUDIO-MAPPING.md)
- Transition feels natural, not abrupt

---

### Whisper → Speech Gradient

Silence threshold creates clean boundary, but smoothing creates gradient:

```
RMS 0.01 → silent (ambient drift only)
RMS 0.02 → threshold (barely moving)
RMS 0.05 → whisper (subtle motion)
RMS 0.30 → normal speech (clear presence)
```

No "pop" when crossing threshold.

---

## 5. SILENCE IN DIFFERENT STATES

### Live Orb (IDLE)
- Microphone active, no recording
- Silence detected in real-time
- Phases apply as described above

**Use Case:** User opens app, doesn't speak immediately

---

### Playback
- Silence is deterministic (embedded in audio file)
- Phases replay exactly as recorded
- If recording had 5-second pause → orb shows 5-second silence

**Use Case:** Voice memo with pauses between thoughts

---

### Export
- Offline rendering follows same physics
- Silence phases identical to playback
- No shortcuts (renders every frame, even silent ones)

**Ensures:** Exported video matches live experience

---

## 6. SILENCE EDGE CASES

### Rapid Speech with Short Pauses

**Scenario:** User speaks in short bursts with <1 second pauses

**Behavior:**
- Smoothing prevents full silence detection
- Orb maintains low-level presence
- Micro-ripples fade partially but don't disappear

**Result:** Orb feels "ready" rather than "resting"

---

### Background Noise

**Scenario:** Ambient room noise (HVAC, traffic) sustains RMS ~0.01

**Behavior:**
- Below silence threshold (0.02)
- Treated as silence
- Ambient motion continues, no audio-driven forces

**Rationale:** Background noise is not voice, should not animate orb

---

### Microphone Hiss (High-Gain Mics)

**Scenario:** USB mic with high gain produces noise floor RMS ~0.03

**Behavior:**
- Above silence threshold
- Orb shows minimal motion (noise drives small forces)

**Mitigation (Optional):**
- Future: Adaptive silence threshold (calibrate to noise floor)
- V1: User adjusts mic gain in system settings

---

## 7. VISUAL INDICATORS (OUT OF SCOPE V1)

### Optional Future Enhancement

**Idea:** Subtle UI hint during deep silence

**Examples:**
- Tiny "pulse" icon (heartbeat, low contrast)
- Barely visible text: "listening..." (fades after 3 seconds)

**Rationale:**
- Confirms app is active (not frozen)
- Reduces "is it working?" anxiety

**V1:** No indicator. Ambient motion is sufficient.

---

## 8. SILENCE IN ERROR STATES

### Microphone Disconnected
- Silence detected immediately (no input)
- Orb enters deep silence phase
- User sees error message (see ERROR-MESSAGES.md)

### Permission Denied
- No audio input (forced silence)
- Orb shows ambient motion only
- Recording disabled (button grayed out)

---

## 9. TUNING PARAMETERS

### Reference Values
```swift
// Silence Detection
let silenceThreshold: Float = 0.02 // RMS
let rmsSmoothing: Float = 0.15 // exponential moving average alpha

// Phase 1: Active Silence
let activesilenceDuration: Float = 2.0 // seconds
let rippleDecayTime: Float = 1.5 // seconds (exponential decay tau)
let globalDamping: Float = 0.75 // energy dissipation

// Phase 2: Deep Silence
let ambientFrequency: Float = 0.05 // Hz (20-second cycle)
let ambientAmplitude: Float = 0.001 // 0.1% of base radius
```

### Tuning Process
1. Implement with reference values
2. Test with various silence durations (1s, 5s, 30s, 5min)
3. Adjust if:
   - Orb feels "dead" → increase ambientAmplitude
   - Orb feels "jittery" → increase damping, decrease ambientFrequency
   - Orb responds too slowly to voice → decrease rmsSmoothing

---

## 10. TESTING SCENARIOS

### Manual Tests

**Test: 5-Second Silence Feels Intentional**
1. Speak for 10 seconds
2. Stay silent for 5 seconds
3. Speak again
4. **Expected:** Orb settles smoothly, maintains presence, resumes naturally

---

**Test: 5-Minute Silence Doesn't Feel Frozen**
1. Start live orb
2. Stay silent for 5 minutes
3. **Expected:** Subtle ambient motion visible (barely perceptible drift)

---

**Test: Whisper → Silence → Speech Gradient**
1. Whisper (RMS ~0.05)
2. Pause (RMS <0.02)
3. Speak normally (RMS ~0.3)
4. **Expected:** Smooth transitions, no sudden pops or jumps

---

### Automated Tests

**Test: Silence Threshold Detection**
```swift
func testSilenceThreshold() {
    let audioMapping = AudioMapping()
    
    // Below threshold
    let silentRMS: Float = 0.01
    XCTAssertTrue(audioMapping.isSilent(rms: silentRMS))
    
    // Above threshold
    let activeRMS: Float = 0.05
    XCTAssertFalse(audioMapping.isSilent(rms: activeRMS))
}
```

---

**Test: Ambient Motion Bounded**
```swift
func testAmbientMotionBounded() {
    let physics = OrbPhysics()
    
    // Simulate 60 seconds of deep silence
    for _ in 0..<3600 { // 60 seconds @ 60 Hz
        physics.updateAmbientMotion(time: Float(_ / 60.0))
    }
    
    // Maximum displacement should be ≤ 0.1%
    for vertex in physics.vertices {
        let displacement = abs(vertex.distance - physics.baseRadius)
        XCTAssertLessThanOrEqual(displacement, physics.baseRadius * 0.001)
    }
}
```

---

## 11. ACCEPTANCE CRITERIA

### V1 Ship Requirements
- [ ] 5-second silence feels calm (not dead)
- [ ] 5-minute silence shows subtle ambient motion
- [ ] Silence → speech transition feels natural (no pop)
- [ ] Two silence recordings feel similar (deterministic)

---

## FINAL PRINCIPLE

Silence is not absence.

Silence is presence at rest.

⸻

**Status:** Silence handling locked
