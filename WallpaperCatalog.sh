#!/usr/bin/env bash

# List the wallpapers available for the active theme as tab-separated rows:
#   <resolved path>\t<thumbnail path>
#
# The thumbnail reuses Omarchy's existing image-selector cache
# (~/.cache/omarchy/image-selector/<hash>.jpg, keyed like the built-in picker),
# so previews stay small and no duplicate cache is created. When a cached
# thumbnail is missing the original path is returned so the preview still
# works (run `omarchy-theme-bg-cache` to populate it).

theme_name=$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null)
current_bg_dir="$HOME/.local/state/omarchy/current/theme/backgrounds"
user_bg_dir="$HOME/.config/omarchy/backgrounds/$theme_name"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/omarchy/image-selector"
index_file="$cache_dir/index.tsv"

thumbnail_for() {
  local image="$1" signature hash thumbnail
  signature=$(stat -Lc '%s:%Y' "$image") || return
  hash=$(awk -F $'\t' -v path="$image" -v sig="$signature" \
    '$1 == path && $2 == sig { print $3; exit }' "$index_file" 2>/dev/null)
  if [[ -z $hash ]]; then
    hash=$(printf '%s\t%s' "$image" "$signature" | md5sum | cut -d ' ' -f 1)
  fi
  thumbnail="$cache_dir/$hash.jpg"
  if [[ -f $thumbnail ]]; then
    printf '%s' "$thumbnail"
  else
    printf '%s' "$image"
  fi
}

{
  find -L "$current_bg_dir" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' \
       -o -iname '*.bmp' -o -iname '*.webp' \) -print 2>/dev/null
  find -L "$user_bg_dir" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' \
       -o -iname '*.bmp' -o -iname '*.webp' \) -print 2>/dev/null
} | sort -u | while IFS= read -r path; do
  full=$(realpath -m "$path")
  thumb=$(thumbnail_for "$full")
  [[ -n $thumb ]] || thumb="$full"
  printf '%s\t%s\n' "$full" "$thumb"
done | sort -u
