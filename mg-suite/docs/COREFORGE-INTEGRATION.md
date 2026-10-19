# mg-coreforge ↔ Geist Suite Integration Plan

**Status:** Draft architecture and implementation plan
**Created:** 2026-09-01
**Update when:** Geist features are fully implemented, interop contracts stabilize, or Coreforge's curriculum/diagnostic model changes materially.

## Purpose

Integrate `~/mg-coreforge` and `~/mg-coreforge/bootcamp` into the Geist digital-brain suite without creating a second copy of the curriculum or a second planning authority.

Coreforge remains authoritative for curriculum content and operational evidence. Geist becomes the structured reasoning layer around intent, knowledge, scheduling, evidence, and verification.

```text
mg-coreforge
  curriculum, notes, labs, diagnostics, project artifacts
        ↓ references and evidence envelopes
mg-plan
  objectives, dependencies, criteria, decisions, verification
        ↓ scheduling intent
mg-calr
  actual calendar allocation and conflicts
        ↓
execution in Coreforge, homelab, shell, Git repositories
        ↓
evidence references and completion judgments
        ↓
mg-vault
  durable own-words explanations, concepts, claims, conclusions
```

## Authority boundaries

- Coreforge owns the curriculum, lesson/lab structures, hand-written study notes, diagnostics, and lab/project records.
- Git repositories remain authoritative for source code, commits, and repository state.
- Homelab and infrastructure systems remain authoritative for operational state and raw evidence.
- `mg-brief` owns acquired external sources, revisions, observations, provenance, and advisories.
- `mg-vault` owns user-authored knowledge: own-words explanations, concepts, interpretations, claims, citations, and conclusions.
- `mg-plan` owns plans, work items, dependencies, acceptance criteria, plan-scoped decisions, evidence references, verification attempts, and completion judgments.
- `mg-calr` owns calendars, events, time blocks, recurrence, availability, and conflicts.
- `mg-contacts` owns sensitive relationship records for employers, mentors, professors, references, and collaborators.
- Search and dashboard data are disposable projections.
- AI proposes; deterministic domain code and explicit user approval commit durable changes.

Do not make `mg-vault` a mirror of all Coreforge Markdown. Do not make `mg-plan` own calendar events, Git state, raw evidence, or another application's database.

## Coreforge source artifacts

The initial Coreforge authority set is:

- `~/mg-coreforge/bootcamp/COMPETENCY_MODEL.md`
- `~/mg-coreforge/bootcamp/DIAGNOSTIC-2026-09-01.md`
- `~/mg-coreforge/bootcamp/STUDY_ORDER.md`
- `~/mg-coreforge/bootcamp/SCHEDULE_CONSTRAINTS.md`
- `~/mg-coreforge/bootcamp/ROADMAP.md`
- `~/mg-coreforge/bootcamp/CERT_PLAN.md`
- `~/mg-coreforge/bootcamp/subjects/*/labs/`
- `~/mg-coreforge/curriculum/`

Important current learning priorities:

1. Networking foundations and troubleshooting: Ethernet → MAC → switching → ARP → IPv4 → subnetting → routing → gateway → VLANs → DNS/DHCP → Linux networking → firewalls → troubleshooting.
2. Cybersecurity foundations before advanced exploitation: AuthN/AuthZ, CIA/risk, least privilege, cryptography, sessions, SQLi/XSS/CSRF concepts, recon methodology, and owned-lab practice.
3. Rust: ownership → borrowing → references → mutable borrowing → collections → `Option`/`Result` → error handling. Move semantics is a demonstrated strength; borrowing and error handling are not yet demonstrated.
4. Linux/systems reinforcement through the RHEL fleet, systemd, journald, permissions, LVM, SELinux, podman, storage, and troubleshooting.
5. Mathematics: maintain calculus; repair vectors, matrices, variance, standard deviation, logarithms, z-scores, and anomaly reasoning.
6. AI/ML: approximately one focused block/week on model mechanics and classification metrics; no premature advanced-platform expansion.

RHCSA (EX200) is the only pre-employment exam. CCNA (200-301) and Security+ (SY0-701) are employed-time objectives. Network+ is not an active exam target, but its foundational networking material remains important.

## Typed Coreforge references

The integration should use stable, revision-aware references rather than copied records.

Conceptual reference shape:

```text
repository: mg-coreforge
path: bootcamp/COMPETENCY_MODEL.md
revision: <git commit or content fingerprint>
artifact_type: competency-model
provenance: coreforge
```

Possible URI form:

