# DECISION — macOS-Only Focus & Virtual Camera as MVP Feature

**Date:** January 21, 2026
**Status:** APPROVED
**Impact:** High (platform scope + feature inclusion)

---

## CONTEXT

AURA was initially designed as a universal app (macOS + iOS). After initial documentation, virtual camera output needed repositioning as core MVP feature.

**Clarifications needed:**
1. Platform priorities for v1
2. Virtual camera output as MVP vs future feature
3. Integration of both artifact and live modes

---

## DECISION

### 1. Platform Focus
**macOS-only for v1, iOS deferred to Phase 2**

**Rationale:**
- Reduces complexity for initial implementation
- macOS allows full keyboard-first interaction model
- Simpler testing and validation surface
- Faster path to production-ready state
- iOS can be added later with proven architecture

### 2. Virtual Camera Output
**Core MVP feature, Phase 6 (after export pipeline)**

**Positioning:**
- Core feature for v1 (not optional or future)
- Integrated into implementation roadmap as Phase 6
- Uses CoreMediaIO APIs on macOS
- Same orb engine as MP4 exports (real-time version)

**Technical Implementation:**
- No driver or system extension installation required
- Appears as "AURA Orb" in system camera list
- 1080p/720p at 60fps (30fps fallback)
- Video only (no audio routing)
- Must not impact audio/recording performance

**Privacy & Trust:**
- Requires camera access permission (standard macOS security)
- Clear UI indicator when virtual camera is active
- User can toggle on/off at any time
- Shows which apps are using the camera

### 3. Usage Modes
**Both artifact and live modes supported:**
1. **Artifact mode:** Record → Replay → Export MP4 (durable)
2. **Live mode:** Microphone → Orb → Virtual Camera (real-time)

Both modes use identical orb engine.

---

## IMPLEMENTATION

### Documentation Updates
Added Virtual Camera sections to:
- ✓ AURA-MANIFEST.md (core feature, Phase 6)
- ✓ PRD.md (Section 14: Virtual Camera Output)
- ✓ GOAL.md (included in done state)
- ✓ ARCHITECTURE.md (Section 14: Module design)
- ✓ EXPORT-SPEC.md (Section 12: Live streaming specs)
- ✓ DESIGN.md (Section 11: UI constraints)
- ✓ HANDOFF-PACKAGE.md (Section 10: Implementation notes)
- ✓ STATUS.md (updated to reflect MVP status)

### Implementation Phases
Updated to 7 phases:
1. Audio + Physics (no rendering)
2. Metal + Integration
3. Platform Views (macOS)
4. Coordination + State
5. Export Pipeline
6. **Virtual Camera Output** ← NEW
7. Polish + Error States

### Key Technical Details
- Module: `VirtualCameraOutput` (Layer 2: Rendering Core)
- APIs: CoreMediaIO Extension (macOS 12.3+)
- Integration: Reuses OrbRenderer output
- Performance: Must maintain 60fps or degrade gracefully
- State: Can be active during idle or recording modes

---

## CONSTRAINTS PRESERVED

### Non-Negotiables
- ✓ Audio > Rendering > UI priority maintained
- ✓ No driver or system extension required
- ✓ Trust, privacy, and calm remain top priorities
- ✓ Local-first architecture unchanged
- ✓ Same orb engine for both export and live modes

### Design Principles
- ✓ Calm indicator when active (no "LIVE" badges)
- ✓ Simple toggle control
- ✓ No visual changes to orb (same rendering)
- ✓ Orb remains primary, UI structural

---

## OUTCOMES

### What Changed
1. Platform scope narrowed to macOS-only for v1
2. Virtual camera elevated to core MVP feature (Phase 6)
3. Implementation roadmap expanded from 6 to 7 phases
4. Documentation now describes both artifact and live modes
5. All docs now end with: "AURA supports both durable artifacts and live presence."

### What Did NOT Change
- Core architecture (5 layers, thread model, state machine)
- Audio pipeline specifications
- Physics constants and motion contract
- Export settings (H.264, 1080p60, MP4)
- Privacy principles (local-first, no cloud, no accounts)
- Design philosophy (calm > expressive, tools over hype)

### Developer Impact
- **Reduced scope** for initial implementation (macOS-only)
- **Added feature** in Phase 6 (after export is working)
- **Clear specifications** for CoreMediaIO integration
- **Same orb engine** reused for virtual camera

---

## SUCCESS CRITERIA

Update succeeds if:
- ✓ No confusion about platform priorities (macOS v1)
- ✓ Clear understanding that virtual camera is MVP feature
- ✓ Technical specifications complete for implementation
- ✓ Both artifact and live modes well-defined
- ✓ Philosophy remains intact (tools over hype, precision, voice as memory)

---

## RISKS ADDRESSED

1. **Feature clarity** — Virtual camera now clearly defined as Phase 6
2. **Platform complexity** — iOS deferred reduces initial burden
3. **Implementation order** — Virtual camera comes after export (can reuse code)
4. **Performance** — Must maintain audio priority, cannot block recording
5. **Privacy** — Standard macOS permissions, clear UI indicators

---

## NEXT STEPS

1. Developer proceeds with Phases 1-5 as specified
2. Phase 6: Implement VirtualCameraOutput module
   - Integrate CoreMediaIO APIs
   - Reuse OrbRenderer frame output
   - Add toggle UI and status indicators
   - Test with Zoom, FaceTime, OBS
3. Phase 7: Polish and error states

---

## APPROVAL

**Approved by:** Dr. X
**Date:** January 21, 2026
**Method:** DECISION.md protocol

---

**FINAL STATEMENT**

AURA is macOS-first with dual modes:
- Artifact mode: Record → Replay → Export (durable)
- Live mode: Microphone → Orb → Virtual Camera (real-time)

Virtual camera is a core MVP feature, not optional or future.

**AURA supports both durable artifacts and live presence.**
