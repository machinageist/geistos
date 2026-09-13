<!--
Author: Jeff
Date: 2026-09-13
Description: Richer calendar event and reminder detail cards — decisions so far
Notes: Queued behind stickies. This records scope decisions and the survey behind
       them; the full spec and plan are written when the work starts
-->

# Detail cards — decisions

## Outcome

The calendar event and reminder cards should edit what a mature calendar and
reminders app edits: detail text, place, real start and end times, repeat,
alerts, lists, tags and priority.

## Decisions

| Question | Decision |
|---|---|
| Order | After stickies |
| Reminder fields | **Deepen mg-remindr.** This consciously reverses the suite README rule that mg-remindr is transitional and not to be deepened; update that README when this lands |
| Location on reminders | Out. Location-triggered reminders need geofencing, which a desktop lacks |

### Event card, first version

- Description, location, URL
- Start and end date and time pickers, all-day toggle, timezone
- Repeat, choice of calendar, busy/free
- Alerts that actually fire

### Reminder card, first version

- Notes (description) and URL
- A due date and time picker
- Priority, list (project), tags
- Repeat and subtasks

## Survey, 2026-09-13

**mg-calr.** `events` already stores `description`, `location`, `url`,
`status`, `busy`, `timezone`, all-day dates and `recurrence_rule`, and ICS import
fills them. `event create` exposes repeat flags but not description, location or
URL. `event edit` changes only the title and one temporal form. A `reminders`
table with `offset_seconds`/`absolute_at` exists in the domain, but
`src/notify/` holds only `null.rs`, so **alerts have no delivery**. That is the
largest item: it needs a scheduler and a desktop notification path.

**mg-remindr.** `todos` has title, project, lifecycle, due date/time/timezone and
completion times; separate tables hold tags, parents (subtasks), dependencies,
recurrence and reminders with delivery. There is **no** notes, priority or URL
column. The human CLI (`add`, `edit`) exposes only the title and due value; the
`todo` subcommand takes JSON.

**Desktop.** `EventEditPanel.qml` offers a title, a day, start presets
(09:00/13:00/17:00) and length presets (15m–2h). `ReminderEditPanel.qml` offers
a title and Keep/None/Today/Tomorrow. The bridges are `~/dotfiles/scripts/geist-calendar`
and `geist-reminders`.

## Constraints to carry into the spec

- Applications never call each other; the cards reach them through the bridges.
- Append migrations; never edit an applied one.
- Both CLIs use optimistic versions; the cards already carry them.
- Card click actions that exist today are protected; new controls are fine.
