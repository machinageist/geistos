# Geist Suite — Consolidated Post-MVP Roadmap

Status: planned post-MVP bootstrap roadmap.

All five current repository MVPs have passed their scoped gates:

- `mg-vault` — user-owned Markdown authority, safe note operations, trash/restore, disposable search index, and deterministic export;
- `mg-plan` / `mg-remindr` — plans, projects, work items, prerequisites, dependencies, recurrence, criteria, verification, evidence references, completion judgments, reminders, delivery state, and compatibility export;
- `mg-calr` / `calendar` — calendars, events, agenda behavior, optimistic locking, cancel/restore, import/export, and validated todo projection import;
- `mg-brief` — bounded source acquisition, CVE records and history, asset observations, provenance, immutable imports, and deterministic export;
- `mg-contacts` — encrypted local contacts, process-local authentication, CRUD, audit, soft deletion, and privacy safeguards.

The next work is post-MVP bootstrap work. It should not expand scope opportunistically or weaken the current authority boundaries. Integration begins only after each authority is independently usable.

## Recommended order

1. Typed cross-application reference and receipt path
2. `mg-plan` native cutover
3. `mg-vault` Milestone 2 runtime and structural depth
4. `mg-calr` post-MVP domain expansion
5. Verified cross-suite integration
6. Plan-native competency and assessment
7. Deliberate evidence capture
8. `mg-brief` monitoring and enrichment
9. `mg-contacts` hardening and extensions
10. `mg-dev` read-only adapters
11. Controlled publishing
12. Operational projections
13. Federated search and synchronization

Each phase remains independently gated. A phase is complete only after its behavior tests, restart/persistence tests, invalid-input and safety-boundary tests, strict quality checks, independent review, remediation, local commit, and clean working tree pass.

## Phase 1 — Typed cross-application reference and receipt path

### Objective

Close the first useful suite loop without introducing a shared writable database:

```text
mg-brief source
  -> mg-vault cited note
  -> mg-plan work item
  -> mg-calr schedule request/receipt
  -> execution evidence
  -> mg-plan verification/completion
  -> mg-vault retained conclusion
```

### Scope

Build only the contracts and narrow CLI/library flows needed for this path:

- Versioned reference and observation envelopes;
- stable identifiers and exact source revisions;
- brief-to-vault citations;
- vault-to-plan references;
- plan-to-calendar scheduling requests and accepted-event receipts;
- evidence references returned to `mg-plan`;
- idempotency keys and exact revision references;
- explicit rejection of stale, conflicting, malformed, or unauthorized requests and receipts;
- deterministic machine-readable output and restart-safe acceptance workflows;
- explicit states for missing, stale, conflicted, tombstoned, and unavailable targets.

### Authority boundaries

- `mg-brief` owns acquired sources, revisions, observations, and provenance.
- `mg-vault` owns user-authored knowledge and citations.
- `mg-plan` owns work, criteria, evidence references, verification, and completion judgments.
- `mg-calr` owns calendars, events, time allocation, and conflicts.
- Evidence producers own raw evidence; `mg-plan` stores references and judgments only.

### Non-goals

- No shared writable suite database.
- No generalized event bus.
- No automatic completion.
- No hidden cross-application mutation.
- No delivery implied by request acceptance.

### Completion evidence

The narrow reference path can be exercised end to end, survives restart, preserves exact revisions, and rejects stale, conflicting, malformed, or unauthorized inputs without mutating a sibling authority.

## Phase 2 — `mg-plan` native cutover

### Objective

Move the suite from the compatibility surface of `mg-remindr` toward the plan-native `mg-plan` vocabulary and contracts without breaking existing durable data or consumers.

### Scope

- Preserve existing project, todo, tag, relationship, and revision identifiers.
- Introduce and verify plan-native `work_item` APIs and projections.
- Preserve the existing `mg-remindr` CLI and producer contract during migration.
- Export compatibility and plan-native projections when their bytes or identities differ.
- Extend acceptance criteria, gates, verdicts, waivers, and verification-gap reporting.
- Keep verification pinned to exact subject revisions.
- Keep evidence producer-owned; store references and receipts rather than raw evidence.
- Migrate consumers only after their projection acceptance tests pass.

