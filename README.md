# geistos

A local-first Linux workstation: the Geist application suite plus the Hyprland
and Quickshell configuration that surfaces it on the desktop.

This repository is early. Today it holds the desktop configuration, the user
units, and `bin/geist-install` — which builds the suite from this machine's
checkouts and installs it for this user. Distribution packaging is deliberately
gated: see `docs/PACKAGING-GATE.md`.

## Layout

```text
geistos/
  bin/geist-install   Builds the suite from the checkouts and installs it for this user
  config/hypr/        Hyprland: keybindings, autostart, look and feel, lock, idle
  config/quickshell/  The shell: bar, launcher, panels, services, 38 themes
  systemd/            User units for the suite's daemons
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

## Storage

Every authoritative application keeps its data in one SQLite file of its own,
under `$XDG_DATA_HOME`, in WAL with foreign keys on. There is no server to
install, provision or supervise, and no cluster to resolve:

```sh
mg-calr database migrate     # create or update the calendar store
mg-remindr migration apply   # the same for reminders
```

Each application takes an explicit path when you want one — `--db`, or
`MG_CALR_DB`, `MG_REMINDR_DB`, `MG_PLANR_DB` — and otherwise uses its default
file. A store is created when a command asks for one, never by opening.

## Installing

```sh
bin/geist-install              # prints what it would do, changes nothing
bin/geist-install --apply      # builds release binaries into ~/.local/bin, writes the units
bin/geist-install --check      # says whether what is installed still matches the checkouts
```

It deliberately leaves three things to you: the desktop configuration
(`~/dotfiles/scripts/install.sh --apply`), enabling the units, and creating each
application's store. `--only mg-calr,mg-feedr` limits a run; `GEIST_PREFIX` installs
somewhere else entirely, taking its units and manifest with it.

## Requirements

Hyprland, Quickshell, ghostty, python3, and a Nerd Font for the glyphs. The
suite adds a Rust toolchain at 1.85 or newer; SQLite comes with `rusqlite`, so
there is nothing else to install. See Storage above.

## Configuration notes

The configuration here is sanitized for distribution and differs from a working
checkout in two places:

- `config/hypr/hyprlock.conf` uses placeholder paths for the lock background and
  the avatar image. Set your own or delete the avatar block.
- `config/hypr/hyprpaper.conf` points at `~/pictures/wallpaper/default.jpg`. The
  shell's wallpaper service scans `~/pictures/wallpaper` and drives hyprpaper
  over IPC at runtime, so this file mostly matters at first launch.

Everything else resolves through `$HOME` and needs no editing.

## Where this stands

[docs/HANDOFF.md](docs/HANDOFF.md) records what has been built, the bugs found
along the way, and what to pick up next. [docs/KEYBINDINGS.md](docs/KEYBINDINGS.md)
records the global window, panel, session, and lifecycle controls.

## Not here yet

- **An installer.** `dotfiles/scripts/install.sh` has the symlink-with-backup
  model this should grow from. Whether geistos owns the config paths or defers
  to that installer is undecided — doing both would fight.
- **The bridge scripts.** The Quickshell services shell out to
  `~/dotfiles/scripts/geist-*`, which are the seam between the shell and the
  suite CLIs. They resolve binaries through `MG_*_BIN` environment variables
  with development-build defaults. A distribution has to ship them and point
  those defaults at installed paths.

`mg-suite/docs/GEISTOS-PACKAGING.md` carries the full packaging notes: build
requirements, the constraints a packager hits, and the open questions.

## License

MIT. See `LICENSE`.
