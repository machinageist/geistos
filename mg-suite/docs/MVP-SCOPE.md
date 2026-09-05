# Geist Suite MVP Scope

Status: MVP scope complete; implementation and integration verified

Purpose: keep agents focused on the smallest useful, operable version of each repository. This document is a scope fence, not a complete roadmap. Build the MVP first; add capability only after the MVP can be used end to end.

Current implementation status: `mg-vault`, `mg-plan`, `mg-brief`, and `mg-contacts` have
their scoped MVP behavior and quality gates implemented. `mg-calr` has the scoped behavior,
contract coverage, and disposable PostgreSQL persistence verification. The suite has a
read-only status/launcher surface and explicit projection refresh in the Quickshell bar.

## Suite rule

A repository is MVP-complete when a user can perform its core job from the CLI, close the process, reopen it, and still find the authoritative result. Tests must cover the happy path, restart/persistence, invalid input, and the most important safety boundary.

Do not build a dashboard, service, plugin system, generalized event bus, shared writable suite database, AI mutation authority, or broad synchronization layer to make an MVP feel complete.

## Recommended delivery order

1. mg-vault: dependable user-owned knowledge files and basic search.
2. mg-todo / mg-plan: dependable commitments and work-item state.
3. mg-calr: dependable events and day agenda.
4. mg-brief: dependable source/CVE catalog and provenance-preserving findings.
5. mg-contacts: dependable encrypted local contacts.
6. Cross-application projections and receipts only after the individual authorities are usable.

The order is practical, not a requirement that every repository wait for the previous one. Agents may work in parallel only when they do not change the same authority or interoperability boundary.

## 1. mg-vault

Repository: `~/mg-suite/mg-vaultr`

### MVP promise

A user can register a Markdown vault, create and edit notes safely, recover trashed notes, and search the vault without the index becoming the source of truth.

### Required MVP behavior

- Register, list, and select a vault.
- Enforce vault confinement: reject traversal, symlink escape, collisions, and protected application paths.
- Create, read, and replace Markdown notes.
- Require an expected source fingerprint for replacement and fail on stale writes.
- Move a note to vault-local trash and restore it without overwriting an existing note.
- Rebuild a disposable index, report whether it is current/stale/degraded, and provide deterministic basic text/title/path search.
- Provide stable JSON output for automation.
- Export a deterministic snapshot of the current source files.

### Explicitly not required for MVP

Watcher daemon, IPC/service lifecycle, TUI/editor, rich Markdown AST, headings/blocks/properties/tags/tasks projection, FTS, fuzzy/regex query grammar, backlinks/refactoring, Canvas, plugins, AI, sync, and publishing.

### Done means

A scripted session can register a temporary vault, create a note, read it, update it with the correct fingerprint, reject a stale update, trash/restore it, rebuild/search, restart the binary, and obtain the same source-backed result. Security tests prove that unsafe paths cannot escape the vault.

## 2. mg-todo compatibility surface / mg-plan authority

Repositories: `~/mg-suite/mg-remindr` and `~/mg-suite/mg-planr`

### Product decision

`mg-plan` is the product. `reminders` is the existing `mg-todo` authority and migration/compatibility surface. Do not create two competing task products. Preserve existing IDs and compatibility exports while moving consumers to plan-native vocabulary.

### MVP promise

A user can create a project and work items, organize prerequisites, move work through lifecycle states, record acceptance criteria and verification, and see what is blocked or still lacks proof.

### Required MVP behavior

- Create, show, list, and persist a plan/project.
- Add work items with stable IDs and deterministic ordering.
- Add prerequisites and reject missing references and dependency cycles.
- Start, block, unblock, revise, and complete work items through domain validation.
- Add acceptance criteria.
- Record a verification attempt against an exact subject revision with producer-owned evidence references.
- Report typed verification gaps: missing, failing, stale, or missing evidence.
- Reject stale writers using optimistic revision checks.
- Export/import a versioned `mg.plan/1` JSON envelope with producer identity and conflict-safe revision checks.
- Preserve the current `mg-todo` CLI/projection long enough for verified migration.

### Explicitly not required for MVP

Live calendar adapters, automatic completion, Git/CI adapters, raw evidence storage, execution orchestration, generalized workflow automation, dashboards, synchronization, missions/portfolios, and extraction into a separate lab/review product.

### Done means

A scripted session can create a plan, add dependent work, demonstrate blocked state, add criteria, record passing and stale verification, show the resulting gap, complete only when the rules allow it, export/import, restart, and prove that a stale writer cannot overwrite newer state. The same test must identify which repository owns each piece of data.

## 3. mg-calr

Repository: `~/mg-suite/mg-calr`

### MVP promise

A user can create calendars and events, inspect a reliable day agenda, and cancel/restore events from a keyboard-friendly local application backed by PostgreSQL.

### Required MVP behavior

- Diagnose configuration and database readiness without sudo or implicit provisioning.
- Apply idempotent embedded migrations with drift detection.
- Create/list calendars.
- Create timed and all-day events with explicit timezone/date semantics.
- List/show events, query a day agenda, edit events with optimistic locking, and cancel/restore them.
- Provide the bounded keyboard-first agenda shell already present, but do not expand it into a full desktop application.
- Export/import calendar/event data transactionally and deterministically.
- Read `mg-todo` only through a validated imported projection; never read the sibling database directly.

### Explicitly not required for MVP

Event recurrence/exceptions, iCalendar fidelity, vdirsyncer/iCloud synchronization, reminder delivery services, bulk editing, search, backup/restore, packaging, or a feature-complete TUI.

### Done means

