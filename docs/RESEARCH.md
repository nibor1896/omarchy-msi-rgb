# Research notes: MSI RGB on Linux

Summary of the investigation that shaped this plugin (2026-09).

## Reverse engineering the Mystic Light USB hub (1462:921b)

Since no OpenRGB build detects the `1462:921b` "MYSTIC LIGHT" controller,
we reverse engineered it directly on a MEG Vision X AI (2026-09-16):

- HID interface with vendor-defined usage page; feature reports per the
  report descriptor: `0x50` (290 B), `0x51` (727 B), `0x90–0x93` (302 B),
  `0xB0–0xB3` (761 B), `0xF0` (64 B status).
- Firmware ping: 65-byte output report `01 B0 CC…` → response `01 5a 02`
  (firmware 5a.02) — confirms the classic Mystic Light family protocol.
- **Feature report 0x50 (290 bytes) is the zone table**: 16-byte channel
  entries at offset 1, up to 6 channels, each:
  `mode | RGB#1 | RGB#2 | RGB#3 | ff ff ff | 03 15 | led_count`
  Observed modes: `0x00` off, `0x01` static, `0x02` breathing,
  `0x03` flashing, `0x0a` rainbow (default, ships with R/G/B triple).
  Channel LED counts on the reference machine: 23, 18, 11, 8 (4 active
  channels: cooler/fans), channels 5–6 unpopulated.
- Writes: read 0x50, patch entry, `hid_send_feature_report` (290 B);
  the controller applies immediately, read-back confirms.
- Udev rule `60-msi-mystic-light.rules` grants user access — no root.

Tool: `src/msi-mystic.c` (this repo). Upstream-worthy for OpenRGB as a
new Mystic Light PID against the 761-byte/X870-era protocol family.

## How MSI Mystic Light is exposed on Linux

| Path | Devices | Requirements |
|------|---------|--------------|
| USB HID (`1462:921b` "MYSTIC LIGHT") | Case/fan lighting hub of MSI desktops (e.g. MEG Vision X AI) | OpenRGB device support (whitelist by VID:PID) |
| SMBus i2c at `0x4B` (register `0x1462`) | Motherboard RGB zones, JRainbow headers | `i2c-dev` + `i2c-i801` (Intel) / `i2c-piix4` (AMD), udev rules or root |
| NVIDIA NvAPI I2C | MSI/other NVIDIA GPU LEDs | OpenRGB NvAPI support per GPU generation |
| RAM SPD (`0x50–0x57`) | RGB RAM | same SMBus setup |

On the reference machine (MSI MEG Vision X AI, Ultra 9, RTX 5090):

- `lsusb` shows `1462:921b Micro Star International MYSTIC LIGHT`
- `i2cdetect -y 19` (SMBus I801) shows a device at `0x4B`
- OpenRGB 1.0rc3 (Arch stable) detects neither — the hardware is newer than
  the whitelists. `openrgb-git` (Pipeline branch) is the remedy and is what
  `install.sh` recommends when detection fails.

## RTX 5090

GPU RGB for the 5090 is **not implemented** in OpenRGB yet; tracked in
[OpenRGB GitLab issue #4585](https://gitlab.com/CalcProgrammer1/OpenRGB/-/issues/4585).
The card can appear as `NVIDIA NvAPI I2C on GPU 0` without being
controllable. Upstream limitation — this plugin surfaces whatever OpenRGB
supports and hides the rest.

## msi-ec kernel driver

Mainline `drivers/platform/x86/msi-ec.c` (out-of-tree: BeardedIronGiant /
BeardOverflow `msi-ec`) is **laptop-only** (EC fan/shift/battery/keyboard
backlight). Not usable for desktops — irrelevant for the MEG Vision X AI.

## Omarchy plugin system (verified locally)

- Plugins = git repos with a `manifest.json` at the root; installed via
  `omarchy plugin add <url>` into `~/.config/omarchy/plugins/<id>/` (land
  disabled, review then `omarchy plugin enable <id>`), or dropped in by hand.
- Runtime is Quickshell/QML; bar widgets subclass `qs.Ui.BarWidget` and
  expose `open()/close()/opened` for popup routing; popups build on
  `KeyboardPanel` + `PanelKeyCatcher`; user code may import `qs.Commons`
  (`Style`, `Color`) and `qs.Ui`.
- Settings live inline on the widget entry in `~/.config/omarchy/shell.json`;
  third-party ids must not use the `omarchy.*` namespace.
- Validation: `omarchy plugin validate <dir>`; hot reload on save;
  force with `omarchy-shell shell rescanPlugins`.

## Sources

- OpenRGB wiki — <https://openrgb-wiki.readthedocs.io/>
- Device list — <https://openrgb.org/devices.html>
- ArchWiki — <https://wiki.archlinux.org/title/OpenRGB>
- OpenRGB CLI (cli.cpp / man page) — <https://github.com/CalcProgrammer1/OpenRGB/blob/master/cli.cpp>
- MSI GPU RGB tracking — <https://gitlab.com/CalcProgrammer1/OpenRGB/-/issues/4585>
- msi-ec — <https://github.com/BeardOverflow/msi-ec>
