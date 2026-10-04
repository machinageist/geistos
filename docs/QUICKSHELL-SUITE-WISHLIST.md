# Quickshell, mg-suite, and AI — next wishlist

Status: Jeff selected all 18 additions for implementation on 2026-09-28. This is approved scope, not a claim that the features are already done. Each option still needs a bounded slice, owner, authority boundary, and acceptance test.

The already-selected bar/panel/Hyprland features remain in `HYPERBAR-EXPANSION.md`; this list focuses on next-step opportunities and avoids restating that scope.

## AI module and mg-suite

1. **AI context packet builder.** Let me select an exact `mg-brief` source, `mg-vault` note, or `mg-plan` item before a request. Show the included text, source revision, and citations so I can remove sensitive or irrelevant context before sending.
2. **Truthful provider and privacy gate.** Show the actual provider, model, and whether the request leaves the machine; let me set a local-only policy and per-request consent. The current AI service infers cloud status from model file size, so replace that guess with explicit provider metadata and fail closed if it is unknown.
3. **Cited answer mode.** For research or security questions, separate source-backed statements from inference, link each claim to the selected source/revision, and mark unsupported claims plainly. Never turn an AI answer into a verified mg-brief finding by itself.
4. **Reviewable drafts to the owning app.** Turn an answer into a proposed `mg-vault` note, `mg-plan` work item, or `mg-calr` scheduling request, with a field-by-field preview and exact target revision. The owning app validates and commits only after I confirm; no direct sibling database writes.
5. **Read-only suite cockpit.** Show each app's supported status, freshness, current work, and a useful next link/action using its published CLI or versioned projection. Keep it a projection, not a shared database or a dashboard-owned workflow.
6. **Verification-gap helper.** Let AI explain missing, failing, stale, or evidence-free `mg-plan` criteria and suggest a test or evidence source. It may draft a checklist, but only `mg-plan`'s deterministic rules can accept evidence or judge completion.
7. **Brief-to-vault learning loop.** From a chosen `mg-brief` source/CVE or asset observation, draft a deduplicated, cited `mg-vault` note and optionally a linked plan item. Preserve provenance and distinguish source fact from interpretation; no exploit execution or automatic remediation.
8. **Local AI session shelf.** Save named prompts and optionally local conversation history, with per-item retention, redaction, export, and deletion controls. Clipboard text and vault content are never stored or reused implicitly.
9. **AI action cards with receipts.** For any supported action, show the exact command/request, app that owns it, expected revision, and likely effect before I approve. After execution, display the owner's acceptance/rejection receipt; stale or ambiguous requests stop rather than being guessed or retried.

## Quickbar, panels, and Hyprland

10. **One command palette across shell and suite.** Extend the existing launcher to find Quickshell panels, safe Hyprland actions, and installed mg-suite commands in one keyboard-first surface. Show whether each result reads, changes state, or launches an app; never run an AI-suggested command without an explicit preview and approval.
11. **Active-window quick actions.** Offer a small optional action menu for the focused window/workspace—inspect matched Hyprland rules, move/focus/float, or capture a user-selected window reference for a plan item. Make the exact target visible and keep capture opt-in.
12. **Appearance audition with undo.** In the requested theme/wallpaper flipbook, browsing is preview-only until Enter applies; Escape restores the prior choice. Pause rotation during audition and restore its prior enabled/interval state when audition ends. Keep current palette/contrast behavior and expose an undo path if the applied choice is restored.
13. **Named appearance collections.** Save user-curated wallpaper/theme combinations (for example, “work”, “night”, or “presentation”) and preview the whole set before applying. This extends, rather than replaces, the existing theme and wallpaper services.
14. **Hyprland rule inspector.** For the focused window, explain which configured rules matched and show the effective workspace, monitor, floating, and layout state. Start read-only; any rule editor should show a diff and validate before changing configuration.
15. **Automation test bench.** Before enabling a selected event automation, simulate triggers such as monitor attach or low battery and show the proposed changes, confirmation points, and rollback path. Keep test events separate from real system state.
16. **Guided recovery cards.** When Quickshell or an integration is stale/unavailable, show the failed check, last-known-good time, safe diagnostic command, and documented recovery options. No hidden restart loops, root action, or destructive “repair” button.
17. **Accessibility and focus preset.** Offer a reversible profile for readable text, contrast, hit targets, keyboard focus cues, and reduced motion without silently replacing the active palette or moving modules.
18. **Local action history.** Keep a user-controlled, bounded record of bar layout changes, appearance changes, approved automations, and cross-app requests, including result receipts and available undo. Redact prompts and secret content; support clearing the history.

## Guardrails

- The suite applications remain separate authorities. Use their supported CLIs and versioned envelopes; never open sibling databases from Quickshell or AI.
- AI proposes, cites, and explains. It does not mark criteria passed, complete work, waive verification, remediate vulnerabilities, or write directly to another application's store.
- The suite roadmap already favors typed references/receipts and federated authority; treat those as the integration direction, not as permission to build a shared writable database, event bus, or broad sync layer.
- Provider/network use must be explicit and bounded. Do not send clipboard or private vault content without item-specific user consent.
- Existing mg-suite checkouts have unrelated uncommitted work. Inspect and preserve each repository baseline before any implementation task touches them.
