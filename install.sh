#!/usr/bin/env bash
# Install the omarchy-msi-rgb plugin:
#   1. openrgb (backend) via pacman/omarchy pkg
#   2. msi-rgb CLI into ~/.local/bin
#   3. the Omarchy shell plugin into ~/.config/omarchy/plugins/
#   4. (optional) udev rules + i2c modules: pass --udev
#   5. (optional) systemd user unit that restores a profile at login: --boot <profile>
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ID="io.github.nibor1896.msi-rgb"
BIN_DIR="${HOME}/.local/bin"
PLUGIN_DIR="${HOME}/.config/omarchy/plugins/${PLUGIN_ID}"

say() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }

DO_UDEV=0
BOOT_PROFILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --udev) DO_UDEV=1 ;;
    --no-boot) BOOT_PROFILE="__none__" ;;
    --boot) BOOT_PROFILE="${2:-}"; shift ;;
    --boot=*) BOOT_PROFILE="${1#*=}" ;;
    *) echo "Unknown option: $1 (supported: --udev, --boot [profile], --no-boot)" >&2; exit 1 ;;
  esac
  shift
done

# 1. Backend
if ! command -v openrgb >/dev/null 2>&1; then
  say "Installing openrgb…"
  if command -v omarchy >/dev/null 2>&1; then
    omarchy pkg add openrgb || pacman -S --needed --noconfirm openrgb
  else
    pacman -S --needed --noconfirm openrgb
  fi
fi

# 2. CLI
say "Installing msi-rgb CLI to ${BIN_DIR}"
mkdir -p "$BIN_DIR"
install -m 755 "$REPO_DIR/bin/msi-rgb" "$BIN_DIR/msi-rgb"

# 3. Plugin
say "Installing shell plugin to ${PLUGIN_DIR}"
mkdir -p "$(dirname "$PLUGIN_DIR")"
rm -rf "$PLUGIN_DIR"
cp -a "$REPO_DIR/plugin" "$PLUGIN_DIR"

# 4. udev (optional — needed for motherboard/RAM SMBus devices)
if [[ $DO_UDEV -eq 1 ]]; then
  say "Setting up udev rules and i2c modules (sudo)…"
  "$BIN_DIR/msi-rgb" install-udev
fi

# 5. Boot persistence (default on): msi-rgb auto-saves the applied state as
#    profile "last" after every change; this unit restores it at login so
#    settings survive reboots/power loss (controllers forget when unpowered).
if [[ $BOOT_PROFILE != "__none__" ]]; then
  [[ -z "$BOOT_PROFILE" ]] && BOOT_PROFILE="last"
  say "Installing systemd user unit to restore profile '${BOOT_PROFILE}' at login…"
  mkdir -p "${HOME}/.config/systemd/user"
  sed "s/@PROFILE@/${BOOT_PROFILE}/" \
    "$REPO_DIR/systemd/msi-rgb-boot.service.in" > "${HOME}/.config/systemd/user/msi-rgb-boot.service"
  systemctl --user daemon-reload
  systemctl --user enable msi-rgb-boot.service
fi

# 6. Register with the running shell
say "Registering plugin with Omarchy shell…"
omarchy-shell shell rescanPlugins 2>/dev/null || true
omarchy plugin enable "$PLUGIN_ID" 2>/dev/null || {
  echo "Note: could not enable via CLI (shell not running?). The plugin will be"
  echo "picked up on your next login; or run: omarchy plugin enable $PLUGIN_ID"
}

say "Done. Left-click the 'RGB' bar widget to control your lighting."
if [[ $DO_UDEV -eq 1 ]]; then
  echo "Remember to log out/in once so the i2c group membership applies."
fi