```text
coreforge://bootcamp/COMPETENCY_MODEL.md
coreforge://curriculum/03-networking-fundamentals/...
```

The exact URI syntax remains open, but references must be:

- repository-qualified
- path-specific
- revision-aware
- type-labeled
- provenance-preserving
- safe to resolve without granting mutation authority

## mg-plan integration

`mg-plan` is the natural home for curriculum execution and competency control.

Represent Coreforge objectives as structured plan items rather than generic tasks. A plan item may contain:

- stable objective or competency ID
- title and domain
- source references
- prerequisite IDs
- current demonstrated level
- failure classification
- next learning objective
- suggested mode: LAB, TEXT, REPS, or TEST
- acceptance criteria
- evidence references
- latest assessment observation
- remediation and retest links

The current `mg-plan` kernel already owns plans, work items, dependencies, acceptance criteria, evidence references, verification attempts, and completion judgments.

### Recommended future domain types

Add a narrow competency/assessment slice after proving the first end-to-end path:

```text
Competency
- id
- title
- domain
- target level
- current demonstrated level
- status
- prerequisite IDs
- source references
- next objective

AssessmentObservation
- competency_id
- assessment_id
- confidence_before
- demonstrated_result
- failure_class
- evidence_ref
- remediation_plan_id
- retest_ref
```

Failure classes must distinguish:

- syntax/recall
- conceptual
- mental-model
- operational
- diagnostic/troubleshooting
- transfer

Do not raise a competency level because a note was created or a task was checked. Require an explanation, successful lab, troubleshooting result, transfer task, or verified project artifact.

## mg-vault integration

`mg-vault` should receive durable knowledge after study, lab, or assessment work produces something worth retaining.

A vault note should preserve:

- own-words explanation
- source references
- observed evidence
- misconception corrected
- related concepts
- unresolved question
- confidence calibration
- next review or plan reference

Example note topic:

```text
ARP: destination resolution at the L2/L3 boundary

Source references:
- mg-coreforge/bootcamp/COMPETENCY_MODEL.md
- mg-coreforge/bootcamp/DIAGNOSTIC-2026-09-01.md
- networking curriculum unit
- packet-capture evidence

Own-words explanation:
...

Misconception corrected:
Same-subnet traffic was initially believed to traverse a router.

Observed evidence:
...

Open question:
How does proxy ARP alter this simplified model?
```

Coreforge's existing distinction remains useful:

- source/reference material
- personal explanatory notes
- exercises/reps
- labs
- assessments
- project artifacts
- conclusions/lessons learned

Do not copy textbook content or entire curriculum files into the vault.

## mg-calr integration

`mg-plan` should issue scheduling intent; `mg-calr` should allocate actual time.

Conceptual scheduling request:

```text
objective: networking.arp-gateway-path
mode: LAB
duration: 2h
preferred_windows: mid-morning or late evening
recovery_after: 60m
priority: high
flexibility: movable
deadline: before Saturday assessment
```

`mg-calr` must inspect:

- existing events
- immovable commitments
- available windows
- recovery requirements
- recurring maintenance
- conflicts
- Sunday light-day constraints

The calendar is authoritative for when life is possible. It must not rewrite curriculum priorities.

## mg-brief integration

Use `mg-brief` for changing external material:

- official RHCSA, CCNA, and Security+ objectives
- RFCs
- official Linux and vendor documentation
- changing security advisories
- CVEs affecting homelab software
- role and employer research

Coreforge remains an internal curated curriculum source, not an acquired external source.

## mg-contacts integration

Use `mg-contacts` for sensitive structured relationship data:

- employers
- mentors
- professors
- references
- recruiters
- OSS collaborators
- interviewers

Store relationship status, consent, interaction history, next action, and Coreforge references. Do not copy all career notes into contacts. Sensitive data remains encrypted/classified according to `mg-contacts` policy.

## Project graph

Projects should be represented as capability-producing plans rather than merely repository names.

Existing project relationships:

- Proxmox cluster → Linux, networking, storage, troubleshooting, backup/restore, documentation.
- `machinageist.dev` / `mg-server` → Rust/Axum, systemd, HTTP/TLS/DNS, deployment, security headers, troubleshooting.
- Network/DNS foundation lab → Ethernet, switching, ARP, VLANs, DNS/DHCP, packet capture, troubleshooting.
- RHEL fleet lab → Linux, LVM, SELinux, podman, systemd, backup/restore, Ansible.
- Hardening/monitoring lab → security foundations, firewall concepts, authentication, logs, detection, incident workflow.
- `mg-logbook` → incident documentation and ticket reasoning.
- `mg-health` → Rust, monitoring, error handling, operational automation.
- `mg-netnotes` → Rust, networking, diagnostic snapshots, evidence generation.
- GeistScope → carefully scoped local/authorized security learning; not automatic evidence of cybersecurity mastery.

