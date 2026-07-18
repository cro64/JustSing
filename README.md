# MinusOne

macOS menu bar app for live vocal reduction in system audio. Runs in the background, processes in real time, and does not record or store anything.

## Modes

| Mode | Latency | CPU | Best for |
|------|---------|-----|----------|
| **Direct** | Zero | Minimal | Unmodified listening, routing check |
| **Center Cut** | Near-zero | Minimal | Karaoke — instant `L − R` center vocal cut |
| **Neural** | ~10 s | Low (~single-digit % on Apple Silicon) | Best vocal removal — Demucs v4 separation |

**Neural** uses overlapping ~10-second windows. Playback is delayed by one window so the instrumental stream stays aligned with the dry path. The neural pipeline starts only when you enable reduction (not on app launch).

**Center Cut** and **Neural** ramp intensity over ~50 ms when toggled. **Direct** passes audio through unchanged.

Capture uses **Process Tap** on macOS 14.2+ (recommended), with **BlackHole** fallback on older macOS or if the tap fails. Process Tap can target **all apps** or **selected apps** only.

## Quick Start

```sh
Scripts/build-app.sh release          # → build/MinusOne.app
Scripts/download-model.sh             # Neural only, ~200 MB one-time
```

Open `build/MinusOne.app`. On first launch, download the Neural model (or skip and use Center Cut). Left-click the menu bar waveform icon for settings, then choose **Neural** after the model is installed. Right-click the icon to toggle reduction.

## Requirements

- macOS 14+ (14.2+ recommended for Process Tap)
- [BlackHole 2ch](https://existential.audio/blackhole/) if Process Tap is unavailable
- Neural: Demucs model download (not bundled)

| Capture | Permission |
|---------|------------|
| Process Tap | System Audio Recording |
| BlackHole | Microphone |

## Controls

| Action | Result |
|--------|--------|
| Left-click icon | Settings |
| Right-click icon | Toggle vocal reduction |
| Capture → Custom → Apps menu | Pick which apps to process |
| ⌘⌥M | Toggle vocal reduction |

### Settings

Compact menu-style panel (opens to the right of the icon):

| Control | Description |
|---------|-------------|
| **Mode** | Direct · Center Cut · Neural |
| **Intensity** | Vocal removal amount when on (0–100%); value shows while dragging |
| **Gain** | Loudness compensation (0–12 dB, default 4.5); value shows while dragging |
| **Capture** | All Apps · Custom (Process Tap only) |

Intensity and gain apply to Center Cut and Neural only.

**Custom** only processes checked apps — FaceTime, Discord, and other unchecked apps play normally. Requires Process Tap (macOS 14.2+).

### Status header

| Title | Notes |
|-------|-------|
| **Off** | Reduction disabled |
| **On** | Reduction active |
| **Warming up** | Neural model loading |
| **Mono input** | Center cut unavailable |
| **Permission needed** | Open Settings to allow |
| **Error** | Info button shows the error message |

### Icon

Official logo is the **active** waveform (center as a dot) — see `Resources/MinusOne.icon`. Menu bar states:

| Appearance | Meaning |
|------------|---------|
| Full center bar (menu-bar tint) | Idle / reduction off |
| Center dot (accent) | Reduction on |
| Cyan | Neural warming up |
| Yellow | Mono input — Center Cut unavailable |
| Orange | Permission required |
| Red | Error |

## Neural model

Neural mode uses **Demucs v4** (`htdemucs`) — Meta’s open-source 4-stem music separation model, converted to CoreML for Apple Silicon.

### Install

```sh
Scripts/download-model.sh
```

Downloads [HTDemucs FP16 CoreML](https://huggingface.co/dexxdean/htdemucs-coreml) to `~/Library/Application Support/MinusOne/Models/`, compiles once (~20 s), and installs `htdemucs.mlmodelc`. Legacy `HTDemucs_CoreML.*` paths still work. The welcome screen can also download it on first launch.

## Audio routing

**Process Tap** — creates a tap + temporary aggregate device, sets it as system output, processes audio, restores on quit. Supports all-apps or selected-app capture.

**BlackHole** — routes output through BlackHole, captures and processes, restores previous device on quit. Orphaned BlackHole defaults and stale tap aggregates are cleaned up on launch.

## Development

```sh
Scripts/package-icon.sh       # compile Resources/MinusOne.icon → Assets.car (Xcode 26.6+)
Scripts/build-app.sh          # debug build (embeds icon)
Scripts/build-app.sh release
swift build --disable-sandbox # SPM only
```

```
Sources/MinusOne/           App and UI
Sources/MinusOne/Audio/   Engine, DSP, neural pipeline
Sources/CAtomics/         Realtime primitives
Resources/MinusOne.icon   App icon (Icon Composer)
Resources/MinusOneIcon.svg  Logo vector (active waveform)
Scripts/build-app.sh
Scripts/package-icon.sh
Scripts/download-model.sh
```

Logs: `~/Library/Logs/MinusOne/MinusOne.log`

## Limits

- Direct does not reduce vocals; mono sources cannot use Center Cut.
- Center-panned non-vocals are affected in Center Cut; Neural behaves differently but is not perfect.
- Neural adds ~10 s delay and re-warms after track changes (dry audio until ready).
- BlackHole capture processes all system audio — per-app selection requires Process Tap.

## License

MIT — see [LICENSE](LICENSE).
