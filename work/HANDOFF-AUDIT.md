# HANDOFF CHECKLIST — Pre-Development Audit

⸻

## COMPLETENESS AUDIT

### ✓ Strategy Documents
- [x] GOAL.md — clear outcome, success criteria
- [x] PRD.md — requirements locked, boundaries defined
- [x] DESIGN.md — visual constraints, usability rules
- [x] PREREQUISITES.md — philosophy, core capabilities
- [x] DECISION-UI-FRAMEWORK.md — framework choice with rationale
- [x] ARCHITECTURE.md — technical blueprint, module structure

### ✓ Philosophy Lock
- [x] "Tools over hype, precision, voice as memory" stated explicitly
- [x] Non-goals clearly bounded (no DAW, no social, no cloud)
- [x] Privacy constraints absolute (local-first, no telemetry)

### ✓ Technical Lock
- [x] Thread model defined (audio never blocked)
- [x] Module boundaries drawn (5 layers)
- [x] State machine specified (5 states + transitions)
- [x] File structure mapped
- [x] Dependencies: zero third-party

---

## GAPS IDENTIFIED

### 1. **Audio Feature Extraction (MISSING SPEC)**

**Issue:** ARCHITECTURE.md says "audio features → force application" but doesn't define which features.

**Impact:** OrbPhysics implementation will require guessing.

**Recommendation:**
Create `./work/AUDIO-MAPPING.md` specifying:
- Which audio features drive physics (RMS, spectral centroid, zero-crossing rate?)
- How features map to forces (linear? log? custom curve?)
- Time-domain windowing (buffer size, overlap)
- Smoothing/damping constants

**Example missing detail:**
- "Syllables → micro ripples" — what constitutes a syllable detection?
- "Phrases → macro shifts" — what triggers a phrase boundary?

---

### 2. **Orb Physics Constants (MISSING VALUES)**

**Issue:** PREREQUISITES.md says "3× slower than literal audio" and "deformation ≤ 3%" but doesn't provide concrete physics constants.

**Impact:** Developer will need to tune via trial-and-error.

**Recommendation:**
Add to ARCHITECTURE.md or create `./work/PHYSICS-SPEC.md`:
- Mass (kg equivalent)
- Spring constant (N/m)
- Damping coefficient
- Force scaling factors
- Update rate (60Hz or 120Hz decision)
- Maximum deformation threshold (3% = ? units)

---

### 3. **Metal Shader Spec (MISSING)**

**Issue:** ARCHITECTURE.md mentions "OrbShaders.metal" and "surface deformation" but no shader algorithm specified.

**Impact:** Rendering approach unclear (vertex displacement? normal mapping? custom SDF?).

**Recommendation:**
Create `./work/SHADER-SPEC.md` or add to ARCHITECTURE.md:
- Deformation algorithm (spherical harmonics? simplex noise? physics-driven vertex displacement?)
- Lighting model (Phong? PBR-lite? custom?)
- Performance budget (triangle count, texture resolution)
- Color space (linear RGB required for proper blending)

---

### 4. **Export Quality Settings (MISSING)**

**Issue:** PRD.md says "MP4 (orb + audio muxed)" but doesn't specify codec, bitrate, resolution.

**Impact:** Export quality will be arbitrary.

**Recommendation:**
Add to PRD.md or ARCHITECTURE.md:
- Video codec (H.264 for compatibility? HEVC for quality?)
- Resolution (1080p? 4K? Match screen?)
- Frame rate (30fps? 60fps?)
- Audio codec (AAC at what bitrate?)
- File size targets (balance quality vs. shareability)

---

### 5. **Keyboard Shortcuts (MISSING MAP)**

**Issue:** DESIGN.md says "keyboard-first" but no shortcut definitions.

**Impact:** Platform views will implement inconsistent or incomplete shortcuts.

**Recommendation:**
Create `./work/KEYBOARD-SHORTCUTS.md`:
- Record/Stop (Space? R?)
- Play/Pause (Space during playback?)
- Export (Cmd+E?)
- Device switching (Cmd+D?)
- Quit (Cmd+Q)
- Conflict resolution (Space in different states?)

---

### 6. **Error Message Copy (MISSING)**

**Issue:** DESIGN.md says errors must be "quiet, clear, non-alarming" but no example copy provided.

**Impact:** Error states will lack consistency.

**Recommendation:**
Create `./work/ERROR-MESSAGES.md` with examples:
- Microphone permission denied
- Disk full during recording
- Audio device disconnected mid-recording
- Export cancellation confirmation
- File already exists (overwrite?)

Tone test: "Something didn't work. You're safe."

---

### 7. **Testing Scenarios (INCOMPLETE)**

**Issue:** ARCHITECTURE.md lists test categories but no concrete scenarios.

**Impact:** Critical edge cases may be missed.

