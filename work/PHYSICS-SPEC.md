# PHYSICS-SPEC — Orb Physics Simulation Constants

⸻

## 0. PURPOSE

Define concrete physics constants for OrbPhysics module.

This ensures:
- Motion is 3× slower than literal audio
- Deformation ≤ 3% of radius
- Inertia dominates responsiveness
- Silence has weight

⸻

## 1. SIMULATION MODEL

### Physics Engine
**Type:** Mass-spring-damper system with spherical constraint

**Update Rate:** 60 Hz (16.67ms timestep)
- Optional: 120 Hz on ProMotion displays (8.33ms timestep)
- Fixed timestep (not variable) for deterministic replay

**Integration Method:** Velocity Verlet (stable, energy-conserving)

---

## 2. ORB GEOMETRY

### Base Configuration
```swift
let baseRadius: Float = 1.0 // meters (unit sphere)
let vertexCount: Int = 2562 // icosphere subdivision 5
let mass: Float = 1.0 // kg (unit mass)
```

### Coordinate System
- Center: (0, 0, 0)
- Radius defined in local space (scaled for rendering)
- No rotation (orb is spherically symmetric)

---

## 3. MASS & INERTIA

### Core Mass
```swift
let coreMass: Float = 1.0 // kg
let momentOfInertia: Float = (2.0 / 5.0) * coreMass * (baseRadius * baseRadius)
```

**Behavior:**
- Heavy enough to resist instant changes
- Light enough to respond over ~500ms

---

## 4. SPRING SYSTEM

### Surface Springs
**Purpose:** Maintain spherical shape, allow controlled deformation

```swift
let springConstant: Float = 10.0 // N/m (base tension)
let springDamping: Float = 0.85 // dimensionless (0 = no damping, 1 = critical)
let restLength: Float = baseRadius // spring equilibrium
```

**Deformation Constraint:**
```swift
let maxDeformation: Float = baseRadius * 0.03 // 3% maximum
```

**Force Calculation:**
```swift
let displacement = currentRadius - restLength
let clampedDisplacement = clamp(displacement, -maxDeformation, maxDeformation)
let springForce = -springConstant * clampedDisplacement
let dampingForce = -springDamping * velocity
let totalForce = springForce + dampingForce
```

---

## 5. DAMPING

### Global Damping
**Purpose:** Energy dissipation, prevents endless oscillation

```swift
let globalDamping: Float = 0.75 // applied to all motion
```

**Application:**
```swift
velocity *= (1.0 - globalDamping * deltaTime)
```

**Behavior:**
- Motion decays to rest over ~2 seconds without input
- Higher damping = slower, more "massive" feel
- Lower damping = longer oscillation (too reactive, rejected)

---

## 6. FORCE APPLICATION

### Radial Force (from RMS)
**Source:** Audio energy (see AUDIO-MAPPING.md)

```swift
let radialForceScale: Float = 0.03 * baseRadius // 3% max expansion
```

**Direction:** Outward from center (uniform pressure)

---

### Impulse Force (from Onset)
**Source:** Syllable attacks

```swift
let impulseForceScale: Float = 0.5 // N·s
let impulseDuration: Float = 0.15 // seconds
```

**Direction:** Random radial (prevents predictable pattern)

---

### Surface Tension Modulation (from Spectral Centroid)
**Source:** Voice timbre

```swift
let tensionBase: Float = 10.0 // N/m
let tensionRange: Float = 5.0 // modulation ±50%
```

**Application:**
```swift
let dynamicSpringConstant = tensionBase + (centroid * tensionRange)
```

---

### Micro-Ripple Force (from ZCR)
**Source:** Fricatives, breath

```swift
let rippleAmplitude: Float = 0.005 * baseRadius // 0.5% local deformation
let rippleFrequency: Float = 8.0 // Hz
```

**Spatial Distribution:** Simplex noise (see SHADER-SPEC.md)

---

## 7. VELOCITY CONSTRAINTS

### Maximum Velocity
**Purpose:** Prevent explosive motion from audio glitches

```swift
let maxVelocity: Float = 0.5 // m/s (50% radius per second)
```

**Clamping:**
```swift
if velocity.magnitude > maxVelocity {
    velocity = velocity.normalized * maxVelocity
}
```

---

## 8. TIME SCALING (3× SLOWER RULE)

### Rationale
Audio events happen in milliseconds. Orb motion must integrate over hundreds of milliseconds to feel like presence, not reaction.

### Implementation
**Method 1: Increased mass**
- Already applied (mass = 1.0 kg for unit sphere is "heavy")

