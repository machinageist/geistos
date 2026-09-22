<!--
Author: Jeff
Date: 2026-09-20
Description: The session that moved the suite off PostgreSQL, and what is left after it
Notes: Every state claim here was checked against the machine, not recalled
-->

# Current handoff — 2026-09-20

This canonical handoff supersedes the older dated handoffs. Stale history was pruned on 2026-09-22; use the repository and live service as the source of truth.

## What changed

**The suite is server-free.** mg-planr, mg-remindr, mg-calr and mg-contactr each
keep one SQLite file under `$XDG_DATA_HOME`, in WAL with foreign keys on. There is
no cluster to resolve, provision or supervise, which makes "clone to a working
suite with no manual database setup" true rather than the finish line.

**Jeff's real data came across, as it stood.** 78 reminders and 2 calendars with
389 events, each keeping its identity, version and recorded times — an interop
import could not have done that, because a record at version three is neither new
nor a version-matched replacement.

| Application | Store | How the data moved |
|---|---|---|
| `mg-planr` | `$XDG_DATA_HOME/mg-planr/<name>.sqlite` | `mg-plan adopt-postgres` (no rows existed) |
| `mg-remindr` | `…/mg-remindr/remindr.sqlite` | `mg-remindr interop adopt-postgres`, 78 todos, revision 141 |
| `mg-calr` | `…/mg-calr/calr.sqlite` | `event export` from the old build → `event import`, 2 calendars + 389 events |
| `mg-contactr` | `…/mg-contacts/contacts.sqlite` | nothing stored yet |

**`geist-db` is gone**, with `systemd/geist-postgres.service`. The suite pipe test
took a store in its own temporary directory instead of standing up a cluster, so
it no longer needs opting into: `tests/suite-pipe.sh`, 9 checks, and still proven
to fail when pointed at a broken consumer.

**Mouse resize works again in the flat look.** Hyprland resizes by dragging
borders and gaps and nothing else, so a look with no border and a gap under four
pixels left nothing to take hold of. Such a look now sends one pixel of border,
which reads as a hairline seam between windows that touch.

**The ticker and the brief carry defense, war and OSINT.** Ten sources added:
`war-twz`, `war-breaking-defense`, `war-defense-one`, `war-defensescoop`,
`war-naval-news`, `war-aviationist`, `osint-bellingcat`, `osint-war-on-rocks`,
`osint-oryx`, `news-al-jazeera`. All fetch; 24 sources now.

## What this cost, and what it bought

The PostgreSQL-only tests went with the engine: the legacy ledger upgrade, the
multi-migration history gaps, the disposable-server harnesses. What they
protected — ledger integrity, checksum drift, optimistic writes, timestamp
precision — is covered by the storage unit tests and the new store integration
suites, which run everywhere with nothing to provision.

## Things a fresh session should know

- **The retired databases still exist**: `mg_todo` and `mg_calr` on the system
  cluster, plus the private cluster at `$XDG_DATA_HOME/geist/pg` and its disabled
  `geist-postgres.service` in `~/.config/systemd/user/`. Nothing reads them.
  Dumps taken before the move are in `~/geist-migration-backups/`. Dropping any
  of it is a decision to make after living with the new stores.
- **`~/wt/mg-calr-details` is a worktree on `detail-cards/calr`**, still at the
  PostgreSQL commit. It needs rebasing onto the port before that work continues.
- **Adoption is a one-shot path.** `mg-remindr interop adopt-postgres` fills an
  empty store only, and refuses an export carrying tag links, parents,
  dependencies, recurrence or deliveries rather than dropping them. Delete
  `mg-remindr/src/adopt.rs` once the databases are gone.
- **No vault is registered** (`mg-vault vault list` is empty), so the vault card
  stays inert and mg-bookr's note export says so.
- **mg-contacts has never been initialized**; its store is created on first use.
- Do not change keybindings or existing bar click actions without approval —
  `dotfiles/docs/PROTECTED_KEYBINDINGS.md`.

## Verification

```sh
# every repo clean
for d in geistos dotfiles geistos/mg-suite geistos/mg-suite/mg-*; do
  git -C ~/$d status --porcelain | wc -l; done

# the one live cross-application path, and proof the test can fail
~/geistos/tests/suite-pipe.sh
MG_CALR_BIN=/bin/true ~/geistos/tests/suite-pipe.sh   # must fail

# per crate
cargo fmt --all -- --check
TMPDIR=/dev/shm cargo clippy --all-targets --all-features -- -D warnings
TMPDIR=/dev/shm cargo test

# desktop
cd ~/dotfiles && node --test config/quickshell/mgeist/Services/tests/*.test.js \
  config/quickshell/mgeist/Services/tests/*.test.cjs
python3 -m unittest discover -s scripts/tests -p 'test_*.py'
python3 scripts/geist-status.py
qs -c mgeist ipc call calendar status
```

## What to work on next

1. **The teaching-comment pass** across the codebase, comment-only diffs.
2. **The installer and PKGBUILD** — the finish line, and nothing now stands in
   its way: no server to provision, no cluster to supervise.
3. **mg-briefr's reader** (three panes through `w3m -dump`, a shell card, saving
   cited notes into mg-vault) and the source adapters after atom: OSV/GHSA,
   arXiv, mbox.
4. **Register a vault**, which unblocks the brief→vault citation path and the
   mg-bookr note export.
5. Rebase `detail-cards/calr` onto the SQLite port.
