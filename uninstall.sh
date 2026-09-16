#!/usr/bin/env bash
# Remove the omarchy-msi-rgb plugin, CLI and boot unit.
set -euo pipefail

PLUGIN_ID="io.github.nibor1896.msi-rgb"

say() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }

if omarchy plugin disable "$PLUGIN_ID" 2>/dev/null; then
  say "Plugin disabled."
fi
rm -rf "${HOME}/.config/omarchy/plugins/${PLUGIN_ID}"
rm -f "${HOME}/.local/bin/msi-rgb" "${HOME}/.local/bin/msi-mystic"
rm -rf "${HOME}/.config/omarchy-msi-rgb"

if [[ -f "${HOME}/.config/systemd/user/msi-rgb-boot.service" ]]; then
  systemctl --user disable --now msi-rgb-boot.service 2>/dev/null || true
  rm -f "${HOME}/.config/systemd/user/msi-rgb-boot.service"
  systemctl --user daemon-reload
fi

if [[ -f /etc/udev/rules.d/60-msi-mystic-light.rules ]]; then
  if command -v pkexec >/dev/null 2>&1; then
    if pkexec bash -c 'rm -f /etc/udev/rules.d/60-msi-mystic-light.rules && udevadm control --reload-rules'; then
      say "Removed udev rule."
    else
      err "could not remove udev rule (sudo rm /etc/udev/rules.d/60-msi-mystic-light.rules)"
    fi
  fi
fi

omarchy-shell shell rescanPlugins 2>/dev/null || true
say "Removed. (openrgb and its udev rules were left installed — remove with 'pacman -R openrgb' if desired.)"
