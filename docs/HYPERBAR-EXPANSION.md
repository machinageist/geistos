# Hyperbar and adjacent-module expansion

Status: Jeff selected this scope on 2026-09-28. It is an approved implementation program, not a claim that the features are already done.

Runtime implementation is maintained in the dotfiles repository; geistos carries only deliberately synchronized files. Preserve each repository's ownership and history, and mirror only accepted changes.

## Selected scope

The selected candidates from the prior wishlist are:

- Adaptive density/overflow and a bar module layout editor.
- Richer workspace indicators and a visual window/workspace overview.
- Hyprland workspace-layout controls, desktop modes, workspace launch recipes, and event automations.
- Ticker controls, notification policies, per-application audio controls, richer power presets, a pinned-panel shelf, and a service-freshness/error center.

Additional explicit requests:

- Theme/wallpaper flipbook: Wallpaper is the first page, Themes the second. Tab/Shift-Tab or Up/Down switches pages; the wheel or Left/Right steps through the active page. Browsing is preview-only; Enter applies and Escape restores the prior appearance. Pause rotation during audition and restore its prior enabled/interval state when audition ends.
- A genuinely compact floating-bar mode, not merely a shorter full-width bar. It should draw a translucent, lightly blurred capsule only around selected bar modules, and allow the user to choose which elements appear.
- All 18 items in the accompanying `QUICKSHELL-SUITE-WISHLIST.md` are separately approved scope; deliver them as bounded slices without silently widening the current slice or weakening the listed app-authority/privacy boundaries.

## Invariants

- Preserve existing bar actions and panel routes unless the accepted feature explicitly changes them. Do not add or remap global Hyprland bindings without approval; in-panel theme-picker keys are explicitly approved.
- Keep user layout preferences in Quickshell state, not generated QML or checked-in machine state. Provide a safe fallback to the current full bar if settings are missing or malformed.
- Treat Hyprland as authority for workspaces, windows, layouts, and monitors; Quickshell presents controls and validated requests, not a second compositor model.
- AI may prepare proposals; deterministic mg-suite applications remain the authorities. No AI-generated result directly mutates another application's store or completes work.
- Preserve unrelated work and history across repositories; avoid broad copying or staging across repositories.
- Visually verify bar/panel behavior on every connected output before claiming UI completion.

## Dependency-ordered delivery

1. Theme/wallpaper flipbook interaction and visual preview.
2. Persisted bar module preferences, ordering, density, and the compact floating capsule. The capsule geometry is blocked on the design checkpoint below.
3. Workspace indicators and read-only window/workspace overview.
4. Hyprland layout controls and named desktop/workspace scenes.
5. Bounded event automations with visible rules, status, and disable/undo behavior.
6. Notification policy, per-app audio, richer power presets, panel shelf, and integration freshness center, each as a separately verified slice.
7. Continue mg-suite/AI discovery in the wishlist; any cross-app mutation, provider/privacy policy, or new authority needs a separate decision and contract first.

Each slice gets behavior tests, a fresh runtime/log check, and a visual check. Do not treat a passing QML load as proof of the operator workflow.

## Product decision — recorded

Decision: Use one content-sized capsule centered on the selected screen, with user-selected modules in one ordered row; keep the clock at the screen center. Preserve the current left/center/right full-bar composition as a separate mode. The capsule must remain limited to selected modules with subtle blur and no full-width strip.

Decisions recorded through 2026-09-30: module ordering/visibility and inner/outer gaps are global across outputs/workspaces; new workspaces inherit saved layout, with canonical order used only when saved state is absent or malformed. Inner/outer gaps are independently adjustable from 0–32 px in 1 px steps, with 2 px defaults only for missing/new preferences; preserve existing values, including zero. Modes and recipes do not modify gaps. Appearance browsing previews only; Enter applies, Escape restores, and rotation resumes with its prior enabled state and interval.
