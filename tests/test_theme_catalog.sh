#!/usr/bin/env bash
set -euo pipefail

test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

export HOME="$test_root/home"
export OMARCHY_PATH="$test_root/omarchy"
mkdir -p "$HOME/.config/omarchy/themes/custom-no-mode" \
  "$HOME/.config/omarchy/themes/overlaid" \
  "$OMARCHY_PATH/themes/dark-stock" \
  "$OMARCHY_PATH/themes/light-stock" \
  "$OMARCHY_PATH/themes/overlaid"

printf 'mode = "dark"\n' >"$OMARCHY_PATH/themes/dark-stock/colors.toml"
printf 'mode = "light"\n' >"$OMARCHY_PATH/themes/light-stock/colors.toml"
printf 'mode = "dark"\n' >"$OMARCHY_PATH/themes/overlaid/colors.toml"
printf 'mode = "light"\n' >"$HOME/.config/omarchy/themes/overlaid/colors.toml"

expected=$'Custom No Mode\t\nDark Stock\tdark\nLight Stock\tlight\nOverlaid\tlight'
actual=$(bash "$(dirname "$0")/../ThemeCatalog.sh")

if [[ $actual != "$expected" ]]; then
  printf 'FAIL theme catalog\nexpected:\n%s\nactual:\n%s\n' "$expected" "$actual" >&2
  exit 1
fi

printf 'ok - theme catalog reads modes and respects user overlays\n'
