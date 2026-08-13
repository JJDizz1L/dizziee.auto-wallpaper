# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-08-13

### Added

- Random day and night theme selections based on Omarchy's `colors.toml` mode metadata.
- Theme pickers grouped by preferred mode with alphabetical ordering within each group.

## [0.1.0] - 2026-08-13

### Added

- Automatic switching between independently selected day and night themes.
- Local-time schedules configurable in 15-minute increments.
- Catch-up after sleep, restart, or a missed schedule boundary.
- Overnight schedule support.
- Manual theme overrides that remain active until the next boundary.
- Omarchy bar panel with enable/disable controls and an apply-now action.
- Sun and moon bar indicators, dimmed while automation is disabled.
- Shell IPC commands for status, enable, disable, and immediate application.
- Persistent configuration under `~/.config/omarchy/theme-scheduler/`.
- Scheduling unit tests and GitHub Actions CI.

[Unreleased]: https://github.com/acrogenesis/omarchy-theme-scheduler/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/acrogenesis/omarchy-theme-scheduler/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/acrogenesis/omarchy-theme-scheduler/releases/tag/v0.1.0