### Non-goals

- No shared writable suite database.
- No generic workflow or graph engine.
- No automatic completion without explicit verification rules.
- No AI-issued verdicts, waivers, or mutations.
- No raw evidence warehouse.
- No live calendar adapter in the authority layer.

### Completion evidence

A compatibility-preserving migration can create and inspect a plan-native work item, retain existing IDs, export both required representations, detect stale verification, reject stale writers, and prove that existing `mg-remindr` consumers still work.

## Phase 3 — `mg-vault` Milestone 2 runtime and structural depth

### Objective

Turn the current rebuildable vault index into a reliable local indexing runtime without making the index a source of truth.

### Scope

- Long-running watcher/service with reliable lifecycle behavior;
- versioned, stable local IPC protocol and client;
- bounded dirty queue;
- overflow detection and full-rebuild recovery;
- reconciliation scheduling and observable freshness transitions;
- structural projections for headings, blocks, embeds, tags, properties, and tasks;
- deterministic ambiguity-safe link and backlink projections;
- query foundations beyond basic substring search;
- scale, corruption, crash, and source-drift evidence.

The watcher, service, IPC, queue, and recovery behavior should land before rich structural projections. Projections must remain disposable and rebuildable from user-owned files. Markdown remains authoritative; indexes must be visibly stale or degraded when source observation is incomplete.

### Non-goals

- No TUI/editor in this phase.
- No plugin host, AI adapter, synchronization, publishing, Canvas, or Quickshell integration.
- No mutation authority in the service or index.

### Completion evidence

A service restart, source change, queue overflow, database deletion, interrupted rebuild, and IPC failure all recover without rewriting Markdown or publishing stale derived results.

## Phase 4 — `mg-calr` post-MVP domain expansion

### Objective

Extend the calendar domain and agenda experience after the MVP event and projection contracts are stable.

### Scope

- Broader todo/work-item projection support;
- richer event-domain and agenda behavior;
- recurrence and exception handling;
- more complete keyboard-first agenda and chooser behavior;
- operational diagnostics, backup, verification, and recovery;
- later: iCalendar import/export and synchronization.

Offline event and todo domain behavior comes before synchronization. Import/export and local reconciliation come before network transport.

### Non-goals

- No direct connection to sibling databases.
- No reminder-delivery service as an implicit calendar mutation path.
- No automatic work-item completion from calendar activity.
- No broad desktop application before local domain contracts are stable.

## Phase 5 — Verified cross-suite integration

### Objective

Connect the applications through explicit, versioned references and receipts while preserving federated authority.

### Scope

- `mg-plan` scheduling requests to `mg-calr` accepted-event receipts;
- `mg-brief` source, CVE, and asset references in `mg-plan` criteria and evidence records;
- `mg-vault` note and citation references in plan commitments and verification context;
- rebuildable suite projections for cross-application views;
- versioned observation envelopes separate from command/request envelopes;
- idempotency keys, acceptance/rejection receipts, and exact revision references;
- explicit states for missing, stale, conflicted, tombstoned, and unavailable targets.

Applications must never read or write sibling databases. Cross-repository integration uses validated snapshot exports/imports, request envelopes, immutable references, and receipts.

### Non-goals

- No central event bus.
- No shared writable suite database.
- No universal evidence lake.
- No dashboard-owned workflow.
- No delivery implied by request acceptance.

## Phase 6 — Plan-native competency and assessment

Do not create standalone `mg-lab` or `mg-review` applications yet. Add a narrow competency capability to `mg-plan`, or a dedicated module, only after the reference path is proven:

- competency/objective identifiers;
- demonstrated level;
- assessment observations;
- failure classifications;
- remediation and retest links;
- revision-pinned evidence;
- explicit criteria for increasing demonstrated ability.

