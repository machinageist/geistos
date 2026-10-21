<!--
Description: Dependency-ordered implementation and verification plan.
-->

# mg-bookr library GUI plan

1. Establish the testable authority contract. Preserve and understand the inherited CLI/TUI search/sort diff. Add an append-only migration and Store/CLI behavior for per-book statuses, collection lifecycle, many-to-many membership, per-list order, and bulk membership. Pin legacy no-option CLI/TUI behavior. Verify temporary-database readback after reopen.
2. Make scanning incremental and safe. Persist fingerprints; skip unchanged metadata/cover/audio parsing; add force-rescan. Make traversal completeness explicit so incomplete roots never produce false missing records. Test new/changed/unchanged/deleted/unreadable files, folder audiobooks, force paths, and history/list preservation.
3. Complete reader progress presentation. Add format-aware remaining content to the existing reader footer and status transitions via mg-bookr's public JSON CLI. Add speed-adjusted audiobook remaining time to the listening projection. Test the pure calculation seams first.
4. Expand the active Quickshell BooksPanel. Add Lists navigation, search, filters, status controls, bulk selection/actions, order controls, list lifecycle, scan feedback, compact row status/progress, and event-triggered reconciliation. Keep all mutations behind mg-bookr's JSON CLI.
5. Verify end to end using temporary stores/roots and the active installed toolchain. Run focused tests during each slice, then all applicable Rust/Node/Python gates; perform live UI/keyboard/pointer checks and inspect screenshots on every active display only after safe runtime ownership is established.
6. Obtain a fresh independent blind review of the exact final diff, fix findings with regression tests, rerun affected gates, and preserve all unrelated dirty work. Do not commit or claim completion while a required gate or runtime dependency is blocked.

## Baseline recorded before feature edits

- `cargo fmt --check`, strict Clippy, and `cargo test --locked` pass on the inherited dirty mg-bookr tree (47 library tests, 2 binary tests).
- `node --test reader/tests/rules.test.js` passes (7 tests).
- Quickshell BooksState tests pass (7 tests).
- Reader Python test invocation failed because the selected interpreter cannot import PySide6. A follow-up interpreter probe was blocked by the tool's approval timeout; do not retry that probe without fresh authorization. Keep this gate explicitly blocked unless the user authorizes another environment check.
- mg-bookr has pre-existing uncommitted changes in README.md, src/main.rs, src/store.rs, and src/tui/*.rs. The dotfiles repository has broad unrelated dirty work, including shell.qml; target BooksPanel/Books service files were clean at baseline. Preserve all of it.
