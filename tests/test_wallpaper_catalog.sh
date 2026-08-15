#!/usr/bin/env bash
set -euo pipefail

test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

export HOME="$test_root/home"
theme_dir="$HOME/.local/state/omarchy/current/theme"
mkdir -p "$theme_dir/backgrounds" \
  "$HOME/.config/omarchy/backgrounds/test-theme"

printf 'test-theme\n' >"$HOME/.local/state/omarchy/current/theme.name"

# Theme-provided wallpapers.
printf 'x' >"$theme_dir/backgrounds/dark-1.png"
printf 'x' >"$theme_dir/backgrounds/flower.jpg"
# Not an image; must be excluded.
printf 'x' >"$theme_dir/backgrounds/notes.txt"

# User overlay wallpapers (one with a space in the name).
printf 'x' >"$HOME/.config/omarchy/backgrounds/test-theme/mine-1.jpg"
printf 'x' >"$HOME/.config/omarchy/backgrounds/test-theme/green hills.webp"

expected=$'%s/.config/omarchy/backgrounds/test-theme/green hills.webp\n%s/.config/omarchy/backgrounds/test-theme/mine-1.jpg\n%s/.local/state/omarchy/current/theme/backgrounds/dark-1.png\n%s/.local/state/omarchy/current/theme/backgrounds/flower.jpg'
expected=$(printf "$expected" "$HOME" "$HOME" "$HOME" "$HOME")

actual=$(bash "$(dirname "$0")/../WallpaperCatalog.sh")

if [[ $actual != "$expected" ]]; then
  printf 'FAIL wallpaper catalog\nexpected:\n%s\nactual:\n%s\n' "$expected" "$actual" >&2
  exit 1
fi

printf 'ok - wallpaper catalog lists theme + user wallpapers, excludes non-images\n'
