# Rust Desktop Platform Plan

Status: Planning only; approved for continued refinement, not implementation.
Owner: Jeff
Created: 2026-10-11

This is the living product contract for an integrated Rust desktop platform and its eventual custom Linux distribution. It sits above, and does not replace, the separate `mg-suite` roadmap or GeistScope's current learning/MVP decisions.

## 1. Product direction

Build a lean, keyboard-first Linux workstation for developers, power users, and security researchers. The experience should be cohesive and expert-oriented, without unnecessary handholding. Its components remain independent products under the hood, sharing only code and contracts that produce clear efficiency, correctness, or usability gains.

Develop from the outside in:

1. Prove the user-space desktop and app integrations on the existing Arch installation as an opt-in session.
2. Replace selected desktop and workflow layers with Rust implementations after compatibility and performance gates pass.
3. Consider a custom Linux distribution only after the user-space system is stable.

The current direction retains the Linux kernel and ordinary Linux application compatibility. A custom kernel is not in scope.

## 2. Success criteria

Primary optimization: reduce settled idle proportional set size (PSS).

Required guardrails:

- Set a workload-memory ceiling after measuring the current desktop; do not invent a numeric target before the baseline exists.
- Preserve responsiveness and startup behavior for the defined everyday workload.
- Measure the whole desktop group, including compositor, shell, browser, suite clients, and resident helpers; distinguish private from shared pages.
- Compare the same outputs, applications, profiles, and actions on the old and new sessions.
- Do not count Rust rewrites, shared source code, or fewer process names as RAM savings without measurements.

The first compatibility target is the actual daily-driver application and workflow set, discovered from the current configuration and use—not broad Hyprland feature parity.

## 3. Accepted product and architecture decisions

- The first deployment is an opt-in user-space session on the existing Arch installation. Daily-driver replacement follows acceptance gates.
- The Rust compositor and desktop shell form one integrated platform. Keep process fusion conditional: begin with boundaries that preserve fault isolation, then compare split and fused variants using PSS, responsiveness, and failure-containment tests.
- The launcher is a native desktop-shell surface, not a separate always-on daemon by default. It discovers app-owned, versioned action manifests and routes requests; apps retain their data and authorization authority.
- The suite supports both CLI/TUI composition and explicit GUI deep-links/context handoffs.
- Cross-app transfers use typed, versioned envelopes and owner-issued receipts. No app reads or mutates a sibling app's database. No central writable suite database or generalized event bus is planned.
- A private Rust library will hold genuinely shared command/action and handoff structures. Keep it as focused crates; code reuse is not itself a performance claim.
- The target audience is technically capable. Prefer keyboard-first surfaces, direct commands, transparent status, and concise errors over guided flows.

## 4. Component direction

### Compositor and desktop shell

Build a Rust-native compositor and shell that preserve the important workflows identified in the compatibility inventory. Provide import/migration support for selected Hyprland and Quickshell configuration rather than promising drop-in compatibility with every config language, IPC detail, or QML component.

Smithay is the first compositor substrate to evaluate, not a final dependency decision. The spike must prove support for the required Wayland protocol and backend set, multi-monitor behavior, recovery, and memory goals. Recreate compositor policy and shell behavior; do not treat a C++/Qt implementation as directly portable source.

The shell owns the launcher, bar/status surfaces, panels, notifications, and global action discovery. Keep compositor authority minimal. Keep the browser and suite apps outside the compositor process.

### Shared Rust library and app contracts

Begin with:

- typed command and action descriptions;
- versioned app-owned action manifests;
- stable app/action identifiers;
- versioned CLI/IPC and GUI context-handoff envelopes;
- typed errors and visible stale, unavailable, invalid, or conflicting states;
- conformance fixtures that independent apps can run.

Audit existing `mg.interop/1`, `mg.plan/1`, and other app-owned contracts before introducing another envelope family. Reuse or adapt an existing contract where semantics fit; do not create competing sources of truth. The library's repository placement, release mechanism, and exact crate boundaries remain to be decided before implementation.

### Blended Rust shell

Create a new shell language that combines interactive, keyboard-oriented use with structured data workflows; do not aim for transparent zsh or Nushell language compatibility.

Pipeline contract:

- External programs use ordinary byte-stream stdin/stdout pipes.
- Shell-native and suite-aware commands may exchange typed structured values.
- Conversion between the two is explicit and testable.

Migration tooling is review-first: inspect zsh configuration, classify supported/unsupported constructs, generate proposed native configuration, and explain conversions. Do not execute legacy startup files as the new shell. Keep zsh as an explicit fallback during transition.

### Terminal emulator

Build a new Rust terminal inspired by selected Ghostty capabilities, not a literal fork or compatibility clone. Keep the initial terminal lean: PTY and terminal-emulation core, with the compositor managing windows and external tools managing persistent sessions. Defer built-in session/multiplexer services unless demonstrated workflows justify them.

### Browser

The browser has two roles: low-footprint everyday browsing and GeistScope research browsing. Keep their profiles and session state strictly separate. Research profiles use an explicitly selected engagement-specific proxy route; if that route is required but unavailable, fail closed rather than silently going direct.

Sandboxing is a release gate, not a property inferred from Rust. The browser must isolate untrusted page content from host files, credentials, sibling profiles, and unauthorized network paths. Private browsing policy is configurable from permissive to strict, defaulting to useful common protections; do not present private mode as network anonymity.

Keep the rendering-engine decision open, with a preference for a Rust-native engine. Evaluate a Rust engine candidate such as Servo against a mature embedded-engine reference such as WebKitGTK. Do not ship a research profile until sandbox enforcement, proxy routing, compatibility, and PSS have been demonstrated. The engine spike must measure direct-egress, DNS, redirect, and profile-isolation failure cases as well as successful browsing.

