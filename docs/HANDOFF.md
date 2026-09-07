<!--
Author: Jeff
Date: 2026-09-07
Description: What the geistos work has reached, and what to pick up next
Notes: Written at the end of a long session. State claims here were checked
       against the machine, not recalled
-->

# Handoff — 2026-09-07

## Where this stands

Nine repositories, all clean and pushed. `geistos` is the umbrella holding the
desktop configuration; `mg-suite` sits inside it as its own repository holding
six applications, each also its own repository.

| Repository | Branch | Commits | Remote |
|---|---|---|---|
| `geistos` | main | 4 | github.com/machinageist/geistos |
| `mg-suite` | main | 5 | …/mg-suite |
| `mg-briefr` | main + `postgres-port` | 12 | …/mg-briefr |
| `mg-calr` | main | 56 | …/mg-calr |
| `mg-contactr` | main | 8 | …/mg-contactr |
| `mg-planr` | main | 12 | …/mg-planr |
| `mg-remindr` | main | 29 | …/mg-remindr |
| `mg-vaultr` | main | 16 | …/mg-vaultr |
| `dotfiles` | `quickshell-shell` | 48 | …/dotfiles |

All private. `dotfiles` work sits on a branch, not merged to its `main`.

The living plan, with every decision and its reasoning, is
`~/.claude/plans/let-s-do-a-deep-imperative-hopcroft.md`. This document is the
short version.

## What the suite is for

*"A suite of tools that work on their own like normal productivity tools, but
together work like a second digital brain."*

**Done means packageable for others** — a fresh Arch machine going from clone to
a working suite with no manual database setup. That makes the installer and
PKGBUILD the finish line, not a nice-to-have.

## Accomplished

**Published.** Nine repositories initialised, licensed MIT, and pushed. Personal
data removed first: two iCalendar test fixtures were a real schedule (job
applications, employer research, a cert track, and health information) and are
now synthetic with every structural property the tests pin preserved.

**PostgreSQL foundation.** `geistos/bin/geist-db` resolves a cluster — an explicit
`GEIST_PGHOST`, then one the machine already runs, then a private per-user
cluster it creates itself with `initdb`. The private cluster serves a `0700` unix
socket with `listen_addresses` empty, so it opens no TCP port. A systemd user
unit supervises it and never touches a system cluster. `mg-planr` is ported off
SQLite.

**The desktop.** The calendar card gained day, week and month views: a week as
seven day columns over twenty-four hour rows, a month as the Monday-first grid a
wall calendar uses. Events are positioned from real minutes, which the bridge now
computes. Double-clicking an event opens an editor for its title, day, time and
length.

**One live cross-application path, now tested end to end.**
`geistos/tests/suite-pipe.sh` runs the real mg-remindr, the real sync script and
the real mg-calr against a disposable database. Both halves were previously
tested only against hand-authored fixtures that agreed with each other by
construction. The test is proven to fail when pointed at a broken consumer.

**Adoption started.** mg-remindr holds four real commitments (the applications
floor, the RHCSA baseline gate, D-01, D-02) and they reach the calendar agenda.

## Bugs found and fixed

Worth knowing because each says something about the system:

- **A stale todo cache killed the whole agenda.** mg-remindr sets a snapshot's
  `created_at` to the newest record's `observed_at`, deliberately, so an export of
  unchanged data is byte-identical. mg-calr read the same field as "when this was
  taken" and refused anything over 24 hours old. A quiet todo list went stale and
  **re-syncing could not fix it**. Freshness is now measured from when this machine
  last accepted a projection.
- **A migration-ledger race in mg-calr** (found, not yet fixed — see below).
- **The suite root was hardcoded in eight places**, which broke the desktop twice
  in one day. One resolver now, honouring `GEIST_ROOT`.
- **`CARGO_BIN_EXE_*` is an absolute path baked at compile time.** Any directory
  move leaves test binaries pointing at paths that no longer exist. `cargo clean -p`
  after a move.
- **Naming a QML function `open()` shadows `PopupPanel`'s `bool open`** and stops
  the whole `Panels/` directory registering its types. The error names whichever
  type `shell.qml` reaches first, which is misleading.

## What to work on next

