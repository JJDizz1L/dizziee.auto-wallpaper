# Auto Wallpaper for Omarchy

Preview the active Omarchy theme's wallpapers and automatically cycle or shuffle
them on a schedule, with no interaction. The plugin runs as an Omarchy Shell
service, so scheduling continues while you work and resumes after sleep or a
shell restart.

## Features

- Shows the current theme's wallpapers as a grid of clickable previews in the
  panel; click one to set it immediately.
- Automatic switching on an interval: **Sequential** (advance one wallpaper per
  tick) or **Shuffle** (play every wallpaper once before repeating).
- Interval choices from 5 minutes to 24 hours, right in the panel.
- Manual picks and automatic switches share the same rotation, so a manual
  choice never breaks the schedule.
- Survives sleep, restart, and manual theme changes; the rotation resets when
  the active theme changes.
- Bar icon with a live "next wallpaper" tooltip; middle-click to apply the next
  wallpaper now.
- Shell IPC controls listed below.
- Persistent configuration at `~/.config/omarchy/auto-wallpaper/config.json`.

## Install

```bash
omarchy plugin add https://github.com/JJDizz1L/dizziee.auto-wallpaper.git --enable
```

Add the widget to the bar and it starts cycling automatically — automatic switching
is on by default with a 30-minute interval. Adjust the interval, order (sequential
or shuffle), or switch it off from the panel.

## Requirements

- Omarchy 4 with the Quattro shell plugin API.
- A theme that has wallpapers. Themes provide them under
  `/usr/share/omarchy/themes/<theme>/backgrounds/`; add your own for a theme in
  `~/.config/omarchy/backgrounds/<theme>/` (run `omarchy theme bg install` to
  open that folder).

## Remove

```bash
omarchy plugin remove dizziee.auto-wallpaper
```

Removing the plugin leaves its settings at
`~/.config/omarchy/auto-wallpaper/config.json` so a later reinstall can reuse
them. Delete that file only if you also want to discard the saved schedule and
shuffle cycle.

For local development:

```bash
ln -sfn "$PWD" ~/.config/omarchy/plugins/dizziee.auto-wallpaper
omarchy plugin enable dizziee.auto-wallpaper --section right
```

## Commands

```bash
omarchy-shell dizziee.auto-wallpaper status
omarchy-shell dizziee.auto-wallpaper enable
omarchy-shell dizziee.auto-wallpaper disable
omarchy-shell dizziee.auto-wallpaper applyNow
```

## How scheduling behaves

Every 5 seconds the service checks the wall clock. When automatic switching is
enabled and the current interval has elapsed since the last change, it applies
the next wallpaper with `omarchy theme bg set`. Both scheduled and manual
switches restart the interval, so the rotation stays regular.

- **Sequential**: advances to the wallpaper after the current one, wrapping at
  the end.
- **Shuffle**: builds a random order (a saved cycle) and steps through it
  without repeating until every wallpaper has been shown. Manual picks and
  theme changes keep the cycle aligned.

Changing the active theme resets the rotation and waits one interval before
switching, so you can enjoy the new theme first.

## Development

```bash
node tests/test_schedule.js
bash tests/test_wallpaper_catalog.sh
node -e 'JSON.parse(require("fs").readFileSync("manifest.json","utf8"))'
qmllint -I /usr/share/omarchy/shell ./*.qml
```

## License

MIT
