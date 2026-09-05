---
name: "Audio Promt — Native macOS"
version: "1.0"
tags:
  - macos
  - swiftui
  - native
  - menu-bar-app
author: "Fatih"
source_url: ""
created: "2026-09-05"

style_prompt_short: >
  A menu-bar utility that looks like it shipped with macOS itself —
  no brand color, no custom font, no decoration. It borrows the
  system's own accent color and system font and gets out of the way.

style_prompt_full: >
  Design this exactly like a first-party macOS System Settings pane or
  a well-behaved menu-bar utility (think: Notes, Reminders, the actual
  System Settings app). Do NOT introduce a fixed brand color — every
  accent, checkbox tint, slider fill, and highlighted control must use
  the system accent color (SwiftUI `Color.accentColor` /
  `NSColor.controlAccentColor`), which follows whatever the user has
  chosen in System Settings → General → Accent Color. Do NOT hardcode
  hex values for interactive elements. Typography is exclusively SF Pro
  (the system font — in SwiftUI, plain `.font(.body)`, `.font(.title2)`
  etc. with no custom family), except numeric/time values (HUD duration
  counter) which use the system monospaced-digit variant
  (`.monospacedDigit()` or `.system(.body, design: .monospaced)`) so
  digits don't jitter in width as they change. The Settings window is a
  standard SwiftUI `Settings` scene with `TabView`, fixed 520×420pt,
  non-resizable — visually indistinguishable from a native macOS
  preferences pane, using only standard controls (Toggle, Slider,
  Picker, TextField, TextEditor, Stepper, Table) with system-default
  styling — no custom control chrome. The HUD panel is the one place
  with a little material: `.ultraThinMaterial` background (translucent,
  blurred, adapts automatically to Dark/Light mode and desktop wallpaper
  behind it — this is what gives it a "floating glass" feel without any
  custom color), 16pt corner radius, a thin 0.5pt `.separatorColor`
  border, and a soft ambient shadow (20pt radius, 15% opacity black) —
  never a colored glow. Every color reference in code must resolve
  through a semantic system token (`.accentColor`, `.secondaryLabelColor`,
  `.separatorColor`, `.quaternaryLabelColor`, `.systemRed`,
  `.systemOrange`) so the whole app repaints correctly for Dark Mode,
  Light Mode, and any accent color choice with zero custom palette code.

colors:
  primary:
    - name: "System Background"
      hex: "#FFFFFF"
      role: "Light-mode window background (system-resolved; #1E1E1E equivalent in Dark Mode) — never set explicitly, inherited from NSWindow/Settings scene"
    - name: "Label / Secondary Label"
      hex: "#1D1D1F"
      role: "Primary text (labelColor) and dimmed text (secondaryLabelColor, ~#8E8E93) — both system-resolved, never fixed"
  accent:
    - name: "System Accent (dynamic)"
      hex: "#007AFF"
      role: "Toggle fills, active Picker highlight, waveform bars, progress indicators, checked menu items — hex shown is macOS's own default blue, but this MUST resolve to Color.accentColor at runtime so it follows the user's actual System Settings choice (graphite, red, orange, yellow, green, blue, purple, pink, multicolor)"
  neutral:
    - name: "Separator"
      hex: "#3C3C4340"
      role: "0.5pt hairline borders — HUD panel edge, table row dividers (separatorColor, ~25% opacity)"
    - name: "Quaternary Label"
      hex: "#3C3C432E"
      role: "Subtle fill for the ⌘V badge pill in the HUD result state (quaternaryLabelColor)"
    - name: "System Red / Orange"
      hex: "#FF3B30 / #FF9500"
      role: "Recording indicator dot + mic.fill icon (red), error states — icon + HUD warning triangle (orange). These two are the only non-accent, non-neutral colors in the whole app, and both are semantic system colors (systemRed/systemOrange), not custom hex"

typography:
  display:
    family: "SF Pro (system default — .largeTitle/.title2, no custom font)"
    weight: "semibold"
    style: "Used sparingly — only the onboarding welcome line, if built"
  body:
    family: "SF Pro (system default — .body)"
    weight: "regular"
    style: "All Settings labels, Toggle/Picker text, menu items, HUD transcribed-text preview"
  caption:
    family: "SF Mono (system monospaced-digit variant of SF Pro, via .monospacedDigit())"
    weight: "regular"
    style: "HUD duration counter (0:07), any numeric stepper value — fixed-width digits so layout never shifts mid-count"
  rules:
    - "Never import or specify a custom font family anywhere in the app"
    - "Only numeric/time displays get the monospaced variant — everything else is proportional SF Pro"
    - "Font sizes come from SwiftUI semantic styles (.body, .caption, .footnote) not fixed point sizes, so Dynamic Type / accessibility text sizing keeps working"