Ordered as decided. Items B–D are small and unblock clarity; E–G are the substance.

**B — the migration race.** `mg-calr/src/storage.rs:728` calls
`ensure_migration_table()` on the raw client *before* the transaction opens, so its
`CREATE TABLE IF NOT EXISTS` runs outside the advisory lock. Concurrent identical
DDL is not race-safe; the loser gets `42P07`. Move the bootstrap inside the lock,
copying `mg-remindr/src/storage.rs:401-475`, which already does it correctly. Add a
concurrent-migrate test — single-threaded runs hide this.

**C — prune the vault specs.** Delete branches D, E, F (the editor stack) and N, O
(plugins, AI adapters) with their scorecards; recoverable from history. Keep I, J,
K, L, M, P — "stands alone as a normal productivity tool" is the argument for the
Obsidian-parity branches — and Q, R, which the finish line depends on.

**D — remove mg-calr's orphaned todo authority.** ~1,600 lines of full CRUD over a
`todos` table the agenda deliberately ignores. `interop export` depends on it and is
being deleted too; it has zero consumers. Keep the import direction and the shared
domain types. Append a migration dropping the tables; never edit an applied one.

**E — mg-briefr.** The largest item. The port is started on the `postgres-port`
branch and **does not compile**; its commit message enumerates what remains. After
the port: item content and read state, a full three-pane reader rendering through
`w3m -dump`, a Quickshell card, saving as a cited note into mg-vault through a
bridge, and source adapters in the order atom → OSV/GHSA → arXiv → mbox.

**F — mg-contactr.** Ciphertext to PostgreSQL, `keyring.json` stays a local 0600
file, `envelope.rs` and `keyring.rs` unchanged. Removes a real failure mode: today
one corrupted line makes the entire store unreadable.

**G — the installer and PKGBUILD.** The finish line.

### Also open, from a survey of capability the GUI never exposed

- **mg-remindr has no edit at all** — not in the bridge, not in the CLI. Changing a
  due date means destroying the item and its history. This is the only one that is
  a genuine capability hole rather than missing plumbing, and it is in the
  application now being used daily.
- **Vault search** exists (`mg-vault search`) and is unreachable from the desktop.
- **Vault note read** likewise.
- **Calendar `.ics` import** is CLI-only.

## Things a fresh session should know

- **No vault is registered.** `mg-vault vault list` is empty, which blocks the
  brief→vault citation path and makes the vault card mostly inert.
- **Nothing syncs the todo projection on a schedule.** It runs on a reminder
  mutation or when triggered. That is why it went stale for two days.
- **mg-remindr's database is still named `mg_todo`**, and its migration ledger
  `mg_todo_schema_migrations`. Renaming the database needs `ALTER DATABASE` from
  another connection; renaming the ledger needs the runner to bootstrap on both
  names. Both deliberately left.
- **Applications never call each other.** Cross-application work goes through a
  bridge in `dotfiles/scripts/`. The planned brief→vault save follows this.
- **Do not change keybindings or existing bar click actions** without approval —
  `dotfiles/docs/PROTECTED_KEYBINDINGS.md`.
- The career plan this competes with is real and was accepted knowingly, with a
  **2026-11-01 review trigger**: if RHCSA is not scheduled by then, revisit rather
  than let it ride.

## Verification

```sh
# every repo clean and synced
for d in geistos geistos/mg-suite geistos/mg-suite/mg-*; do
  git -C ~/$d status --porcelain | wc -l; done

# the one live cross-application path, and proof the test can fail
GEIST_RUN_SUITE_TESTS=1 ~/geistos/tests/suite-pipe.sh
GEIST_RUN_SUITE_TESTS=1 MG_CALR_BIN=/bin/true ~/geistos/tests/suite-pipe.sh   # must fail

# per crate
cargo fmt --all -- --check
TMPDIR=/dev/shm cargo clippy --workspace --all-targets --all-features -- -D warnings
TMPDIR=/dev/shm cargo test --workspace --all-targets

# desktop
cd ~/dotfiles/scripts && python3 -m unittest discover -s tests -p 'test_*.py'
python3 ~/dotfiles/scripts/geist-status.py
qs -c mgeist ipc call calendar status
```