**Recommendation:**
Expand testing section with:
- Bluetooth mic disconnect during recording (does recording save?)
- Mac goes to sleep during recording (resume behavior?)
- Disk full at 90% through recording (partial file handling?)
- Export while playback active (state transition validation)
- Rapid state changes (recording → cancel → playback → export)

---

### 8. **Device Switching UX (UNDEFINED)**

**Issue:** AudioDeviceRegistry enumerates devices but no UX for switching specified.

**Impact:** User can't change input device easily.

**Recommendation:**
Add to DESIGN.md or PRD.md:
- Device picker UI (dropdown? modal?)
- When can user switch? (only in idle state per ARCHITECTURE.md)
- Default device selection (system default? last used?)
- Device list refresh (manual? automatic when device added?)

---

### 9. **File Naming Convention (MISSING)**

**Issue:** WavRecorder saves files but no naming scheme specified.

**Impact:** Cluttered recordings folder, no metadata.

**Recommendation:**
Add to ARCHITECTURE.md:
- Naming pattern (timestamp? user-editable? incremental?)
- Example: `Voice_2026-01-21_143022.wav`
- Save location (Documents/AURA? User-selectable?)
- Overwrite behavior (prompt? auto-increment?)

---

### 10. **Minimum Viable Silence Handling (MISSING)**

**Issue:** Core philosophy: "silence feels intentional" but no definition of how long silence persists orb state.

**Impact:** Orb behavior during pauses unclear.

**Recommendation:**
Add to PHYSICS-SPEC.md:
- Decay time constant (how fast does orb return to rest?)
- Minimum energy threshold (when is audio considered "silence"?)
- Visual indicator of silence vs. stopped recording?

---

## STRENGTHS (KEEP THESE)

### ✓ Clarity
- Non-goals explicitly stated (no DAW, no social)
- Success criteria qualitative but clear ("silence feels intentional")
- Philosophy locked ("tools over hype, precision")

### ✓ Safety First
- Audio > rendering > UI priority enforced
- Partial file recovery specified
- Error handling philosophy clear

### ✓ Constraints as Features
- No third-party dependencies (reduces risk)
- Local-first (no cloud complexity)
- Keyboard-first (reduces testing surface)

### ✓ Reversibility
- UIKit/AppKit chosen for exit paths
- State machine enforces valid transitions
- Export doesn't modify originals

---

## RECOMMENDATIONS (PRIORITY ORDER)

### Critical (Block Development)
1. **Create AUDIO-MAPPING.md** — audio features → physics forces
2. **Create PHYSICS-SPEC.md** — concrete constants for OrbPhysics
3. **Define file naming + save location** — WavRecorder needs this

### High Priority (Avoid Rework)
4. **Create SHADER-SPEC.md** — rendering algorithm locked
5. **Define export quality settings** — codec, resolution, bitrate
6. **Create KEYBOARD-SHORTCUTS.md** — consistent shortcuts across platforms

### Medium Priority (UX Clarity)
7. **Device switching UX** — how user changes input
8. **Error message copy** — consistent tone examples
9. **Expand testing scenarios** — edge cases documented

### Low Priority (Nice to Have)
10. **Silence handling spec** — decay constants, thresholds

---

## FINAL VERDICT

**This is 85% ready for handoff.**

### What's Locked
- Vision and philosophy (bulletproof)
- Architecture strategy (sound)
- Framework choice (justified)
- Module boundaries (clear)

### What's Missing
- Implementation-level specs (audio mapping, physics constants, shader algorithm)
- UX micro-decisions (file naming, device switching, keyboard shortcuts)
- Copy/content (error messages)

### Recommendation

**Option A: Ship docs as-is + accept iteration**
- Developer will need to make tactical decisions
- Risk: inconsistency, rework

**Option B: Add 3 critical specs (AUDIO-MAPPING, PHYSICS-SPEC, file naming)**
- Blocks ambiguity at most critical points
- Adds ~2-4 hours to planning
- Significantly reduces rework risk

**Option C: Full spec (all 10 gaps)**
- Maximum clarity
- Adds ~1 day to planning
- Developer can execute mechanically

---

## DR-X FILTER CHECK

**Does this planning set increase developer agency?**
- YES (clear boundaries, no hidden constraints)

**Does it reduce cognitive drag?**
- PARTIAL (vision clear, implementation details require guessing)

**Does it preserve ownership?**
- YES (local-first, no dependencies, reversible architecture)

**Does it keep exit paths?**
- YES (UIKit/AppKit chosen explicitly for reversibility)

---

## NEXT ACTION RECOMMENDATION

**If time allows:** Create AUDIO-MAPPING.md, PHYSICS-SPEC.md, and file naming spec (3 critical gaps).

**If handing off now:** Document known gaps in STATUS.md so developer knows where decisions are deferred.

---

**Status:** Ready for handoff with known gaps documented
