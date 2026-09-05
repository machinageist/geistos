# mg-suite

The Geist Suite: a local-first set of independent Rust applications for the
closed loop between finding something out and proving you acted on it.

```text
Discover → Understand → Decide → Plan → Schedule → Execute →
Capture Evidence → Verify → Learn → Publish
```

Every application owns its own domain data and runs on its own. Cross-application
integration uses stable identifiers, versioned envelopes, provenance, typed links,
and explicit request/receipt boundaries. No application reads or mutates another
application's database.

This repository is the umbrella: it holds suite-level documentation only. Each
application below is a separate Git repository with its own history and remote.

## Applications

| Directory | Binary | Owns | Storage |
|---|---|---|---|
| `mg-briefr/` | `mg-brief` | Registered sources, fetched artifacts, CVE records and history, immutable asset observations, provenance | SQLite |
| `mg-vaultr/` | `mg-vault`, `mg-vault-indexd` | Notes, concepts, claims, citations, knowledge relationships and revisions | Markdown files; disposable SQLite index |
| `mg-planr/` | `mg-plan` | Plans, work items, dependencies, acceptance criteria, evidence references, verification records, completion judgments | SQLite |
| `mg-calr/` | `mg-calr` | Calendars, events, time blocks, recurrence, availability, conflicts, external sync state | PostgreSQL |
| `mg-remindr/` | `mg-todo` | Todos, projects, tags, lifecycle and transition times; the projection `mg-calr` reads for its agenda | PostgreSQL |
| `mg-contactr/` | `mg-contacts` | Contact identity, encrypted fields, revisions, audit history, soft-delete state | Encrypted local store |

Directory names carry an `r` suffix; crate and binary names do not. The binary is
what you type.

### Boundaries worth stating

- **mg-brief** does not own curated knowledge, project work, task completion, or
  remediation. It explains and preserves provenance; it never remediates.
- **mg-vault** keeps Markdown as the authoritative representation. The index is a
  disposable projection and is never the source of truth.
- **mg-plan** owns verification judgments, not the facts inside the evidence. It
  does not own raw evidence, repositories, CI, or calendar events.
- **mg-plan** owns work and scheduling *intent*; **mg-calr** owns the resulting
  temporal allocation.
- **mg-todo** is a transitional authority retained for compatibility while planning
  ownership moves to mg-plan. Do not deepen this boundary without an explicit
  migration step.

## Build and test

Requires a Rust toolchain at **1.85 or newer** (several crates use edition 2024).
`mg-calr` and `mg-todo` additionally need a local PostgreSQL server; the rest are
self-contained.

Each application builds independently:

```sh
cd mg-vaultr
cargo fmt --check
cargo clippy --workspace --all-targets --all-features -- -D warnings
cargo test --workspace --all-targets --all-features
```

The PostgreSQL-backed applications keep their database tests opt-in, so a default
`cargo test` run needs no server:

```sh
# mg-calr
MG_CALR_RUN_DATABASE_TESTS=1 \
MG_CALR_TEST_DATABASE_URL=postgresql:///mg_calr_test \
TMPDIR=/dev/shm cargo test --test postgres_integration -- --ignored

# mg-remindr
MG_TODO_ALLOW_INTEGRATION_TESTS=1 TMPDIR=/dev/shm cargo test --all-targets
```

`mg-calr init` diagnoses configuration only. It never runs `sudo`, creates roles or
databases, or applies migrations; `mg-calr database migrate` applies schema
migrations explicitly.

Each application's README is the authority for its current implementation status
and exact verification commands.

## Suite integration

The one cross-application path in service today is the todo agenda projection:

```text
mg-todo interop export
  -> validated temporary snapshot
  -> mg-calr interop import-todo
  -> crash-safe todo projection used by the calendar agenda
```

The bridge invokes the two CLIs and never touches a sibling database directly. It
runs from `~/dotfiles/scripts/geist-sync-todo-projection`, or from the "Refresh todo
agenda" action in the Quickshell Geist panel. The script resolves binaries through
`MG_TODO_BIN` and `MG_CALR_BIN`, which is how you point it at this checkout.

## Authority rules

- One authority exists for every mutable domain object.
- References and revision-pinned projections beat copied records.
- Raw evidence stays authoritative at the system that produced it.
- Search and dashboard data are disposable projections.
- External Git, CI, calendar, infrastructure, and publishing systems remain
  authoritative for their own state.
- AI proposes; deterministic domain code and explicit user approval commit durable
  changes.
- No automatic vulnerability remediation is part of this suite.

## Development principles

- Build narrow verified slices, not empty application shells.
- Establish authority, identity, provenance, and revision semantics before broad
  integration.
- Prefer local libraries, CLIs, files, and explicit envelopes over microservices or
  event infrastructure.
- Treat stale, unavailable, partial, and conflicting state as visible states.
- Do not claim completion from a green-looking projection or an unverified artifact.

## First end-to-end acceptance path

The first meaningful cross-application path, most of which is still ahead:

1. Acquire a source in mg-brief.
2. Create a cited interpretation in mg-vault.
3. Create a plan item and acceptance criterion in mg-plan.
4. Request scheduled time through mg-calr.
5. Execute work in a repository, shell, or lab.
6. Capture a revision-pinned evidence reference.
7. Record verification and prove completion in mg-plan.
8. Return the result to mg-vault as retained knowledge.
9. Export approved vault material through the publishing workflow.

## Deferred capabilities

These start as modules, adapters, or projections rather than standalone
applications, and become an application only on earning an independent
authoritative domain, lifecycle, and operational reason to exist:

`mg-lab` (vault lab module plus evidence capture) · `mg-review` (split between vault
learning review and plan completion review) · `mg-dev` (repository and CI adapters)
· `mg-publish` (controlled export from mg-vault) · `mg-inbox` (shared capture
envelope and spool) · `mg-ops` (operational health views) · `mg-search` (rebuildable
federated index) · `mg-dashboard` (read-only shell with deep links) · `mg-sync`
(transport and conflict handling, not another datastore) · `mg-ai` (explicit domain
copilots, not a central agent) · `mg-secrets` (integration with an established
secret manager).

## Documentation

| Document | What it covers |
|---|---|
| [docs/MVP-SCOPE.md](docs/MVP-SCOPE.md) | The scope fence: the smallest useful version of each application, and what is explicitly not required |
| [docs/POST-MVP-ROADMAP.md](docs/POST-MVP-ROADMAP.md) | Phased post-MVP roadmap, each phase independently gated |
| [docs/COREFORGE-INTEGRATION.md](docs/COREFORGE-INTEGRATION.md) | How the suite layers over `mg-coreforge` without duplicating its curriculum or planning authority |

`mg-calr` and `mg-vaultr` additionally carry per-feature specs and blind review
scorecards under their own `docs/specs/` and `docs/reviews/`.

## Status

Every application has passed its scoped MVP gate: it does its core job from the
CLI, survives a restart with the authoritative result intact, and covers the happy
path, persistence, invalid input, and its most important safety boundary. mg-plan
and mg-todo were gated together as one planning surface during the transition.

The work ahead is post-MVP integration, starting with the typed cross-application
reference and receipt path.

## License

Not yet settled. `mg-brief` and `mg-plan` declare MIT in their manifests; the
remaining crates declare nothing, and the packaging specs record an open
MIT-versus-Apache-2.0 question. Treat every repository as all rights reserved until
a `LICENSE` file lands.
