# Pull Request / Audit Report: SwingBarMidnight_Debugger — Retail 12.1 (Interface 120100) Compliance & Sanitized Prediction Observer Refactor

## Executive Summary

| Item | Details |
| :--- | :--- |
| **Addon Name** | **SwingBarMidnight_Debugger** (Companion Debugger for SwingBarMidnight) |
| **Addon Directory** | `_Addons/SwingBarMidnight_Debugger` |
| **Remote Repository** | `github-swing-bar-midnight-debugger` (`https://github.com/UnknownAlienHuman/swing-bar-midnight-debugger.git`) |
| **Target Client** | World of Warcraft: Midnight / Retail 12.1 (`Interface: 120100`, Build `12.1.0.69497`) |
| **Addon Purpose** | Sanitized event-driven observer and diagnostic UI for SwingBarMidnight's predicted melee cadence. |
| **Audit Date** | 2026-09-08 |
| **Local Status** | **v0.1.7 (Severely Broken for 12.1)**: Traverses Blizzard's `SpellActivationOverlayFrame` child hierarchy (`GetChildren()`), runs an uncoordinated 0.20s `OnUpdate` polling loop mutating the parent addon's internal state, invokes an undefined global `GetSwingSpeeds()` causing fatal Lua errors on UI open, performs unshielded formatting on potential `SecretValue` proxies, lacks declared dependencies in TOC, and violates RT-AUDIT-001 and RT-AUDIT-002. |
| **Remote Status** | **v0.2.0 (Fully Modernized & Compliant)**: Modernized on `github-swing-bar-midnight-debugger/main` across 10 structured commits. Purged all overlay frame scanning, eliminated all polling loops, implemented zero-delay event burst coalescing (`C_Timer.After(0)`), established an access-first sanitization boundary (`canaccessvalue`, `issecretvalue`, `issecrettable`), instituted bounded SavedVariables Schema v2, aligned with `SwingBarMidnight` 0.9.0's predicted cadence model, and added an automated regression test suite (`tests/test_safe_prediction_debugger_12_1.lua`). |

---

## Remote Comparison (`git diff HEAD:_Addons/SwingBarMidnight_Debugger github-swing-bar-midnight-debugger/main`)

A full comparative diff between the local workspace `HEAD:_Addons/SwingBarMidnight_Debugger` and the upstream repository `github-swing-bar-midnight-debugger/main` shows a complete architectural transformation:

```text
 AGENT_GUIDE.md                               | 128 ++++++++---
 ARCHITECTURE.md                              |  76 +++++-
 CODE_GRAPH.md                                |  27 ++-
 CODE_INDEX.md                                |  16 +-
 README.md                                    |  82 ++++++-
 SwingBarMidnight_Debugger.toc                |  10 +-
 log.lua                                      | 202 ++++++++++++----
 main.lua                                     | 218 +++++++++++-------
 tests/test_safe_prediction_debugger_12_1.lua | 113 +++++++++
 ui.lua                                       | 332 +++++++++++++++------------
 10 files changed, 849 insertions(+), 355 deletions(-)
```

### Upstream Commit Journey:
The upstream repository `github-swing-bar-midnight-debugger` completed a systematic 10-commit modernization journey:
1. `d9628ae`: `fix: bound and sanitize debugger SavedVariables logs`
2. `75d8b4c`: `refactor: observe only whitelisted prediction state without polling`
3. `b605014`: `refactor: display sanitized event-driven prediction snapshots`
4. `7ce059b`: `chore: target Retail 12.1 and require the prediction addon`
5. `7bb65a6`: `test: cover sanitized snapshots, bounded logs and event coalescing`
6. `918b29d`: `docs: document sanitized prediction-state debugging`
7. `71c160f`: `docs: define logger, snapshot and UI ownership`
8. `69c701b`: `docs: rewrite agent instructions for sanitized event-driven debugging`
9. `edb75cf`: `docs: update the safe debugger code index`
10. `438f2e6`: `docs: update the event-driven debugger graph`

### Key Assessment:
The upstream repository has already addressed the core 12.1 requirements. The local workspace directory, however, remains stranded on outdated commit `1cfa5ec` (v0.1.7). This Pull Request synchronizes the local codebase with upstream while incorporating additional defensive hardening (such as `## LoadSavedVariablesFirst: 1` and dynamic DB pointer recovery in `Ensure()`) derived from the WoW Addon Engineering Knowledge Base.

---

## Detailed Audit Findings against Retail 12.1 & KB Standards

### 1. TOC Interface Metadata, Load Order & Dependencies (Critical)
- **Local State (`SwingBarMidnight_Debugger.toc:1-6`)**:
  ```toc
  ## Interface: 120000
  ## Title: SwingBarMidnight Debugger
  ## Notes: Debug UI + SavedVariables log for SwingBarMidnight glow anchoring and speed.
  ## Author: Roth
  ## Version: 0.1.7
  ## SavedVariables: SwingBarMidnightDebuggerDB
  ```
- **Violations**:
  - Outdated Interface version. Retail 12.1 requires `## Interface: 120100`.
  - **Missing Mandatory Dependency**: The debugger reads `_G.SwingBarMidnightState` and `_G.SwingBarMidnightDB`. Without `## Dependencies: SwingBarMidnight`, the WoW client does not guarantee load order. If the debugger loads first, it accesses uninitialized global tables, logging nil or invalid states.
  - Stale description referencing retired "glow anchoring" heuristics.
  - Missing `## X-Verified-Build: 12.1.0.69497`.
  - Missing `## LoadSavedVariablesFirst: 1` (KB `Addon_SavedVariables.md`), which ensures `SwingBarMidnightDebuggerDB` is loaded into `_G` prior to file execution.
- **Required 12.1 Configuration**:
  ```toc
  ## Interface: 120100
  ## Title: SwingBarMidnight Prediction Debugger
  ## Notes: Event-driven sanitized observer for SwingBarMidnight's predicted MH/OH cadence state.
  ## Author: Roth
  ## Version: 0.2.0
  ## SavedVariables: SwingBarMidnightDebuggerDB
  ## LoadSavedVariablesFirst: 1
  ## Dependencies: SwingBarMidnight
  ## X-Verified-Build: 12.1.0.69497
  ```

---

### 2. Elimination of Blizzard Frame Scraping & Taint Hazards (WOWUI-2026-012)
- **Local State (`main.lua:4-23`, `main.lua:82-101`)**:
  ```lua
  local function OverlayActiveCount(spellId)
    local f = _G.SpellActivationOverlayFrame
    if not f or not f.GetChildren then return 0 end
    local cnt = 0
    local kids = { f:GetChildren() }
    for i=1, #kids do
      local c = kids[i]
      if c and c.IsShown and c:IsShown() then
        local sid = c.spellId or c.spellID
        if type(sid) == "number" and sid == spellId then cnt = cnt + 1 end
      end
    end
    return cnt
  end

  local sampler = CreateFrame("Frame")
  sampler:SetScript("OnUpdate", function(_, elapsed)
    ...
    st.overlayCount = OverlayActiveCount(spellId)
  end)
  ```
