# Starfall

A matchmaking app for souls, not profiles. It starts on iPhone, and the goal is a phone-free, screen-free device that hums when someone kindred drifts close.

## The idea

Everyone is a circle of light drifting through the same sky. Your light is made of what you **do** (interests), how you **are** (traits) and what you **hold** (values). When two lights touch, they either **mend**, **spark** or **clash**, and you *feel* it as a vibration pattern before you read anything.

### The bank of light
- Every soul has the same **100 units of light**. Loving one thing costs loving another.
- **Interests** max out at 20. Push one all the way past its ceiling into its slot and it **ascends**: it stops being a hobby and becomes part of its root value (Hiking → Presence, Music → Beauty, Hardware → Craft…).
- Interests you haven't ascended still feed **25%** of their light into their root value as an *undercurrent*. Your values are partly made of the things you do.
- **Traits** are polarities, not quantities (Stillness ↔ Motion, Solitude ↔ Communion, Heart ↔ Mind…). Some axes mend when two people sit close on them; others mend through a little difference.

### Resonance
`score = 0.5·values (cosine) + 0.3·shared interests + 0.2·trait harmony`
- **Mend** ≥ 0.45 · **Spark** 0.27–0.45 (or strong shared values with different traits) · **Clash** below that.

### Five energies
Ember (fire) · Tide (water, Starfall Blue) · Grove (earth) · Sol (light) · Aether (spirit). Each has a colour and a Bauhaus glyph (triangle, circle, square, half-circle, ring). A soul's aura is the weighted blend.

## Screens
- **Attune**: name → gather interests → weigh (bank + ascension slots) → traits → values → reveal. You move forward by sliding a circle into its slot.
- **Drift**: the sky of souls. Drag your light around. Kindred souls drift toward you and discordant ones drift away. As someone nears, you feel a heartbeat that speeds up. When you touch: collision.
- **Encounter**: mend/spark/clash haptics and animation, the resonance breakdown, and where you meet. Slide left to **drift on** or right to **bond**.
- **Constellation**: your bonds as stars.
- **Essence**: your aura, the light ring, every realm editable, and a resonator panel for feeling each meeting pattern.

## Hardware path
All haptics are written as a platform-neutral `VibrationScore` (`Starfall/Hardware/Resonator.swift`). The iPhone plays them through Core Haptics. A future Starfall pebble receives the same score as bytes over BLE. See [docs/HARDWARE.md](docs/HARDWARE.md).

## Build
```sh
brew install xcodegen
xcodegen generate
open Starfall.xcodeproj
```
iOS 17+, SwiftUI, no dependencies.

- `scripts/device.sh`: build, install and launch on the USB-connected iPhone.
- `scripts/testflight.sh`: archive and upload to TestFlight (needs a paid Apple Developer team + App Store Connect API key).
- `.github/workflows/testflight.yml`: every push to `main` ships to TestFlight once the `ASC_*` / `TEAM_ID` repo secrets exist.
