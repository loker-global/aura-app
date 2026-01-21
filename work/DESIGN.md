# AURA — Visual & Usability Constraints

⸻

## 0. DESIGN INTENT

AURA's design exists to get out of the way of presence.

The interface must never compete with the voice, the orb, or silence.
Design is not decoration — it is containment.

The UI holds space so the voice can exist.

⸻

## 1. PRIMARY DESIGN PRINCIPLE

**Calm > Expressive**

Every design decision must reduce stimulation, not increase it.
If something draws attention to itself, it is suspect.

The orb is the visual focus.
The UI is structural.

⸻

## 2. COLOR SYSTEM (STRICT)

### 2.1 Default Mode

Dark Mode is the default and preferred mode.
Light mode may exist later, but parity is not required.

Dark mode is not aesthetic — it is functional:
- reduces visual noise
- preserves contrast
- gives silence visual weight

⸻

### 2.2 Background Colors

Use near-black, not pure black.

**Recommended background range:**
- Primary: `#0E0F12`
- Secondary: `#12141A`
- Panels: `#181B22`

**Avoid:**
- pure black (`#000000`)
- high-contrast patterns
- gradients except where explicitly defined

Backgrounds should feel architectural, not cinematic.

⸻

### 2.3 Orb Colors

The orb must feel material, not digital.

**Approved palette** (linear space equivalents recommended):
- Bone / off-white
- Warm gray
- Soft neutral metallic

**Examples:**
- `#E6E7E9`
- `#D9DADC`
- `#CFCFD2`

**Forbidden:**
- neon
- pure green
- saturated brand colors
- rainbow effects

Color must communicate presence, not signal.

⸻

### 2.4 Accent Color (Minimal Use)

Accent color is used only for state:
- recording active
- clipping warning
- error

**Rules:**
- one accent color at a time
- low saturation
- brief appearance

**Red is reserved exclusively for:**
- clipping
- destructive actions

Never use accent colors for decoration.

⸻

## 3. TYPOGRAPHY

Typography is secondary to the orb.

**Font Characteristics**
- neutral
- highly legible
- low personality

System fonts are preferred.

**Rules:**
- No display fonts
- No condensed styles
- No dramatic weights

Text should feel structural, not expressive.

⸻

## 4. LAYOUT CONSTRAINTS

### 4.1 Hierarchy
1. Orb (primary)
2. Recording state
3. Controls
4. Metadata

The orb must always be visually dominant.

⸻

### 4.2 Spacing
- Generous negative space
- Few elements per screen
- No crowding

Empty space is intentional and required.

⸻

### 4.3 Panels & Controls
- Panels must feel docked, not floating
- No overlapping UI over the orb
- Controls should disappear when idle

UI should recede when not needed.

⸻

## 5. MOTION & INTERACTION

### 5.1 UI Motion Rules
- Motion must be slow and predictable
- No bounce
- No spring animations
- Linear or ease-in-out only

If motion feels playful, it is wrong.

⸻

### 5.2 Interaction Feedback
- Subtle opacity changes
- Gentle fades
- No flashing
- No vibration metaphors

Feedback should confirm action, not celebrate it.

⸻

## 6. USABILITY PRINCIPLES

### 6.1 Cognitive Load

AURA must be usable without thinking.

**Rules:**
- No mode confusion
- No hidden gestures
- No nested controls

If a tooltip is needed, the design failed.

⸻

### 6.2 Keyboard-First

Primary actions must be accessible via keyboard:
- Record / Stop
- Play / Pause
- Export

Mouse use is optional.

⸻

### 6.3 Error States

Errors must be:
- quiet
- clear
- non-alarming

No modal panic dialogs.

Errors should feel like:

**"Something didn't work. You're safe."**

⸻

## 7. ACCESSIBILITY (BASELINE)
- High contrast between orb and background
- Minimum text contrast (WCAG AA)
- No reliance on color alone for state

Accessibility is part of calm.

⸻

## 8. ICONOGRAPHY
- Minimal
- Line-based
- Neutral geometry

Icons should feel like tools, not brand marks.

**Avoid:**
- filled icons
- playful metaphors
- animated icons

⸻

## 9. WHAT IS EXPLICITLY FORBIDDEN
- Bright gradients
- Visual clutter
- Decorative UI chrome
- Gamified feedback
- Trend-driven design
- Anything that feels loud

If it feels impressive, remove it.

⸻

## 10. FINAL DESIGN TEST

Before shipping any visual change, ask:
1. Does this make silence feel heavier or lighter?
2. Does this help the orb feel more present?
3. Does this reduce or increase cognitive load?

If the answer is unclear, revert.

⸻

## 11. VIRTUAL CAMERA OUTPUT (MVP FEATURE)

### Design Constraints for Live Streaming

Virtual camera must maintain AURA's calm principles while being functional.

**Visual Indicators:**
- Subtle, non-alarming indicator when virtual camera is active
- Small icon in menu bar or status area — single-color, line-based
- Shows which app is using the camera (read from system)
- Clear "Enable/Disable" toggle in main UI

**Toggle Control:**
- Simple switch or checkbox
- Label: "Virtual Camera" or "Camera Output"
- Shows status: "Off" / "Active" / "In Use by [App Name]"
- No promotional copy, just functional description

**Permission Flow:**
- Standard macOS camera permission dialog (system-controlled)
- If permission denied: calm explanation with link to System Preferences
- No repeated nagging or dark patterns

**Active State:**
- Minimal indicator (small dot or icon)
- No pulsing, flashing, or animation
- No "LIVE" badges or red accents
- Presence remains unchanged

**Forbidden:**
- Red "LIVE" indicators
- Countdown timers
- Pulsing effects
- Attention-seeking notifications
- Recording dots (not recording, just streaming)
- Any design element that breaks calm

**Visual Consistency:**
- Virtual camera does NOT change orb appearance
- Same rendering, same motion, same colors
- No "streaming mode" visual state
- Orb behaves identically whether camera is on or off

The same design principles apply: calm > expressive, orb is primary, UI is structural.

⸻

**FINAL STATEMENT**

AURA's design is successful when:
- The orb feels like the only thing that matters
- The UI fades into infrastructure
- Silence feels intentional
- Users stop noticing the interface

Design does not speak.

Presence does.

**AURA supports both durable artifacts and live presence.**

⸻

**Status:** Design constraints locked (macOS-only focus)
