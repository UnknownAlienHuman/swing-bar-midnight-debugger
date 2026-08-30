# SwingBarMidnight Prediction Debugger architecture

## Ownership

`log.lua` owns the SavedVariables schema, access boundary, bounded sanitization, log retention, clear, and deterministic text formatting.

`main.lua` owns event registration, snapshot coalescing, the whitelist that may be copied from SwingBarMidnight prediction state, slash commands, and UI notifications.

`ui.lua` owns the on-demand window and copy panel. It renders only the latest sanitized snapshot and bounded formatted log.

SwingBarMidnight remains the owner of attack-speed access, predicted periods, local phase, combat visibility, and frame settings. The debugger is read-only with respect to the main addon.

## Load order

```text
SwingBarMidnight_Debugger.toc
  -> dependency SwingBarMidnight
  -> log.lua
  -> ui.lua
  -> main.lua
```

## Snapshot boundary

The debugger reads only `_G.SwingBarMidnightState` and `_G.SwingBarMidnightDB`, then copies a closed set of ordinary fields. Every field is checked through the logger access helpers before type/format/storage.

The debugger does not retain the source tables or arbitrary keys. Inaccessible fields become `<unavailable>`.

## Events

```text
PLAYER_LOGIN
PLAYER_REGEN_DISABLED
PLAYER_REGEN_ENABLED
UNIT_ATTACK_SPEED player
PLAYER_EQUIPMENT_CHANGED
```

Event bursts coalesce into one `C_Timer.After(0)` snapshot. This delay permits the main addon to process the same event before the debugger copies its exported state. There is no repeating timer or `OnUpdate`.

## Log schema

Schema v2 stores an array of sanitized entries:

```text
t: ordinary timestamp
tag: bounded ordinary string
data: bounded ordinary primitives/tables
```

Limits:

- default 500 entries;
- configurable range 50–2,000;
- 24 fields per table;
- depth 3;
- 240 characters per string;
- cycle detection;
- bounded export length.

## Explicit non-ownership

The debugger does not inspect or log:

- SpellActivationOverlay frames/events/children;
- aura data or aura events;
- action bars, macros, range or spellcasts;
- combat log;
- actual hit timestamps;
- frame visibility as timing evidence;
- removed `lastAnchor`, `suppressUntil`, or `overlayCount` values.

## Evidence boundary

Snapshots describe SwingBarMidnight's predicted-cadence model only. They do not convert prediction into observed swing evidence. Local regression proves sanitization/coalescing/bounds against mocks; live dependency ordering and UI behavior remain separate gates.