Creating a note or checking a task must not automatically increase competency.

## Phase 7 — Deliberate evidence capture

Add producer-owned evidence tooling as modules or adapters:

- shell command result references;
- test and CI result references;
- Git commit and repository-state references;
- lab observation references;
- environment and timestamp metadata;
- immutable content fingerprints.

Raw evidence stays with its producer. `mg-plan` accepts validated references and records verification judgments.

## Phase 8 — `mg-brief` monitoring and enrichment

### Objective

Make source and advisory collection useful over time without hiding network access or weakening provenance.

### Scope

- scheduled source monitoring;
- feed lifecycle and source-health reporting;
- additional bounded source formats;
- broader advisory normalization;
- explainable advisory-to-asset matching;
- historical comparison and change notifications.

### Non-goals

- No automatic remediation.
- No exploit execution or vulnerability scanner.
- No unsupported probabilistic risk conclusions.
- No AI-generated conclusions without cited source records.
- No hidden network access in unrelated commands.

## Phase 9 — `mg-contacts` hardening and extensions

### Objective

Increase durability and audit assurance before adding contact breadth.

### Scope

- explicit durable audit-trail inspection;
- append-log compaction and recovery without plaintext exposure;
- atomic publication and corruption recovery;
- optimistic-concurrency behavior for updates;
- additional locked, malformed, and permission-failure tests;
- only later: imports, organizations, relationships, or synchronization.

### Non-goals

- No generic CRM.
- No shared identity database.
- No plaintext sensitive-field index.
- No synchronization before local authority and recovery are proven.

## Phase 10 — `mg-dev` read-only adapters

After the evidence protocol is stable, add adapters for:

- repositories;
- branches and commits;
- tests and CI;
- releases and hosting state.

Git and hosting providers remain authoritative. `mg-dev` must not mirror repositories or gain mutation authority.

## Phase 11 — Controlled publishing

Begin `mg-publish` as a vault workflow or module, not a standalone application:

- select approved vault material;
- preserve citations and provenance;
- run redaction checks;
- generate deterministic previews and exports;
- require explicit approval;
- retain source-to-publication traceability.

## Phase 12 — Operational projections

Add read-only operational views for:

- stale feeds;
- failed imports;
- index health;
- unavailable services;
- pending verification;
- schedule receipt failures;
- backup and maintenance state.

Start as an operational module or suite shell. It must not own or mutate another application's domain data.

## Phase 13 — Federated search and synchronization

Treat these as later infrastructure phases:

- federated search over exported projections;
- transport and conflict handling;
- optional synchronization adapters;
- disposable caches with rebuild behavior.

Synchronization must not become a second authority, and it must not require a shared writable suite database.

## Shared delivery gate

Every phase must provide:

1. A documented install/run command.
2. One copy-paste happy-path workflow.
3. Restart and persistence coverage where applicable.
4. Invalid-input and important safety-boundary coverage.
5. Deterministic machine-readable output where automation is expected.
6. Focused behavior tests and the repository's full quality gate.
7. Explicit authority ownership for every stored or referenced object.
8. Independent review and remediation of actionable findings.
9. No unrelated refactor churn or unreviewed scope expansion.
10. A small logical local commit.
11. A clean working tree.

The current architecture remains federated:

- `mg-brief` owns external sources, advisories, observations, and provenance.
- `mg-vault` owns user-curated knowledge and source files.
- `mg-plan` owns commitments, work structure, criteria, gates, and verdicts.
- `mg-calr` owns events, recurrence, time blocks, and scheduling responses.
- `mg-contacts` owns encrypted local contact records.

Projections, indexes, exports, and receipts are disposable or derived unless a contract explicitly assigns them authority. User-owned data remains authoritative.

The immediate implementation target is Phase 1: the smallest typed reference and scheduling-receipt workflow that connects already-complete authorities without turning any projection into a new source of truth.