### mg-suite and GeistScope

Apps remain independent processes and authorities. Integrate them through the global launcher, action manifests, supported CLIs, and versioned non-mutating handoffs. Preserve existing app-owned stores, schemas, IDs, and receipts.

GeistScope remains an independently owned manual-first security workbench. Its current learning/MVP boundaries remain in force: this plan authorizes cross-system planning, not active testing, browser automation, proxy operation, or new Geistscope implementation. The first platform proof may exercise launch, preparation, proposal, and review using inert/local fixtures. Any future live run must require a separate explicit user approval bound to the exact immutable plan revision, target scope, and action set. A launcher handoff or prepared plan is never run approval.

## 5. Recommended phase sequence and gates

### Phase 0 — Baseline and compatibility inventory

- Inventory current Hyprland/Quickshell workflows, monitors, launch paths, suite surfaces, and relevant CLI/TUI behavior.
- Record clean/dirty state for each repo before implementation work; preserve existing work.
- Measure settled idle PSS, startup, representative workflow PSS, and responsiveness on the current session.
- Establish a daily-driver app/protocol compatibility matrix from actual use.

Exit gate: reproducible baseline and a user-approved workflow/compatibility list; no numeric memory target until measurements are available.

### Phase 1 — Shared contract foundation

- Audit suite and GeistScope interop contracts and current roadmaps.
- Define action manifests, command/action types, versioned handoff envelopes, error/freshness states, and owner-issued receipts.
- Implement no shared database, daemon, event bus, or cross-app mutation in this phase.

Exit gate: independent producer/consumer fixtures round-trip; stale, malformed, conflicting, and unauthorized requests fail closed; existing app contracts remain authoritative.

### Phase 2 — First integration proof on current Arch

- Exercise launcher discovery and app-owned action routing.
- Prove a non-mutating security-research preparation flow: open the appropriate app surfaces, prepare a versioned proposal, inspect its provenance, and show that a handoff cannot start a test.
- While GeistScope's present learning/MVP gate is active, use only permitted manual/local or inert-fixture behavior; do not add live browser/proxy testing to satisfy this gate.

Exit gate: the user can launch, prepare, inspect, and reject/accept a proposal without hidden execution or cross-app database access.

### Phase 3 — Shell and terminal

- Implement the new shell's byte/typed pipeline boundary and command grammar.
- Build the zsh analyzer/converter and verify generated configurations without executing legacy startup files.
- Implement the lean terminal core and exercise real shell sessions.

Exit gate: migration report is reviewable, shell pipelines behave deterministically at both data boundaries, and terminal workload stays within the measured envelope.

### Phase 4 — Browser engine and sandbox spike

- Compare the Rust-native candidate and mature-engine reference using the same site/workflow set.
- Test process isolation, storage/profile separation, proxy enforcement, direct-egress failure, recovery, compatibility, PSS, and responsiveness.
- Select an engine only if it passes the security gate and fits the measured resource budget; otherwise keep the engine open and revise the approach.

Exit gate: documented threat model, passing isolation/egress tests, and measured compatibility/resource results.

### Phase 5 — Rust compositor and integrated shell session

- Implement the opt-in compositor using the selected substrate and the approved compatibility matrix.
- Rebuild the critical shell surfaces and configuration migration path.
- Compare split-process and fused-process configurations; keep the safer/smaller configuration that meets the agreed gates.

Exit gate: required daily-driver apps and workflows work; multi-monitor, lock/recovery, startup, and memory gates pass; no unsupported Hyprland/Quickshell parity is implied.

### Phase 6 — Custom distribution

- Revisit the existing Geistos packaging gate only after the user-space session passes.
- Define image/install/update/recovery and private-suite distribution policy as a separate planning slice.

The existing packaging gate stays closed until that decision is explicitly reopened.

## 6. Existing authority and documents

This plan supplements, and does not silently reorder, these authorities:

- `mg-suite/docs/MVP-SCOPE.md` for each app's MVP and suite-surface boundary;
- `mg-suite/docs/POST-MVP-ROADMAP.md` for app-owned interop sequencing;
- `geistos/docs/PACKAGING-GATE.md` and `mg-suite/docs/GEISTOS-PACKAGING.md` for distribution packaging;
- `geistscope/docs/PRODUCT_RECOVERY_DECISIONS.md` and the current GeistScope MVP specification for its learning and active-testing boundaries.

Before any implementation slice, re-read current repo status and reconcile the owning app's current plan. This platform roadmap does not authorize changing neighboring app plans or touching unrelated dirty work.

## 7. Open decisions and required evidence

- Browser engine: Rust-native engine versus mature embedded engine; decide only after the Phase 4 gate.
- Process topology: separate versus fused compositor/shell; decide from PSS, latency, and failure-isolation evidence.
- Shell rendering/UI toolkit and compositor protocol set: select after the Phase 0 workflow matrix and a bounded technical spike.
- Numeric PSS, startup, and responsiveness thresholds: set after the current-session baseline.
- Private shared-library repository location, versioning, and distribution: settle before Phase 1 implementation.
- Exact Geistscope integration timing: active work remains deferred until its current learning/MVP gate is explicitly revisited.

## 8. Change control

This is a living planning document, not implementation authorization. Keep accepted decisions, recommendations, and open questions distinct. Change an accepted decision only with the new evidence, trade-off, and user decision recorded here and, where applicable, in the owning application's decision record.

Initial decision checkpoint: 2026-10-11. The user approved planning the integrated platform, the measured-memory objective, app ownership boundaries, the explicit plan-bound GeistScope approval model, and preservation of current GeistScope and packaging gates.