- **Defects in Retail 12.1**:
  - **Severe UI Taint Violation**: Blizzard's `SpellActivationOverlayFrame` is a managed UI subsystem. Scraping child frames (`GetChildren()`), inspecting their internal properties, and executing arbitrary script queries on them during or near combat propagates execution taint to Blizzard action buttons, causing `[ADDON_ACTION_FORBIDDEN]` during combat lockdown.
  - **Obsolete Parent Model**: `SwingBarMidnight` completely eliminated glow-anchor heuristics and spell activation overlay inspection in v0.9.0. It operates on a deterministic cadence prediction model (`UnitAttackSpeed`). Querying `SpellActivationOverlayFrame` and injecting `st.overlayCount` into the parent addon's state is completely obsolete and destabilizing.
- **Retail 12.1 Resolution**:
  - Completely purge `OverlayActiveCount`, the `sampler` frame, and all registrations for `SPELL_ACTIVATION_OVERLAY_*`.

---

### 3. Elimination of Undefined API Call: `GetSwingSpeeds()` (Fatal Lua Error)
- **Local State (`ui.lua:135`)**:
  ```lua
  function UI:Update()
    ...
    local mh, oh = GetSwingSpeeds()
    self.frame._vSpeed:SetText(string.format("%.3f / %.3f", mh or 0, oh or 0))
  ```
- **Defect**:
  - `GetSwingSpeeds()` is **not** a World of Warcraft API function. In vanilla WoW or private server environments it may have existed in third-party libraries, but in standard WoW Retail it evaluates to `nil`.
  - Calling `GetSwingSpeeds()` throws an immediate Lua error (`attempt to call global 'GetSwingSpeeds' (a nil value)`) whenever `/swingdebug` is opened or `UI:Update()` is invoked.
- **Retail 12.1 Resolution**:
  - Remove all calls to `GetSwingSpeeds()`. The debugger does not poll combat APIs directly; it displays the exported prediction values from `_G.SwingBarMidnightState.mhPeriod` and `_G.SwingBarMidnightState.ohPeriod`.

---

### 4. SecretValue & Inaccessible Value Protection (Retail 12.1 Secret Arithmetic)
- **Local State (`log.lua:47-70`, `main.lua:44`, `ui.lua:137-154`)**:
  ```lua
  -- log.lua
  for k,v in pairs(e.data) do
    if type(v) == "number" then
      parts[#parts+1] = k.."="..string.format("%.3f", v)
    else
      parts[#parts+1] = k.."="..tostring(v)
    end
  end

  -- main.lua
  local mh, oh = UnitAttackSpeed("player")
  ns.Log("SPEED", { mh=mh, oh=oh })
  ```
- **Defects in Retail 12.1**:
  - In Retail 12.1 (Midnight), values originating from restricted APIs or execution paths during combat lockdown can be wrapped in `SecretValue` userdata proxies.
  - Calling `tostring(v)`, `string.format(...)`, `pairs(v)`, comparisons (`v < 0`), or arithmetic on a `SecretValue` throws a fatal Lua error (`attempt to perform arithmetic on a secret value` / `inaccessible value was stringified`).
  - Local `log.lua` and `main.lua` unconditionally log raw `UnitAttackSpeed` and format tables using `pairs()` and `tostring()`.
- **Retail 12.1 Resolution**:
  - Establish an **access-first boundary** in `log.lua`:
    - Check accessibility using `canaccessvalue(v)` and `issecretvalue(v)` before attempting any type check, comparison, or string conversion.
    - Check table accessibility using `issecrettable(v)`.
    - Inaccessible primitives are safely represented as `<inaccessible>` or `<unavailable>`.
    - Inaccessible table keys are safely sanitized to `<inaccessible-key>`.
    - Recursion is bounded by `MAX_DEPTH = 3`, `MAX_FIELDS = 24`, and cycle detection.

---

### 5. RT-AUDIT-001: SavedVariables Default Mutation & Schema v2 Hardening
- **Local State (`log.lua:4-29`)**:
  ```lua
  SwingBarMidnightDebuggerDB = SwingBarMidnightDebuggerDB or {}
  ns.DB = SwingBarMidnightDebuggerDB
  local DB = ns.DB

  local function Ensure()
    DB.log = DB.log or {}
    DB.maxLines = DB.maxLines or 6000
  end
  ```
- **Defects**:
  - **TOC/Load Race**: When `log.lua` loads, if SavedVariables have not yet been deserialized by the engine, `local DB` captures the initial fallback table `{}`. If the engine later populates `_G.SwingBarMidnightDebuggerDB`, `local DB` is orphaned.
  - **Unbounded Growth**: `DB.maxLines` default is 6,000 entries. With raw nested tables, SavedVariables files quickly balloon to tens of megabytes, causing client hitching on `/reload` and logout.
  - **O(N^2) Trimming**: Trimming via `for _=1, drop do table.remove(DB.log, 1) end` shifts the entire table array in memory on every single dropped element.
- **Retail 12.1 Resolution**:
  - Migrate to **Schema v2**:
    - Default entries capped at 500 (`DEFAULT_MAX_ENTRIES`), bounded strictly between 50 and 2,000 (`MAX_ENTRIES_LIMIT`).
    - String length clamped to 240 chars (`MAX_STRING`).
    - Obsolete `maxLines` migrated to `maxEntries`.
    - Add dynamic sync in `Ensure()`: if `_G.SwingBarMidnightDebuggerDB` was re-instantiated, re-sync `DB` reference.

---

### 6. RT-AUDIT-002: Single Runtime Owner & Polling Elimination
- **Local State (`main.lua:28-101`)**:
  - Frame 1 (`ev`): Listens to 8 events (`PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED`, `SPELL_ACTIVATION_OVERLAY_*`, `UNIT_ATTACK_SPEED`, `UNIT_SPELLCAST_SUCCEEDED`).
  - Frame 2 (`defer`): Runs an `OnUpdate` polling loop waiting for `not InCombatLockdown()` to register events if loaded in combat.
  - Frame 3 (`sampler`): Runs an `OnUpdate` loop every 0.20s crawling Blizzard overlay frames and writing `st.overlayCount`.
- **Defects**:
  - Violates RT-AUDIT-002 by spawning three concurrent frames, two of which use continuous `OnUpdate` polling.
  - The `sampler` frame mutates `_G.SwingBarMidnightState.overlayCount`—a direct violation of single-owner runtime boundaries.
- **Retail 12.1 Resolution**:
  - Consolidate all lifecycle events into a single passive frame: `local events = CreateFrame("Frame")`.
  - Zero `OnUpdate` loops across the entire addon.
  - Use `RegisterUnitEvent("UNIT_ATTACK_SPEED", "player")` to filter events at the C-engine level, preventing event wakeups for non-player units.
  - Implement **zero-delay burst coalescing** via `C_Timer.After(0, Run)`: multiple events firing in the same frame (e.g. combat start + attack speed shift + equipment change) coalesce into a single snapshot. This also ensures `SwingBarMidnight` has completed its own calculations before the debugger snapshots the exported state.