**Method 2: Increased damping**
- springDamping = 0.85 (high damping slows response)
- globalDamping = 0.75 (dissipates energy quickly)

**Method 3: Force smoothing**
- All audio features use exponential moving average (see AUDIO-MAPPING.md)
- Smoothing alpha values: 0.1–0.2 (slow response)

**Result:**
- Instant audio attack → orb responds over 300-500ms
- 3× slower than direct audio-to-visual mapping
- Feels like voice influences orb, not puppeteers it

---

## 9. COLLISION & CONSTRAINTS

### Self-Collision
**None.** Orb is a single deformable sphere (no internal structure).

### Boundary Constraints
**None.** Orb floats in infinite space (no walls, floor, ceiling).

### Deformation Clamp
**Hard constraint:** No vertex can move >3% from base radius.

```swift
let vertexDistance = length(vertexPosition)
if vertexDistance > baseRadius * 1.03 {
    vertexPosition = normalize(vertexPosition) * (baseRadius * 1.03)
}
if vertexDistance < baseRadius * 0.97 {
    vertexPosition = normalize(vertexPosition) * (baseRadius * 0.97)
}
```

---

## 10. SILENCE BEHAVIOR

### Active Silence (0–2 seconds)
- Residual forces continue (damping reduces motion)
- No new forces applied (RMS < silence threshold)
- Micro-ripples fade exponentially (τ = 1.5s)

### Deep Silence (>2 seconds)
- Orb reaches rest state (velocity → 0)
- All vertices return to base radius (no deformation)
- Subtle ambient motion (optional):
  ```swift
  let ambientFrequency: Float = 0.05 // Hz (very slow drift)
  let ambientAmplitude: Float = 0.001 * baseRadius // 0.1% drift
  ```

**Purpose:** Silence feels intentional and calm, not frozen or dead.

---

## 11. NUMERICAL STABILITY

### Integration
**Velocity Verlet** (2nd order accuracy, energy-stable):

```swift
// Position update
let acceleration = force / mass
position += velocity * dt + 0.5 * acceleration * dt * dt

// Force recalculation at new position
let newAcceleration = newForce / mass

// Velocity update
velocity += 0.5 * (acceleration + newAcceleration) * dt
```

### Timestep
**Fixed:** 16.67ms (60 Hz)
- Do NOT use variable timestep (non-deterministic)
- If frame rate drops, run multiple physics steps per render frame

---

## 12. PERFORMANCE BUDGET

### Per Frame (60 Hz)
- Vertex updates: 2562 vertices
- Spring force calculations: ~7686 springs (icosphere edges × 3)
- Total budget: <2ms per physics update

**Optimization:**
- Use SIMD for vertex math (Accelerate framework)
- Pre-compute spring rest lengths
- Spatial hashing unnecessary (small vertex count)

---

## 13. TUNING PARAMETERS (INITIAL VALUES)

```swift
// Geometry
let baseRadius: Float = 1.0
let vertexCount: Int = 2562
let mass: Float = 1.0

// Springs
let springConstant: Float = 10.0
let springDamping: Float = 0.85
let maxDeformation: Float = 0.03 * baseRadius

// Damping
let globalDamping: Float = 0.75

// Forces
let radialForceScale: Float = 0.03 * baseRadius
let impulseForceScale: Float = 0.5
let tensionBase: Float = 10.0
let tensionRange: Float = 5.0
let rippleAmplitude: Float = 0.005 * baseRadius
let rippleFrequency: Float = 8.0

// Constraints
let maxVelocity: Float = 0.5

// Silence
let silenceDecayTime: Float = 2.0
let ambientFrequency: Float = 0.05
let ambientAmplitude: Float = 0.001 * baseRadius

// Simulation
let updateRate: Float = 60.0 // Hz
let deltaTime: Float = 1.0 / updateRate
```

**Note:** Tuning expected during user testing.

---

## 14. VALIDATION TESTS

### Unit Tests
1. **Silence → Rest:** Zero forces → orb returns to base radius
2. **Impulse → Decay:** Single impulse → oscillation decays to rest in ~2s
3. **Max Deformation:** Large force → vertex displacement clamped at 3%
4. **Determinism:** Same audio input → identical orb motion (replay test)

### Manual Tests
1. **Slow Motion Feel:** Orb responds over 300-500ms, not instantly
2. **Silence Weight:** 5 seconds of silence → orb calm, not frozen
3. **No Jitter:** Continuous speech → smooth motion, no sudden jumps

---

## FINAL PRINCIPLE

Physics must enforce presence over reactivity.

If the orb feels like an audio visualizer, the constants have failed.

⸻

**Status:** Physics spec locked
