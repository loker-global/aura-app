# DECISION — UI Framework for AURA

A one-shot decision protocol.
Use when stakes are non-trivial or ambiguity is blocking progress.

---

## 0) NAME THE DECISION

**Decision:**
- SwiftUI vs UIKit for AURA (universal macOS + iOS app with Metal rendering and precise audio control)

---

## 1) DEFINE THE OPERATOR

**Who is deciding?**
- Project operator (lxps)

**Who is affected?**
- End users (experience quality, platform compatibility)
- Future maintainers (code clarity, debugging surface)
- Project timeline (velocity, risk of rewrites)

---

## 2) DEFINE THE OPTIONS (MAX 3)

**Option A: SwiftUI**
- Use SwiftUI for all UI
- Wrap Metal renderer in UIViewRepresentable/NSViewRepresentable
- Use SwiftUI state management
- Target iOS 17+ / macOS 14+

**Option B: UIKit/AppKit**
- Use UIKit (iOS) + AppKit (macOS) with shared controllers
- Direct Metal integration via MTKView
- Manual state management
- Target iOS 15+ / macOS 12+

**Option C: Hybrid (SwiftUI shell + UIKit/AppKit core)**
- SwiftUI for lightweight controls and layout
- UIKit/AppKit for Metal view and audio management
- Bridge via representables
- Target iOS 16+ / macOS 13+

---

## 3) DEFINE THE SUCCESS CRITERIA (MAX 5)

1. **Audio must never be compromised** — no dropped buffers, no UI blocking audio thread
2. **Metal rendering must be precise** — 60fps minimum, orb physics never stutters
3. **Universal target works** — single codebase for macOS + iOS with minimal conditionals
4. **Keyboard-first on macOS** — keyboard shortcuts work reliably, no SwiftUI focus bugs
5. **Code must be debuggable** — when audio or rendering fails, root cause is traceable

---

## 4) DEFINE CONSTRAINTS (NON-NEGOTIABLES)

**Technical:**
- Metal rendering required (real-time orb + offline export)
- CoreAudio/AVAudioEngine required (precise audio capture)
- WAV recording must survive UI crashes

**Design:**
- Dark mode default
- Minimal UI (few controls, generous spacing)
- No complex animations (slow, predictable motion only)

**Platform:**
- Universal binary (macOS + iOS)
- Local-first (no network, no accounts)

**Time:**
- Minimize risk of mid-project rewrites
- Ship calm, not rushed

**Reversibility:**
- Must be able to refactor UI layer without touching audio/Metal core

---

## 5) RISK / REVERSIBILITY CHECK

### Option A: SwiftUI

**Worst-case outcome:**
- Keyboard shortcuts unreliable on macOS (known SwiftUI issue)
- State updates cause unnecessary Metal re-renders
- Debugging Metal wrapper is opaque
- Universal target hits SwiftUI platform parity bugs

**Is it reversible?** Partially
**Cost to reverse:** High (complete UI rewrite)
**Time to detect failure:** 2-4 weeks (during keyboard + Metal integration)

---

### Option B: UIKit/AppKit

**Worst-case outcome:**
- Code duplication between iOS and macOS
- Manual state management introduces bugs
- Verbose boilerplate slows iteration

**Is it reversible?** Yes
**Cost to reverse:** Medium (wrap in SwiftUI later)
**Time to detect failure:** 1-2 weeks (during dual-platform setup)

---

### Option C: Hybrid

**Worst-case outcome:**
- Bridge complexity introduces state sync bugs
- Performance overhead from representable wrapping
- Debugging crosses SwiftUI/UIKit boundary (harder to trace)

**Is it reversible?** Yes
**Cost to reverse:** Low-Medium (collapse to either A or B)
**Time to detect failure:** 2-3 weeks (during integration testing)

---

## 6) THE DR-X FILTER

### Option A: SwiftUI
- Does it increase human agency? **Partial** (keyboard issues reduce control)
- Does it reduce cognitive drag? **Yes** (less boilerplate)
- Does it preserve ownership? **Yes** (local, debuggable)
- Does it keep exit paths? **No** (high rewrite cost)

**Status:** Risk due to keyboard reliability and reversibility cost.

---

### Option B: UIKit/AppKit
- Does it increase human agency? **Yes** (full keyboard control, predictable behavior)
- Does it reduce cognitive drag? **Partial** (more boilerplate, but explicit)
- Does it preserve ownership? **Yes** (full control, debuggable)
- Does it keep exit paths? **Yes** (can wrap in SwiftUI later)

**Status:** Safe, verbose, explicit control.

---

### Option C: Hybrid
- Does it increase human agency? **Yes** (combines benefits)
- Does it reduce cognitive drag? **Partial** (bridge adds cognitive load)
- Does it preserve ownership? **Yes** (control where it matters)
- Does it keep exit paths? **Yes** (collapsible to A or B)

**Status:** Pragmatic compromise, but complexity risk.

---

## 7) DECIDE (AND WRITE IT DOWN)

**Chosen option:**
- **Option B: UIKit/AppKit with shared Metal + Audio core**

**Reason:**
- Audio and Metal precision are non-negotiable; UIKit/AppKit give direct control with zero abstraction risk
- Keyboard-first requirement cannot tolerate SwiftUI focus management bugs on macOS
- Reversibility preserved: can add SwiftUI shell later if justified, but cannot easily escape SwiftUI constraints once committed
- AURA's UI is minimal (few controls, simple layout) — SwiftUI's declarative benefits are less valuable here
- Explicit state management aligns with "tools over hype, precision" philosophy

---

## 8) COMMITMENT CONTRACT

**What happens next?**

**Next Action:**
- Create technical architecture document defining:
  - Shared Metal renderer (iOS + macOS)
  - Shared audio engine (AVAudioEngine wrapper)
  - Shared state model (recording/playback/export states)
  - Platform-specific view controllers (UIViewController + NSViewController)
  - File: `./work/ARCHITECTURE.md`

**Owner:**
- Dr. X (operator: lxps)

**Deadline:**
- Next session (no rush)

**Rollback Trigger:**
- If Metal integration proves trivial and keyboard issues disappear in future SwiftUI versions (iOS 18+/macOS 15+), revisit hybrid approach
- If code duplication exceeds 30% between platforms, introduce shared abstractions (not full SwiftUI rewrite)

---

→ NEXT ACTION: Create `./work/ARCHITECTURE.md` defining shared core + platform-specific view layer structure
