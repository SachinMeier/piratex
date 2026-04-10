# Changelog

All notable changes to the Piratex TUI are documented here.

## [0.1.0] — 2026-04-10

### Added

- First release. Terminal client for Pirate Scrabble.
- Three-mode input engine: normal (word entry), `:` command, `/` chat.
- All gameplay screens: home menu, find game, create game, join prompt,
  watch prompt, waiting room, playing, finished, watch.
- Static rules and about screens, paginated (no scrolling).
- Compact "recent" pane and full `:h` history panel.
- Full Phoenix Channel client with reconnect.
- Protocol versioning (major + minor) with hard-gate at major mismatch
  and soft "upgrade available" hint at minor mismatch.
- Self-contained binary distribution via GitHub Releases (`piratex`).
- One-line install script with OS/arch detection.
- `make tui` / `make install` / `make uninstall` build targets.

### Protocol

- Speaks protocol version **1.0**.
