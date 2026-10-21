<!--
Description: Dependency-ordered implementation and verification plan.
-->

# mg-bookr collection import plan

1. Metadata: give `Meta` the EPUB's separate creators and its `dc:date` year. Verify: meta tests.
2. Naming: `import::library_name` builds the conventional file name. Verify: unit tests drawn from
   `~/books/texts/RENAME_LOG_*.txt` (multiple authors, "Last, First", editions, `+`, accents,
   undated, length cap).
3. Planning and filing: classify entries (shelved / duplicate / new / skipped), infer or check the
   subject, place new files without clobbering, link entries back. Verify: temp-root tests for
   dry run (nothing changes), a real run, a re-run (idempotent), subject errors.
4. Lists: scan, resolve ids by `(root, path)`, create the list and append members. CLI
   `collection import` with text and JSON output. Verify: CLI parse test, end-to-end temp test.
5. Docs: README command line and paragraph. Gates: `cargo fmt --check`,
   `cargo clippy --locked --all-targets -- -D warnings`, `cargo test --locked`. Then a dry run
   against `~/reading-hub/books/*` with the real library, read-only.

## Baseline recorded before feature edits (2026-10-21)

- Strict Clippy and `cargo test --locked` pass on the inherited dirty tree (54 library, 3 binary).
- `cargo fmt --check` fails at `src/store.rs:547`, in the inherited uncommitted diff.
- mg-bookr carries the uncommitted books-library-gui work; it is built on, not committed.