---

### 7. UI Modernization & Safe Combat Drag Protection
- **Local State (`ui.lua:45-116`)**:
  - Displays outdated metrics: `vAnchor` (`lastAnchor`), `vSupp` (`suppressUntil`), `vOv` (`overlayCount`).
  - Draggable via `f:SetScript("OnDragStart", function(self) self:StartMoving() end)` without checking `InCombatLockdown()`.
- **Defects**:
  - In Retail 12.1, initiating `StartMoving()` on frames parented to `UIParent` during `InCombatLockdown()` can lead to taint propagation and UI errors.
  - Displays dead fields that no longer exist in `SwingBarMidnightState`.
- **Retail 12.1 Resolution**:
  - Guard drag initiation: `if not InCombatLockdown() then self:StartMoving() end`.
  - Redesign UI layout (620x460) to display the complete prediction state:
    - Model (`predicted-cadence`) and Reason
    - Main loaded state and Combat flag
    - MH period & status (`mhPeriod` / `mhStatus`)
    - OH period & status (`ohPeriod` / `ohStatus`)
    - Phase origins (`t0MH` / `t0OH`)
    - Phase reset reason (`phaseReason`)
    - Main addon settings (`enabled`, `combatOnly`, `showOffhand`, `locked`)
  - Provide dedicated buttons: `Snapshot` (manual capture), `Clear` (wipe log), and `Copy` (safe sanitized export modal with bounded 100k character limit).

---

## Analysis of Online GitHub Differences

A detailed analysis of each file in `github-swing-bar-midnight-debugger/main` confirms that the remote repository has already implemented these required transformations:

| File | Local `HEAD` (v0.1.7) | Remote `main` (v0.2.0) | Assessment & Action |
| :--- | :--- | :--- | :--- |
| `SwingBarMidnight_Debugger.toc` | `Interface: 120000`, v0.1.7, no dependencies, obsolete notes. | `Interface: 120100`, v0.2.0, `Dependencies: SwingBarMidnight`, updated notes. | **Adopt remote**. Add `## LoadSavedVariablesFirst: 1` as KB enhancement. |
| `log.lua` | Raw SavedVariables, no accessibility checks, vulnerable to SecretValue crashes, O(N^2) trim. | Access-first sanitization (`canaccessvalue`, `issecretvalue`, `issecrettable`), Schema v2, bounded entries. | **Adopt remote**. Add defensive `Ensure()` DB pointer re-sync. |
| `main.lua` | `SpellActivationOverlayFrame` child crawl, 0.2s polling loop, 3 frames, no event coalescing. | Whitelisted snapshot reader, single event frame, zero polling, `C_Timer.After(0)` burst coalescing. | **Adopt remote**. |
| `ui.lua` | Calls nil `GetSwingSpeeds()`, displays obsolete anchor/overlay fields, unprotected drag. | Modern 620x460 layout, sanitized snapshot display, combat drag guard, Copy dialog. | **Adopt remote**. |
| `tests/test_safe_prediction_debugger_12_1.lua` | Missing completely. | Full 113-line regression test covering SecretValue handling, bounded logs, and zero polling. | **Adopt remote**. |
| `README.md`, `AGENT_GUIDE.md`, etc. | Obsolete 0.1.x documentation describing glow anchoring. | Comprehensive documentation defining honest prediction observer architecture. | **Adopt remote**. |

---

## Proposed PR Diffs

### Patch 1: `SwingBarMidnight_Debugger.toc`
```diff
--- a/_Addons/SwingBarMidnight_Debugger/SwingBarMidnight_Debugger.toc
+++ b/_Addons/SwingBarMidnight_Debugger/SwingBarMidnight_Debugger.toc
@@ -1,9 +1,12 @@
-## Interface: 120000
-## Title: SwingBarMidnight Debugger
-## Notes: Debug UI + SavedVariables log for SwingBarMidnight glow anchoring and speed.
+## Interface: 120100
+## Title: SwingBarMidnight Prediction Debugger
+## Notes: Event-driven sanitized observer for SwingBarMidnight's predicted MH/OH cadence state.
 ## Author: Roth
-## Version: 0.1.7
+## Version: 0.2.0
 ## SavedVariables: SwingBarMidnightDebuggerDB
+## LoadSavedVariablesFirst: 1
+## Dependencies: SwingBarMidnight
+## X-Verified-Build: 12.1.0.69497
 
 log.lua
 ui.lua
```

---

