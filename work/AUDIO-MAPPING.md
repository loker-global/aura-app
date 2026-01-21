# AUDIO-MAPPING — Audio Features to Physics Forces

⸻

## 0. PURPOSE

Define precisely how audio analysis drives OrbPhysics.

This spec ensures:
- Voice influences orb presence (not puppeteering)
- Motion is 3× slower than literal audio
- Syllables → micro ripples, phrases → macro shifts
- Silence has weight

⸻

## 1. AUDIO ANALYSIS PIPELINE

### Input
- PCM audio buffers from AudioCaptureEngine
- Sample rate: 48kHz (preferred) or 44.1kHz
- Buffer size: 2048 samples (~43ms @ 48kHz)
- Overlap: 50% (1024 samples)

### Output
- Force vectors applied to OrbPhysics
- Update rate: 60Hz (matches physics timestep)

⸻

## 2. FEATURES EXTRACTED

### Feature 1: RMS Energy (Root Mean Square)
**What it measures:** Overall loudness/energy

**Calculation:**
```
RMS = sqrt(sum(sample²) / bufferSize)
```

**Range:** 0.0 (silence) to 1.0 (normalized)

**Smoothing:** Exponential moving average, α = 0.15
```
smoothedRMS = α * currentRMS + (1 - α) * previousRMS
```

**Maps to:** Orb radial force (expansion/contraction pressure)

---

### Feature 2: Spectral Centroid
**What it measures:** "Brightness" of sound (weighted average of frequencies)

**Calculation:**
```
Centroid = sum(frequency * magnitude) / sum(magnitude)
```

**Range:** 0 Hz to Nyquist frequency (24kHz @ 48kHz sampling)
**Normalized range:** 0.0 to 1.0

**Smoothing:** Exponential moving average, α = 0.1

**Maps to:** Orb surface tension (higher centroid = tighter surface)

---

### Feature 3: Zero-Crossing Rate (ZCR)
**What it measures:** Noisiness/fricatives (how often signal crosses zero)

**Calculation:**
```
ZCR = count(sign(sample[i]) ≠ sign(sample[i-1])) / bufferSize
```

**Range:** 0.0 (pure tone) to 1.0 (noise)

**Smoothing:** Exponential moving average, α = 0.2

**Maps to:** Orb surface micro-ripples (high-frequency deformation)

---

### Feature 4: Onset Detection
**What it measures:** Sudden energy increases (syllable attacks, phrase starts)

**Calculation:**
```
EnergyDelta = currentRMS - previousRMS
Onset detected if EnergyDelta > threshold (0.08)
```

**Output:** Binary flag + magnitude (0.0 to 1.0)

**Cooldown:** 100ms minimum between onsets (prevents double-triggers)

**Maps to:** Impulse force (radial push outward)

---

## 3. FEATURE → FORCE MAPPING

### Force 1: Radial Expansion (from RMS)
**Purpose:** Breathing presence (not direct volume)

**Formula:**
```swift
let baseRadius: Float = 1.0 // orb rest radius
let expansionScale: Float = 0.03 // max 3% deformation
let force = smoothedRMS * expansionScale * baseRadius
```

**Application:**
- Applied as uniform radial pressure
- Pushes all orb vertices outward from center
- Damping coefficient: 0.85 (slow return to rest)

**Behavior:**
- Loud voice → gentle expansion (≤3%)
- Silence → slow return to base radius
- No instant jumps (smoothing enforces gradual change)

---

### Force 2: Surface Tension (from Spectral Centroid)
**Purpose:** Voice timbre affects orb stiffness

**Formula:**
```swift
let baseTension: Float = 10.0 // spring constant base
let tensionRange: Float = 5.0 // modulation range
let tension = baseTension + (normalizedCentroid * tensionRange)
```

**Application:**
- Modulates spring constant in physics simulation
- Higher centroid (brighter voice) → tighter surface (less deformation)
- Lower centroid (darker voice) → softer surface (more deformation)

**Behavior:**
- Bright voice (sibilants, "s" sounds) → orb feels taut
- Deep voice (vowels, "o" sounds) → orb feels fluid

---

### Force 3: Micro-Ripples (from Zero-Crossing Rate)
**Purpose:** Fricatives and breath create surface texture

**Formula:**
```swift
let rippleAmplitude: Float = 0.005 // max 0.5% local deformation
let rippleFrequency: Float = 8.0 // Hz (slow undulation)
let rippleForce = smoothedZCR * rippleAmplitude * sin(time * rippleFrequency)
```

**Application:**
- Applied as localized vertex displacement
- Uses simplex noise for spatial variation
- Affects only surface layer (not core mass)

