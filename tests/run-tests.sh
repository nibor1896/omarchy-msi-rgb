#!/usr/bin/env bash
# Unit tests for bin/msi-rgb that do NOT touch real hardware — they run the
# script against a fake `openrgb` binary (tests/fake-openrgb) via OPENRGB_BIN.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$REPO_DIR/bin/msi-rgb"
export OPENRGB_BIN="$REPO_DIR/tests/fake-openrgb"

export XDG_CONFIG_HOME="$(mktemp -d)"
export XDG_DATA_HOME="$XDG_CONFIG_HOME"
trap 'rm -rf "$XDG_CONFIG_HOME"' EXIT

pass=0; fail=0
ok()   { pass=$((pass+1)); printf '  ✓ %s\n' "$1"; }
nok()  { fail=$((fail+1)); printf '  ✗ %s\n' "$1"; }

check() { # check <desc> <expected> <actual>
  if [[ "$2" == "$3" ]]; then ok "$1"; else nok "$1 (expected: $2, got: $3)"; fi
}

echo "== help / version"
"$CLI" help >/dev/null        && ok "help exits 0" || nok "help exits 0"
check "version" "msi-rgb $("$CLI" --version | grep -o '[0-9.]*')" "msi-rgb 0.1.0"

echo "== status JSON"
out="$("$CLI" status)"
echo "$out" | jq -e '.devices | length == 3' >/dev/null && ok "3 devices" || nok "3 devices ($out)"
check "device 0 name" "MSI Mystic Light" "$(echo "$out" | jq -r '.devices[0].name')"
echo "$out" | jq -e '.devices[0].colors[0] == "ff0000"' >/dev/null && ok "color parsed" || nok "color parsed"

echo "== color validation"
"$CLI" set --color zzzaq >/dev/null 2>&1 && nok "invalid color rejected" || ok "invalid color rejected"
"$CLI" set --color '#FF0000' >/dev/null 2>&1 && ok "#-prefixed color accepted" || nok "#-prefixed color accepted"

echo "== fake openrgb received correct args"
argsfile="$XDG_CONFIG_HOME/openrgb-args"
: > "$argsfile"
"$CLI" set -d 0 -m rainbow-wave -c 00ff88 -s 3 >/dev/null
grep -q -- '--device 0 --mode Rainbow Wave --color 00ff88 --speed 3' "$argsfile" \
  && ok "set maps to openrgb flags + mode alias" \
  || nok "set maps flags ($(cat "$argsfile"))"

: > "$argsfile"
"$CLI" off >/dev/null
grep -q -- '--mode Off --color 000000' "$argsfile" && ok "off → Off/000000" || nok "off"

echo "== presets"
"$CLI" preset list | grep -q stealth && ok "preset list" || nok "preset list"
"$CLI" preset nosuch >/dev/null 2>&1 && nok "unknown preset rejected" || ok "unknown preset rejected"
: > "$argsfile"; "$CLI" preset matrix >/dev/null
grep -q -- '--mode Static --color 00ff41' "$argsfile" && ok "preset matrix applies static green" || nok "preset matrix"

echo "== profiles"
"$CLI" profile save test >/dev/null && [[ -f "$XDG_CONFIG_HOME/omarchy-msi-rgb/profiles/test.rgbprofile" ]] \
  && ok "profile saved" || nok "profile saved"
"$CLI" profile list | grep -q test && ok "profile listed" || nok "profile listed"
"$CLI" profile load test >/dev/null && ok "profile loaded" || nok "profile loaded"
"$CLI" profile delete test >/dev/null && ok "profile deleted" || nok "profile deleted"
"$CLI" profile load test >/dev/null 2>&1 && nok "missing profile rejected" || ok "missing profile rejected"

echo
echo "passed: $pass, failed: $fail"
[[ $fail -eq 0 ]]
