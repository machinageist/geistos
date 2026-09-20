# geistos — prep notes for a future Arch package

Status: notes, not a decision. Nothing here is committed to a shape yet.

`geistos` now exists as a repository at `~/geistos`, holding the Hyprland and
Quickshell configuration. This suite lives inside it at `~/geistos/mg-suite` and
remains a separate repository, ignored there. The installer described below is
still unwritten.

The goal is one downloadable thing that installs the Geist application suite and
its Hyprland/Quickshell integration together, in the spirit of Omarchy. These are
the constraints a packager will hit, gathered while renaming the suite and
repairing the shell integration on 2026-09-05.

Worth knowing up front: Omarchy is not itself a pacman package. It is a git repo
you clone, with an installer that pins versions and pulls packages. A PKGBUILD is
a different and heavier commitment — it is listed here because that is the
direction these notes were asked for, but the two are not the same product.

## What has to ship

Eight repositories, seven of them Rust applications and one config tree.

| Component | Builds to | Runtime needs |
|---|---|---|
| `mg-briefr` | `mg-brief` | SQLite (bundled via rusqlite) |
| `mg-vaultr` | `mg-vault`, `mg-vault-indexd` | User Markdown vault; disposable SQLite index |
| `mg-planr` | `mg-plan` | SQLite (bundled) |
| `mg-calr` | `mg-calr` | SQLite (bundled) |
| `mg-remindr` | `mg-remindr` | SQLite (bundled) |
| `mg-contactr` | `mg-contacts` | SQLite, holding only ciphertext |
| `mg-calcr` | `mg-calcr` | No external service; bounded local expression/graph engine |
| `dotfiles` | config tree | Hyprland, Quickshell, ghostty, python3 |

## Build

- Rust **1.85 or newer**; four crates are edition 2024.
- `rusqlite` with `bundled` compiles SQLite from source, so a C toolchain is a
  makedepend. `mg-vaultr` is a workspace with five member crates.
- No test needs a server or an opt-in variable any more: every storage test
  takes a store in a throwaway directory, so `check()` runs the whole suite.
- Every repo is clean under `cargo fmt --check` and
  `cargo clippy --all-targets --all-features -- -D warnings`. Keep that as the
  package's own gate.

## The hard parts

These are the things that will actually bite, in rough order of severity.

**Licensing is settled: MIT.** Every repository carries a `LICENSE` file and
declares `MIT` in its manifest. `mg-vaultr`'s packaging spec still describes the
MIT-versus-Apache-2.0 question as open; that spec predates the decision.

**There is nothing left to provision.** Every application keeps one SQLite file
under `$XDG_DATA_HOME`, so a clean machine goes from clone to a working suite
with no server, role or database to create. `mg-calr init` still diagnoses only,
and opening a store never migrates it.

**Migrations are explicit and user-run.** The applications embed checksummed,
append-only migrations and verify the live schema before applying anything
pending. `mg-remindr migration apply` and `mg-calr database migrate` are user
actions. An upgrade path needs to tell the user when a new version ships
migrations, the way Omarchy's migration steps do — it must not run them silently.

**User data lives in XDG directories the package cannot own.** Config at
`~/.config/<app>/`, data at `~/.local/share/<app>/`. A package owns `/usr/bin`
and shipped defaults only.

**The dotfiles tree installs by symlink today.** `dotfiles/scripts/install.sh`
has a dry-run/apply model that links into `$HOME` and `$HOME/.config` with
timestamped backups, and `~/.config/quickshell` is a symlink into the repo. A
package that writes those paths directly would fight it. Decide whether geistos
owns the config or defers to that installer — do not do both.

**A renamed interop producer invalidates the stored projection.** Learned the
hard way during the mg-remindr rename: `mg-calr` validates the *existing* store
before replacing it, so a projection written under an old producer name refuses
its own replacement. The store is disposable — delete
`~/.local/share/mg-calr/todo-projection.json` and re-run the sync bridge. Any
upgrade that changes interop identity needs that as a migration step.

## Open questions

- **Binary names collide with common words.** `mg-*` prefixing avoids this, but
  `mg-vault` is close to HashiCorp Vault's `vault`. Probably fine; worth a check
  before claiming a package name.
- **One package or a split?** `geistos` metapackage plus `geistos-apps` and
  `geistos-shell` would let someone take the applications without the desktop.
  The applications genuinely do stand alone; the shell integration does not.
- **Where do the bridge scripts live?** `dotfiles/scripts/geist-*` are the seam
  between Quickshell and the CLIs. They resolve binaries through `MG_*_BIN`
  environment variables with `~/geistos/mg-suite/...` debug-build defaults — that default
  is a development path and must become the installed path in a package.
- **Where does `mg-calcr` live?** Both production calculator surfaces currently
  resolve `MG_CALCR_BIN` or a checkout `target/debug/mg-calcr`. Packaging must ship
  the pinned release binary and set one installed-path contract; a development
  artifact is not a distributable runtime dependency.
- **Versioning.** Seven independently versioned repos, all at 0.1.0. A
  distribution needs one version that pins a set, which is the manifest idea from
  the orchestrator shape.

## Loose ends noticed nearby

- `~/gauntlet-universal/` still exists at home level. The copies vendored inside
  `mg-calr` and `mg-vaultr` were removed; this one was left alone.
- The retired PostgreSQL databases `mg_todo` and `mg_calr` still exist on this
  machine, with the rows they held before the move. Nothing reads them; they are
  kept until the SQLite stores have been lived with, then can be dropped.
