# SwingBarMidnight Debugger agent guide

## Start here

Read [`SwingBarMidnight_Debugger.toc`](SwingBarMidnight_Debugger.toc), then [`log.lua`](log.lua), [`ui.lua`](ui.lua), and [`main.lua`](main.lua). The TOC order is logger -> UI -> event/sampler main; the debugger is a companion, not a library consumed by `SwingBarMidnight`.

TOC release metadata is `0.1.7` (`SwingBarMidnight_Debugger.toc`, `## Version`).

## Load order and execution path

Complete `loadedFiles` inventory (root `docs/addon-architecture.json`, in execution order):

```text
log.lua
ui.lua
main.lua
```

`log.lua` creates/merges `SwingBarMidnightDebuggerDB`, exposes `ns.InitLogger`, `ns.Log`, `ns.Clear`, and `ns.Format`. `ui.lua` exposes `ns.UI:Init`, `Toggle`, `Update`, and `ShowCopy`, creating the main DIALOG frame on load but hiding it. `main.lua` initializes logger/UI, registers combat, overlay, speed, and cast events (deferring registration out of combat), samples every 0.20 s, reads `_G.SwingBarMidnightState` and the first configured anchor spell from `_G.SwingBarMidnightDB`, and updates the UI.

The cross-addon reads are anchored at `ui.lua:131` (`SwingBarMidnightState`) and `main.lua:89`/`main.lua:92` (`SwingBarMidnightState`/`SwingBarMidnightDB`).

## State and surfaces

- SavedVariables: `SwingBarMidnightDebuggerDB.log` (array) and `maxLines` (default 6000). `ns.Format` limits output characters, not persisted entry count alone.
- Reads main addon state/DB conditionally; missing `SwingBarMidnight` leaves the debugger functional but with no timing sample.
- Slash: `/swingdebug` toggles the window. UI buttons clear log, show copy dialog, and display combat/speed/anchor/suppression/overlay count.
- `OverlayActiveCount` inspects up to 256 children of `_G.SpellActivationOverlayFrame` for the selected anchor spell.

## Dependencies and relationships

There is no `Dependencies`/`OptionalDeps` line in the TOC. Runtime relationship is one-way: debugger -> `_G.SwingBarMidnightState`/`SwingBarMidnightDB`. The intended load-order/schema contract is tracked in [GitHub issue #2](https://github.com/UnknownAlienHuman/swing-bar-midnight-debugger/issues/2). Do not add reverse calls or make the main addon require this debug addon. The debugger also uses `GetSwingSpeeds`, overlay globals, and the same combat-sensitive event names.

Falsification notes: the debugger has no `COMBAT_LOG_EVENT_UNFILTERED` registration, no Masque/CDM integration, and no namespaced Blizzard API calls detected by the root inventory. Its actual update scripts are the combat-registration deferral (`main.lua:74`) and 0.20 s sampler (`main.lua:84`), not a per-frame log writer.

## Change routing

- Log schema, retention, formatting: [`log.lua`](log.lua), especially `Ensure`, `Trim`, `ns.Log`, `ns.Format`.
- Window, copy controls and displayed fields: [`ui.lua`](ui.lua), `UI:Init`, `UI:Update`, `UI:ShowCopy`.
- Events, sampling, anchor spell selection, slash registration: [`main.lua`](main.lua), `RegisterEventsNow`, `OverlayActiveCount`, sampler `OnUpdate`.
- If main addon state fields change, update `main.lua` defensively and document the optional relationship; never rename the main state's exported globals without coordinated changes.

## Invariants and risks

- The debugger must tolerate missing main addon globals and missing overlay frame children.
- Event registration is deferred while in combat; preserve this guard to avoid forbidden registration on combat reload.
- Sampling is periodic (0.20 s), and log retention is bounded by `maxLines`; do not add per-frame log writes.
- `SwingBarMidnightDebuggerDB` is runtime data and must not be copied into repository docs or releases.
- `ui.lua` reads `GetSwingSpeeds` directly; this may be unavailable or differ from the main addon's cached values. Treat displayed speed as observational, not authoritative.
- `OverlayActiveCount` scans child frame fields that are Blizzard-internal and patch-sensitive.

## Verification

1. Verify TOC references and parse Lua.
2. Install/load both addons; `/reload`; confirm `print` banner and `/swingdebug`.
3. Exercise combat enter/leave, overlay show/hide, speed/equipment, and spellcast events; confirm entries appear in the UI and persist.
4. Test Clear, Copy, Escape, scroll, bounded formatting, and missing-main-addon behavior.
5. Compare sampled values with `_G.SwingBarMidnightState`; confirm no taint/Lua error and no unbounded SavedVariables growth.

## Uncertain or version-sensitive claims

`SpellActivationOverlayFrame` child layout/fields, `GetSwingSpeeds`, overlay event variants, and protected event-registration rules are client-build dependent. Verify against the live client before treating debugger output as authoritative.
