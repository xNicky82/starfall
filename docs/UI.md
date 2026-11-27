# Starfall UI: Orbit

After Attune, Starfall is one persistent field of orbs with four tabs that only rearrange it. Nothing navigates: your orb never leaves the screen, other orbs glide to new positions and a thin layer of UI fades in over them.

## The field

- Every soul is a black orb on a grey micro-dot ground. Orbs are metaballs, so they only goo together right at contact, and they keep a personal space of 80% of the two radii so nobody gets squished.
- Physics is molasses: heavy drag, viscosity between touching orbs, slow wander. Pairs rest closer the higher their resonance, and low-resonance pairs barely pull at all.
- Each orb carries a hidden stacked copy of itself per energy. A band slides out from behind the body when the orb moves fast (it trails the motion), or when a neighbour that shares that energy comes close (it reaches toward them). Band width is that energy's share of the soul. Same-colour bands on two orbs are one metaball field, so they melt into a bridge.
- Where two similar rims cross, a diamond-ring bead appears with a short streak and magenta flecks.
- When your orb first truly touches another, the phone plays that pair's meeting score (mend, spark or clash).

Resonance comes straight from `Resonance.between`. The physics uses `sim = clamp((score - 0.2) / 0.45)`.

## Tabs

| Tab | What the field does |
|---|---|
| Friends | Camera zooms out to about 0.5 and every friend gathers around you. Friends who have never met still overlap if they resonate. **Read** ranks the best never-met pairs, the bridge and anyone drifting. |
| Home | You sit in the middle. People nearby wait in the four corners as soft glows in their dominant energy. Tap one and they drift in from that corner. **Say hi** bonds and opens a thread; **Pass** releases them. |
| Inbox | Orbs line up on the left as avatars. A one-to-one chat is one orb, a group is an overlapping cluster. Open a row and its cluster slides into the thread header. Your orb tucks into the top right. |
| Profile | Tapping your orb from anywhere comes here. Your orb grows (with your photo inside it), other orbs leave, and every energy band fans out upward as a solid stack. Below it everything is editable in place: your nature spectrums, colour breakdown, interests with specifics and watch/play, values. **Details** holds name, photo (crop and edit), age, sex, location, education. |

The tab bar is a floating Liquid Glass capsule (real `glassEffect` on iOS 26, a material fallback before that). Inside it lives one orb: it slides to the chosen tab with your energy colours smeared behind it, stretches a little with speed, then settles into that tab's icon shape.

## Nature, colour and interests

- **Nature** is eleven spectrums: Introvert ↔ Extrovert, Haste ↔ Concentration, Progress ↔ Tradition, Quiet ↔ Loud, Discipline ↔ Freedom, Mathematical ↔ Artistic, Mind ↔ Body, Observe ↔ Partake, Comfort ↔ Adventure, Depth ↔ Breadth, Gentle ↔ Competitive. Each pole belongs to an energy (Introvert, Quiet, Observe and Gentle are Tide blue, for example), so where you sit decides which colours you are made of (`Soul.nature`).
- **Interests** decide how strongly each colour takes hold. An energy your interests and values feed shows at full strength; one they ignore shows at 30% of its nature share (`Soul.elements`). Total interest light sets how far your bands can reach (`Soul.hold`).
- **Specifics** sit one level down (Sport → Hockey). Two people who both picked Hockey resonate a little more than two who only share Sport.
- **Watch or play** is assumed from Observe ↔ Partake until you say otherwise: a full observer who adds Sport → Hockey is assumed to watch it. Person cards say it plainly: "Hockey · you watch, Theo plays".

## Code

| File | What it holds |
|---|---|
| `Starfall/Orbit/OrbEngine.swift` | Pure-Swift physics: orbs, pairs, bands, shimmer beads. No UI. |
| `Starfall/Orbit/Orbit.swift` | The observable app model: tabs, scenes per tab, inbox, camera, display link, shader packing. |
| `Starfall/Orbit/Orbit.metal` | `orbField` (the whole field in one pass) and `tabOrb` (the morphing bar orb). |
| `Starfall/Orbit/OrbitRoot.swift` | Stage, field view, gestures, name pills, header, glass helper. |
| `Starfall/Orbit/OrbitTabBar.swift` | The tab bar. |
| `Starfall/Orbit/OrbitLayers.swift` | Home glows, Friends header, Inbox rows and thread, Profile panel. |
| `Starfall/Orbit/OrbitCard.swift` | Person card, circle read, chips, energy bar, flow layout. |
| `Starfall/Orbit/ProfileView.swift` | Profile: nature sliders, colours, interest cards, values, add-interest sheet, your photo in the orb. |
| `Starfall/Orbit/DetailsSheet.swift` | Details form, photo crop (pinch and drag in a circle) and photo edit (looks and adjustments). |
| `Starfall/Model/Photo.swift` | Crop rendering and Core Image edits. |

The field supports up to 16 orbs per frame. Friends and nearby people come from the demo `SoulFactory` field until real people exist; bonded souls always come first.

New files need the project regenerated: run `xcodegen generate` (the device and TestFlight scripts already do).

## Still true from before

- Attune stays the onboarding: slide-to-slot, the bank of light, ascension. Essence stays the editor, opened from Profile.
- Haptics are `VibrationScore`s played through `Resonator`, so the pebble can receive the same scores later (see [HARDWARE.md](HARDWARE.md)).
- Type is SF Pro (the system font) in Orbit; Attune and Essence keep their monospaced captions for now.
