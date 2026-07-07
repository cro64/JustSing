# JustSing

JustSing is a macOS menu bar app that reduces center-panned vocals in live system audio using center-channel cancellation. It runs in the background, processes audio in real time, and does not record or store anything.

## How It Works

JustSing captures system audio, applies stereo center-channel cancellation (`L - R`), and plays the result to your speakers or headphones. Toggling ramps intensity smoothly over ~50 ms to avoid clicks — the audio pipeline stays running in passthrough when reduction is off, so re-enabling is instant.

On macOS 14.2 and newer, JustSing uses Apple's **Process Tap** API to capture system audio directly, with automatic **BlackHole** fallback if Process Tap is unavailable. On macOS 14.0–14.1, BlackHole is used directly.

## Requirements

- macOS 14 or newer
- macOS 14.2+ recommended (Process Tap — no extra software required)
- [BlackHole 2ch](https://existential.audio/blackhole/) as fallback if Process Tap fails, or on macOS 14.0–14.1

## Permissions

| Capture path | Permission |
|---|---|
| Process Tap (macOS 14.2+) | **System Audio Recording** — prompted on first use |
| BlackHole fallback | **Microphone** — required because BlackHole appears as an input device |

If permission is denied, open the settings popover (right-click the menu bar icon) and use the permission button, or grant access in **System Settings → Privacy & Security**.

## Build

```sh
Scripts/build-app.sh
```

Release build:

```sh
Scripts/build-app.sh release
```

The packaged app is written to `build/JustSing.app`.

You can also build with Swift Package Manager directly:

```sh
swift build --disable-sandbox
```

## Run

Open `build/JustSing.app`. JustSing lives in the menu bar as a headphones icon.

| Action | Result |
|---|---|
| **Left-click** icon | Toggle vocal reduction on/off (smooth ramp, pipeline stays active) |
| **Right-click** icon | Open settings |
| **⌘⌥M** | Toggle vocal reduction (global hotkey) |

### Settings

- **Intensity** — how much center content to remove when toggled on (0–100%)
- **Makeup Gain** — loudness compensation after reduction (0–12 dB, default 4.5 dB)

### Icon Colors

| Color | Meaning |
|---|---|
| White | Idle or passthrough (reduction off) |
| Accent | Vocal reduction active |
| Yellow | Mono input — reduction unavailable |
| Orange | Permission required |
| Red | Error |

## Audio Routing

### Process Tap (macOS 14.2+, preferred)

1. Creates a private system audio tap.
2. Builds a temporary aggregate device that combines the tap with your physical output.
3. Sets the system default output to the aggregate device.
4. Processes tapped audio and plays it through your speakers.
5. Tears down the tap and aggregate device on quit, restoring the previous output.

If Process Tap fails, JustSing automatically falls back to the BlackHole path.

### BlackHole (fallback)

1. Finds BlackHole as the capture device.
2. Saves the current physical output device.
3. Sets the system output to BlackHole.
4. Captures from BlackHole, processes audio, and plays the result to the physical output.
5. Restores the previous output device on quit when possible.

If JustSing launches and finds the system output still set to BlackHole from a previous session, it switches back to the first compatible physical output device. Stale Process Tap aggregate devices from crashed sessions are cleaned up on launch.

## Toggle Behavior

- **First toggle on** starts the audio pipeline and ramps intensity to your configured target.
- **Toggle off** ramps intensity to zero (passthrough) but keeps the pipeline running for instant re-toggle.
- **Quit** fully tears down capture and restores your previous system output device.
- **Last on/off state** is remembered across restarts; if you had reduction enabled, JustSing restores it after the pipeline is healthy (brief passthrough first).

## Debugging

Logs are written to `~/Library/Logs/JustSing/JustSing.log`.

## Project Structure

```
Sources/JustSing/       App and UI
Sources/JustSing/Audio/ Audio engine, DSP, device management
Sources/CAtomics/       Lock-free primitives for realtime audio
Resources/Info.plist    App bundle metadata
Scripts/build-app.sh    Package JustSing.app from SPM build output
```

## Known Limits

- Mono sources cannot be center-cancelled.
- Center-panned non-vocal elements (kick, bass, lead instruments) are also reduced.
- Wide or heavily reverbed vocals may remain audible.
- All system audio is processed together; per-app selection is not supported.

## License

MIT — see [LICENSE](LICENSE).