Against a disposable local PostgreSQL database, a scripted session can migrate, create a calendar, create timed/all-day events, query a timezone-aware agenda, edit with a correct version, reject a stale edit, cancel/restore, export/import, restart, and reproduce the same results. Projection import must reject invalid, stale, or conflicting todo snapshots and replace the file crash-safely.

## 4. mg-brief

Repository: `~/mg-suite/mg-briefr`

### MVP promise

A user can collect external source artifacts and inspect current/historical CVE records and installed-asset observations with provenance that can be explained and rechecked.

### Required MVP behavior

- Register named RSS/Atom sources and list them.
- Fetch with bounded bytes and timeout, retaining the source artifact and provenance.
- Export a deterministic interop snapshot.
- Ingest CVE 5 JSON and the validated internal CVE envelope.
- Query the current record and bounded history for a CVE ID.
- Import, list, and inspect immutable assets and observations, including freshness/status and correction history.
- Validate identifiers, timestamps, provenance, locators, input sizes, and redaction rules before persistence or export.
- Make repeated imports idempotent and reject immutable conflicts.

### Explicitly not required for MVP

A full vulnerability scanner, automatic remediation, exploit execution, vendor-specific enrichment, web dashboard, alerting service, broad hardware inventory extraction, probabilistic risk scoring, or AI-generated conclusions without cited source records.

### Done means

A fixture-driven session can register/fetch a source using bounded network behavior, ingest a CVE fixture, retrieve current/history records, import an asset observation, inspect freshness, replay the same input idempotently, reject a conflicting record, and export redacted provenance. Network access must be explicit rather than hidden in unrelated commands.

## 5. mg-contacts

Repository: `~/mg-suite/mg-contactr`

### MVP promise

A user can keep a small local address book whose sensitive fields are encrypted at rest and whose key/passphrase lifecycle fails closed.

### Required MVP behavior

- Resolve XDG paths and accept only local PostgreSQL/Unix-socket configuration if a database is used.
- Set up an encrypted user-held key, report status, and verify a passphrase for the current process only.
- Create, read, list, update, and soft-delete a contact with a stable identifier.
- Encrypt sensitive fields with authenticated encryption and zeroize plaintext/key intermediates.
- Keep ordinary/non-sensitive indexing opt-in and fail closed by default.
- Append an audit record for successful mutations without exposing private payloads.
- Provide deterministic, redacted CLI output and clear nonzero errors for locked, invalid, or missing data.

### Explicitly not required for MVP

Organizations, relationship graphs, astrology/esoteric records, synchronization, imports, digests, sharing, contact discovery, background key agents, full-text indexing of sensitive fields, or a UI.

### Done means

A scripted session can initialize the key, create and retrieve a contact in one authenticated process, demonstrate that a fresh process is locked, update and soft-delete the contact, reopen the store, verify that ciphertext—not plaintext—is persisted, and inspect an audit trail without leaking private values. Wrong passphrases and unauthorized plaintext indexing must fail closed.

## Agent operating rules

1. Start from the smallest vertical slice that satisfies one MVP requirement.
2. Read the current implementation before changing scope; existing code is evidence, not permission to expand the roadmap.
3. Keep authority explicit. A projection, cache, index, export, or receipt must not become a second source of truth.
4. Preserve stable IDs, versions, migrations, and compatibility surfaces unless a deletion checkpoint explicitly authorizes removal.
5. Prefer a narrow CLI and behavior tests over a UI, service, or abstraction layer.
6. Every feature proposal must name its user-visible workflow and its non-goals.
7. Do not add “future-proof” generic frameworks, plugin systems, or cross-suite infrastructure to an MVP.
8. For security, persistence, concurrency, and interoperability changes, add the failure-path test before broadening the implementation.
9. Stop when the relevant “Done means” workflow passes. Record deferred ideas under a later milestone instead of implementing them opportunistically.
10. Report scope honestly: foundation, partial MVP, or MVP-complete. A green unit-test suite is not proof of an operable end-to-end product.

## Shared acceptance bar

Every MVP release candidate must have:

- a documented install/run command;
- one copy-paste happy-path walkthrough;
- restart/persistence coverage;
- invalid-input and important safety-boundary coverage;
- deterministic machine-readable output where automation is expected;
- focused tests plus repository quality gates;
- no new warnings, unreviewed authority duplication, or unrelated refactor churn.

## 6. Suite status and desktop integration

### Product decision

The individual applications remain the authorities. The suite surface is a read-only
projection and launcher; it must never become a shared database, a second task/calendar
authority, or an implicit mutation path.

### Required MVP behavior

- Expose a bounded, read-only status probe for each application.
- Report `ready`, `unconfigured`, `locked`, `stale`, and `unavailable` states without leaking credentials, private paths, or sensitive records.
- Launch only existing, independently smoke-tested application artifacts through a stable wrapper.
- Provide a Quickshell bar pill and panel showing per-application status, supported capabilities, and explicit remaining scope.
- Permit refresh, repository inspection, and application launch without direct sibling-database access.
- Provide an explicit todo-to-calendar projection refresh that exports through `mg-todo` and imports through `mg-calr` validation; never synchronize by opening the sibling database.
- Keep status refresh bounded by time and output limits, with last-known-good state marked stale rather than presented as current.

### Explicitly not required for this slice

Cross-application mutation, a shared writable suite database, a central event bus, a
dashboard-owned workflow, background synchronization, automatic completion, or a
feature-complete desktop UI.

### Done means

The bar can refresh all five application probes, render truthful per-application states,
open each available application through its stable launcher, and explicitly refresh the
validated todo-to-calendar projection. It fails safely when a build artifact or local
backend is unavailable. The bridge, status script, and Quickshell configuration have
focused regression coverage and a clean reload with no new suite integration errors.

This document intentionally leaves polishing, optimization, deeper cross-application workflows,
and breadth for post-MVP bootstrap phases.