### Patch 2: `log.lua` (Access-First Sanitization & Schema v2)
```diff
--- a/_Addons/SwingBarMidnight_Debugger/log.lua
+++ b/_Addons/SwingBarMidnight_Debugger/log.lua
@@ -1,76 +1,192 @@
 -- SwingBarMidnight_Debugger/log.lua
+-- Bounded ordinary-data logger for the Retail 12.1 prediction debugger.
+
 local ADDON_NAME, ns = ...
 
-SwingBarMidnightDebuggerDB = SwingBarMidnightDebuggerDB or {}
+SwingBarMidnightDebuggerDB = type(SwingBarMidnightDebuggerDB) == "table" and SwingBarMidnightDebuggerDB or {}
 ns.DB = SwingBarMidnightDebuggerDB
 local DB = ns.DB
 
+local DEFAULT_MAX_ENTRIES = 500
+local MAX_ENTRIES_LIMIT = 2000
+local MAX_FIELDS = 24
+local MAX_DEPTH = 3
+local MAX_STRING = 240
+
+local function CanAccess(value)
+  if type(canaccessvalue) == "function" then
+    local ok, accessible = pcall(canaccessvalue, value)
+    return ok and accessible == true
+  end
+  if type(issecretvalue) == "function" then
+    local ok, secret = pcall(issecretvalue, value)
+    return ok and secret ~= true
+  end
+  return true
+end
+
+local function SafeBoolean(value)
+  if not CanAccess(value) or type(value) ~= "boolean" then return nil end
+  return value
+end
+
+local function SafeNumber(value)
+  if not CanAccess(value) or type(value) ~= "number" or value ~= value then return nil end
+  return value
+end
+
+local function SafeString(value)
+  if not CanAccess(value) or type(value) ~= "string" then return nil end
+  if #value > MAX_STRING then return value:sub(1, MAX_STRING) .. "…" end
+  return value
+end
+
+local function IsSafeTable(value)
+  if not CanAccess(value) or type(value) ~= "table" then return false end
+  if type(issecrettable) == "function" then
+    local ok, secret = pcall(issecrettable, value)
+    if not ok or secret == true then return false end
+  end
+  return true
+end
+
+local function SanitizeKey(value)
+  if not CanAccess(value) then return "<inaccessible-key>" end
+  local valueType = type(value)
+  if valueType == "string" then return SafeString(value) or "<invalid-key>" end
+  if valueType == "number" then
+    local number = SafeNumber(value)
+    return number and tostring(number) or "<invalid-key>"
+  end
+  if valueType == "boolean" then return value and "true" or "false" end
+  return "<" .. valueType .. "-key>"
+end
+
+local function Sanitize(value, depth, seen)
+  if not CanAccess(value) then return "<inaccessible>" end
+  local valueType = type(value)
+  if value == nil then return nil end
+  if valueType == "string" then return SafeString(value) end
+  if valueType == "number" then return SafeNumber(value) end
+  if valueType == "boolean" then return SafeBoolean(value) end
+  if valueType ~= "table" then return "<" .. valueType .. ">" end
+  if not IsSafeTable(value) then return "<secret-table>" end
+
+  depth = depth or 0
+  if depth >= MAX_DEPTH then return "<max-depth>" end
+  seen = seen or {}
+  if seen[value] then return "<cycle>" end
+  seen[value] = true
+
+  local result = {}
+  local count = 0
+  for key, child in pairs(value) do
+    count = count + 1
+    if count > MAX_FIELDS then
+      result["<truncated>"] = count - 1
+      break
+    end
+    result[SanitizeKey(key)] = Sanitize(child, depth + 1, seen)
+  end
+  seen[value] = nil
+  return result
+end
+
 local function Ensure()
-  DB.log = DB.log or {}
-  DB.maxLines = DB.maxLines or 6000
+  if type(_G.SwingBarMidnightDebuggerDB) == "table" and _G.SwingBarMidnightDebuggerDB ~= DB then
+    DB = _G.SwingBarMidnightDebuggerDB
+    ns.DB = DB
+  end
+  DB.version = 2
+  DB.log = IsSafeTable(DB.log) and DB.log or {}
+  local maxEntries = SafeNumber(DB.maxEntries) or SafeNumber(DB.maxLines) or DEFAULT_MAX_ENTRIES
+  if maxEntries < 50 then maxEntries = 50 elseif maxEntries > MAX_ENTRIES_LIMIT then maxEntries = MAX_ENTRIES_LIMIT end
+  DB.maxEntries = math.floor(maxEntries + 0.5)
+  DB.maxLines = nil
 end
 
 function ns.InitLogger()
   Ensure()
 end
 
 local function Trim()
   Ensure()
-  local maxLines = DB.maxLines
-  if #DB.log <= maxLines then return end
-  local drop = #DB.log - maxLines
-  for _=1, drop do table.remove(DB.log, 1) end
+  local overflow = #DB.log - DB.maxEntries
+  if overflow <= 0 then return end
+  for _ = 1, overflow do table.remove(DB.log, 1) end
 end
 
 function ns.Log(tag, data)
   Ensure()
-  table.insert(DB.log, { t = GetTime(), tag = tag, data = data })
+  local timestamp = 0
+  if type(GetTime) == "function" then
+    local ok, value = pcall(GetTime)
+    if ok then timestamp = SafeNumber(value) or 0 end
+  end
+  DB.log[#DB.log + 1] = {
+    t = timestamp,
+    tag = SafeString(tag) or "?",
+    data = Sanitize(data),
+  }
   Trim()
 end
 
 function ns.Clear()
+  Ensure()
   DB.log = {}
 end
 
+local function ScalarText(value)
+  local valueType = type(value)
+  if value == nil then return "nil" end
+  if valueType == "string" then return value end
+  if valueType == "number" then return string.format("%.3f", value) end
+  if valueType == "boolean" then return value and "true" or "false" end
+  return "<" .. valueType .. ">"
 end
 
+local function Flatten(prefix, value, output, depth)
+  depth = depth or 0
+  if type(value) ~= "table" or depth >= MAX_DEPTH then
+    output[#output + 1] = prefix .. "=" .. ScalarText(value)
+    return
+  end
+
+  local keys = {}
+  for key in pairs(value) do keys[#keys + 1] = key end
+  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
+  for _, key in ipairs(keys) do
+    local childPrefix = prefix == "" and tostring(key) or (prefix .. "." .. tostring(key))
+    Flatten(childPrefix, value[key], output, depth + 1)
+  end
+end
+
 function ns.Format(limitChars)
   Ensure()
-  limitChars = limitChars or 12000
-  local out, total = {}, 0
-
-  local function add(s)
-    total = total + #s + 1
-    if total > limitChars then return false end
-    out[#out+1] = s
-    return true
-  end
-
-  for i = #DB.log, 1, -1 do
-    local e = DB.log[i]
-    local ts = string.format("%.3f", e.t or 0)
-    local tag = tostring(e.tag or "?")
-    local msg = ""
-
-    if type(e.data) == "table" then
-      local parts = {}
-      for k,v in pairs(e.data) do
-        if type(v) == "number" then
-          parts[#parts+1] = k.."="..string.format("%.3f", v)
-        else
-          parts[#parts+1] = k.."="..tostring(v)
-        end
-      end
-      table.sort(parts)
-      msg = table.concat(parts, " ")
-    elseif e.data ~= nil then
-      msg = tostring(e.data)
-    end
-
-    local line = ts.."  "..tag..(msg~="" and ("  "..msg) or "")
-    if not add(line) then break end
+  limitChars = SafeNumber(limitChars) or 50000
+  if limitChars < 1000 then limitChars = 1000 elseif limitChars > 200000 then limitChars = 200000 end
+
+  local reversed = {}
+  local total = 0
+  for index = #DB.log, 1, -1 do
+    local entry = DB.log[index]
+    local parts = {}
+    if type(entry.data) == "table" then
+      Flatten("", entry.data, parts, 0)
+    elseif entry.data ~= nil then
+      parts[1] = ScalarText(entry.data)
+    end
+    local suffix = #parts > 0 and ("  " .. table.concat(parts, " ")) or ""
+    local line = string.format("%.3f  %s%s", SafeNumber(entry.t) or 0, SafeString(entry.tag) or "?", suffix)
+    total = total + #line + 1
+    if total > limitChars then break end
+    reversed[#reversed + 1] = line
   end
 
-  local rev = {}
-  for i = #out, 1, -1 do rev[#rev+1] = out[i] end
-  return table.concat(rev, "\n")
+  local output = {}
+  for index = #reversed, 1, -1 do output[#output + 1] = reversed[index] end
+  return table.concat(output, "\n")
 end
+
+ns.Safe = {
+  CanAccess = CanAccess,
+  SafeBoolean = SafeBoolean,
+  SafeNumber = SafeNumber,
+  SafeString = SafeString,
+  Sanitize = Sanitize,
+}
```

---

