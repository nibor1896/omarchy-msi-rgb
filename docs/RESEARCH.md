# Research notes: MSI RGB on Linux

Summary of the investigation that shaped this plugin (2026-09).

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
