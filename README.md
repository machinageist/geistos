# geistos

A local-first Linux workstation: the Geist application suite plus the Hyprland
and Quickshell configuration that surfaces it on the desktop.

This repository is early. Today it holds the desktop configuration and the
packaging plan. The installer that pins, builds, and links everything does not
exist yet.

## Layout

```text
geistos/
  config/hypr/        Hyprland: keybindings, autostart, look and feel, lock, idle
  config/quickshell/  The shell: bar, launcher, panels, services, 38 themes
  mg-suite/           The application suite — a separate repository
```

`mg-suite/` is not tracked here. It is its own repository with its own history,
and it in turn treats each of its six applications as a separate repository. The
plan is for geistos to pin them by commit rather than vendor them.

## The desktop

One Quickshell QML codebase replaces Waybar, wofi and mako: the bar, launcher,
notifications, popups, and a 38-palette theme system shared with
machinageist.dev. It runs as `qs -c mgeist`, started from Hyprland's Lua config.

```text
config/quickshell/mgeist/
  shell.qml       entrypoint: screen variants, resident panels, IPC handlers
  Theme/          the only source of colour; palettes.json drives 38 generated themes
  Bar/            the bar surface and one file per module
  Panels/         launcher, quick settings, notifications, clipboard, session,
                  theme selector, AI, system monitor, keybindings
  Services/       singletons: stats, backlight, notifications, wallpaper,
                  palette, rotation, pomodoro, stopwatch, AI, spectrum
  Widgets/        Pill, PopupPanel, BarText, AppIcon, Graph, BarMeter
```

The Geist panel is the suite's face on the desktop: per-application status, a
launcher for each CLI, and an explicit "Refresh todo agenda" action that runs the
mg-remindr to mg-calr projection bridge.

## Requirements

Hyprland, Quickshell, ghostty, python3, and a Nerd Font for the glyphs. The
suite adds a Rust toolchain at 1.85 or newer and, for `mg-calr` and
`mg-remindr`, a user-provisioned PostgreSQL server.

## Configuration notes

The configuration here is sanitized for distribution and differs from a working
checkout in two places:

- `config/hypr/hyprlock.conf` uses placeholder paths for the lock background and
  the avatar image. Set your own or delete the avatar block.
- `config/hypr/hyprpaper.conf` points at `~/pictures/wallpaper/default.jpg`. The
  shell's wallpaper service scans `~/pictures/wallpaper` and drives hyprpaper
  over IPC at runtime, so this file mostly matters at first launch.

Everything else resolves through `$HOME` and needs no editing.

## Not here yet

- **An installer.** `dotfiles/scripts/install.sh` has the symlink-with-backup
  model this should grow from. Whether geistos owns the config paths or defers
  to that installer is undecided — doing both would fight.
- **The bridge scripts.** The Quickshell services shell out to
  `~/dotfiles/scripts/geist-*`, which are the seam between the shell and the
  suite CLIs. They resolve binaries through `MG_*_BIN` environment variables
  with development-build defaults. A distribution has to ship them and point
  those defaults at installed paths.
- **A license.** Four of the six suite repositories declare none, which blocks
  distribution outright. See `mg-suite/docs/GEISTOS-PACKAGING.md`.

`mg-suite/docs/GEISTOS-PACKAGING.md` carries the full packaging notes: build
requirements, the constraints a packager hits, and the open questions.
