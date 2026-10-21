<!--
Description: Local contract for importing a folder of books as one reading list.
Basis: User request and interview on 2026-10-21; implementation details below are safe defaults.
-->

# mg-bookr collection import

## Problem statement

Reading lists get assembled as folders of books — mostly symlinks into `~/books`, sometimes real
files that are not in the library yet (`~/reading-hub/books/ccna-weekly/`). Turning one into an
mg-bookr list today means scanning, looking up each id by hand and running `collection add-many`,
and a new file has to be renamed and filed under `texts/<Subject>/` by hand first.

## User-facing contract

`mg-bookr collection import <dir> [--subject <name>] [--dry-run]`

- The list is named after the folder (its last path component). It is created when missing; when
  it exists, members not already in it are appended. Re-running is idempotent.
- Only the folder's direct entries are read, in natural name order; hidden entries are ignored.
  An entry is a regular file or a symlink to one with an ebook extension (epub, pdf, cbz, cbr).
  Anything else — a directory, a broken link, a non-ebook — is reported as skipped, never an error.
- Each entry resolves (following symlinks) to one of:
  - **shelved**: the file already lives under the books root. Used as is; nothing on disk changes.
  - **duplicate**: same size and SHA-256 as a file under the books root. The entry is replaced by a
    symlink to that library file. Identity is by content only — never by title or author.
  - **imported**: new to the library. Filed at `texts/<Subject>/<conventional name>` and the entry
    is replaced by a symlink to it. A real file in the folder is moved; a symlink's target outside
    the folder is copied and left in place.
- Conventional name: `<last>-<first and middle>[-et-al]-<year|undated>-<title>.<ext>`, lower-case
  ASCII words joined by hyphens: accents folded, apostrophes dropped, `+` → `plus`, `&` → `and`,
  an `Nth edition` moved to the end, at most 180 characters. Author and title come from the
  book's metadata (falling back to `unknown` and the file name); the year from the EPUB's
  `dc:date`, else a standalone 19xx/20xx in the file name, else `undated`.
- Subject: `--subject` names an existing folder under `texts/`. Without it, the subject holding
  most of the list's shelved and duplicate books is used; with none, or a tie, the command fails
  and names the subjects.
- A destination name already taken — on disk or by another book in the same import — is skipped
  with a reason, never overwritten.
- `--dry-run` reports the same plan and changes nothing: no file moves, links, scan or list.
- After the file changes, an ordinary incremental scan records new books before the list is built.

## Safety

- Validate the list name and the subject before touching any file.
- Never clobber: library files are placed with a hard link (or a copy then hard link across
  file systems), which fails if the name exists. Entries are replaced by renaming a fresh symlink
  over them, so a failure leaves either the old entry or the new link, never neither.
- Only a SHA-256-verified duplicate's bytes are removed from the folder.

## Out of scope

- Recursing into subfolders, audiobooks, title/author fuzzy matching, editing scanned metadata.
- Renaming or re-filing books already in the library.
