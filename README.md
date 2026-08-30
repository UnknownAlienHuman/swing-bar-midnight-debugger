# SwingBarMidnight Prediction Debugger

Event-driven companion for SwingBarMidnight 0.9.0 on World of Warcraft Retail 12.1.

The debugger observes only SwingBarMidnight's exported ordinary prediction state. It does not inspect SpellActivationOverlay frames, aura state, action buttons, combat log, actual swing hits, or hidden managed objects.

## Compatibility

- Game: World of Warcraft Retail / Midnight 12.1.0
- Interface: `120100`
- Version: `0.2.0`
- Required dependency: `SwingBarMidnight`
- Verified source baseline: `12.1.0.69497`
- SavedVariables: `SwingBarMidnightDebuggerDB`
- GitHub Actions: none

## What it records

Each sanitized snapshot can contain only whitelisted fields:

- model identifier: `predicted-cadence`;
- snapshot reason;
- main addon loaded state;
- combat flag;
- MH/OH predicted periods and accessibility status;
- MH/OH local phase origins;
- phase-reset reason;
- pending settings apply;
- enabled, combat-only, separate-OH, and lock settings.

Inaccessible values become ordinary `<unavailable>` markers. Raw values, frames, userdata, functions, event payload tables, and arbitrary addon state are not persisted.

## Event model

Snapshots are requested on:

- `PLAYER_LOGIN`;
- combat enter/leave;
- player `UNIT_ATTACK_SPEED`;
- `PLAYER_EQUIPMENT_CHANGED`;
- manual snapshot.

Same-frame event bursts coalesce through one zero-delay callback. There is no `OnUpdate` sampler or periodic scan.

## Commands

```text
/swingdebug
/swingdebug snapshot
/swingdebug clear
/swingdebug copy
```

The default command toggles the debugger window. The UI also provides Snapshot, Clear, and Copy buttons.

## Bounded log

The SavedVariables log defaults to 500 entries and is capped at 2,000. Each entry is sanitized with finite depth, field count, and string length. Cycles, inaccessible values, secret tables, unsupported types, and inaccessible keys are replaced with ordinary markers.

Copy/export formatting is bounded and deterministic. The logger never calls raw `tostring` on an inaccessible value.

## Removed behavior

Version 0.2.0 removes:

- SpellActivationOverlay event logging;
- overlay child scans and visibility checks;
- the 0.2-second polling frame;
- raw `UnitAttackSpeed` logging;
- obsolete `lastAnchor`, `suppressUntil`, and `overlayCount` fields;
- raw table/value persistence.

## Validation status

`log.lua`, `ui.lua`, `main.lua`, and `tests/test_safe_prediction_debugger_12_1.lua` are designed for local Lua 5.1 parsing. The regression verifies sanitized inaccessible values/keys, event coalescing, bounded log size, no overlay/aura registration, and no polling loop.

Live testing remains required for dependency load order, snapshot freshness after main-addon events, UI/copy/clear behavior, combat, reload persistence, taint, errors, and SavedVariables inspection.

## License

Licensed under the [MIT License](LICENSE).
