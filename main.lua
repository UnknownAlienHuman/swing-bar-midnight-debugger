-- SwingBarMidnight_Debugger/main.lua
local ADDON_NAME, ns = ...

local function OverlayActiveCount(spellId)
  local f = _G.SpellActivationOverlayFrame
  if not f or not f.GetChildren then return 0 end

  local cnt = 0
  local kids = { f:GetChildren() }
  local max = #kids
  if max > 256 then max = 256 end

  for i=1, max do
    local c = kids[i]
    if c and c.IsShown and c:IsShown() then
      local sid = c.spellId or c.spellID
      if type(sid) == "number" and sid == spellId then
        cnt = cnt + 1
      end
    end
  end
  return cnt
end

ns.InitLogger()
if ns.UI and ns.UI.Init then ns.UI:Init() end

local ev = CreateFrame("Frame")

ev:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_REGEN_DISABLED" then
    ns.Log("COMBAT", { enter=1 })
  elseif event == "PLAYER_REGEN_ENABLED" then
    ns.Log("COMBAT", { leave=1 })
  elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" or event == "SPELL_ACTIVATION_OVERLAY_SHOW" then
    local spellId = ...
    ns.Log("OVERLAY_SHOW", { ev=event, spellId=spellId })
  elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" or event == "SPELL_ACTIVATION_OVERLAY_HIDE" then
    local spellId = ...
    ns.Log("OVERLAY_HIDE", { ev=event, spellId=spellId })
  elseif event == "UNIT_ATTACK_SPEED" then
    local unit = ...
    if unit == "player" then
      local mh, oh = UnitAttackSpeed("player")
      ns.Log("SPEED", { mh=mh, oh=oh })
    end
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    local unit, _, spellId = ...
    if unit == "player" then
      ns.Log("CAST_OK", { spellId=spellId })
    end
  end

  if ns.UI and ns.UI.Update then ns.UI:Update() end
end)

local function RegisterEventsNow()
  ev:RegisterEvent("PLAYER_REGEN_DISABLED")
  ev:RegisterEvent("PLAYER_REGEN_ENABLED")
  ev:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
  ev:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
  ev:RegisterEvent("SPELL_ACTIVATION_OVERLAY_SHOW")
  ev:RegisterEvent("SPELL_ACTIVATION_OVERLAY_HIDE")
  ev:RegisterEvent("UNIT_ATTACK_SPEED")
  ev:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
  ns.Log("DBG", { msg="events registered" })
end

-- Avoid forbidden RegisterEvent if loaded in combat (/reload in combat)
if not InCombatLockdown() then
  RegisterEventsNow()
else
  local defer = CreateFrame("Frame")
  defer:SetScript("OnUpdate", function(self)
    if not InCombatLockdown() then
      self:SetScript("OnUpdate", nil)
      RegisterEventsNow()
    end
  end)
end

local sampler = CreateFrame("Frame")
local acc=0
sampler:SetScript("OnUpdate", function(_, elapsed)
  acc = acc + elapsed
  if acc < 0.20 then return end
  acc = 0

  local st = _G.SwingBarMidnightState
  if type(st) ~= "table" then return end

  local mainDB = _G.SwingBarMidnightDB
  local spellId = 49020
  if type(mainDB) == "table" and type(mainDB.anchorSpellIDs) == "string" then
    local first = mainDB.anchorSpellIDs:match("(%d+)")
    if first then spellId = tonumber(first) or spellId end
  end

  st.overlayCount = OverlayActiveCount(spellId)
  if ns.UI and ns.UI.Update then ns.UI:Update() end
end)

SLASH_SWINGDEBUG1 = "/swingdebug"
SlashCmdList["SWINGDEBUG"] = function()
  if ns.UI and ns.UI.Toggle then ns.UI:Toggle() end
end

print("SwingBarMidnight Debugger loaded. /swingdebug")
ns.Log("DBG", { msg="debugger loaded" })