### Patch 3: `main.lua` (Prediction Snapshot Whitelist & Event Coalescing)
```diff
--- a/_Addons/SwingBarMidnight_Debugger/main.lua
+++ b/_Addons/SwingBarMidnight_Debugger/main.lua
@@ -1,110 +1,112 @@
 -- SwingBarMidnight_Debugger/main.lua
+-- Event-driven observer for SwingBarMidnight's exported prediction state.
+
 local ADDON_NAME, ns = ...
+local Safe = ns.Safe
 
-local function OverlayActiveCount(spellId)
-  local f = _G.SpellActivationOverlayFrame
-  if not f or not f.GetChildren then return 0 end
-
-  local cnt = 0
-  local kids = { f:GetChildren() }
-  local max = #kids
-  if max > 256 then max = 256 end
-
-  for i=1, max do
-    local c = kids[i]
-    if c and c.IsShown and c:IsShown() then
-      local sid = c.spellId or c.spellID
-      if type(sid) == "number" and sid == spellId then
-        cnt = cnt + 1
-      end
-    end
+local latestSnapshot
+local pendingSnapshot = false
+local pendingReason
+
+local function ReadMainState()
+  local state = _G.SwingBarMidnightState
+  if not state or not Safe.CanAccess(state) or type(state) ~= "table" then return nil end
+  if type(issecrettable) == "function" then
+    local ok, secret = pcall(issecrettable, state)
+    if not ok or secret == true then return nil end
   end
-  return cnt
+  return state
 end
 
-ns.InitLogger()
-if ns.UI and ns.UI.Init then ns.UI:Init() end
-
-local ev = CreateFrame("Frame")
-
-ev:SetScript("OnEvent", function(_, event, ...)
-  if event == "PLAYER_REGEN_DISABLED" then
-    ns.Log("COMBAT", { enter=1 })
-  elseif event == "PLAYER_REGEN_ENABLED" then
-    ns.Log("COMBAT", { leave=1 })
-  elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" or event == "SPELL_ACTIVATION_OVERLAY_SHOW" then
-    local spellId = ...
-    ns.Log("OVERLAY_SHOW", { ev=event, spellId=spellId })
-  elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" or event == "SPELL_ACTIVATION_OVERLAY_HIDE" then
-    local spellId = ...
-    ns.Log("OVERLAY_HIDE", { ev=event, spellId=spellId })
-  elseif event == "UNIT_ATTACK_SPEED" then
-    local unit = ...
-    if unit == "player" then
-      local mh, oh = UnitAttackSpeed("player")
-      ns.Log("SPEED", { mh=mh, oh=oh })
-    end
-  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
-    local unit, _, spellId = ...
-    if unit == "player" then
-      ns.Log("CAST_OK", { spellId=spellId })
-    end
+local function ReadMainDB()
+  local db = _G.SwingBarMidnightDB
+  if not db or not Safe.CanAccess(db) or type(db) ~= "table" then return nil end
+  if type(issecrettable) == "function" then
+    local ok, secret = pcall(issecrettable, db)
+    if not ok or secret == true then return nil end
   end
-
-  if ns.UI and ns.UI.Update then ns.UI:Update() end
-end)
-
-local function RegisterEventsNow()
-  ev:RegisterEvent("PLAYER_REGEN_DISABLED")
-  ev:RegisterEvent("PLAYER_REGEN_ENABLED")
-  ev:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
-  ev:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
-  ev:RegisterEvent("SPELL_ACTIVATION_OVERLAY_SHOW")
-  ev:RegisterEvent("SPELL_ACTIVATION_OVERLAY_HIDE")
-  ev:RegisterEvent("UNIT_ATTACK_SPEED")
-  ev:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
-  ns.Log("DBG", { msg="events registered" })
+  return db
 end
 
--- Avoid forbidden RegisterEvent if loaded in combat (/reload in combat)
-if not InCombatLockdown() then
-  RegisterEventsNow()
-else
-  local defer = CreateFrame("Frame")
-  defer:SetScript("OnUpdate", function(self)
-    if not InCombatLockdown() then
-      self:SetScript("OnUpdate", nil)
-      RegisterEventsNow()
-    end
-  end)
+local function OrdinaryNumber(value)
+  return Safe.SafeNumber(value) or "<unavailable>"
 end
 
-local sampler = CreateFrame("Frame")
-local acc=0
-sampler:SetScript("OnUpdate", function(_, elapsed)
-  acc = acc + elapsed
-  if acc < 0.20 then return end
-  acc = 0
-
-  local st = _G.SwingBarMidnightState
-  if type(st) ~= "table" then return end
-
-  local mainDB = _G.SwingBarMidnightDB
-  local spellId = 49020
-  if type(mainDB) == "table" and type(mainDB.anchorSpellIDs) == "string" then
-    local first = mainDB.anchorSpellIDs:match("(%d+)")
-    if first then spellId = tonumber(first) or spellId end
+local function OrdinaryString(value)
+  return Safe.SafeString(value) or "<unavailable>"
 end
 
-  st.overlayCount = OverlayActiveCount(spellId)
+local function OrdinaryBoolean(value)
+  local boolean = Safe.SafeBoolean(value)
+  if boolean == nil then return "<unavailable>" end
+  return boolean
+end
+
+function ns.CaptureSnapshot(reason)
+  local state = ReadMainState()
+  local db = ReadMainDB()
+  local snapshot = {
+    model = "predicted-cadence",
+    reason = Safe.SafeString(reason) or "manual",
+    mainLoaded = state ~= nil,
+  }
+
+  if state then
+    snapshot.inCombat = OrdinaryBoolean(state.inCombat)
+    snapshot.mhPeriod = OrdinaryNumber(state.mhPeriod)
+    snapshot.ohPeriod = OrdinaryNumber(state.ohPeriod)
+    snapshot.mhStatus = OrdinaryString(state.mhStatus)
+    snapshot.ohStatus = OrdinaryString(state.ohStatus)
+    snapshot.t0MH = OrdinaryNumber(state.t0MH)
+    snapshot.t0OH = OrdinaryNumber(state.t0OH)
+    snapshot.phaseReason = OrdinaryString(state.phaseReason)
+    snapshot.pendingApply = OrdinaryBoolean(state.pendingApply)
+  end
+
+  if db then
+    snapshot.enabled = OrdinaryBoolean(db.enabled)
+    snapshot.combatOnly = OrdinaryBoolean(db.showOnlyInCombat)
+    snapshot.showOffhand = OrdinaryBoolean(db.showOffhand)
+    snapshot.locked = OrdinaryBoolean(db.locked)
+  end
+
+  latestSnapshot = snapshot
+  ns.Log("SNAPSHOT", snapshot)
   if ns.UI and ns.UI.Update then ns.UI:Update() end
+  return snapshot
+end
+
+function ns.GetLatestSnapshot()
+  return latestSnapshot
+end
+
+local function QueueSnapshot(reason)
+  pendingReason = Safe.SafeString(reason) or "event"
+  if pendingSnapshot then return end
+  pendingSnapshot = true
+
+  local function Run()
+    pendingSnapshot = false
+    local queuedReason = pendingReason
+    pendingReason = nil
+    ns.CaptureSnapshot(queuedReason)
+  end
+
+  if C_Timer and type(C_Timer.After) == "function" then
+    C_Timer.After(0, Run)
+  else
+    Run()
+  end
+end
+
+ns.InitLogger()
+if ns.UI and ns.UI.Init then ns.UI:Init() end
+
+local events = CreateFrame("Frame")
+events:RegisterEvent("PLAYER_LOGIN")
+events:RegisterEvent("PLAYER_REGEN_DISABLED")
+events:RegisterEvent("PLAYER_REGEN_ENABLED")
+events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
+if type(events.RegisterUnitEvent) == "function" then
+  events:RegisterUnitEvent("UNIT_ATTACK_SPEED", "player")
+else
+  events:RegisterEvent("UNIT_ATTACK_SPEED")
+end
+
+events:SetScript("OnEvent", function(_, event, ...)
+  if event == "PLAYER_LOGIN" then
+    QueueSnapshot("login")
+  elseif event == "PLAYER_REGEN_DISABLED" then
+    QueueSnapshot("combat-enter")
+  elseif event == "PLAYER_REGEN_ENABLED" then
+    QueueSnapshot("combat-leave")
+  elseif event == "PLAYER_EQUIPMENT_CHANGED" then
+    QueueSnapshot("equipment-change")
+  elseif event == "UNIT_ATTACK_SPEED" then
+    local unit = ...
+    local safeUnit = Safe.SafeString(unit)
+    if safeUnit == nil or safeUnit == "player" then
+      QueueSnapshot("attack-speed-change")
+    end
+  end
+end)
+
+SLASH_SWINGDEBUG1 = "/swingdebug"
+SlashCmdList.SWINGDEBUG = function(message)
+  message = Safe.SafeString(message) or ""
+  message = message:lower():gsub("^%s+", ""):gsub("%s+$", "")
+  if message == "snapshot" then
+    ns.CaptureSnapshot("slash")
+  elseif message == "clear" then
+    ns.Clear()
+    if ns.UI and ns.UI.Update then ns.UI:Update() end
+  elseif message == "copy" then
+    if ns.UI and ns.UI.ShowCopy then ns.UI:ShowCopy() end
+  else
+    if ns.UI and ns.UI.Toggle then ns.UI:Toggle() end
+  end
+end
+
+print("SwingBarMidnight Debugger loaded. /swingdebug")
+ns.Log("DEBUGGER", { status = "loaded", model = "predicted-cadence" })
+
+ns.Runtime = {
+  QueueSnapshot = QueueSnapshot,
+  GetEventFrame = function() return events end,
+  IsSnapshotPending = function() return pendingSnapshot end,
+}
```

