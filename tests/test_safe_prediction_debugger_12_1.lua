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
