# omarchy-msi-rgb

Control **MSI RGB lighting (Mystic Light)** on [Omarchy](https://omarchy.org/) —
straight from your status bar.

A native Omarchy shell plugin (Quickshell/QML bar widget with a popup) plus a
`msi-rgb` CLI, powered by [OpenRGB](https://openrgb.org/). While it is built
for MSI systems (Mystic Light motherboards, Mystic Light USB hubs, MSI GPUs),
it controls **every device OpenRGB detects** — RAM, keyboards, mice, AIOs
included — so it works on any Omarchy machine.

![category](https://img.shields.io/badge/category-Omarchy%20shell%20plugin-blue)

## Features

- **Bar widget** with a live color dot; left click opens the control popup
- **Popup panel**: device selector, mode grid, color swatches + hex input,
  speed control, on/off, presets
- **CLI** (`msi-rgb`): set/off/on, presets, save & restore **profiles**,
  device detection, JSON status for scripting
- **IPC**: other tools can drive it via `quickshell ipc` (see below)
- **Boot persistence**: optional systemd user unit restores a profile at login
- **Generic**: any OpenRGB-supported device, any vendor — tuned for MSI

## Requirements

- Omarchy (or any Quickshell-based shell with the Omarchy plugin API)
- `openrgb` (installed automatically by `install.sh`) —
  use `openrgb-git` from the AUR if your MSI board/controller is not detected
  by the stable release (common for very new boards like the MEG Vision X AI)
- For motherboard/RAM control: i2c (`i2c-dev`, `i2c-i801` on Intel /
  `i2c-piix4` on AMD) — set up by `msi-rgb install-udev`

## Install

From a checkout of this repo:

```bash
./install.sh            # CLI + shell plugin (openrgb installed if missing)
./install.sh --udev     # additionally: udev rules + i2c modules (sudo), then log out/in once
./install.sh --boot myprofile   # additionally: restore profile "myprofile" at login
```

Or, once published/added by URL:

```bash
omarchy plugin add https://github.com/nibor1896/omarchy-msi-rgb.git --enable --yes
```

The bar widget lands in the right section; move it with
`omarchy bar move io.github.nibor1896.msi-rgb --section left`.

## Usage

### Bar widget

- **Left click** — open the RGB popup (modes, colors, speed, presets)
- **Right click** — toggle all lights off / back to your default
- **Middle click** — apply the `pride` preset

### CLI

```bash
msi-rgb devices                       # list controllers + modes
msi-rgb set -m rainbow-wave           # all devices, rainbow wave
msi-rgb set -d 0 -m breathing -c 00ff88 -s 3
msi-rgb off                           # lights out
msi-rgb on ff0000
msi-rgb preset list                   # stealth, ambient, blood, ocean, pride, fire, matrix
msi-rgb preset ocean
msi-rgb profile save evening          # snapshot current state of all devices
msi-rgb profile load evening
msi-rgb status                        # JSON (index/name/colors per device)
msi-rgb doctor                        # diagnostics + troubleshooting hints
msi-rgb install-udev                  # udev rules + i2c modules (sudo)
```

### IPC (from scripts/keybinds)

```bash
quickshell ipc -p /usr/share/omarchy/shell call io.github.nibor1896.msi-rgb setColor "00ff41"
quickshell ipc -p /usr/share/omarchy/shell call io.github.nibor1896.msi-rgb preset pride
quickshell ipc -p /usr/share/omarchy/shell call io.github.nibor1896.msi-rgb toggle ""
```

Available methods: `open`, `close`, `toggle`, `off`, `on`, `setMode`,
`setColor`, `preset`.

## Reboot persistence

RGB controllers forget their state on power loss. The plugin handles this:

- every change (CLI, widget, IPC, presets) updates a state journal at
  `~/.config/omarchy-msi-rgb/state` and auto-snapshots it as profile `last`
- `install.sh` enables a systemd user unit (`msi-rgb-boot.service`) by
  default that restores `last` at login — so your lighting always comes back
  after reboot
- use `--boot <profile>` to restore a different profile instead, or
  `--no-boot` to opt out
- widget settings (default mode/color/label) live in
  `~/.config/omarchy/shell.json` and survive reboots by design

## Uninstall

```bash
./uninstall.sh
```

## Direct Mystic Light control (fans / cooler / case lighting)

MSI desktops (e.g. MEG Vision X AI) drive case fans, CPU cooler and LED
strips through a dedicated **Mystic Light USB controller** (`1462:921b`)
that OpenRGB does not support yet. This repo ships its own driver:

- `src/msi-mystic.c` talks to the controller directly over HID feature
  report `0x50` (protocol reverse engineered on a MEG Vision X AI —
  see [docs/RESEARCH.md](docs/RESEARCH.md))
- `install.sh` builds it into `~/.local/bin/msi-mystic` and installs a
  udev rule (`60-msi-mystic-light.rules`) so **no root and no password**
  is needed to control the lighting
- `msi-rgb` integrates it: `set`, `off`, `on`, presets, profiles and
  reboot persistence all drive the Mystic channels too, and `status`
  lists them as `Mystic Light (fans/cooler)` (device index `-2`)
- manual per-channel access:

```bash
msi-rgb mystic ping                 # firmware check
msi-rgb mystic channels             # channel LED counts + current state
msi-rgb mystic set 0 static ff0000  # single channel (0-3)
msi-rgb mystic set all rainbow 000000
```

Live application is implemented per the MSI Center capture (report 0x21
apply, see docs/RESEARCH.md). If the udev rule was removed, re-run
`./install.sh` once to restore passwordless access.

## Known limitations

- **RTX 5090 GPU RGB** is not yet supported by OpenRGB itself
  ([OpenRGB issue #4585](https://gitlab.com/CalcProgrammer1/OpenRGB/-/issues/4585)).
  The GPU may appear as `NVIDIA NvAPI I2C on GPU 0` but cannot be controlled
  yet — that is an upstream OpenRGB limitation, not a plugin bug.
- Very new MSI mainboards (e.g. MEG Vision X AI) may not be whitelisted in
  the stable OpenRGB release — the case/fan/cooler lighting is covered by
  this repo's own `msi-mystic` driver regardless (see above). For
  motherboard/RAM zones, install `openrgb-git` (AUR) and check
  [openrgb.org/devices.html](https://openrgb.org/devices.html).
- If a controller is missing, run `msi-rgb detect`, then try
  `msi-rgb install-udev` and re-login (i2c group membership).
- The openrgb CLI applies one primary color per device; per-zone layouts are
  available through the OpenRGB GUI, not this plugin.

## Development

```bash
tests/run-tests.sh     # unit tests against a fake openrgb (no hardware needed)
shellcheck bin/msi-rgb install.sh uninstall.sh
omarchy plugin validate plugin/
```

The plugin lives in [`plugin/`](plugin/): `BarWidget.qml` (bar dot + IPC),
`Panel.qml` (popup), `RgbBridge.qml` (spawns `msi-rgb`, parses its JSON).
Edit files under `~/.config/omarchy/plugins/io.github.nibor1896.msi-rgb/` for
live hacking — the shell hot-reloads on save.

See [docs/](docs/) for architecture notes and the OpenRGB research summary.

## License

MIT — see [LICENSE](LICENSE).