---

### Patch 4: `ui.lua` (Sanitized Prediction Display & Safe Drag)
```diff
--- a/_Addons/SwingBarMidnight_Debugger/ui.lua
+++ b/_Addons/SwingBarMidnight_Debugger/ui.lua
@@ -1,38 +1,52 @@
 -- SwingBarMidnight_Debugger/ui.lua
+-- On-demand UI for sanitized prediction snapshots and bounded logs.
+
 local ADDON_NAME, ns = ...
+local Safe = ns.Safe
 
 ns.UI = ns.UI or {}
 local UI = ns.UI
 
-local _id=0
-local function NextName(prefix) _id=_id+1; return prefix.."_".._id end
+local id = 0
+local function NextName(prefix)
+  id = id + 1
+  return prefix .. "_" .. id
+end
 
-local function Backdrop(f)
-  f:SetBackdrop({
-    bgFile="Interface/Tooltips/UI-Tooltip-Background",
-    edgeFile="Interface/Tooltips/UI-Tooltip-Border",
-    tile=true, tileSize=16, edgeSize=16,
-    insets={left=4,right=4,top=4,bottom=4},
+local function ApplyBackdrop(frame)
+  frame:SetBackdrop({
+    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
+    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
+    tile = true,
+    tileSize = 16,
+    edgeSize = 16,
+    insets = { left = 4, right = 4, top = 4, bottom = 4 },
   })
-  f:SetBackdropColor(0,0,0,0.85)
-  f:SetBackdropBorderColor(0.6,0.6,0.6,0.9)
+  frame:SetBackdropColor(0, 0, 0, 0.85)
+  frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.9)
 end
 
-local function Label(parent, text, x, y)
-  local fs = parent:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
-  fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
-  fs:SetText(text)
-  return fs
+local function Label(parent, text, x, y, width)
+  local fontString = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
+  fontString:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
+  fontString:SetText(text)
+  if width then fontString:SetWidth(width) end
+  fontString:SetJustifyH("LEFT")
+  return fontString
 end
 
-local function Value(parent, x, y)
-  local fs = parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
-  fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
-  fs:SetText("")
-  return fs
+local function Value(parent, x, y, width)
+  local fontString = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
+  fontString:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
+  fontString:SetText("")
+  if width then fontString:SetWidth(width) end
+  fontString:SetJustifyH("LEFT")
+  return fontString
 end
 
-local function Button(parent, text, w, h)
-  local b = CreateFrame("Button", NextName("SwingDbgBtn"), parent, "UIPanelButtonTemplate")
-  b:SetText(text)
-  b:SetSize(w,h)
-  return b
+local function Button(parent, text, width, height)
+  local button = CreateFrame("Button", NextName("SwingDbgBtn"), parent, "UIPanelButtonTemplate")
+  button:SetText(text)
+  button:SetSize(width, height)
+  return button
+end
+
+local function OrdinaryText(value)
+  if type(value) == "string" then return value end
+  if type(value) == "number" then return string.format("%.3f", value) end
+  if type(value) == "boolean" then return value and "true" or "false" end
+  if value == nil then return "-" end
+  return "<unavailable>"
 end
 
 function UI:Init()
   if self.frame then return end
 
-  local f = CreateFrame("Frame", "SwingBarMidnightDebuggerFrame", UIParent, "BackdropTemplate")
-  f:SetFrameStrata("DIALOG")
-  f:SetClampedToScreen(true)
-  f:SetSize(560, 420)
-  f:SetPoint("CENTER")
-  Backdrop(f)
-
-  f:EnableMouse(true)
-  f:SetMovable(true)
-  f:RegisterForDrag("LeftButton")
-  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
-  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
-
-  local title = f:CreateFontString(nil,"OVERLAY","GameFontNormal")
-  title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
-  title:SetText("SwingBarMidnight Debugger")
-
-  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
-  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
-
-  local bClear = Button(f,"Clear",70,20)
-  bClear:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -32)
-  bClear:SetScript("OnClick", function()
+  local frame = CreateFrame("Frame", "SwingBarMidnightDebuggerFrame", UIParent, "BackdropTemplate")
+  frame:SetFrameStrata("DIALOG")
+  frame:SetClampedToScreen(true)
+  frame:SetSize(620, 460)
+  frame:SetPoint("CENTER")
+  ApplyBackdrop(frame)
+  frame:EnableMouse(true)
+  frame:SetMovable(true)
+  frame:RegisterForDrag("LeftButton")
+  frame:SetScript("OnDragStart", function(self)
+    if not InCombatLockdown() then self:StartMoving() end
+  end)
+  frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
+
+  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
+  title:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -10)
+  title:SetText("SwingBarMidnight Prediction Debugger")
+
+  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
+  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
+
+  local snapshot = Button(frame, "Snapshot", 80, 20)
+  snapshot:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -32)
+  snapshot:SetScript("OnClick", function() ns.CaptureSnapshot("button") end)
+
+  local clear = Button(frame, "Clear", 70, 20)
+  clear:SetPoint("LEFT", snapshot, "RIGHT", 6, 0)
+  clear:SetScript("OnClick", function()
     ns.Clear()
     UI:Update()
   end)
 
-  local bCopy = Button(f,"Copy",70,20)
-  bCopy:SetPoint("LEFT", bClear, "RIGHT", 6, 0)
-  bCopy:SetScript("OnClick", function()
-    UI:ShowCopy()
-  end)
+  local copy = Button(frame, "Copy", 70, 20)
+  copy:SetPoint("LEFT", clear, "RIGHT", 6, 0)
+  copy:SetScript("OnClick", function() UI:ShowCopy() end)
 
-  Label(f, "In combat:", 12, -62)
-  local vCombat = Value(f, 90, -62)
-
-  Label(f, "Speed (mh/oh):", 12, -78)
-  local vSpeed = Value(f, 110, -78)
-
-  Label(f, "Last anchor:", 12, -94)
-  local vAnchor = Value(f, 110, -94)
-
-  Label(f, "Suppress until:", 12, -110)
-  local vSupp = Value(f, 110, -110)
-
-  Label(f, "Overlay count:", 12, -126)
-  local vOv = Value(f, 110, -126)
-
-  local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
-  sf:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -148)
-  sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 12)
-
-  local eb = CreateFrame("EditBox", nil, sf)
-  eb:SetMultiLine(true)
-  eb:SetFontObject(ChatFontNormal)
-  eb:SetWidth(1)
-  eb:SetAutoFocus(false)
-  eb:EnableMouse(true)
-  eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
-  sf:SetScrollChild(eb)
-
-  f._vCombat = vCombat
-  f._vSpeed = vSpeed
-  f._vAnchor = vAnchor
-  f._vSupp  = vSupp
-  f._vOv    = vOv
-  f._scroll = sf
-  f._edit = eb
+  Label(frame, "Model:", 12, -64)
+  frame.model = Value(frame, 115, -64, 180)
+  Label(frame, "Reason:", 310, -64)
+  frame.reason = Value(frame, 380, -64, 200)
+
+  Label(frame, "Main loaded:", 12, -82)
+  frame.loaded = Value(frame, 115, -82, 100)
+  Label(frame, "In combat:", 310, -82)
+  frame.combat = Value(frame, 380, -82, 100)
+
+  Label(frame, "MH period/status:", 12, -100)
+  frame.mh = Value(frame, 135, -100, 170)
+  Label(frame, "OH period/status:", 310, -100)
+  frame.oh = Value(frame, 435, -100, 165)
+
+  Label(frame, "MH/OH phase origin:", 12, -118)
+  frame.origins = Value(frame, 150, -118, 230)
+  Label(frame, "Phase reason:", 390, -118)
+  frame.phaseReason = Value(frame, 485, -118, 115)
+
+  Label(frame, "Enabled / combat-only / OH / locked:", 12, -136)
+  frame.settings = Value(frame, 245, -136, 355)
+
+  local note = Label(
+    frame,
+    "Prediction state only. No overlay count, proc aura, range, action-slot, cast, or actual swing-hit evidence is collected.",
+    12,
+    -158,
+    580
+  )
+  note:SetWordWrap(true)
+
+  local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
+  scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -196)
+  scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 12)
+
+  local edit = CreateFrame("EditBox", nil, scroll)
+  edit:SetMultiLine(true)
+  edit:SetFontObject(ChatFontNormal)
+  edit:SetWidth(1)
+  edit:SetAutoFocus(false)
+  edit:EnableMouse(true)
+  edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
+  scroll:SetScrollChild(edit)
+
+  frame.scroll = scroll
+  frame.edit = edit
+  self.frame = frame
+  frame:Hide()
 end
 
 function UI:Toggle()
@@ -43,45 +57,71 @@ function UI:Toggle()
   if self.frame:IsShown() then
     self.frame:Hide()
   else
     self.frame:Show()
+    if not ns.GetLatestSnapshot() then ns.CaptureSnapshot("ui-open") end
     self:Update()
   end
 end
 
 function UI:Update()
   if not self.frame or not self.frame:IsShown() then return end
+  local snapshot = ns.GetLatestSnapshot() or {}
+
+  self.frame.model:SetText(OrdinaryText(snapshot.model))
+  self.frame.reason:SetText(OrdinaryText(snapshot.reason))
+  self.frame.loaded:SetText(OrdinaryText(snapshot.mainLoaded))
+  self.frame.combat:SetText(OrdinaryText(snapshot.inCombat))
+  self.frame.mh:SetText(OrdinaryText(snapshot.mhPeriod) .. " / " .. OrdinaryText(snapshot.mhStatus))
+  self.frame.oh:SetText(OrdinaryText(snapshot.ohPeriod) .. " / " .. OrdinaryText(snapshot.ohStatus))
+  self.frame.origins:SetText(OrdinaryText(snapshot.t0MH) .. " / " .. OrdinaryText(snapshot.t0OH))
+  self.frame.phaseReason:SetText(OrdinaryText(snapshot.phaseReason))
+  self.frame.settings:SetText(table.concat({
+    OrdinaryText(snapshot.enabled),
+    OrdinaryText(snapshot.combatOnly),
+    OrdinaryText(snapshot.showOffhand),
+    OrdinaryText(snapshot.locked),
+  }, " / "))
+
+  self.frame.edit:SetText(ns.Format(50000))
+  local width = self.frame.scroll:GetWidth()
+  if type(width) == "number" and width > 50 then self.frame.edit:SetWidth(width - 10) end
+end
+
+function UI:ShowCopy()
+  if not self.frame then self:Init() end
+  if self.copy and self.copy:IsShown() then self.copy:Hide() end
+
+  local panel = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
+  panel:SetFrameStrata("FULLSCREEN_DIALOG")
+  panel:SetPoint("CENTER")
+  panel:SetSize(560, 380)
+  ApplyBackdrop(panel)
+
+  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
+  title:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -10)
+  title:SetText("Copy sanitized log (Ctrl+C)")
+
+  local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
+  close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -2, -2)
+  close:SetScript("OnClick", function() panel:Hide() end)
+
+  local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
+  scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -32)
+  scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 12)
+
+  local edit = CreateFrame("EditBox", nil, scroll)
+  edit:SetMultiLine(true)
+  edit:SetFontObject(ChatFontNormal)
+  edit:SetAutoFocus(true)
+  edit:SetWidth(1)
+  edit:EnableMouse(true)
+  edit:SetScript("OnEscapePressed", function(self)
+    self:ClearFocus()
+    panel:Hide()
+  end)
+  scroll:SetScrollChild(edit)
+  edit:SetText(ns.Format(100000))
+  edit:HighlightText()
+
+  panel:Show()
+  self.copy = panel
+end
```