Use many-to-many relationships:

```text
project → produces evidence for → competency
project → requires → competency
project → references → repository artifact
project → yields → publication candidate
```

Each competency still needs separate acceptance criteria. Project completion must not automatically complete every connected competency.

## First end-to-end vertical slice

Prove this path with one objective before importing the whole curriculum:

```text
Coreforge objective
    ↓
mg-plan work item
    ↓
acceptance criteria
    ↓
scheduling intent
    ↓
mg-calr event
    ↓
real lab execution
    ↓
Coreforge lab record
    ↓
revision-pinned evidence reference
    ↓
mg-plan verification
    ↓
mg-vault own-words note
```

Recommended first objective:

```text
Networking — same-subnet versus different-subnet packet path
```

Acceptance criteria:

- explain same-subnet ARP
- explain gateway ARP
- identify source/destination MAC addresses
- identify source/destination IP addresses
- perform one controlled observation
- document the result in own words
- answer one novel transfer question without notes

Then exercise the architecture with:

```text
Rust — borrowing and mutable references
Linux — systemd, journald, and service failure diagnosis
```

These test LAB, TEXT, REPS, TEST, evidence, remediation, and knowledge retention.

## Saturday feedback loop

The Saturday process should produce:

```text
assessment result
→ failure classification
→ remediation plan
→ retest result
→ competency update
→ next-week allocation proposal
```

Every assessment observation should preserve:

- prompt
- response or performance record
- confidence before response
- result
- failure class
- evidence reference
- remediation
- retest result
- allocation consequence

## Recommended implementation order

1. Define a stable Coreforge reference and provenance format.
2. Build a read-only Coreforge adapter for the competency model, diagnostic, study order, schedule constraints, and selected lab files.
3. Produce validated proposal envelopes rather than mutating Geist databases automatically.
4. Add a narrow competency-observation model to `mg-plan`.
5. Implement one approved Coreforge objective → `mg-plan` item flow.
6. Add scheduling-intent export to `mg-calr`.
7. Add revision-pinned evidence receipts after lab execution.
8. Add vault distillation after verified work.
9. Synchronize Saturday assessment results into remediation and next-week allocation proposals.
10. Add broader project mapping, external-source enrichment, contacts, and publishing projections only after the first path is reliable.

## Non-goals

- importing every Coreforge Markdown file into the vault
- maintaining duplicate curriculum text in Geist
- allowing AI output to become authoritative without review
- allowing calendar events to determine curriculum priority
- marking skills complete from project existence or note creation
- making `mg-plan` own Git, CI, raw evidence, calendar events, or infrastructure state
- expanding `mg-remindr` instead of completing the migration toward `mg-plan`
- building advanced scheduling, generalized workflow automation, or a central omnipotent agent before the narrow path works

## Completion gates for the integration

The integration is not complete until the following are demonstrated:

- Coreforge references resolve by repository, path, and revision.
- A plan item can be created from a validated Coreforge proposal.
- Dependencies and acceptance criteria survive round-trip serialization.
- Scheduling intent reaches `mg-calr` without granting it curriculum authority.
- Existing calendar conflicts remain visible and are not silently overwritten.
- A real Coreforge lab produces an evidence reference that is revision-pinned.
- `mg-plan` can verify criteria without owning the raw evidence.
- A verified result can produce an own-words `mg-vault` note with provenance.
- A failed assessment creates a typed remediation and retest path.
- AI-generated proposals cannot mutate durable state without deterministic validation and explicit approval.
- Missing, stale, conflicting, and unavailable source/evidence states remain visible.

## Open decisions to resolve later

- Canonical URI syntax for Coreforge references.
- Whether competency observations live directly in `mg-plan` or in a narrow companion domain projected into it.
- Git commit versus content fingerprint versus both for evidence revision identity.
- Exact interop envelope names and versioning policy.
- Whether Coreforge should expose a generated machine-readable manifest or the first adapter should parse Markdown directly.
- How privacy classification propagates from Coreforge artifacts into vault, plan, contacts, and calendar projections.
- How assessment records are signed or otherwise protected against accidental retroactive mutation.

Until these decisions are resolved, prefer read-only adapters, explicit proposals, revision-pinned references, and small verified slices.
