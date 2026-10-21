<!--
Description: Local contract for expanding the mg-bookr Quickshell library UI.
Basis: Decisions accepted in the user interview on 2026-10-19; implementation details below are safe defaults.
-->

# mg-bookr library GUI and incremental scan

## Problem statement

mg-bookr has an authoritative local SQLite library, a separate Qt Quick reader, and a partial Quickshell BooksPanel. The panel can browse and open books, but it cannot manage reading lists, search, or edit reading status. A full scan currently reparses every discovered book, which wastes compute. The reader restores saved position and shows percentage, but does not show how much remains.

## User-facing contract

- Expand the existing Quickshell BooksPanel. Keep the reader as the separate Qt application required by WebEngine; do not embed it in Quickshell or add a second reader.
- Include EPUB, PDF, CBZ/CBR comics, and audiobooks in the same compact, keyboard-first, cover-thumbnail list UI.
- Add a Lists view alongside Continue, Library, and Listening. Lists are manually curated and may contain the same book simultaneously.
- Support create, rename, delete, add, remove, bulk membership changes, and persisted per-list ordering. Deleting a list removes only the list and memberships, never books. New members append to the end. Manual ordering is the default; alphabetical-by-title is a non-destructive alternate view. Reorder with keyboard move-up/down and optional drag-and-drop.
- Add case-insensitive search over title, author, and series, within the library or current list. Provide status and kind filters. Keep scanned title/author/cover metadata read-only in this slice.
- Add a global, explicitly editable per-book status independent of saved reading/listening position: `to-read`, `reading`, `paused`, `finished`. New books default to `to-read`. Existing rows migrate from current data: finished flag -> `finished`; otherwise nonzero saved progress -> `reading`; otherwise `to-read`. Opening `to-read` or `paused` changes it to `reading`; reaching the end changes it to `finished`. Changing status never erases or resets position.
- Support keyboard multi-select: Space toggles a row, Escape exits/clears selection, and bulk actions apply only to the selected list membership. Preserve ordinary Enter-to-open behavior outside selection mode.
- Keep book rows compact and show cover, title, author, status, and progress without requiring a separate detail window.
- Keep current reader position persistence. In the reader footer/status area show pages remaining for fixed-page PDF/comics; show percentage plus section/spine progress for reflowable EPUB; for audiobooks show remaining time adjusted for current playback speed when duration is known, otherwise percentage.

## Incremental scan contract

- Store a cheap persistent fingerprint per scanned candidate in mg-bookr's SQLite authority. Use the logical root and relative path plus file size and modification time; folder audiobooks use a deterministic aggregate over their member paths and stat data.
- Normal scans still enumerate roots and stat candidates, but skip metadata extraction, cover generation, and track/chapter replacement for unchanged fingerprints. Parse only new or changed candidates. A force-rescan mode bypasses fingerprints.
- Perform a cheap reconciliation at BooksPanel startup/open and use debounced filesystem events while the panel is open; retain explicit Refresh and Force rescan actions. Events must be coalesced and must never trigger repeated metadata reads for unchanged books.
- Same logical root/path retains the existing book ID, progress, status, highlights, and list memberships when metadata refreshes. Renamed/moved paths remain a missing old record plus a new record; do not guess identity or transfer history automatically in this slice.
- A nonexistent or inaccessible root, or an incomplete directory walk, must not mark its old catalog entries missing. Only reconcile missing records after a complete walk of the corresponding root. Report incomplete traversal instead of presenting a false fresh result.
- A metadata parse failure remains visible in scan diagnostics and must not silently erase previously known metadata for an existing row. Force rescan retries it.

## Authority and persistence

- mg-bookr SQLite remains the only durable authority for book records, statuses, list memberships/order, fingerprints, and progress. Quickshell is a projection/controller and calls mg-bookr's JSON CLI; it must not open the database itself.
- Extend the append-only migration ledger; retain compatibility with existing databases and preserve all current list memberships, progress, highlights, and reader settings.
- Use parameterized values, transactional list mutations/reordering, stable IDs, bounded search input/results, and deterministic sorting.
- Preserve all pre-existing dirty work in both the suite repository and dotfiles repository. Do not stage or commit unrelated paths.

## Testing seams and acceptance

1. Store/CLI seam: use temporary SQLite databases and temporary book roots to test migration/backfill, list CRUD/membership/order/bulk operations, statuses and transitions, incremental fingerprint skip/refresh/force paths, incomplete-walk safety, and readback after reopening the database. This catches persistence and command-contract errors; it does not prove live Quickshell interaction.
2. Reader rules seam: exercise format-specific remaining calculations and progress-location serialization with Node tests; retain the existing PySide/QML reader tests where the environment supports them. This does not prove the reader window renders correctly.
3. Quickshell service-state seam: test JSON parsing, search/status/kind filtering, selection, ordering, progress labels, and failure behavior through the existing Node-loaded BooksState.js contract. This does not prove QML focus/layout.
4. UI/runtime seam: validate QML loading, action-to-CLI wiring, keyboard and pointer flows, empty/error/loading states, scan feedback, and reader launch in the real Hyprland/Quickshell session; visually inspect every active display. Keep service-startup/IPC evidence distinct from screenshots.
5. Gates: `cargo fmt --check`, `cargo clippy --locked --all-targets -- -D warnings`, `cargo test --locked`, `node --test reader/tests/rules.test.js`, `QT_QPA_PLATFORM=offscreen python3 -m unittest reader.tests.test_reader` when the project's Qt Python runtime is available, and Quickshell BooksState tests. Exercise clean temporary database/root scenarios and never run destructive tests against the user's library.

## Out of scope

- A new standalone catalog application or an embedded Quickshell book reader.
- Smart/rule-driven lists, cloud sync, store/accounts/DRM, manual edits to scanned title/author/cover metadata, or mobile UI.
- Automatic content-based identity matching for moved files.
- Unrelated defects outside the feature paths; record them for a later brownfield QA review.