---

### Patch 5: `tests/test_safe_prediction_debugger_12_1.lua` (New Regression Harness)
```lua
local SECRET = setmetatable({}, {
  __tostring = function() error("inaccessible value was stringified") end,
  __index = function() error("inaccessible value was indexed") end,
  __lt = function() error("inaccessible value was compared") end,
  __concat = function() error("inaccessible value was concatenated") end,
})
local scheduled = {}
local eventFrame
local registeredEvents = {}
local registeredUnitEvents = {}
local uiUpdates = 0

local function assertEq(actual, expected, message)
  if actual ~= expected then
    error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

function canaccessvalue(value) return not rawequal(value, SECRET) end
function issecretvalue(value) return rawequal(value, SECRET) end
function issecrettable(value) return false end
function GetTime() return 123.456 end
function InCombatLockdown() return false end

C_Timer = {
  After = function(_, callback) scheduled[#scheduled + 1] = callback end,
}

SlashCmdList = {}

function CreateFrame()
  local frame = { scripts = {} }
  function frame:RegisterEvent(event) registeredEvents[event] = true end
  function frame:RegisterUnitEvent(event, unit) registeredUnitEvents[event] = unit end
  function frame:SetScript(name, callback) self.scripts[name] = callback end
  eventFrame = frame
  return frame
end

SwingBarMidnightState = {
  inCombat = true,
  mhPeriod = 2.6,
  ohPeriod = SECRET,
  mhStatus = "accessible",
  ohStatus = SECRET,
  t0MH = 100,
  t0OH = SECRET,
  phaseReason = "manual reset",
  pendingApply = false,
}
SwingBarMidnightDB = {
  enabled = true,
  showOnlyInCombat = true,
  showOffhand = false,
  locked = true,
}
SwingBarMidnightDebuggerDB = {
  maxEntries = 50,
  log = {},
}

local ns = {
  UI = {
    Init = function() end,
    Update = function() uiUpdates = uiUpdates + 1 end,
    Toggle = function() end,
    ShowCopy = function() end,
  },
}

assert(loadfile("log.lua"))("SwingBarMidnight_Debugger", ns)
assert(loadfile("main.lua"))("SwingBarMidnight_Debugger", ns)

assertEq(registeredEvents.SPELL_ACTIVATION_OVERLAY_GLOW_SHOW, nil, "overlay event must not be registered")
assertEq(registeredEvents.UNIT_AURA, nil, "UNIT_AURA must not be registered")
assertEq(registeredEvents.PLAYER_LOGIN, true, "login event")
assertEq(registeredEvents.PLAYER_EQUIPMENT_CHANGED, true, "equipment event")
assertEq(registeredUnitEvents.UNIT_ATTACK_SPEED, "player", "attack-speed event owner")
assertEq(eventFrame.scripts.OnUpdate, nil, "debugger must not poll")

local onEvent = assert(eventFrame.scripts.OnEvent)
onEvent(eventFrame, "PLAYER_LOGIN")
onEvent(eventFrame, "UNIT_ATTACK_SPEED", "player")
assertEq(ns.Runtime.IsSnapshotPending(), true, "snapshot was not queued")
assertEq(#scheduled, 1, "event burst was not coalesced")

scheduled[1]()
assertEq(ns.Runtime.IsSnapshotPending(), false, "snapshot remained pending")
local snapshot = ns.GetLatestSnapshot()
assertEq(snapshot.model, "predicted-cadence", "model")
assertEq(snapshot.reason, "attack-speed-change", "coalesced reason")
assertEq(snapshot.mhPeriod, 2.6, "accessible MH period")
assertEq(snapshot.ohPeriod, "<unavailable>", "inaccessible OH period")
assertEq(snapshot.ohStatus, "<unavailable>", "inaccessible OH status")
assertEq(snapshot.t0OH, "<unavailable>", "inaccessible OH origin")
assertEq(snapshot.enabled, true, "enabled state")
assert(uiUpdates > 0, "UI was not notified")

local raw = {}
raw[SECRET] = SECRET
ns.Log("RAW", raw)
local ok, text = pcall(ns.Format, 50000)
assert(ok, text)
assert(text:find("<inaccessible%-key>"), "inaccessible key marker missing")
assert(text:find("<inaccessible>"), "inaccessible value marker missing")

for index = 1, 80 do ns.Log("ROW", { index = index }) end
assertEq(#SwingBarMidnightDebuggerDB.log, 50, "bounded log size")

ns.Clear()
assertEq(#SwingBarMidnightDebuggerDB.log, 0, "clear")

print("PASS: debugger logs only sanitized prediction snapshots, coalesces events, and has no overlay scan or polling loop")
```