**Behavior:**
- Fricatives ("sh", "f", "th") → subtle surface shimmer
- Pure tones (vowels) → smooth surface
- Silence → ripples fade over 2 seconds

---

### Force 4: Impulse (from Onset Detection)
**Purpose:** Phrase starts create macro shifts

**Formula:**
```swift
let impulseScale: Float = 0.5 // force magnitude
let impulseDuration: Float = 0.15 // seconds
if onset detected {
    applyImpulse(magnitude: onsetMagnitude * impulseScale, 
                 duration: impulseDuration,
                 direction: randomRadialDirection())
}
```

**Application:**
- Applied as instantaneous radial push
- Direction randomized (prevents predictable pattern)
- Decays over 150ms

**Behavior:**
- Syllable attack → brief outward pulse
- No continuous pumping (cooldown prevents rapid fire)
- Creates "phrase boundaries" visually

---

## 4. TIME-DOMAIN INTEGRATION

### Temporal Smoothing
**Why:** Prevent orb from being "audio-reactive" (feels like visualization, not presence)

**Strategy:**
1. All features use exponential moving average
2. Forces integrate over time (physics simulation, not direct mapping)
3. Inertia dominates responsiveness

**Target feel:**
- Voice influences orb over ~500ms windows
- No frame-accurate lip-sync feel
- Silence persists for 2-3 seconds before full rest

---

### Physics Update Rate
**60 Hz** (16.67ms per frame)

**Why:**
- Matches typical display refresh
- Audio buffer overlap provides enough resolution
- Higher rates (120Hz) acceptable on ProMotion displays (optional enhancement)

---

## 5. SILENCE HANDLING

### Threshold
Audio considered "silent" when:
```
smoothedRMS < 0.02 (normalized scale)
```

### Behavior
**Active silence (0-2 seconds):**
- Orb continues subtle motion from residual forces
- Micro-ripples fade exponentially (τ = 1.5s)
- Surface tension returns to baseline

**Deep silence (>2 seconds):**
- Orb reaches rest state (no motion)
- Maintains calm presence (not frozen)
- Subtle ambient motion (very slow drift, magnitude <0.001)

**Purpose:** Silence feels intentional, not broken.

---

## 6. CALIBRATION TARGETS

### Perceptual Goals
- **Whisper** (RMS ~0.1): Orb barely moves, surface calm
- **Normal speech** (RMS ~0.3-0.5): Gentle breathing motion, visible ripples
- **Loud voice** (RMS ~0.7-0.9): Clear expansion, taut surface, visible onsets
- **Shout** (RMS >0.9): Maximum expansion (3%), clipping warning if sustained

### Anti-Goals
- Must NOT feel like: music visualizer, VU meter, spectrogram
- Must NOT allow: lip-reading from motion, beat syncing, jitter

---

## 7. IMPLEMENTATION NOTES

### Thread Safety
- Feature extraction runs on audio thread (real-time priority)
- Force values copied to physics thread via lock-free ring buffer
- Physics simulation runs independently (never blocks audio)

### Performance Budget
- Feature extraction: <1ms per buffer (48kHz, 2048 samples)
- FFT for spectral centroid: use vDSP (Accelerate framework)
- All other features: simple math (no external libraries)

### Validation
- Unit test: silence → zero forces
- Unit test: impulse → force spike, then decay
- Manual test: two people saying "hello" → different orb behavior

---

## 8. TUNING PARAMETERS (INITIAL VALUES)

```swift
// Audio Analysis
let bufferSize = 2048
let overlapFactor = 0.5
let sampleRate: Float = 48000.0

// Smoothing
let rmsAlpha: Float = 0.15
let centroidAlpha: Float = 0.1
let zcrAlpha: Float = 0.2

// Force Scaling
let expansionScale: Float = 0.03 // 3% max
let tensionBase: Float = 10.0
let tensionRange: Float = 5.0
let rippleAmplitude: Float = 0.005 // 0.5% local
let impulseScale: Float = 0.5

// Onset Detection
let onsetThreshold: Float = 0.08
let onsetCooldown: TimeInterval = 0.1 // 100ms

// Silence
let silenceThreshold: Float = 0.02
let silenceDecayTime: Float = 2.0 // seconds
let ambientMotionMagnitude: Float = 0.001
```

**Note:** These are starting values. Tuning via user testing expected.

---

## 9. EXPORT BEHAVIOR

During video export (OrbExporter):
- Use identical feature extraction pipeline
- Process audio offline (no real-time constraint)
- Apply same smoothing/forces for frame-perfect reproduction
- Playback = recording re-embodiment (exact match)

---

## FINAL PRINCIPLE

Audio analysis must serve presence, not reactivity.

If the orb feels like it's "following" the voice, the mapping has failed.

⸻

**Status:** Audio mapping locked
