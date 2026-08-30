-- SwingBarMidnight_Debugger/main.lua
-- Event-driven observer for SwingBarMidnight's exported prediction state.

local ADDON_NAME, ns = ...
local Safe = ns.Safe

local latestSnapshot
local pendingSnapshot = false
local pendingReason

local function ReadMainState()
  local state = _G.SwingBarMidnightState
  if not state or not Safe.CanAccess(state) or type(state) ~= "table" then return nil end
  if type(issecrettable) == "function" then
    local ok, secret = pcall(issecrettable, state)
    if not ok or secret == true then return nil end
  end
  return state
end

local function ReadMainDB()
  local db = _G.SwingBarMidnightDB
  if not db or not Safe.CanAccess(db) or type(db) ~= "table" then return nil end
  if type(issecrettable) == "function" then
    local ok, secret = pcall(issecrettable, db)
    if not ok or secret == true then return nil end
  end
  return db
end

local function OrdinaryNumber(value)
  return Safe.SafeNumber(value) or "<unavailable>"
end

local function OrdinaryString(value)
  return Safe.SafeString(value) or "<unavailable>"
end

local function OrdinaryBoolean(value)
  local boolean = Safe.SafeBoolean(value)
  if boolean == nil then return "<unavailable>" end
  return boolean
end

function ns.CaptureSnapshot(reason)
  local state = ReadMainState()
  local db = ReadMainDB()
  local snapshot = {
    model = "predicted-cadence",
    reason = Safe.SafeString(reason) or "manual",
    mainLoaded = state ~= nil,
  }

  if state then
    snapshot.inCombat = OrdinaryBoolean(state.inCombat)
    snapshot.mhPeriod = OrdinaryNumber(state.mhPeriod)
    snapshot.ohPeriod = OrdinaryNumber(state.ohPeriod)
    snapshot.mhStatus = OrdinaryString(state.mhStatus)
    snapshot.ohStatus = OrdinaryString(state.ohStatus)
    snapshot.t0MH = OrdinaryNumber(state.t0MH)
    snapshot.t0OH = OrdinaryNumber(state.t0OH)
    snapshot.phaseReason = OrdinaryString(state.phaseReason)
    snapshot.pendingApply = OrdinaryBoolean(state.pendingApply)
  end

  if db then
    snapshot.enabled = OrdinaryBoolean(db.enabled)
    snapshot.combatOnly = OrdinaryBoolean(db.showOnlyInCombat)
    snapshot.showOffhand = OrdinaryBoolean(db.showOffhand)
    snapshot.locked = OrdinaryBoolean(db.locked)
  end

  latestSnapshot = snapshot
  ns.Log("SNAPSHOT", snapshot)
  if ns.UI and ns.UI.Update then ns.UI:Update() end
  return snapshot
end

function ns.GetLatestSnapshot()
  return latestSnapshot
end

local function QueueSnapshot(reason)
  pendingReason = Safe.SafeString(reason) or "event"
  if pendingSnapshot then return end
  pendingSnapshot = true

  local function Run()
    pendingSnapshot = false
    local queuedReason = pendingReason
    pendingReason = nil
    ns.CaptureSnapshot(queuedReason)
  end

  if C_Timer and type(C_Timer.After) == "function" then
    C_Timer.After(0, Run)
  else
    Run()
  end
end

ns.InitLogger()
if ns.UI and ns.UI.Init then ns.UI:Init() end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
if type(events.RegisterUnitEvent) == "function" then
  events:RegisterUnitEvent("UNIT_ATTACK_SPEED", "player")
else
  events:RegisterEvent("UNIT_ATTACK_SPEED")
end

events:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" then
    QueueSnapshot("login")
  elseif event == "PLAYER_REGEN_DISABLED" then
    QueueSnapshot("combat-enter")
  elseif event == "PLAYER_REGEN_ENABLED" then
    QueueSnapshot("combat-leave")
  elseif event == "PLAYER_EQUIPMENT_CHANGED" then
    QueueSnapshot("equipment-change")
  elseif event == "UNIT_ATTACK_SPEED" then
    local unit = ...
    local safeUnit = Safe.SafeString(unit)
    if safeUnit == nil or safeUnit == "player" then
      QueueSnapshot("attack-speed-change")
    end
  end
end)

SLASH_SWINGDEBUG1 = "/swingdebug"
SlashCmdList.SWINGDEBUG = function(message)
  message = Safe.SafeString(message) or ""
  message = message:lower():gsub("^%s+", ""):gsub("%s+$", "")
  if message == "snapshot" then
    ns.CaptureSnapshot("slash")
  elseif message == "clear" then
    ns.Clear()
    if ns.UI and ns.UI.Update then ns.UI:Update() end
  elseif message == "copy" then
    if ns.UI and ns.UI.ShowCopy then ns.UI:ShowCopy() end
  else
    if ns.UI and ns.UI.Toggle then ns.UI:Toggle() end
  end
end

print("SwingBarMidnight Debugger loaded. /swingdebug")
ns.Log("DEBUGGER", { status = "loaded", model = "predicted-cadence" })

ns.Runtime = {
  QueueSnapshot = QueueSnapshot,
  GetEventFrame = function() return events end,
  IsSnapshotPending = function() return pendingSnapshot end,
}
