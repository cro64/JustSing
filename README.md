# JustSing

macOS menu bar app for live vocal reduction in system audio. Runs in the background, processes in real time, and does not record or store anything.

## Modes

| Mode | Latency | CPU | Best for |
|------|---------|-----|----------|
| **Direct** | Zero | Minimal | Unmodified listening, routing check |
| **Center Cut** | Near-zero | Minimal | Karaoke — instant `L − R` center vocal cut |
| **Neural** | ~10 s | Low (~single-digit % on Apple Silicon) | Best vocal removal — Demucs v4 separation |

**Neural** uses overlapping ~10-second windows. Playback is delayed by one window so the instrumental stream stays aligned with the dry path. With reduction off, the pipeline stays warm on a delayed timeline so toggling back on stays in sync.

**Center Cut** and **Neural** ramp intensity over ~50 ms when toggled. **Direct** passes audio through unchanged.

Capture uses **Process Tap** on macOS 14.2+ (recommended), with **BlackHole** fallback on older macOS or if the tap fails.

## Quick Start

```sh
Scripts/build-app.sh release          # → build/JustSing.app
Scripts/download-model.sh htdemucs    # Neural only, ~200 MB one-time
```

Open `build/JustSing.app`. Select **Neural → Balanced** in settings (right-click the menu bar icon) after installing the model.

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
| Left-click icon | Toggle vocal reduction |
| Right-click icon | Settings |
| ⌘⌥M | Toggle vocal reduction |

### Settings

| Control | Description |
|---------|-------------|
| **Mode** | Direct · Center Cut · Neural |
| **Model** | Neural only — Balanced · Fine-Tuned · Six-Stem |
| **Intensity** | Vocal removal amount when on (0–100%) |
| **Makeup Gain** | Loudness compensation (0–12 dB, default 4.5) |

Intensity and makeup gain apply to Center Cut and Neural only.

### Icon colors

| Color | Meaning |
|-------|---------|
| White | Idle or reduction off |
| Accent | Reduction active |
| Cyan | Neural warming up |
| Yellow | Mono input — Center Cut unavailable |
| Orange | Permission required |
| Red | Error |

## Neural models

| Name | Demucs ID | Stems | Notes |
|------|-----------|-------|-------|
| **Balanced** | `htdemucs` | 4 | Default — installable today |
| **Fine-Tuned** | `htdemucs_ft` | 4 | Best quality, slower — coming soon |
| **Six-Stem** | `htdemucs_6s` | 6 | +guitar/piano — coming soon |

Only **Balanced** has a CoreML build. Fine-Tuned and Six-Stem appear grayed in settings until packages are available.

### Install Balanced

```sh
Scripts/download-model.sh          # same as htdemucs
```

Downloads [HTDemucs FP16 CoreML](https://huggingface.co/dexxdean/htdemucs-coreml) to `~/Library/Application Support/JustSing/Models/`, compiles once (~20 s), and installs `htdemucs.mlmodelc`. Legacy `HTDemucs_CoreML.*` paths still work.

## Audio routing

**Process Tap** — creates a tap + temporary aggregate device, sets it as system output, processes audio, restores on quit.

**BlackHole** — routes output through BlackHole, captures and processes, restores previous device on quit. Orphaned BlackHole defaults and stale tap aggregates are cleaned up on launch.

## Development

```sh
Scripts/build-app.sh          # debug build
swift build --disable-sandbox # SPM only
```

```
Sources/JustSing/           App and UI
Sources/JustSing/Audio/   Engine, DSP, neural pipeline
Sources/CAtomics/         Realtime primitives
Scripts/build-app.sh
Scripts/download-model.sh
```

Logs: `~/Library/Logs/JustSing/JustSing.log`

## Limits

- Direct does not reduce vocals; mono sources cannot use Center Cut.
- Center-panned non-vocals are affected in Center Cut; Neural behaves differently but is not perfect.
- Neural adds ~10 s delay and re-warms after track changes (dry audio until ready).
- All system audio is processed together — no per-app selection.

## License

MIT — see [LICENSE](LICENSE).
