#!/usr/bin/env bash

# Omarchy's public theme list contains names only. Add the authoritative
# light/dark mode from each effective colors.toml for the scheduler.
omarchy_path="${OMARCHY_PATH:-/usr/share/omarchy}"
user_themes="$HOME/.config/omarchy/themes"

{
  find "$user_themes" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) -printf '%f\n' 2>/dev/null
  find "$omarchy_path/themes" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null
} | sort -u | while IFS= read -r slug; do
  colors="$user_themes/$slug/colors.toml"
  [[ -f "$colors" ]] || colors="$omarchy_path/themes/$slug/colors.toml"

  mode=$(sed -nE 's/^[[:space:]]*mode[[:space:]]*=[[:space:]]*"(dark|light)".*/\1/p' \
    "$colors" 2>/dev/null | head -n 1)
  name=$(sed -E 's/(^|-)([a-z])/\1\u\2/g; s/-/ /g' <<<"$slug")
  printf '%s\t%s\n' "$name" "$mode"
done
