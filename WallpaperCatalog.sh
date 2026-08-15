#!/usr/bin/env bash

# List the wallpapers available for the active theme as absolute paths, one per
# line. Combines the theme's own backgrounds with any user overlays for that
# theme and deduplicates by resolved path. Mirrors the file set that
# omarchy-theme-bg-next / omarchy-theme-bg-switcher operate on.

theme_name=$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null)
current_bg_dir="$HOME/.local/state/omarchy/current/theme/backgrounds"
user_bg_dir="$HOME/.config/omarchy/backgrounds/$theme_name"

{
  find -L "$current_bg_dir" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' \
       -o -iname '*.bmp' -o -iname '*.webp' \) -print 2>/dev/null
  find -L "$user_bg_dir" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' \
       -o -iname '*.bmp' -o -iname '*.webp' \) -print 2>/dev/null
} | sort -u | while IFS= read -r path; do
  realpath -m "$path"
done | sort -u
