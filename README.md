# Theme Scheduler for Omarchy

Automatically switch between a light and dark Omarchy theme using your local
time. The plugin runs inside Omarchy Shell, catches up after sleep or restart,
and does not require root access or systemd units.

## Features

- Independent day and night themes
- Random light and dark choices using each theme's Omarchy mode metadata
- 15-minute schedule controls
- Local-time operation with overnight schedules supported
- Resume/restart catch-up
- Manual theme overrides remain until the next scheduled boundary
- Bar panel, middle-click “apply now,” and shell IPC controls
- Configuration stored at `~/.config/omarchy/theme-scheduler/config.json`

## Install

```bash
omarchy plugin add https://github.com/acrogenesis/omarchy-theme-scheduler.git --enable
```

The plugin is safe on first install: its internal automation toggle defaults
to off. Add its widget to the bar, choose the two themes and times, then enable
automatic switching.

## Requirements

- Omarchy 4 with the Quattro shell plugin API
- No external packages, root access, or background system services

## Remove

```bash
omarchy plugin remove acrogenesis.theme-scheduler
```

Removing the plugin leaves its settings at
`~/.config/omarchy/theme-scheduler/config.json` so a later reinstall can reuse
them. Delete that file separately only if you also want to discard the saved
schedule and theme choices.

For local development:

```bash
ln -sfn "$PWD" ~/.config/omarchy/plugins/acrogenesis.theme-scheduler
omarchy plugin enable acrogenesis.theme-scheduler --section right
```

## Commands

```bash
omarchy-shell acrogenesis.theme-scheduler status
omarchy-shell acrogenesis.theme-scheduler enable
omarchy-shell acrogenesis.theme-scheduler disable
omarchy-shell acrogenesis.theme-scheduler applyNow
```

## How scheduling behaves

At each day/night boundary, the service applies the configured theme with
`omarchy theme set`. It records that boundary after a successful switch. This
means choosing another theme manually will not be immediately undone; the
scheduler takes control again at the next boundary.

The day and night pickers also offer **Random light theme** and **Random dark
theme**. Omarchy declares the classification as `mode = "light"` or `mode =
"dark"` in each theme's effective `colors.toml`. Themes without that metadata
remain available for explicit selection but are excluded from random choices.
Each picker lists its matching mode first, the opposite mode second, and any
unclassified themes last; themes within every group are alphabetical.

The service evaluates the wall clock every minute. If the computer sleeps
through a boundary or Omarchy Shell starts later, it applies the theme for the
current period when it resumes.

## Development

```bash
node tests/test_schedule.js
bash tests/test_theme_catalog.sh
omarchy plugin validate .
qmllint -I /usr/share/omarchy/shell ./*.qml
```

## License

MIT
