---
title: GeistOS Operations Manual
subtitle: The Geist suite and desktop, made simple
author: machinageist
date: October 2026
lang: en-US
rights: MIT License
description: >
  A plain-language operations manual for GeistOS: the Hyprland and Quickshell
  desktop and the Geist application suite. Setup, everyday tasks, app
  reference, data, services and troubleshooting.
subject: Linux desktop, local-first software
---

# Before you start

This manual explains how to run and use GeistOS day to day. You don't need to
read the source code. If you can open a terminal and type a command, you have
everything you need.

## How the manual is organised

| Part | Chapters | Read it when |
|---|---|---|
| Getting going | 1–2 | You are new, or setting up a machine |
| Using it | 3–4 | You want to get something done |
| Reference | 5–10, appendices | You need the details of one app or one problem |

If you only read one chapter, read **Chapter 1**. It explains the one idea
behind the whole suite, and the rest of the manual follows from it.

## Conventions

- **SUPER** is the Windows/logo key. `SUPER + CTRL + K` means hold SUPER and
  CTRL, then press K.
- Text `like this` is something you type in a terminal. Open one with
  `SUPER + RETURN`.
- A **panel** or **card** is a small window the desktop opens over everything
  else. Press `Escape` to close one.
- `~` means your home folder. `~/.local/share` is where the apps keep their
  data unless you say otherwise.
- **Good to know** boxes call out the things that most often surprise people.
- Where a feature isn't built yet, the manual says so.

::: tip
**Good to know.** Every command in the suite answers `--help`. When this
manual and `--help` disagree, trust `--help`. It comes from the program
itself.
:::

# 1. GeistOS in five minutes

## What GeistOS is

GeistOS is a Linux workstation made of two layers.

1. **The desktop.** Hyprland arranges your windows. Quickshell draws everything
   else: the bar along the top, the launcher, the panels, notifications and
   themes. The whole shell is one program, `qs -c mgeist`.
2. **The Geist suite.** About a dozen small applications, each doing one job:
   reminders, calendar, news, music, books, notes and so on. Every one of them
   is a command-line program first. The desktop gives them buttons.

![How the pieces fit together](images/architecture.png)

## The one rule that explains everything

> **Each app owns its own data, and nothing else touches it.**

Each app keeps its data in one file of its own (a SQLite database) inside your
data folder. No app opens another app's file. The desktop doesn't store your
data either. When you click a button, the shell runs the app's command and shows
you the answer.

When two apps need to share, one **exports** a snapshot and the other
**imports** it through a checked handoff. Neither one reaches into the other's
file.

What this means for you:

- **There is nothing to install or babysit.** There's no database server. Each
  file is created the first time it's needed.
- **One broken app doesn't break the others.** If the calendar is unhappy,
  your reminders still work.
- **The app is always right.** If a panel and a command ever disagree, the
  command is the truth, because the app is the *authority* for its data.
- **Some views are copies you refresh.** The reminders shown on your calendar
  are a copy (a *projection*) of what the reminders app holds. Chapter 6
  explains when it refreshes by itself and when you refresh it.

## The apps at a glance

| I want to… | App | You type |
|---|---|---|
| Keep todos and reminders | mg-remindr | `mg-remindr` |
| Keep a calendar | mg-calr | `mg-calr` |
| Plan work and prove it's done | mg-planr | `mg-plan` |
| Collect feeds, CVEs and asset records | mg-briefr | `mg-brief` |
| See live headlines on the bar | mg-feedr | `mg-feedr` |
| Play music and podcasts | mg-streamr | `mg-streamr` |
| Read ebooks, comics, audiobooks | mg-bookr | `mg-bookr` |
| Keep notes as Markdown files | mg-vaultr | `mg-vault` |
| Keep private, encrypted contacts | mg-contactr | `mg-contacts` |
| See and control running programs | mg-taskr | `mg-taskr` |
| Calculate and draw graphs | mg-calcr | `mg-calcr` |

Two more folders hold experiments, not tools for daily use: **mg-shellr** (a
minimal command shell) and **mg-terrm** (a GPU terminal prototype).

::: tip
**Good to know: folder names and command names differ.** Each app's folder
ends in an `r`, but four of the commands drop it. You type the command, not
the folder:

| Folder | Command |
|---|---|
| mg-briefr | `mg-brief` |
| mg-planr | `mg-plan` |
| mg-vaultr | `mg-vault` |
| mg-contactr | `mg-contacts` |
:::

## Three ways to reach every app

1. **The bar and panels.** Click a pill on the bar, or press a shortcut, to open
   that app's card. Best for quick, everyday actions.
2. **The launcher.** Press `SUPER + SPACE` and type a few letters: an app name,
   a sum, or an action such as "Reminders" or "Task manager".
3. **The terminal.** Every app's full set of features is here. The panels show
   only the common ones.

## Every command speaks two languages

By default a command prints text for people. Add `--json` and most commands
print structured output for scripts instead. Failures exit with a non-zero
status, and the JSON form says what went wrong, for example
`{"ok":false,"error":"…"}`.

# 2. Setting up

This chapter takes a fresh machine to a working suite. Each step says what it
does and how to check it worked. The installers start in **dry-run** mode:
they print what they would do and change nothing until you add `--apply`.

## What you need