layout:
  grid: "8pt base spacing unit throughout (matches PLAN.md HUD spec: 8pt padding, 8pt gaps)"
  alignment: "Settings window: leading-aligned form labels per tab, standard macOS Settings pane grouping. HUD: horizontally centered content in a fixed 300×72pt pill, bottom-center of the active screen."
  aspect_ratio: "Settings window fixed 520×420pt, non-resizable. HUD panel fixed 300×72pt, 16pt corner radius."
  notes:
    - "Settings window must feel identical to flipping through real macOS System Settings panes — same tab bar behavior, same control sizing"
    - "HUD never exceeds 300×72pt regardless of content — long transcripts truncate with an ellipsis at 40 characters, never wrap or grow the panel"

motion:
  transitions:
    - "HUD enter/exit: 180ms, opacity 0→1 + 8pt upward slide, spring(response: 0.3, dampingFraction: 0.8)"
    - "Recording dot: 1.2s pulse cycle, opacity 1.0 ↔ 0.5, easeInOut, repeats while recording"
    - "Menu bar icon: same 1.2s pulse while recording; instant (no animation) switch between idle/transcribing/error icons"
  animation_style: >
    Motion exists only to communicate state, never for decoration. Every
    animation in the app maps to a real status change (recording started,
    transcription running, result ready, error occurred) — nothing
    animates just to look lively. Springs are soft and quick (under
    300ms settle time), never bouncy or playful.
  pacing: "Fast and quiet — the HUD should feel like it was always there, not like it 'arrived'"
  audio_cues:
    - "Ping (soft, ~40% volume) on recording start"
    - "Pop (soft, ~40% volume) on recording stop"
    - "No sound on transcription complete or error — visual only, to avoid audio spam on frequent use"

mood:
  keywords:
    - "invisible"
    - "native"
    - "unbranded"
    - "quiet"
    - "trustworthy"
  era: "contemporary macOS (Sonoma/Sequoia-era System Settings design language)"
  cultural_reference: "Apple's own System Settings app, Ice/Bartender-style menu-bar utilities, Raycast's native-feeling (not web-feeling) macOS presence"
  avoid:
    - "any fixed brand hex color used for an interactive element"
    - "a custom/downloaded font anywhere"
    - "gradients, drop shadows with color, neumorphism, glassmorphism beyond the one sanctioned .ultraThinMaterial HUD background"
    - "decorative animation with no status meaning"
    - "a Settings window that looks like a web app or Electron app ported to Mac"

assets:
  reference_images: []
  gsep_elements: []
  html_snippets: []
  color_palette_image:
    url: ""

x_swiftui:
  settings_scene: true
  tab_view_style: "native"
  fixed_size: "520x420"
---

## Design Principles

This app has no brand identity of its own — that is the identity. It
runs constantly in the menu bar, so the moment it looks like a
third-party app fighting for attention, it becomes annoying. Every
visual decision defers to the system: the user's own accent color
choice, the user's own Light/Dark Mode, the user's own font size
settings. The only place the app allows itself a signature look is the
HUD's frosted-glass material, because that's a real native
material (`.ultraThinMaterial`), not an invented one.

Trade-off accepted deliberately: this means the app cannot have a
"wow" moment of unique visual branding. That's fine — the product's
value is in disappearing into the OS, not standing out from it.

## Connectors

No web/video/design-tool connector applies — this style is consumed
directly as SwiftUI code, not through one of this skill's standard
connectors (HeyGen/HTML/paper.design/Figma). Implementation lives in:
- `Sources/AudioPromt/UI/HUDContentView.swift` (motion + material rules)
- `Sources/AudioPromt/UI/SettingsView.swift` (5-tab window, once built)
- `Sources/AudioPromt/UI/MenuBarIconController.swift` (icon color states)

## Extraction Notes

Not extracted from an external source — defined interactively with
Fatih on 2026-09-05: accent = system accent color, font = system font
(SF Pro + monospaced digits for numbers), window style = fully native
macOS Settings-pane look. See PLAN.md bölüm 6 for the full interaction
spec this style is dressing.
