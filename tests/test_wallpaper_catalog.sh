#!/usr/bin/env bash
set -euo pipefail

test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

export HOME="$test_root/home"
export XDG_CACHE_HOME="$test_root/cache"
theme_dir="$HOME/.local/state/omarchy/current/theme"
mkdir -p "$theme_dir/backgrounds" \
  "$HOME/.config/omarchy/backgrounds/test-theme" \
  "$XDG_CACHE_HOME/omarchy/image-selector"

printf 'test-theme\n' >"$HOME/.local/state/omarchy/current/theme.name"

# Theme-provided wallpapers.
printf 'x' >"$theme_dir/backgrounds/dark-1.png"
printf 'x' >"$theme_dir/backgrounds/flower.jpg"
# Not an image; must be excluded and never get a thumbnail row.
printf 'x' >"$theme_dir/backgrounds/notes.txt"

# User overlay wallpapers (one with a space in the name).
printf 'x' >"$HOME/.config/omarchy/backgrounds/test-theme/mine-1.jpg"
printf 'x' >"$HOME/.config/omarchy/backgrounds/test-theme/green hills.webp"

# Simulate an existing Omarchy thumbnail cache row for flower.jpg only, in the
# exact format omarchy writes (path, size:mtime signature, md5 hash).
flower="$HOME/.local/state/omarchy/current/theme/backgrounds/flower.jpg"
flower_sig=$(stat -Lc '%s:%Y' "$flower")
flower_hash=$(printf '%s\t%s' "$flower" "$flower_sig" | md5sum | cut -d ' ' -f 1)
printf '%s\t%s\t%s\n' "$flower" "$flower_sig" "$flower_hash" \
  >>"$XDG_CACHE_HOME/omarchy/image-selector/index.tsv"
printf 'thumb' >"$XDG_CACHE_HOME/omarchy/image-selector/$flower_hash.jpg"

actual=$(bash "$(dirname "$0")/../WallpaperCatalog.sh")

# Expected rows: realpath<TAB>thumb. flower.jpg resolves to its cached
# thumbnail; every other wallpaper falls back to its own path.
expected=$'%s/.config/omarchy/backgrounds/test-theme/green hills.webp\t%s/.config/omarchy/backgrounds/test-theme/green hills.webp\n%s/.config/omarchy/backgrounds/test-theme/mine-1.jpg\t%s/.config/omarchy/backgrounds/test-theme/mine-1.jpg\n%s/.local/state/omarchy/current/theme/backgrounds/dark-1.png\t%s/.local/state/omarchy/current/theme/backgrounds/dark-1.png\n%s/.local/state/omarchy/current/theme/backgrounds/flower.jpg\t%s/cache/omarchy/image-selector/%s.jpg'
expected=$(printf "$expected" "$HOME" "$HOME" "$HOME" "$HOME" "$HOME" "$HOME" "$HOME" "$test_root" "$flower_hash")

if [[ $actual != "$expected" ]]; then
  printf 'FAIL wallpaper catalog\nexpected:\n%s\nactual:\n%s\n' "$expected" "$actual" >&2
  exit 1
fi

printf 'ok - catalog reuses omarchy thumbnail cache and falls back to originals\n'
