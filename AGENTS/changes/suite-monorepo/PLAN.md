# Suite monorepo — PLAN

Each task stops for review before the next. Tasks 3 onward need Jeff's go-ahead:
they publish, or they touch the live `~/geistos` checkout.

1. **Merge histories** — `git filter-repo --to-subdirectory-filter` per repo, then one
   `--allow-unrelated-histories` merge each into `geistos`. Done 2026-10-19 in scratch.
   → verify: tree hash per app equals the original `main^{tree}`; per-path commit
   counts equal the originals; the root of `geistos` and `mg-suite/` unchanged.
2. **Fix docs and ignores** — drop the `/mg-suite/` and per-app ignore rules; reword
   the READMEs and `GEISTOS-PACKAGING.md`. Done 2026-10-19.
   → verify: `cargo test --locked --all-targets` per app in the merged layout.
3. **Push** — `main`, `mg-briefr/postgres-port`, `mg-planr/ticket/qs-n06-01-planr`.
   → verify: `git merge-base --is-ancestor origin/main main` before pushing.
4. **Cut over the live checkout** — confirm no other session is working in `~/geistos`;
   clone the pushed repo to `~/geistos.merged`; for each old checkout with changes,
   `git diff --binary | git -C ~/geistos.merged apply --directory=mg-suite/<app>`;
   copy local-only state (`.sessions`, `qs-briefs`, `mg-suite/.claude/`,
   `mg-suite/.sessions`, `mg-suite/gititerate.sh`, `mg-planr/.tmp/`); then
   `mv ~/geistos ~/geistos.pre-merge && mv ~/geistos.merged ~/geistos`.
   → verify: `diff -r` of tracked files, old vs new, per app, shows no differences.
5. **Retire old repositories** — `gh repo edit --visibility private
   --accept-visibility-change-consequences` and `gh repo archive -y` for each of the
   fourteen. Deletion, if wanted, is a later manual step.
6. **Update inbound links** — `mg-server` links `github.com/machinageist/mg-suite` in
   `content/projects/mg-suite.md` and `src/models/project.rs`; point both at
   `github.com/machinageist/geistos/tree/main/mg-suite`.
