# SwingBarMidnight Prediction Debugger agent guide

## Contract

This addon is a sanitized observer of SwingBarMidnight's **prediction state**. It must never become an alternate swing detector.

Target:

- Retail 12.1.0;
- Interface `120100`;
- version `0.2.0`;
- required dependency `SwingBarMidnight`;
- no GitHub Actions workflow.

## Hard prohibitions

Do not add:

```text
OnUpdate or repeating sampler
SpellActivationOverlay events or frame scans
GetChildren / GetNumChildren
UNIT_AURA or raw aura APIs
combat-log processing
action-slot, macro, range or spellcast inference
raw UnitAttackSpeed persistence
actual-hit claims
arbitrary copy of SwingBarMidnightState/DB
```

The debugger may copy only the current closed whitelist in `main.lua`.

## Access and logging

`log.lua` must decide accessibility before type checks, stringification, comparison, concatenation, iteration, key use, or persistence.

- inaccessible scalar → `<inaccessible>`;
- inaccessible key → `<inaccessible-key>`;
- secret table → `<secret-table>`;
- unsupported object → ordinary type marker;
- cycle/depth/field/string limits remain finite.

Do not use `pcall(tostring, rawValue)` as an access test. `pcall` is error containment only.

SavedVariables must contain ordinary bounded primitives/tables only. Never store frames, userdata, functions, threads, raw state tables, event payloads, or inaccessible proxies.

## Event model

Allowed snapshot triggers:

```text
PLAYER_LOGIN
PLAYER_REGEN_DISABLED
PLAYER_REGEN_ENABLED
UNIT_ATTACK_SPEED player
PLAYER_EQUIPMENT_CHANGED
manual snapshot
```

`QueueSnapshot` coalesces a burst into one zero-delay callback. Do not convert it to a repeating timer.

## Snapshot whitelist

Current fields:

```text
model
reason
mainLoaded
inCombat
mhPeriod / ohPeriod
mhStatus / ohStatus
t0MH / t0OH
phaseReason
pendingApply
enabled
combatOnly
showOffhand
locked
```

Adding a field requires proving that it is ordinary exported prediction state and does not reveal a managed/private/secret source or claim actual swing evidence.

## UI

`ui.lua` renders the latest sanitized snapshot and `ns.Format` output. It does not call gameplay APIs. The window updates only when opened, when a snapshot arrives, or after clear/copy actions. Dragging is blocked in combat.

The copy panel uses bounded sanitized log text. Keep the note that no actual hit evidence is collected.

## Commands

```text
/swingdebug
/swingdebug snapshot
/swingdebug clear
/swingdebug copy
```

## Verification

Local:

```text
texlua --luaconly log.lua ui.lua main.lua tests/test_safe_prediction_debugger_12_1.lua
texlua tests/test_safe_prediction_debugger_12_1.lua
```

Expected:

```text
PASS: debugger logs only sanitized prediction snapshots, coalesces events, and has no overlay scan or polling loop
```

Live gates: dependency load, event freshness, inaccessible transitions, UI/copy/clear, log retention, combat/reload, taint/errors, and SavedVariables inspection. Prediction snapshots are not actual swing-hit evidence.