**Always:** Hyprland, Quickshell, the ghostty terminal, python3, a Nerd Font
(for the bar's icons), and a Rust toolchain at version 1.85 or newer.

**Only for the features you use:**

| Feature | Needs |
|---|---|
| Music and podcasts | `mpd` |
| Audiobooks, video headlines | `mpv` (add `mpv-mpris` for media keys) |
| Book covers, PDFs, comics, audio | `pdfinfo`, `pdftoppm`, `bsdtar`, `ffprobe`, `ffmpeg` |
| The book reader window | python3 with PySide6 and QtWebEngine |
| Clipboard history | `wl-clipboard` and `cliphist` |
| Screenshots | `grim` and `slurp` |
| The AI panel | `ollama` running local models |
| Lock, idle, wallpaper, night light | `hyprlock`, `hypridle`, `hyprpaper`, `hyprsunset` |
| Volume, brightness, media keys | `wpctl`, `brightnessctl`, `playerctl` |

## The folder layout

The installer expects this layout. Keep it and nothing needs configuring.

| Folder | Holds |
|---|---|
| `~/geistos/` | The desktop configuration and the installer |
| `~/geistos/mg-suite/` | The suite: one folder per app, such as `mg-calr/` and `mg-remindr/` |
| `~/dotfiles/` | The live desktop configuration and its helper scripts |

## Step 1: Install the desktop configuration

```sh
# dry run: shows what it would link
~/dotfiles/scripts/install.sh

# links the config into ~/.config
~/dotfiles/scripts/install.sh --apply
```

It links Hyprland, Quickshell and the other desktop files into place, and backs
up anything already there first. The suite installer never touches these files.
Only one program writes them, so the two installers never fight.

## Step 2: Build and install the apps

```sh
# dry run
~/geistos/bin/geist-install

# build and install for real
~/geistos/bin/geist-install --apply
```

With `--apply`, the installer:

1. builds every app in release mode;
2. copies the commands into `~/.local/bin`;
3. writes the background-service files into `~/.config/systemd/user`;
4. records which commit each app came from in
   `~/.local/state/geist/install-manifest.json`.

| Option | What it does |
|---|---|
| `--apply` | Install. Without it, nothing changes |
| `--only mg-calr,mg-feedr` | Install just these app folders |
| `--skip-build` | Install what is already built |
| `--check` | Say whether what's installed still matches the source |

Make sure `~/.local/bin` is on your `PATH`:

```sh
echo "$PATH" | tr ':' '\n' | grep -x "$HOME/.local/bin"
```

If that prints nothing, add `export PATH="$HOME/.local/bin:$PATH"` to your
shell's startup file.

::: tip
**Good to know: the desktop uses development builds.** The bar and panels
don't run the commands in `~/.local/bin`. They run each app's development
build, in `~/geistos/mg-suite/<folder>/target/debug/`. So for the panels to
work, build the apps you use:

```sh
for d in ~/geistos/mg-suite/mg-*/; do (cd "$d" && cargo build --quiet); done
```

After you change an app's code, the panels run whatever you last built.
Appendix B lists the settings that point the desktop somewhere else.
:::

## Step 3: Create the stores

Two apps want you to create their data file explicitly:

```sh
# the calendar
mg-calr database migrate

# reminders
mg-remindr migration apply
```

The others create their file the first time you use them. Then make your
first calendar:

```sh
mg-calr calendar create --name Personal
```

## Step 4: Turn on the background services

Three small background jobs keep the live parts of the desktop running:

```sh
systemctl --user daemon-reload
systemctl --user enable --now mg-feedr mg-streamr mg-streamr-refresh.timer
```

| Service | What it does |
|---|---|
| `mg-feedr` | Fetches headlines and feeds the ticker on the bar |
| `mg-streamr` | Remembers where you stopped in each podcast episode |
| `mg-streamr-refresh.timer` | Checks your podcasts for new episodes every six hours |

The shell has its own service, `quickshell-mgeist.service`. Hyprland starts it
when you log in.

## Step 5: Optional extras

Do these when you want the feature. Nothing else depends on them.

| Want | Do |
|---|---|
| Notes, book highlights, saving stickies | `mg-vault vault register notes ~/notes` then `mg-vault vault select notes` (the folder must exist) |
| Contacts | `mg-contacts setup`, then choose a passphrase |
| Headlines | `mg-feedr add <name> <feed-url> --every 300` |
| Podcasts | `mg-streamr podcast add <name> <feed-url>` |
| Books | Put files in `~/books` and `~/audiobooks`, then `mg-bookr scan` |
| Camera switch, wake alarms, cleanups, system services | Install the root helper. Read Chapter 8 first |

## Check that it all works

```sh
# every app says "current"
~/geistos/bin/geist-install --check
systemctl --user --no-pager status mg-feedr mg-streamr
python3 ~/dotfiles/scripts/geist-status.py

# reminders → calendar, end to end
~/geistos/tests/suite-pipe.sh
```

`suite-pipe.sh` runs the one live cross-app path (reminders feeding the
calendar) in a throwaway folder. It never touches your real data.

# 3. Getting around the desktop

## The bar

The bar runs along the top of every screen. It has three groups. Most pills
show more when you **hover**, do the main thing when you **click**, and often
do a second thing on **right-click**.

![The bar's three groups](images/bar.png)

### Left: your work

| Pill | Shows | Click | Right-click |
|---|---|---|---|
| OS logo | | Launcher | Theme and wallpaper |
| Workspaces | Your workspaces | Switch to one | |
| Geist | The suite | Geist panel | Vault |
| Reminders | What's due today | Reminders card | |
| Calendar | Today's schedule | Calendar card | |
| AI | The local assistant | AI panel | AI usage page |
| App tools | Actions for the focused app | Tools menu | |
| Active window | The focused window's title | Window actions | |

### Centre: time

| Pill | Click | Other |
|---|---|---|
| Stopwatch | Start / pause | Right-click resets |
| Clock | Cycle time, date, ISO date | Hover for a calendar |
| Pomodoro | Start / pause | Right-click resets, middle-click skips |
| Headline ticker | Feeds panel | Hover for the headline. Right-click toggles the crawl strip |
| Weather | Forecast card | |

### Right: the machine

| Pill | Click | Other |
|---|---|---|
| Power profile | Cycle profiles | |
| Battery | Power page | |
| CPU | Opens `btop` | Hover for a graph |
| Memory | Opens `htop` | Hover for a graph |
| Storage | Storage panel | Hover lists every disk |
| Keep-awake (mug) | Block or allow sleep | |
| Appearance | Theme, brightness, night light | |
| Volume | Pin the volume card | Right-click mutes, scroll changes volume |
| Bluetooth | Bluetooth page | |
| Network | Network page | Hover for traffic |
| Health | Maintenance page | Updates, failed services, disk |
| Privacy | Camera page | Lights when the camera or mic is in use |
| Bell | Notifications | |
| System | Quick settings | Right-click: operations overview |

::: tip
**Good to know.** You can choose which pills appear and in what order. Open
Quick settings (`SUPER + CTRL + W`), then Desktop controls, then the bar
layout editor. You can also switch to a compact floating "capsule" bar or turn
on auto-hide there.
:::

## The launcher

Press `SUPER + SPACE` and start typing. Use the arrow keys to move, `Enter` to
choose and `Escape` to close. The launcher finds:

- **Applications**, by name.
- **Desktop actions**, such as Reminders, Calendar, Headlines, Books, Task
  manager, New sticky note, Pomodoro, Focus mode and System logs.
- **Sums.** Type `2 + 3 * 4` or `sin(90)`. Enter copies the answer.
- **Unit conversions.** Type `10 km to mi`, `72 f in c` or `3 lb to kg`. It
  handles length, mass and temperature.
- **Words.** Type `define serendipity` or `synonyms happy`. This one needs the
  internet.

## Keyboard shortcuts

Press `SUPER + CTRL + K` at any time to browse every shortcut. That list is
built from the live configuration, so it is always current.

### Windows

| Keys | Action |
|---|---|
| `SUPER + H J K L` or arrows | Focus left, down, up, right |
| `SUPER + SHIFT + H J K L` | Move the window left, down, up, right |
| `SUPER + W` | Close the window |
| `SUPER + F` | Full screen |
| `SUPER + T` | Float / tile |
| `SUPER + P` | Pseudo-tile |
| `SUPER + ALT + J` | Flip the split direction |
| `ALT + TAB`, `ALT + SHIFT + TAB` | Next / previous window |
| `SUPER` + drag with left mouse | Move a window |
| `SUPER` + drag with right mouse | Resize a window |

### Workspaces

| Keys | Action |
|---|---|
| `SUPER + 1` … `SUPER + 0` | Go to workspace 1–10 |
| `SUPER + SHIFT + 1` … `0` | Send the window to workspace 1–10 |
| `SUPER + TAB`, `SUPER + SHIFT + TAB` | Next / previous workspace |
| `SUPER` + mouse wheel | Next / previous workspace |
| `SUPER + ALT + TAB` | Send this workspace to the other monitor |
| `SUPER + S` | Show or hide the scratchpad |
| `SUPER + ALT + S` | Send the window to the scratchpad |

### Applications

| Keys | Action |
|---|---|
| `SUPER + RETURN` | Terminal |
| `SUPER + SHIFT + RETURN` | Floating terminal |
| `SUPER + SPACE` | Launcher |
| `SUPER + SHIFT + F` | Floating file manager (yazi) |
| `CTRL + SHIFT + ESCAPE` | Task manager |
| `SUPER + N` | New sticky note |

### Panels

| Keys | Panel |
|---|---|
| `SUPER + CTRL + W` | Quick settings |
| `SUPER + CTRL + V` | Clipboard history |
| `SUPER + CTRL + N` | Notifications |
| `SUPER + CTRL + T` | System dashboard (operations) |
| `SUPER + CTRL + A` | AI |
| `SUPER + CTRL + K` | Keyboard shortcuts |
| `SUPER + CTRL + SPACE` | Theme and wallpaper |
| `SUPER + CTRL + G` | Pomodoro |
| `SUPER + CTRL + D` | Stopwatch |
| `SUPER + ESCAPE` | Session menu |

### Look and session

| Keys | Action |
|---|---|
| `SUPER + CTRL + R` | Next wallpaper and theme |
| `SUPER + CTRL + ALT + N` | Light / dark mode |
| `SUPER + CTRL + L` | Lock the screen |
| `SUPER + CTRL + B` | Restart the shell |
| `SUPER + CTRL + SHIFT + W` | Restart the wallpaper service |

### Media and capture

| Keys | Action |
|---|---|
| Volume keys, mute keys | Volume and mute. They work while locked |
| Brightness keys | Screen brightness |
| Play, next, previous keys | Control whatever is playing |
| `PRINT` | Screenshot a region to `~/pictures/screenshots` |
| `SUPER + PRINT` | Screenshot the whole screen to a file |
| `SUPER + SHIFT + S` | Screenshot a region to the clipboard |

## The panels

| Panel | Open with | For |
|---|---|---|
| Geist | Geist pill | One page per suite app, with its status, a launch button and "Refresh todo agenda" |
| Reminders | Reminders pill | Keep, finish and edit reminders |
| Calendar | Calendar pill | Day, week and month views, and quick scheduling |
| Feeds | Ticker pill | Recent headlines |
| Media | Launcher: "Music & podcasts" | Now playing, queue, library, podcasts |
| Books | Launcher: "Books" | Your library and "Continue reading" |
| Vault | Launcher: "Vault" | Search and read notes |
| Brief | Launcher: "Brief" | Sources and fetched items |
| Contacts | Launcher: "Contacts" | Your encrypted contacts |
| Task manager | `CTRL + SHIFT + ESCAPE` | Processes, apps, performance, services, startup |
| Operations | `SUPER + CTRL + T` | System dashboard: power, maintenance, security, AI usage |
| Storage | Storage pill | Disk use and safe cleanups |
| Quick settings | `SUPER + CTRL + W` | Network, Bluetooth, camera, desktop controls |
| Theme and wallpaper | `SUPER + CTRL + SPACE` | Choose a look |
| AI | `SUPER + CTRL + A` | Ask a local model a question |
| Clipboard | `SUPER + CTRL + V` | Paste something you copied earlier |
| Notifications | `SUPER + CTRL + N` | History and do-not-disturb |
| Session | `SUPER + ESCAPE` | Lock, suspend, log out, reboot, power off |

## Themes and wallpaper

There are 38 colour palettes, many with a light and a dark version, plus an
**auto** theme that takes its colours from your wallpaper. When the theme
changes, the shell also recolours the terminal, `btop`, Neovim, window borders,
the shell prompt and Qt apps.

- `SUPER + CTRL + SPACE` opens the picker. Browsing only previews. `Enter`
  applies and `Escape` puts things back as they were.
- `SUPER + CTRL + R` moves to the next wallpaper, paired with a matching
  theme.
- `SUPER + CTRL + ALT + N` flips between light and dark.
- Wallpapers live in `~/pictures/wallpaper`.

## Notifications

- The bell shows how many you have. Click it, or press `SUPER + CTRL + N`, for
  the history.
- **Do not disturb**, **focus mode** and **quiet hours** hold popups and their
  sounds back.
- Each app's notification sound is set in
  `~/.config/quickshell/mgeist/sounds.json`. Edits take effect immediately,
  with no restart.

## Sticky notes

Press `SUPER + N` for a sticky note under the mouse pointer. Notes stay put
across restarts.

- The **book icon** saves the note into your vault as
  `Stickies/<date>-<first words>-<id>.md`. Saving again updates the same note.
- The **disk icon**, or `CTRL + SHIFT + S`, saves it as a plain file anywhere.
- `SUPER + W` on a note deletes it. The × button asks first if the note has
  text.
- Notes untouched for seven days are swept away.

## Locking and the session menu

`SUPER + ESCAPE` opens the session menu. **Lock** and **suspend** happen at
once. **Log out**, **reboot** and **power off** need a second press, so one
stray click can't end your session. `SUPER + CTRL + L` locks straight away.

# 4. Everyday tasks

Short recipes for the things you'll do most. Each one shows the quick way
first, then the terminal way.

## Keep a reminder and see it on your calendar

**Quick way.** Click the **Reminders** pill. Type the reminder in the box
("Keep a reminder, then Enter"), choose **Today**, **Tomorrow** or **Someday**,
and press `Enter`. It appears on your calendar's agenda by itself.

**Terminal way:**

```sh
mg-remindr add "Pay rent" --due today
mg-remindr add "Dentist" --due 2026-11-08T14:00

# open reminders, each with a short handle
mg-remindr ls

# finish it, by its handle
mg-remindr done 3f2a
```

::: tip
**Good to know.** A reminder added in the **terminal** reaches the calendar
only when you refresh it. Click **Refresh todo agenda** in the Geist panel, or
run `~/dotfiles/scripts/geist-sync-todo-projection`. Reminders added in the
**panel** refresh it for you. Only reminders with a due date appear on the
calendar.
:::

## Put an event on the calendar

**Quick way.** Click the **Calendar** pill. Type the event ("Schedule an event,
then Enter"), choose **All day**, **09:00**, **13:00** or **17:00**, and press
`Enter`. Switch between the **Day**, **Week** and **Month** views.

**Terminal way:**

```sh
# find your calendar's ID
mg-calr calendar list
mg-calr event create --calendar <ID> --title "Review" \
  --start 2026-11-03T10:00:00-08:00 --end 2026-11-03T11:00:00-08:00 \
  --timezone America/Los_Angeles
mg-calr agenda --start 2026-11-03 --end 2026-11-04 --timezone America/Los_Angeles
```

To repeat an event, add `--repeat daily|weekly|monthly`. You can also add
`--by-weekday mon,wed,fri`, `--count 10` or `--until 2026-12-31`. To bring in
events from another calendar program, use
`mg-calr event import-ics --calendar <ID> --file <file.ics>`.

## Follow the headlines

1. Add a source to the ticker:
   `mg-feedr add wire https://example.com/feed.xml --every 300` (seconds
   between checks).
2. Make sure the service is running: `systemctl --user status mg-feedr`.
3. Hover the **ticker** pill (just left of the weather) to read the newest
   headline. Click it for the Feeds panel. Right-click it for a scrolling
   crawl strip.

`mg-feedr open <id>` opens an article in your browser. A video link plays in
`mpv`. `mg-feedr tui` shows the ticker in a terminal.

## Play music and podcasts

Music comes from `~/music` through `mpd`.

```sh
mg-streamr library search "miles davis"
mg-streamr queue add <uri>
mg-streamr play

# Now Playing, Queue, Library, Podcasts
mg-streamr tui
```

Podcasts:

```sh
mg-streamr podcast add mypod https://example.com/podcast.xml

# newest episodes across all your shows
mg-streamr podcast latest

# resumes where you stopped
mg-streamr podcast play <id>

# keep it offline in ~/music/podcasts/
mg-streamr podcast download <id>
```

From the desktop, open **Music & podcasts** in the launcher. The volume card
also shows the cover and has an **Open player** button.

## Read a book or listen to an audiobook

Put EPUB, PDF and comic files in `~/books` and audiobooks in `~/audiobooks`.

```sh
# find what's there
mg-bookr scan

# what you were in the middle of
mg-bookr continue

# open the reader window
mg-bookr open <id>

# start an audiobook
mg-bookr listen play <id>

# stop in 30 minutes (or: chapter)
mg-bookr listen sleep 30
```

**In the reader:** `←` and `→` turn pages, `t` switches between pages and
scrolling, `+` and `-` change the text size, `n` and `p` jump a chapter, `h`
keeps the selected text as a highlight, and `q` closes.

Highlights are also written into your vault as one note per book, under
`Books/`. That needs a registered vault (Chapter 2, Step 5).

## Take notes

Notes are ordinary Markdown files in a folder you choose.

```sh
mg-vault note create ideas/first.md --body '# First idea'
mg-vault index rebuild
mg-vault search "first"
```

The Vault panel searches and reads notes. Open it from the launcher
("Vault"), or right-click the Geist pill and choose **Search & read notes**. For
quick thoughts, use a sticky note (`SUPER + N`) and save it into the vault with
its book icon.

## Find what's slowing the machine

Press `CTRL + SHIFT + ESCAPE` for the task manager, or run `mg-taskr tui`.

- **Processes** lists everything. Sort with `s`, show the tree with `t`, and
  filter with `/`.
- **Apps** groups processes by application.
- **Performance** graphs CPU, memory, network and disks for the last two
  minutes.
- `e` ends a process, `K` kills it, `p` pauses it and `c` continues it. Each
  asks y/n first. `+` makes a process gentler.

For a one-off check: `mg-taskr processes --sort cpu --limit 10`.

## Calculate, convert, look up a word

In the launcher (`SUPER + SPACE`):

- `17 * 23` shows `391`. `Enter` copies it.
- `5 mi to km` converts miles to kilometres. `Enter` copies the result.
- `define laconic` or `synonyms quick` (needs the internet).

For a bigger calculator with scientific and graph modes, choose **Calculator**
in the launcher. Graph mode draws expressions like `y = x^2`.

## Stay focused

- **Pomodoro:** `SUPER + CTRL + G`, or click the pill. Right-click resets and
  middle-click skips a phase.
- **Stopwatch:** `SUPER + CTRL + D`, or click the pill.
- **Focus mode:** in the launcher, choose "Focus mode". Notification popups
  and sounds are held back until you turn it off.
- **Keep awake:** click the mug pill so the screen doesn't sleep.

# 5. The apps, one by one

Each app gets the same short layout: what it's for, where its data lives, the
commands you'll actually use, and what to know.

## mg-remindr: reminders and todos

**For:** the things you need to do, with optional due dates.\
**Data:** `~/.local/share/mg-remindr/remindr.sqlite`\
**Desktop:** the Reminders pill and card.

| Command | Does |
|---|---|
| `add "<title>" [--due …]` | Keep a reminder |
| `ls [--all]` | List open reminders (`--all` adds finished and trashed) |
| `edit <handle> --title … / --due … / --clear-due` | Change one |
| `done <handle>` | Finish it |
| `rm <handle>` | Move it to the trash |
| `restore <handle>` | Bring a finished or trashed one back |
| `interop export` | Export a snapshot (used by the calendar) |

- `--due` takes `today`, `tomorrow`, `YYYY-MM-DD` or `YYYY-MM-DDTHH:MM`.
  Times are in your system time zone unless you add `--timezone`.
- The **handle** is the end of the reminder's ID. Any unambiguous part of the
  ID works.
- A time that doesn't exist, or happens twice, at a daylight-saving change is
  refused, not guessed.

## mg-calr: the calendar

**For:** calendars and events, and a combined agenda that also shows
reminders that have due dates.\
**Data:** `~/.local/share/mg-calr/calr.sqlite`, plus the reminders copy
`todo-projection.json` beside it.\
**Desktop:** the Calendar pill and card.

| Command | Does |
|---|---|
| `database migrate` | Create or update the store |
| `calendar create --name …` / `calendar list` | Make or list calendars |
| `event create …` | Add an event (timed, all-day or repeating) |
| `event list [--calendar ID]` / `event show <ID>` | Look at events |
| `event day-agenda --date … --timezone …` | One day's events |
| `event edit`, `event cancel`, `event restore` | Change an event (each needs its current `--version`) |
| `agenda --start … --end … --timezone …` | Events plus due reminders |
| `event import-ics` | Import from an `.ics` file |
| `event export` / `event import` | Back up or move everything as JSON |
| `tui` | A simple line-by-line agenda: type `j` or `k` to move, `r` to refresh, `q` to quit, each followed by `Enter` |
| `doctor` | Check configuration without changing anything |

- Timed events take full timestamps with an offset, such as
  `2026-11-03T10:00:00-08:00`, plus an IANA time zone such as
  `America/Los_Angeles`.
- Repeats are stored once and worked out when you look, not saved day by day.
- **Not yet:** editing one occurrence of a repeating event, exceptions,
  syncing with iCloud or other services, and backup/restore.

## mg-plan: plans that prove they're done

**For:** turning a goal into work items, each with *acceptance criteria*. A
work item counts as complete only when every criterion has a passing,
recorded check.\
**Data:** `~/.local/share/mg-planr/<store>.sqlite`. You name the store.\
**Desktop:** the Plan / Todo page of the Geist panel (information only).

Every command starts with a store name and a plan ID:

```sh
mg-plan create personal home "Home projects"
mg-plan add-work personal home paint "Paint the hall"
mg-plan add-criterion personal home paint c1 "Two coats, no streaks"
mg-plan start personal home paint
mg-plan list-work personal home

# what still lacks proof
mg-plan verification-gaps personal home
```

| Command | Does |
|---|---|
| `add-dependency` | One item must wait for another |
| `block`, `unblock`, `revise` | Change an item's state or title |
| `verify …` | Record a check against a criterion: pass, fail, inconclusive or waived |
| `complete` | Finish an item. Refused until every criterion passes |
| `add-project`, `add-milestone`, `link-work`, `milestones` | Group work |
| `decide` | Record a decision and why you made it |
| `schedule-request`, `schedule-receipt`, `schedules` | Ask for calendar time and record the answer |
| `export` / `import` | Move a plan as JSON |

::: tip
**Good to know.** If two people (or two windows) change the same plan, the
second save is refused rather than overwriting the first. Reload and try again.
:::

## mg-brief: sources, CVEs and assets

**For:** collecting feeds and the security records you want to keep, with a
record of where each one came from. It explains; it never fixes anything for
you.\
**Data:** `~/.local/share/mg-brief/catalog.sqlite`, plus downloaded files in
`~/.config/mg-brief/artifacts`.\
**Desktop:** the Brief panel and the Geist panel's Brief page.

| Command | Does |
|---|---|
| `register <name> <url> [--ticker --every N]` | Add a source |
| `sources` | List sources |
| `fetch <name>` | Download now. Network use only ever happens here |
| `items [--ticker] [--limit N] [--since ID]` | Stored headlines |
| `ticker <name> on/off` | Show or hide a source on the bar's ticker |
| `cve import-cve5`, `cve current`, `cve history` | CVE records and their history |
| `asset import`, `asset list`, `asset inspect` | Asset observations |
| `export --json` | A snapshot of the catalog |
| `status` | Read-only counts. Never creates anything |
| `integrity --acknowledge-offline` | Check the database on a private copy |

- Fetches are bounded by size, time and redirects. Private and local network
  addresses are refused.
- `integrity` and `recover` want every writer stopped first, including
  `mg-feedr`. Stop it with `systemctl --user stop mg-feedr`.

## mg-feedr: the live ticker

**For:** pushing new headlines to the bar as they arrive. It has no data file
of its own; it uses mg-brief's catalog.\
**Service:** `mg-feedr.service`.\
**Desktop:** the ticker pill, the Feeds panel, the crawl strip.

| Command | Does |
|---|---|
| `add <name> <url> [--every N]` | Register a source in mg-brief and follow it |
| `follow <name>`, `unfollow <name>` | Put an existing source on or off the ticker |
| `sources`, `health` | What's followed, and how each source's last fetch went |
| `items [--limit N]` | Recent headlines, no service needed |
| `open <id>` | Article in the browser, video in `mpv` |
| `stream`, `tui` | Watch live in a terminal |
| `run` | The service itself |

`health` shows `never` for a source that has never been fetched. It reports
what happened; it doesn't fetch.

## mg-streamr: music and podcasts

**For:** controlling `mpd` and keeping podcasts, including where you stopped in
each episode.\
**Data:** `~/.local/share/mg-streamr/streamr.sqlite`. Music stays in
`~/music`.\
**Services:** `mg-streamr.service` (positions) and `mg-streamr-refresh.timer`
(new episodes).\
**Desktop:** the Media panel and the volume card.

| Command | Does |
|---|---|
| `status`, `watch` | What's playing |
| `play`, `pause`, `toggle`, `stop`, `next`, `prev` | Transport |
| `seek 90 / +30 / -10`, `volume 60 / +5 / -5` | Position and volume |
| `queue list / add <uri> / clear / remove <pos>` | mpd's queue |
| `library browse / search / update` | Your music |
| `podcast add / list / latest / refresh / episodes` | Shows and episodes |
| `podcast enqueue / play / download / remove-download / forget` | One episode or show |
| `tui` | Now Playing, Queue, Library, Podcasts. In Podcasts, `l` shows the latest and `a` queues |

- An episode resumes where you left it, unless you were in the first 10
  seconds or the last minute.
- `mpd` is found at `$MPD_HOST`, then `$XDG_RUNTIME_DIR/mpd/socket`, then
  `127.0.0.1:6600`.

## mg-bookr: ebooks, comics and audiobooks

**For:** one library for what you read and what you listen to. Local files
only: no store, no account, no DRM.\
**Data:** `~/.local/share/mg-bookr/bookr.sqlite`. Books stay in `~/books`
and `~/audiobooks`.\
**Desktop:** the Books panel, and Books, Continue reading and Books TUI in the
launcher.

| Command | Does |
|---|---|
| `scan` | Look through both folders |
| `list`, `search <text>`, `continue` | Find books |
| `show <id>` | Chapters, tracks, highlights |
| `open <id>` | Reader window |
| `mode <id> pages/scroll` | How this book is read |
| `highlight add / list / note / remove` | Highlights |
| `collection list / show / add / remove` | Collections |
| `export <id>` | Rewrite the book's vault note |
| `listen play / pause / resume / toggle / stop` | Audiobooks |
| `listen seek`, `speed 0.75..3`, `chapter next/prev`, `sleep 30/chapter/off` | Audiobook control |
| `tui` | Continue, Library, Listening. In Library, `/` filters and `o` sorts |

- A book that disappears (moved, or on an unplugged drive) is marked
  **missing**, never deleted. Its progress and highlights come back on the
  next scan.
- Starting an audiobook pauses your music.
- Resuming after five minutes away backs up 10 seconds so you don't lose your
  place.
- The book's vault note is rebuilt from mg-bookr each time, so edits made to
  it in the vault are replaced.

## mg-vault: notes

**For:** knowledge kept as ordinary Markdown files in a folder you own. The
files are the truth. The search index is a disposable copy you can rebuild at
any time.\
**Data:** your vault folder. The list of vaults is in
`~/.config/mg-vault/vaults.json`. Each vault's index is in its own
`.mg-vault/` folder.\
**Desktop:** the Vault panel.

| Command | Does |
|---|---|
| `vault register <name> <folder>`, `vault list`, `vault select <name>` | Manage vaults |
| `note create <path> --body …`, `note read <path>` | Write and read notes |
| `note write`, `note trash`, `note restore` | Change, trash, undo |
| `index rebuild`, `index status` | Rebuild or check the search index |
| `search <text>` | Search |

- Add `--vault <name>` to use a vault other than the selected one.
- `index status` tells the truth: `current`, `stale`, `empty` or `degraded`.
- It refuses to touch `.obsidian` and `.mg-vault`, or anything outside the
  vault folder.

## mg-contacts: private contacts

**For:** contacts that are encrypted on disk, with full history.\
**Data:** `~/.local/share/mg-contacts/contacts.sqlite`, readable only by you.\
**Desktop:** the Contacts panel.

```sh
# once: choose a passphrase
mg-contacts setup

# then type name, email, phone on three lines
mg-contacts create person-1
mg-contacts list
mg-contacts read person-1
mg-contacts update person-1

# hidden from lists; history is kept, encrypted
mg-contacts delete person-1
```

- Every command asks for your passphrase. It never goes on the command line or
  in an environment variable.
- Each field is encrypted before it reaches the database, so there's no
  plain-text search.

::: tip
**Good to know.** There is no passphrase recovery. If you forget it, the
contacts can't be read. Keep it somewhere safe.
:::

## mg-taskr: the task manager

**For:** what the machine is running, what it costs, and control over it. It
keeps no data and runs no service.\
**Desktop:** the Task manager panel (`CTRL + SHIFT + ESCAPE`).

| Command | Does |
|---|---|
| `processes [--sort cpu/mem/io/gpu/name/pid] [--tree]` | Processes |
| `apps` | Processes grouped by application |
| `system` | CPU per core, memory, swap, network, disks, load |
| `services [--user/--system]` | systemd services |
| `startup` | What starts at login |
| `signal <pid> term/kill/stop/cont` | Stop, kill, pause or continue a process |
| `renice <pid> <niceness>` | Make one of your processes gentler (never faster) |
| `service user start/stop/restart <unit>` | Control a service |
| `startup enable/disable <id>` | Turn a login item on or off |
| `tui` | Tabs 1–5: Processes, Apps, Performance, Services, Startup |

- CPU % counts the whole machine as 100%.
- Your own processes and services are acted on directly. Anything owned by
  root or another user needs the root helper *and* an entry in
  `/etc/geist/taskr.conf` (Chapter 8).

## mg-calcr: the calculator engine

**For:** safe sums and graph points. It's the engine behind the launcher's
calculator and the Calculator panel.

```sh
mg-calcr evaluate '2 + 3 * 4'
mg-calcr evaluate --angle degrees 'sin(90)'
mg-calcr sample 'y = x^2' --minimum -10 --maximum 10 --points 240 --json
```

It handles precedence, brackets, constants, functions and factorials, in
radians or degrees. It refuses division by zero and results that aren't
finite numbers.

## The experiments

**mg-shellr** is a tiny command shell (`rust-shell>`) and **mg-terrm** is a
GPU-drawn terminal. Both are learning projects. The installer builds them, but
nothing in the desktop uses them.

# 6. How the apps work together

## The rules in plain words

1. **Every piece of data has exactly one owner.** Your reminders belong to
   mg-remindr, your events to mg-calr, your notes to the Markdown files.
2. **Copies are labelled as copies.** A copy can be out of date. When it is,
   the app says so instead of pretending.
3. **Apps hand things over through files they check.** One exports, the other
   validates the whole thing before accepting it.
4. **The AI suggests; you decide.** Nothing the AI panel says is saved into an
   app unless you take that step yourself.
5. **Nothing fixes itself behind your back.** No app remediates, deletes or
   syncs anything on its own.

## Reminders on the calendar

This is the main path between apps that works today.

![How reminders reach the calendar](images/agenda-flow.png)

1. mg-remindr exports a snapshot of your reminders.
2. The snapshot goes into a private temporary folder.
3. mg-calr checks the whole snapshot (identity, versions, freshness), then
   swaps it in safely, all or nothing.
4. The calendar's agenda reads reminders only from that checked copy.

If the copy is missing, stale or broken, the calendar tells you which. It
doesn't guess.

## The other connections

| From | To | What travels |
|---|---|---|
| mg-brief | mg-feedr | Ticker sources and the safe way to fetch them |
| mg-brief | mg-streamr | The same safe fetching, for podcast feeds and downloads |
| mg-bookr | mg-vault | One highlights note per book |
| Sticky notes | mg-vault | A note, when you press the book icon |
| mg-plan | mg-calr | A request for time, and the calendar's receipt |
| mg-bookr | mg-streamr | Starting an audiobook pauses your music |

# 7. Your data

## Where everything lives

All paths are the defaults. `~/.local/share` is `$XDG_DATA_HOME` if you've
set it.

| App | Data | Change it with |
|---|---|---|
| mg-remindr | `~/.local/share/mg-remindr/remindr.sqlite` | `--db`, `MG_REMINDR_DB` |
| mg-calr | `~/.local/share/mg-calr/calr.sqlite` | `--db`, `MG_CALR_DB` |
| mg-calr (reminders copy) | `~/.local/share/mg-calr/todo-projection.json` | `--todo-projection` |
| mg-plan | `~/.local/share/mg-planr/<store>.sqlite` | the store name, `MG_PLANR_DB` |
| mg-brief | `~/.local/share/mg-brief/catalog.sqlite` | `--db`, `MG_BRIEF_DB` |
| mg-brief (downloads) | `~/.config/mg-brief/artifacts` | `--artifact-root`, `MG_BRIEF_ARTIFACT_ROOT` |
| mg-streamr | `~/.local/share/mg-streamr/streamr.sqlite` | `MG_STREAMR_DB` |
| mg-bookr | `~/.local/share/mg-bookr/bookr.sqlite` | `MG_BOOKR_DB` |
| mg-contacts | `~/.local/share/mg-contacts/contacts.sqlite` | |
| mg-vault | your vault folder | `vault register` |
| mg-feedr, mg-taskr, mg-calcr | nothing of their own | |

Caches, such as book covers and podcast artwork, live under `~/.cache` and are
safe to delete.

## Privacy

- The data files and their folders are readable by you alone.
- Contacts are encrypted field by field. Your passphrase protects the key.
- Network access happens only where you ask for it: fetching feeds and
  podcasts, weather, and dictionary lookups.
- The AI panel sends questions to Ollama on this machine. A local model keeps
  them on the machine. An Ollama cloud model, if you choose one, sends them
  out.

## Backing up

The simplest backup is each app's own export. These files are plain JSON and
safe to copy anywhere:

```sh
mg-calr event export > calendar-backup.json
mg-remindr interop export > reminders-backup.json
mg-plan export personal home > plan-home.json
mg-brief export --json > brief-backup.json
```

The calendar export goes back in with `mg-calr event import --file …`, and a
plan with `mg-plan import <store> <file>`. The reminders export is a complete
snapshot, but there's no one-step import for it yet.

To copy the database files themselves, first stop anything that writes to
them. Then copy each `.sqlite` file **together with** its `-wal` and `-shm`
files, if they exist. Copying the main file alone can miss recent changes.

Your vault is already plain files, so back up the folder.

::: tip
**Good to know.** Built-in backup and restore is still on the list for the
calendar. Until then, the exports above are the dependable route.
:::

# 8. Background services and root access

## The user services

| Unit | Kind | Start / stop |
|---|---|---|
| `quickshell-mgeist.service` | The desktop shell | Started by Hyprland. `SUPER + CTRL + B` restarts it |
| `mg-feedr.service` | Headline ticker | `systemctl --user enable --now mg-feedr` |
| `mg-streamr.service` | Podcast positions | `systemctl --user enable --now mg-streamr` |
| `mg-streamr-refresh.timer` | New episodes every 6 hours | `systemctl --user enable --now mg-streamr-refresh.timer` |

Useful commands:

```sh
# is it running?
systemctl --user status mg-feedr

# its last 50 log lines
journalctl --user -u mg-feedr -n 50

# how the last podcast check went
journalctl --user -u mg-streamr-refresh -n 50
systemctl --user list-timers mg-streamr-refresh.timer
```

The services restart themselves ten seconds after a crash. The podcast timer
catches up after the machine has been off.

## The root helper

The shell never runs as root. A few features need root, and they go through
one small, checked program: the **geist root helper**. It's optional. Install
it only if you want these features:

| Feature | What the helper does |
|---|---|
| Camera switch in Quick settings | Disconnects or reconnects the cameras listed in `/etc/geist/cameras.conf` |
| Alarm clock waking the machine | Sets the hardware wake timer (up to 8 days ahead) |
| Storage panel cleanups | Removes old package versions (keeps two), trims the system journal to 200 MB |
| Task manager on system services | Starts or stops system units you list in `/etc/geist/taskr.conf` |
| Task manager on root processes | Signals programs you list in `/etc/geist/taskr.conf` |

```sh
# install
sudo ~/dotfiles/system/install-root-helper.sh

# remove it all
sudo ~/dotfiles/system/install-root-helper.sh --remove
```

::: tip
**Good to know.** Once it's installed, any program running as you in your
desktop session can use these actions without a password. The task-manager
list starts empty. Add entries narrowly, and never list an interpreter such as
`python3` or `bash`, because that would cover every script it runs. Re-run the
installer whenever the helper itself changes.
:::

# 9. When something goes wrong

Start with the symptom, run the check, then try the fix.

## Common problems

| Symptom | Check | Fix |
|---|---|---|
| The bar is gone, or there are two | `qs list --all` | `SUPER + CTRL + B` restarts the shell |
| The wallpaper is missing | | `SUPER + CTRL + SHIFT + W` |
| A panel says "build artifact is unavailable" | Does `~/geistos/mg-suite/<folder>/target/debug/<command>` exist? | `cargo build` in that app's folder |
| Reminders don't show on the calendar | Do they have a due date? | Geist panel → **Refresh todo agenda** |
| The calendar says the reminders copy is invalid after an update | | Delete `~/.local/share/mg-calr/todo-projection.json`, then refresh the agenda |
| The ticker is empty | `systemctl --user status mg-feedr`, then `mg-feedr health` | Start the service. Check the source's URL |
| No new podcast episodes | `journalctl --user -u mg-streamr-refresh` | `mg-streamr podcast refresh` to see each show's result |
| Music controls do nothing | Is `mpd` running? | Start `mpd`. Check `$MPD_HOST` |
| The vault panel, book highlights or sticky saving do nothing | `mg-vault vault list` | Register and select a vault |
| The task manager can't stop a process | Is it root's, or another user's? | Install the root helper and list the program in `/etc/geist/taskr.conf` |
| The calendar says the store is missing | `mg-calr doctor` | `mg-calr database migrate` |
| Reminders say the store is missing | `mg-remindr migration status` | `mg-remindr migration apply` |
| Something seems out of date after an update | `~/geistos/bin/geist-install --check` | `~/geistos/bin/geist-install --apply` |

## Where to look

| What | Command |
|---|---|
| The shell's log | `qs log` |
| A service's log | `journalctl --user -u <unit> -n 100` |
| Everything the shell can be asked | `qs -c mgeist ipc show` |
| Suite status in one place | `python3 ~/dotfiles/scripts/geist-status.py` |
| A database health check | `mg-brief integrity --acknowledge-offline` (stop `mg-feedr` first) |

## Restarting the shell safely

`SUPER + CTRL + B` is the safe restart. Avoid `pkill`-ing the shell or
starting a second copy by hand. Programs you opened from the shell can be
closed along with it, so save your work first.

::: tip
**Good to know.** "The app is right" applies when debugging too. If a panel
looks wrong, run the app's command in a terminal. If the command is right,
the problem is in the panel, and your data is fine.
:::

# 10. What isn't built yet

The suite is honest about its edges. These are known gaps, not bugs:

- **Calendar:** editing a single occurrence of a repeating event, exceptions,
  syncing with outside calendars, built-in backup and restore, a full-screen
  terminal interface.
- **Reminders:** repeating reminders and reminder alerts are not part of the
  todo record yet. Over time, planning moves to mg-plan.
- **mg-plan:** no screen of its own yet. It's used from the terminal.
- **Vault:** no file watcher, editor or sync, and search covers basic text and
  links only.
- **Contacts:** no import, and no links to other apps.
- **mg-brief:** no scheduled monitoring or reader view yet.
- **Packaging:** no system package. Everything installs per user with
  `geist-install`.

# Appendix A. Quick reference card

## Ten shortcuts to learn first

| Keys | Does |
|---|---|
| `SUPER + SPACE` | Launcher: apps, actions, sums, conversions |
| `SUPER + RETURN` | Terminal |
| `SUPER + W` | Close the window |
| `SUPER + 1` … `0` | Switch workspace |
| `SUPER + H J K L` | Move focus |
| `SUPER + CTRL + K` | Show every shortcut |
| `SUPER + CTRL + W` | Quick settings |
| `SUPER + N` | Sticky note |
| `CTRL + SHIFT + ESCAPE` | Task manager |
| `SUPER + ESCAPE` | Lock, log out, power off |

## Ten commands to learn first

| Command | Does |
|---|---|
| `mg-remindr add "…" --due today` | Keep a reminder |
| `mg-remindr ls` | See open reminders |
| `mg-calr agenda --start … --end … --timezone …` | See your agenda |
| `mg-feedr items --limit 20` | Latest headlines |
| `mg-streamr tui` | Music and podcasts |
| `mg-bookr continue` | What you're reading |
| `mg-vault search "…"` | Search your notes |
| `mg-taskr tui` | Task manager in the terminal |
| `geist-install --check` | Is everything up to date? |
| `qs -c mgeist ipc show` | What the shell can be asked |

# Appendix B. Settings and environment variables

## Data locations

| Variable | Points at |
|---|---|
| `MG_REMINDR_DB` | The reminders database |
| `MG_CALR_DB` | The calendar database |
| `MG_PLANR_DB` | A plan database (must be inside the `mg-planr` data folder) |
| `MG_BRIEF_DB`, `MG_BRIEF_ARTIFACT_ROOT` | The brief catalog and its downloads |
| `MG_STREAMR_DB` | The podcasts database |
| `MG_BOOKR_DB` | The books database |
| `MG_BOOKR_BOOKS`, `MG_BOOKR_AUDIOBOOKS` | Book folders (default `~/books`, `~/audiobooks`) |
| `MPD_HOST` | Where `mpd` listens |
| `NO_COLOR` | Turn off coloured output |

Configuration files are optional: `~/.config/mg-calr/config.toml` and
`~/.config/mg-remindr/config.toml`.

## Pointing the desktop at different builds

**Use `GEIST_ROOT`.** It says where the suite lives (default
`~/geistos/mg-suite`), and every part of the desktop then looks for
development builds under it. It is the one setting every part honours.

Single-app overrides exist, but different parts of the desktop spell them
differently, and a few parts honour none of them:

| Part of the desktop | Variable |
|---|---|
| Ticker, Media, Books, Task manager, Brief panel | `MG_FEEDR_BIN`, `MG_STREAMR_BIN`, `MG_BOOKR_BIN`, `MG_TASKR_BIN`, `MG_BRIEF_BIN` |
| The "Refresh todo agenda" script | `MG_REMINDR_BIN`, `MG_CALR_BIN` |
| Calendar and Reminders cards, Vault panel, suite status | `MG_MG_CALR_BIN`, `MG_MG_REMINDR_BIN`, `MG_MG_VAULT_BIN`, `MG_MG_BRIEF_BIN`, `MG_MG_CONTACTS_BIN` |
| The calculator | `MG_CALCR_BIN` |
| The Geist panel's launch buttons | `GEIST_ROOT` only |

## The installer

| Variable | Default |
|---|---|
| `GEIST_ROOT` | `~/geistos/mg-suite` |
| `GEIST_PREFIX` | `~/.local` (binaries go in `bin/` under it) |
| `GEIST_UNIT_DIR` | `~/.config/systemd/user` |

# Appendix C. Scripting the desktop

Everything the bar can do, a script can do too, through Quickshell's IPC:

```sh
# list every target and function
qs -c mgeist ipc show
qs -c mgeist ipc call <target> <function> [args]
```

Most panels answer `open`, `close` and `toggle`. Some useful calls:

| Call | Does |
|---|---|
| `launcher toggle` | Open the launcher |
| `reminders keep "Pay rent" today` | Keep a reminder (and refresh the calendar) |
| `reminders done <handle>` | Finish one |
| `calendar schedule "Review" 11:30` | Add an event to the day shown |
| `calendar status` | The day shown, and its counts |
| `theme toggle` | Light / dark |
| `wallpaper next`, `wallpaper set <path>` | Change the wallpaper |
| `rotation next` | Next wallpaper and theme |
| `stickies create` | New sticky note |
| `taskmanager tab performance` | Open the task manager on a tab |
| `player toggle` | The Media panel |
| `media toggle` | Play / pause |
| `ticker toggle` | The crawl strip |
| `alarms add "07:30" "1,2,3,4,5" "Work"` | A weekday alarm (Sunday is 0) |
| `sleep armIn 30` | Suspend the machine in 30 minutes (`sleep cancel` undoes it) |
| `ai ask "…"` | Ask the AI panel |

::: tip
**Good to know.** `show`, `call`, `wait`, `listen` and `prop` are words the
`qs ipc` command uses itself, so the shell never uses them as function names.
That's why panels use `open` rather than `show`.
:::

# Appendix D. Glossary

Authority
:   The one app that owns a piece of data. Its answer wins.

Projection
:   A copy of another app's data, made for reading, such as the reminders on
    your calendar. It can be out of date, and it says so when it is.

Store
:   An app's data file, usually one SQLite database.

Envelope
:   A versioned JSON document one app exports for another to check and import.

Handle
:   The short ID `mg-remindr ls` shows next to each reminder.

Receipt
:   An app's written answer to a request from another app, such as mg-calr
    confirming the event it created for an mg-plan request.

Revision / version
:   A counter that goes up with every change. Edits name the version they
    started from, so two edits can't silently overwrite each other.

Ticker source
:   An mg-brief source marked to appear on the bar's headline ticker.

IPC
:   The way scripts talk to the running shell: `qs -c mgeist ipc call …`.

Root helper
:   The small, optional program that does the few jobs needing root, and
    nothing else.

WAL
:   SQLite's write-ahead log, the `-wal` file next to a database. It's why you
    copy a database together with its sidecar files.
