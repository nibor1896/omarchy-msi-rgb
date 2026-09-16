# Architecture

```
┌────────────────────────────┐        ┌──────────────────────────────┐
│ Omarchy shell (Quickshell) │        │ User session                 │
│                            │        │                              │
│  BarWidget.qml ── Panel.qml│        │  systemd user unit (optional)│
│       │  RgbBridge.qml     │        │  msi-rgb-boot.service        │
│       ▼ (Process, 1-shot)  │        │       │                      │
│  ┌───────────────────┐     │        │       ▼                      │
│  │ msi-rgb (bash)    │◄────┼────────┼── CLI users, keybinds        │
│  └────────┬──────────┘     │        └──────────────────────────────┘
└───────────┼────────────────┘
            ▼
      openrgb CLI  ──►  MSI Mystic Light (USB 1462:921b / SMBus 0x4B),
                        motherboard, RAM, GPU, peripherals
```

## Layers

1. **OpenRGB** is the only component that talks to hardware. MSI Mystic Light
   is reached two ways: the dedicated USB controller (`1462:921b`, present on
   e.g. the MEG Vision X AI case lighting) and the SMBus controller at
   address `0x4B` on `i2c-i801`/`i2c-piix4` (motherboard zones, RAM).
2. **`bin/msi-rgb`** wraps the `openrgb` CLI: mode aliases, color validation,
   device targeting, presets, profile snapshots (`~/.config/omarchy-msi-rgb/
   profiles/*.rgbprofile`), and a stable JSON status for the UI.
3. **The shell plugin** (`plugin/`) is a standard Omarchy `bar-widget` plugin:
   - `BarWidget.qml` — bar dot, click routing, IPC handler
   - `Panel.qml` — popup UI, delegates every action to the CLI
   - `RgbBridge.qml` (QtObject) — spawns one-shot `Process`es, parses
     `msi-rgb status` JSON into `state`
   - `Chip.qml`/`DevChip.qml`/`ModeChip.qml` — shared pill buttons

## Design decisions

- **One-shot processes, no daemon.** Each action runs `msi-rgb <args>` and
  exits; there is no SDK server to keep alive or port to guard. Latency is
  fine for a lighting control.
- **The CLI is the single source of truth.** The QML never constructs
  `openrgb` arguments itself, so CLI, keybinds and IPC all behave identically.
- **Fail soft.** If OpenRGB is missing or no device is detected, the popup
  shows setup instructions instead of empty controls.

## Plugin manifest

`schemaVersion: 1`, id `io.github.nibor1896.msi-rgb`, kind `bar-widget`,
settings schema: `defaultMode`, `defaultColor`, `showLabel`, `binPath`.
Settings are inline on the widget entry in `~/.config/omarchy/shell.json`.