---

## Verification & Live Validation Plan

### Automated Regression Harness
The mock test harness validates:
1. **Access-first boundary**: SecretValue userdata proxies with throwing metamethods are safely intercepted and replaced with `<unavailable>`, `<inaccessible>`, or `<inaccessible-key>` without raising Lua errors.
2. **Prohibited API check**: Asserts that `SPELL_ACTIVATION_OVERLAY_*` and `UNIT_AURA` are never registered.
3. **Burst coalescing**: Asserts that multiple events firing simultaneously result in exactly one scheduled callback (`#scheduled == 1`) and one coalesced snapshot.
4. **Polling elimination**: Asserts that `eventFrame.scripts.OnUpdate == nil`.
5. **Bounded logging**: Asserts that inserting 80 rows into a DB configured for `maxEntries = 50` caps the log length at exactly 50 entries.

### In-Game Live Verification Checklist
1. **Load Order & Dependency Gating**:
   - Ensure `SwingBarMidnight` loads before `SwingBarMidnight_Debugger`.
   - Verify that disabling `SwingBarMidnight` prevents `SwingBarMidnight_Debugger` from loading, reporting dependency missing.
2. **Slash Command & UI Functionality**:
   - Execute `/swingdebug`: window toggles open and displays the initial snapshot (`ui-open`).
   - Execute `/swingdebug snapshot`: captures a manual snapshot and refreshes displayed labels.
   - Execute `/swingdebug clear`: wipes `SwingBarMidnightDebuggerDB.log` and clears the edit box.
   - Execute `/swingdebug copy`: opens fullscreen copy modal with pre-selected text.
3. **Event Coalescing in Combat**:
   - Engage combat (`PLAYER_REGEN_DISABLED`). Verify snapshot with reason `combat-enter`.
   - Change weapons or gear (`PLAYER_EQUIPMENT_CHANGED` / `UNIT_ATTACK_SPEED`). Verify snapshot with reason `attack-speed-change` or `equipment-change`.
   - Disengage combat (`PLAYER_REGEN_ENABLED`). Verify snapshot with reason `combat-leave`.
4. **Taint & Drag Verification**:
   - Attempt to drag the debugger window during combat lockdown: drag is safely blocked without generating execution taint or addon action forbidden popups.
   - Inspect `/dump SwingBarMidnightDebuggerDB`: confirm schema v2 format, bounded entry count, and absence of raw userdata or secret proxy objects.
