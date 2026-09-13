<!--
Author: Jeff
Date: 2026-09-13
Description: Calendar event and reminder detail cards that edit what a mature calendar and reminders app edits
Notes: Spans mg-calr, mg-remindr, the dotfiles bridges and two Quickshell cards.
       Decisions below were made by Jeff on 2026-09-13; the survey was read
       from the code the same day
-->

# Detail cards

## Outcome

Double-clicking an event or a reminder opens a card that edits every field a
mature calendar or reminders app offers, and calendar alerts actually notify.

## Decisions

| Question | Decision |
|---|---|
| Order | After stickies (done) |
| Reminder fields | **Deepen mg-remindr.** This reverses the suite README's "transitional, do not deepen" rule on purpose; the README changes when this lands |
| Location on reminders | Out. Location-triggered reminders need geofencing, which a desktop lacks |
| Alert runner | **One-shot `mg-calr alerts deliver` from a systemd user timer, every minute.** No long-running process |
| Missed alerts | Deliver when missed by up to **60 minutes**, marked late. Older ones are recorded as skipped and never replayed |

## Event card

| Field | Behaviour |
|---|---|
| Title | Required, as today |
| Calendar | Choose from `mg-calr calendar list`; moving an event keeps its id and version history |
| All-day | Toggle between a timed form and an all-day form; the whole temporal form is always sent, as today |
| Start and end | A date picker and an `HH:MM` field for each. End is after start; an all-day end is inclusive on the card and exclusive in storage, as RFC 5545 has it |
| Timezone | IANA zone, default the system zone |
| Repeat | None, daily, weekly (with weekdays), monthly; every N; ends never, after N, or on a date. The domain already has `EventRecurrence` |
| Alerts | Up to 5: at start, 5/10/15/30 minutes, 1/2 hours, 1/2 days before. All-day events alert relative to 09:00 local on the day |
| Availability | Busy or free |
| Location | Free text, up to 500 characters |
| URL | `http`, `https` or `mailto`, up to 2048 characters, with an open button |
| Description | Multi-line plain text, up to 10,000 characters |

## Reminder card

| Field | Behaviour |
|---|---|
| Title | Required, as today |
| Notes | Multi-line plain text, up to 10,000 characters. **New column** |
| URL | As on events. **New column** |
| Due | Date picker, optional `HH:MM`, clearable. Already stored |
| Priority | None, low, medium, high. **New column** |
| List | The mg-remindr project, or none. Already stored |
| Tags | Add and remove. Already stored |
| Repeat | Daily, weekly, monthly; every N; ends never, after N, or on a date. Already stored |
| Subtasks | Set or clear a parent; the card lists a reminder's children. Already stored |

## Alerts

`mg-calr alerts deliver` looks at the window from 60 minutes ago to now:

1. Expand every live event's occurrences, repeats included, and compute each
   alert's due time.
2. Claim each `(reminder, occurrence)` in `reminder_deliveries`. The unique key and
   claim fence mean two overlapping runs cannot both present an alert.
3. Present it through a `NotificationBackend` over `notify-send`: title, time and
   location, marked late when overdue.
4. Record the state: presented, skipped (older than 60 minutes), or
   `unconfirmed_lost` when `notify-send` failed after it may have written. An
   unknown outcome is never retried, as the existing `BackendError` requires.

Alarms become authoritative rows in the existing `reminders` table, which the
ledger already references. An appended migration moves any alarms held in
`events.extension_properties` into rows.

## Constraints

- **The agenda projection does not change.** mg-remindr's export builds an explicit
  key set pinned by its tests, and mg-calr's import is `deny_unknown_fields`. New
  reminder fields stay out of it. `geistos/tests/suite-pipe.sh` must still pass.
- Applications never call each other. The cards reach them only through
  `dotfiles/scripts/geist-calendar` and `geist-reminders`.
- Append migrations; never edit an applied one.
- Every write carries the optimistic version the card read; a stale write reports
  a conflict and reloads instead of overwriting.
- Existing card click actions stay as they are; new controls are fine.
- Text fields reject control characters, except newline and tab in descriptions
  and notes.
- No colour outside `Theme/`; glyphs as `\uXXXX` escapes.

## Acceptance criteria

1. Every event field above can be set, changed and cleared from the card, and
   `mg-calr event show` reflects each change.
2. Every reminder field above likewise, visible in `mg-remindr ls --json`.
3. An alert 10 minutes before a timed event appears as a desktop notification
   within a minute of its due time; running `alerts deliver` twice presents it once.
4. After a suspend of 30 minutes over a due alert, it arrives marked late; after 2
   hours, it is recorded as skipped and never appears.
5. A repeating event's alert fires for each occurrence.
6. A write with a stale version is refused and the card reloads.
7. `geistos/tests/suite-pipe.sh` passes, and still fails against `/bin/true`.
8. Each repository's fmt, clippy `-D warnings` and tests pass; the bridge Python
   tests pass.

## Out of scope

Location-based reminders, invitees and attendee email, travel time, attachments,
sync with external calendars, snoozing from the notification, and reminder alerts
(mg-remindr's own delivery tables stay unused here).

## Survey, 2026-09-13

**mg-calr.** `EventMetadata` holds description, location, URL, status, busy,
categories, recurrence, alarms, organizer and attendees. Alarms, categories,
organizer and attendees are stored as JSON in `events.extension_properties`.
`EventEdit` carries only a title and a temporal form. `event create` exposes repeat
flags but no text fields. `src/notify/` defines `NotificationBackend` with only a
null implementation and no callers. `reminder_deliveries` (migrations 0001 and 0007)
is a complete claim-and-state ledger keyed to `reminders(id)`. There is no D-Bus crate;
`notify-send` is installed.

**mg-remindr.** `Todo` holds title, project, parent, tags, dependencies, lifecycle,
due and completion times, and recurrence in `todo_recurrence`. It has no notes,
priority or URL. The human `add`/`edit` commands expose only the title and due
value. The next migration is 0013.

**Desktop.** `EventEditPanel.qml` offers a title, a day, start presets and length
presets. `ReminderEditPanel.qml` offers a title and Keep/None/Today/Tomorrow.
`Widgets/CalendarMonthGrid.qml` already draws a month and can serve as the date picker.
