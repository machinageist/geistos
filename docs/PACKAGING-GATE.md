<!--
Author: Jeff
Date: 2026-09-20
Description: Why distribution packaging has not started, and what has to be decided first
Notes: Jeff gated this on 2026-09-20: install locally for now, save packaging for later
-->

# Packaging — gated

**Do not start distribution packaging.** No PKGBUILD, no pacman, nothing that installs
outside `$HOME`. Jeff gated this deliberately on 2026-09-20; it needs his say-so to open,
not an agent's judgement that the time looks right.

What exists instead is `bin/geist-install`: it builds the suite from this machine's
checkouts and installs it for this user. That is enough to go from a clone to a working
suite, which is what the storage move was for.

## What is already decided

| Question | Decision |
|---|---|
| What to build from | This machine's checkouts under `mg-suite/`, recorded by commit in the install manifest |
| Where binaries go | `~/.local/bin` — per user, no sudo |
| Who owns the desktop config | `dotfiles/scripts/install.sh`. geistos installs binaries and units only, because two writers for one path is the failure the old notes warned about |
| User units | `systemd/*.service` here, with `@BINDIR@` resolved at install time |

## What a package would still have to answer

- **The application repositories are private.** A PKGBUILD that fetches
  `git@github.com:machinageist/mg-*` builds only for someone holding the keys. Either the
  repos go public, or the package ships a vendored tree.
- **One package or three?** `geistos` as a metapackage over `geistos-apps` and
  `geistos-shell`. The applications stand alone; the shell integration does not.
- **One version across seven repositories.** They are independently versioned, all 0.1.0.
  A distribution pins a set, which is what the install manifest is a first sketch of.
- **The bridge scripts still resolve development paths.** `dotfiles/scripts/geist-*`
  default to `~/geistos/mg-suite/<app>/target/debug/<binary>` and honour `MG_*_BIN`.
  That default is deliberate while the suite is being built daily; a package would have to
  make it the installed path, and the shell would then run release binaries rather than
  whatever was last `cargo build`ed. Changing it is a behaviour change on Jeff's desktop,
  so it waits for the same gate.
- **`mg-calcr` has the same seam**, in both calculator surfaces.

## Loose ends inherited from the old notes

- `~/gauntlet-universal/` still exists at home level; the vendored copies inside `mg-calr`
  and `mg-vaultr` were removed, this one was left alone.
- A renamed interop producer invalidates the stored projection: delete
  `~/.local/share/mg-calr/todo-projection.json` and re-run the sync bridge. Any upgrade
  that changes interop identity needs that as a migration step.
