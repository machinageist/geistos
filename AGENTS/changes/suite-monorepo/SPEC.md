# Suite monorepo — SPEC

## Outcome

The Geist suite lives in one repository. `geistos` tracks `mg-suite/` and every
application under it; the fourteen former repositories (`mg-suite` and thirteen
`mg-*` apps) are retired. A visitor to the GitHub profile sees one Geist repository
instead of fifteen.

## Acceptance criteria

- Each `mg-suite/<app>/` tree in `geistos` is byte-identical to that app's last `main`
  (git tree hash equal), and `git log -- mg-suite/<app>` lists every original commit.
- Branches with unmerged work survive as `<repo>/<branch>`: `mg-briefr/postgres-port`,
  `mg-planr/ticket/qs-n06-01-planr`.
- The on-disk layout does not change: `~/geistos/mg-suite/<app>/`, so relative path
  dependencies (`../mg-briefr`) and `bin/geist-install` keep working unedited.
- Uncommitted work in the old checkouts is carried into the new checkout uncommitted,
  file for file.
- Old repositories are made private and archived, not deleted, until the new layout
  has been used for a while.
- No document still describes the suite or its apps as separate repositories.

## Constraints

- The push to `geistos` is a fast-forward of `origin/main`; no force push.
- Nothing is deleted on GitHub by this change.
- The Quickshell/Hyprland copy in `config/` has drifted from `~/dotfiles` (the live
  config); resolving that is out of scope here.
