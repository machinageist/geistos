<!--
Description: Local contract for reading the lists from the command line and the TUI.
Basis: User request and interview on 2026-10-21; implementation details below are safe defaults.
-->

# mg-bookr reading lists access

## Problem statement

Lists exist (`collection import` made eight), but reading from one means `collection show`, copying
an id, then `open <id>`, and the TUI has no lists at all. `collection …` stays the editing
interface; this adds the reading one.

## Command line

`mg-bookr lists [<name> [open <n> | next]]`

- `lists`: every list, by name, with its book count and how many are `reading` and `finished`.
- `lists <name>`: the list's books in list order, numbered from 1, with status and progress.
  An unknown name is an error.
- `lists <name> open <n>`: the book at place `n`. `lists <name> next`: the first book in list
  order that is not finished and not missing. An audiobook starts playing, as `listen play`
  does; anything else opens in the reader, as `open` does.
- `--json` gives the summaries, the numbered records, or the open/play answer.

## TUI

- A fourth tab, Lists, after Listening, so keys 1–3 keep their tabs.
- It shows every list with the same counts. Enter opens one: its books in list order with place,
  status and progress. Enter on a book reads or plays it, as on the other tabs. Esc or Backspace
  goes back to the lists, with the counts refreshed. Lists and books keep separate cursors.
- With no lists yet, the tab says how to make one. A rescan refreshes the tab too.

## Out of scope

- Editing lists from the TUI (create, rename, reorder, membership); the Quickshell panel and
  `collection …` cover that.
