# Starfall Hardware: draft

The app is built so the phone is only a stand-in. Anything that implements
`ResonanceOutput` can make a person *feel* a meeting.

## Pebble (v0 concept)
- MCU with BLE: nRF52840 or ESP32-C3/S3 (we have C3 SuperMinis on the bench)
- LRA haptic + DRV2605L driver (real-time playback mode for intensity/sharpness)
- RGB ring (WS2812 / SK6812 mini) showing the aura colours, no screen
- LiPo + charger, capacitive touch or a single slide/rotary switch (slide, never tap)

## BLE GATT (proposed)
Service `STARFALL` `5354_4641_4c4c_0000_0000_000000000001`

| Char | UUID suffix | Props | Payload |
|---|---|---|---|
| Score | `…0002` | write | `VibrationScore.encoded()`: `[u8 n]` then n × `[u16 t_ms][u8 intensity][u8 sharpness][u16 dur_ms]` LE |
| Aura | `…0003` | write | up to 3 × RGB (9 bytes) |
| Presence | `…0004` | read/notify | rotating ephemeral soul token (16 bytes) for proximity matching |
| Gesture | `…0005` | notify | `0x01` slide-bond, `0x02` slide-release |

## Phone-less matching (later)
Pebbles advertise an ephemeral token. Resonance is computed server-side or
on-device from pre-synced, consented profiles. RSSI drives the "approach" pulse
(`VibrationScore.pulse`), and the meeting score plays on both pebbles at once.
