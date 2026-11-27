# Starfall UI instructions

Source: [Nordexa / starfall board](https://ca.pinterest.com/NordexaInc/starfall/) (poster design, generative art, motion graphics, logo). Principles only — do not clone pins.

The phone is a stand-in. The real UI is a pebble that hums when someone kindred drifts close. Every screen below must survive being reduced to **light + vibration + one slide**.

**Primary surface: Operate.** Two bodies, one shared field, a log of what actually crossed. Drift is Explore only as a way to reach Operate. Never a dating-app hero, never a profile card grid.

---

## What the board is saying

The board is not “space wallpaper.” It is a grammar for **people as systems**:

| Pin language | Product meaning |
|---|---|
| Human figures made of dots | A soul is a composition of interests, not a photo |
| Metaballs / two cells fusing | Bond = two closed forms opening into one |
| Overlapping hatched discs with role labels | Shared interests as a Venn, not a list |
| One object on a black field | One meeting, one decision, no chrome |
| Stippled ring / occluded planet | Aura. The pebble. Essence. |
| Voronoi sphere, “I am a part of all that I have met” | Constellation: you are the joints, not a follower count |
| Lissajous / two foci | Two souls in one figure; resonance is the interference |
| Split planet: photographic half / dotted half | Hardware body vs. light bank. Never show a selfie as the self |
| Pixelated bodies in motion | Interests are verbs. Weight them as motion, not tags |
| Density field (hatch packing, dash vortex) | Proximity. Approach is a field, not a notification |
| Heat-signature HUD, tiny caps | Labels are instruments. Sparse, tracked, uppercase |
| Four-point star with chromatic fringe | Aura mix on a single point of light |
| Soft blue halo around a dark disc | `Celestial.planet` is already the right object — keep it |

---

## System

Keep what the app already has: void black, Futura Medium, uppercase tracked captions, stipple shader, slide-not-tap, five energies.

### Color

Use the five energies as the only chromatic voices. Paper and mist for type. Nothing else.

| Token | Value | Use |
|---|---|---|
| Void | `#000000` | Every canvas |
| Paper | `#E9E9E9` | Name, primary caption |
| Mist | paper @ 42% | Secondary caption |
| Faint | paper @ 12% | Inactive ticks, unused stars |
| Ember | `#FF8054` | Fire · will · motion |
| Tide | `#3C87ED` | Water · feeling · care (Starfall Blue) |
| Grove | `#3EC498` | Earth · ground · growth |
| Sol | `#F7C258` | Light · joy · making |
| Aether | `#9674FF` | Spirit · mind · mystery |

Rules:

- One meeting = one mixed aura, not a rainbow. Blend at most three energies, weighted by the soul’s light bank.
- Mend / spark / clash are **haptic names**, not color-coded badges. If you must tint: mend = tide, spark = sol, clash = ember — 1px, never a banner.
- No gradients as decoration. Gradients only as light falloff on a body (`Celestial.planet`, comet trail).
- No glass, no cards, no drop shadows.

### Type

One face: **Futura Medium**. One voice: small, uppercase, wide.

| Role | Size | Tracking | Color |
|---|---|---|---|
| Name | 15 | 0.3 × size | Paper |
| Instrument | 10 | 0.3 × size | Mist |
| Facet | 8–8.5 | 0.3 × size | Paper if on, mist if off |
| HUD crumb | 8 | 0.35 × size | Mist @ 70% |

No body copy on Drift, Encounter, or Constellation. If a sentence is needed (Attune prompts, Essence dissolve), one line, never a paragraph. No emoji. No icons except Bauhaus glyphs (triangle, circle, square, half-circle, ring) for the five energies.

### Texture

- Sky = black + stipple (`specks ≈ 0.0035`). Grain is the night, not a filter on top of UI.
- Rings and auras may be **stippled discs** (board: orange spray ring, grainy sun). Hard vector rings only for the dissolve/confirm gesture.
- Density encodes state: sparse dashes = far, packed hatch = near, fused outline = meeting.

### Geometry

Everything is a **circle of light** or a **falling star**.

- Soul = occluded planet (dark body, lit horizon).
- Interest idle = 4-point star, white, dim. Selected = planet in that facet’s energy.
- Bond = two planets whose halos merge (metaball). Do not draw a heart, a check, or a chat bubble.
- Constellation = you at center, bonds as planets, 1px paper@16% rays, paper@7% hull. Voronoi optional as a quiet under-drawing of *shared* facets, not a decoration.
- Never a rectangle that is a “card.” Hit targets may be invisible squares ≥ 44pt around a round body.

### Motion

Motion is physics, not theater.

| Event | Motion | Haptic |
|---|---|---|
| Idle sky | Slow drift, 10–32 pt/s cap | none |
| Kindred near | Pull toward you; dashed 1.4pt tether | `pulse` faster as edge shrinks |
| Discordant | Drift away | none |
| Collision | Pause field, ripple 10→90pt, 1.6s | `meeting` (mend/spark/clash) |
| Bond | Two foci collapse into one lissajous, then snap to constellation | `snap` then `mend` |
| Drift on | Your star thrown up, field resumes | `tick` |
| Attune step | 0.7s ease-in-out opacity. Circle slides into slot | `snap` |
| Weigh | Comet falls toward its root world | ticks while dragging |
| Ascend | Interest planet sinks into value planet | `snap` |
| Pebble approach | — | `pulse` only. Light ring breathes at pulse rate |

`prefers-reduced-motion`: freeze Canvas clocks; keep haptics.

---

## Hardware UI (the real product)

The pebble has **no screen**. Map every phone screen to three channels:

1. **RGB ring** — aura colors, max 3 LEDs worth. Idle = dim breath at 0.2 Hz. Approach = breath rate = pulse rate. Meeting = ring fills, then holds the meeting color for 2s. Bonded = both pebbles lock the same mixed color. Clash = hard flash then dark.
2. **LRA** — the `VibrationScore` already defined. Never invent a second vocabulary.
3. **Slide** — one axis. Toward them = bond. Away = drift on. Same as Encounter’s vertical drag. No tap to confirm.

Phone-less matching: RSSI drives `pulse`. Score plays on **both** pebbles at once. If only one consented, neither plays a meeting — silent path must be real.

Do not put a status LED language that the phone UI then has to explain. The ring *is* the aura. If you cannot feel/see it on the pebble, it does not belong on the phone.

---

## Screens

### 1. Attune — Configure

Arrival → gather → weigh → traits → values → reveal. Six 4pt ticks, paper for current, faint otherwise.

- **Arrival:** void, one name field in Futura 17 tracked 5, paper. Prompt “name” at 20% paper. DescentGate already correct: a world below, a star that only falls when named. Keep.
- **Gather:** interests as a field of idle stars, not a checklist. 4 columns is fine. Touch lights a world. People-as-dots from the board: if you ever show “you,” it is a dotted figure whose dots *are* the selected interests — never an avatar photo.
- **Weigh:** light is finite (100). A comet per interest falling into its root. Bank remaining = LightGauge, always visible. Ascension = the hobby becomes the value; show `Hiking → Presence`, not a badge.
- **Traits:** a polarity is a single axis with two named poles. You sit as a planet on the line. Harmonic axes: closeness mends. Difference axes: a little offset mends, extremes clash. Do not use sliders with tracks and thumbs that look like iOS Settings.
- **Values:** same weigher language as interests. Undercurrent (25%) is felt as a faint fill already in the value planet, not a footnote.
- **Reveal:** DescentGate in their aura. Name only. Sliding the star in writes `store.me`.

No “Next.” Forward = slide the circle home.

### 2. Drift — Explore, in service of Operate

The sky of souls. You are the larger planet at rest. Others are 13–19pt planets.

- Kindred (score > 0.30) pull in; others wash out. Met souls dim to intensity 0.2 and are not collidable.
- As edge < 150pt: dashed tether in *their* lead color, dash phase scrolling; pulse haptic.
- Collision pauses the sim and opens Encounter. Do not overlay a sheet.
- Chrome: none. No search, no filters, no “people nearby” list. The physics *is* the filter.
- Optional board move: idle souls as sparse dash-fields that **pack** as they near you (density = proximity). Keep planets as the readable object; density is the weather.

### 3. Encounter — Operate (two-sided)

Their world rises; your star hangs above it. This is the handshake.

- Copy on screen, max three lines, all captions:
  1. their name
  2. meeting word: `mend` / `spark` / `clash`
  3. up to three shared values, ` · ` separated
- No photos. No bio. No chat. No “message.”
- Gesture: drag your star **down** into their horizon to bond (`> 0.82`), **up** to drift on (`< -0.6`). Release otherwise springs back. Ticks while dragging.
- Visual of shared interest: overlapping hatched discs (board: researcher/designer/…) using energy colors, **or** two foci of a lissajous. Pick one. Do not also show a percentage.
- After bond: metaball merge, then cut to Constellation. After release: field resumes, that mote marked met.

Primary action sits under the meeting word, above any breakdown. A short viewport must still show the slide path.

### 4. Constellation — Inspect

Bonds as a star figure around you.

- You: 15pt, intensity 1.15, spread 1.4.
- Each bond: 7pt, distance `70 + (1 - score) * 170` (closer = stronger).
- Names as 8pt captions 30pt below each planet.
- Empty: one line, paper@ mist, Tennyson is fair game because it is the board’s caption and public domain: `I AM A PART OF ALL THAT I HAVE MET`. Centered under your planet. No illustration of loneliness.
- Optional: voronoi cells whose edges are shared facets. Cells are structure, not ornament — hide if count < 2.

### 5. Essence — Configure + instrument

Portrait is the occluded planet you already draw (horizon at 0.6, R = 0.56w). Name on the body. LightGauge top-right.

- Realm toggle: interests / traits / values. Same editors as Attune.
- **Feel:** three small planets, mend / spark / clash. Tap plays the score. This is the lab for the pebble. Keep it.
- **Dissolve:** 26pt ring, 1.5pt ember stroke, long-press 1.4s to erase the soul. The stippled orange ring on the board is this control at rest.

Do not add settings, account, or a feed.

---

## Shared-interest display (the connectivity idea)

Interests are how people find each other. Show overlap as **geometry**, never as chips.

1. Each soul is a disc whose fill pattern is its energy mix (hatch angle or dot grid per energy).
2. Where two discs overlap, the hatch **interlaces**. That intersection is the reason they met.
3. Label the intersection with at most three facet names, instrument type, inside or just under the overlap.
4. Strength of overlap = `0.5·values + 0.3·shared interests + 0.2·trait harmony`. Do not print the number. Print the meeting word. Let the size of the overlap be the number.

On the pebble, the same overlap is the mixed ring color. If the overlap is empty, the ring does not light and the score does not play.

---

## Do / Don’t

**Do**

- One object, lots of black.
- Grain, stipple, 1px lines.
- Slide, drag, long-press. Never a primary tap-button.
- People as dots, planets, comets.
- Haptics as the copy.
- Two foci becoming one.

**Don’t**

- Profile photos, age, distance in km, swipe-right.
- Card stacks, tab bars with icons, floating action buttons.
- Chat as the destination of a meeting.
- Rainbow palettes, glassmorphism, glow-everything.
- Fake metrics (“12 souls nearby”).
- Onboarding carousels. Attune *is* onboarding.
- Clone a pin. The board is a grammar, not an asset kit.

---

## Already true in code (do not regress)

- `Sky` + `stipple` + `Celestial.planet` / `star` / `comet`
- Futura captions, void black, five `Element` colors
- `DescentGate`, slide-to-slot Attune, vertical Encounter drag
- `DriftSim` pull/repel + `pulse` on approach
- `VibrationScore` as the wire format to the pebble
- Constellation as you-plus-rays, not a list of matches

## Board-driven gaps to build

1. Encounter overlap as hatched Venn or two-foci lissajous (replace the three-line value list as the *primary* read).
2. Drift proximity as a density field, not only a dashed tether.
3. Essence / pebble ring as a stippled energy disc, not a vector circle.
4. Gather: optional dotted-figure portrait whose dots are live interests.
5. Bond motion: metaball merge before the constellation cut.
6. Hardware: ring breath locked to `pulse` rate; silent path when only one side consents.
