#!/usr/bin/env bash
# Remove the omarchy-msi-rgb plugin, CLI and boot unit.
set -euo pipefail

PLUGIN_ID="io.github.nibor1896.msi-rgb"

say() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }

if omarchy plugin disable "$PLUGIN_ID" 2>/dev/null; then
  say "Plugin disabled."
fi
rm -rf "${HOME}/.config/omarchy/plugins/${PLUGIN_ID}"
rm -f "${HOME}/.local/bin/msi-rgb"

if [[ -f "${HOME}/.config/systemd/user/msi-rgb-boot.service" ]]; then
  systemctl --user disable --now msi-rgb-boot.service 2>/dev/null || true
  rm -f "${HOME}/.config/systemd/user/msi-rgb-boot.service"
  systemctl --user daemon-reload
fi

omarchy-shell shell rescanPlugins 2>/dev/null || true
say "Removed. (openrgb and udev rules were left installed — remove with 'pacman -R openrgb' if desired.)"
