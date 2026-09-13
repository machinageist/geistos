<!--
Author: Jeff
Date: 2026-09-13
Description: Atomic tasks for the detail cards change
Notes: One commit per task, in the repository named. Each backend task lands
       before the bridge and card work that depends on it. Suite paths are under
       ~/geistos/mg-suite; dotfiles paths are under ~/dotfiles
-->

# Detail cards — plan

Per-crate verification, referred to below as **crate gate**:

```sh
cargo fmt --all -- --check
TMPDIR=/dev/shm cargo clippy --workspace --all-targets --all-features -- -D warnings
TMPDIR=/dev/shm cargo test --workspace --all-targets
```

mg-calr database tests additionally:
`MG_CALR_RUN_DATABASE_TESTS=1 MG_CALR_TEST_DATABASE_URL=$(~/geistos/bin/geist-db url mg_calr_test) TMPDIR=/dev/shm cargo test --test postgres_integration -- --ignored`

mg-remindr database tests: `MG_REMINDR_ALLOW_INTEGRATION_TESTS=1 TMPDIR=/dev/shm cargo test --all-targets`

## Phase A — mg-calr

**A1. Event text, availability and calendar.** `EventEdit` gains set/clear for
description, location and URL, plus busy and calendar. Add domain validation for
lengths, control characters and URL scheme, and extend the storage `UPDATE`.
`event create` and `event edit` get `--description`, `--location`, `--url`, each
with a `--clear-*` form on edit, plus `--busy`/`--free` and `--calendar`.
Verify: crate gate, database tests, and a CLI round trip through `event show --json`.

**A2. Repeat on edit.** `EventEdit` gains set/clear recurrence; `event edit` takes the
create flags plus `--clear-repeat`. Verify: crate gate; the agenda expands an
edited rule.

**A3. Alarms as rows.** An appended migration moves `extension_properties.alarms`
into `reminders` rows. Storage reads and writes alarms there. `event edit` takes
`--alert <offset>` (repeatable, at most 5) and `--clear-alerts`. Verify: crate gate;
the migration test starts from a JSON-alarm fixture.

**A4. Alert delivery.** Add the `notify-send` `NotificationBackend` and
`mg-calr alerts deliver [--now <rfc3339>]`: expand occurrences in the window, claim,
present, record. Unit tests use a fake backend and fixed clock for on time, late at
30 minutes, skipped at 2 hours, a repeat's second occurrence, and an unknown outcome
that is not retried. A database test runs deliver twice and presents once. Verify:
crate gate, database tests.

**A5. Timer units.** Add `geistos/systemd/mg-calr-alerts.{service,timer}`
(`OnCalendar=minutely`) and document them in the geistos README. Verify:
`systemd-analyze --user verify`, then a live alert appears.

## Phase B — mg-remindr

**B1. Notes, URL and priority.** Migration 0013 adds the columns; domain, storage,
`add` and `edit` flags follow; `ls --json` includes them. Interop export tests are
unchanged and still pass. Verify: crate gate with integration tests, then
`GEIST_RUN_SUITE_TESTS=1 ~/geistos/tests/suite-pipe.sh`.

**B2. Expose list, tags, repeat and parent.** `add`/`edit` get `--list <name|none>`,
`--tag`/`--untag`, repeat flags with `--clear-repeat`, and `--parent <handle>` with
`--clear-parent`. `ls --json` includes list, tags, recurrence, parent and children.
Add `list ls` and `tag ls` for pickers if absent. Verify: as B1.

**B3. Suite docs.** Reword the mg-remindr boundary in `mg-suite/README.md` to record
the deliberate deepening.

## Phase C — bridges (dotfiles `scripts/`)

**C1. geist-calendar.** Add `show <id>` and `calendars`, and pass the new edit and
add flags with validation matching the domain limits. Verify:
`python3 -m unittest discover -s tests -p 'test_*.py'`.

**C2. geist-reminders.** Add `show <handle>`, `lists` and `tags`, and pass the new
flags. Verify: as C1.

## Phase D — cards (dotfiles Quickshell)

**D1. Pickers.** A date picker built on `CalendarMonthGrid`, an `HH:MM` field, and
option chips. Put the time and date maths in a `.js` helper with node tests.

**D2. Event card.** Rework `EventEditPanel.qml` around the event table in the spec.
It sends only changed fields, with the version it read, and handles a conflict by
reloading.

**D3. Reminder card.** Rework `ReminderEditPanel.qml` likewise.

Verify D1–D3: node tests; the colour and glyph greps; live checks of every field
against `event show` and `ls --json` with a shell restart.

## Phase E — close out

Update `docs/HANDOFF.md` and the feature notes, run the full verification set, and
tick off the acceptance criteria one by one.
