-- SwingBarMidnight_Debugger/ui.lua
-- On-demand UI for sanitized prediction snapshots and bounded logs.

local ADDON_NAME, ns = ...
local Safe = ns.Safe

ns.UI = ns.UI or {}
local UI = ns.UI

local id = 0
local function NextName(prefix)
  id = id + 1
  return prefix .. "_" .. id
end

local function ApplyBackdrop(frame)
  frame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  frame:SetBackdropColor(0, 0, 0, 0.85)
  frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.9)
end

local function Label(parent, text, x, y, width)
  local fontString = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  fontString:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  fontString:SetText(text)
  if width then fontString:SetWidth(width) end
  fontString:SetJustifyH("LEFT")
  return fontString
end

local function Value(parent, x, y, width)
  local fontString = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fontString:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  fontString:SetText("")
  if width then fontString:SetWidth(width) end
  fontString:SetJustifyH("LEFT")
  return fontString
end

local function Button(parent, text, width, height)
  local button = CreateFrame("Button", NextName("SwingDbgBtn"), parent, "UIPanelButtonTemplate")
  button:SetText(text)
  button:SetSize(width, height)
  return button
end

local function OrdinaryText(value)
  if type(value) == "string" then return value end
  if type(value) == "number" then return string.format("%.3f", value) end
  if type(value) == "boolean" then return value and "true" or "false" end
  if value == nil then return "-" end
  return "<unavailable>"
end

function UI:Init()
  if self.frame then return end

  local frame = CreateFrame("Frame", "SwingBarMidnightDebuggerFrame", UIParent, "BackdropTemplate")
  frame:SetFrameStrata("DIALOG")
  frame:SetClampedToScreen(true)
  frame:SetSize(620, 460)
  frame:SetPoint("CENTER")
  ApplyBackdrop(frame)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self)
    if not InCombatLockdown() then self:StartMoving() end
  end)
  frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -10)
  title:SetText("SwingBarMidnight Prediction Debugger")

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)

  local snapshot = Button(frame, "Snapshot", 80, 20)
  snapshot:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -32)
  snapshot:SetScript("OnClick", function() ns.CaptureSnapshot("button") end)

  local clear = Button(frame, "Clear", 70, 20)
  clear:SetPoint("LEFT", snapshot, "RIGHT", 6, 0)
  clear:SetScript("OnClick", function()
    ns.Clear()
    UI:Update()
  end)

  local copy = Button(frame, "Copy", 70, 20)
  copy:SetPoint("LEFT", clear, "RIGHT", 6, 0)
  copy:SetScript("OnClick", function() UI:ShowCopy() end)

  Label(frame, "Model:", 12, -64)
  frame.model = Value(frame, 115, -64, 180)
  Label(frame, "Reason:", 310, -64)
  frame.reason = Value(frame, 380, -64, 200)

  Label(frame, "Main loaded:", 12, -82)
  frame.loaded = Value(frame, 115, -82, 100)
  Label(frame, "In combat:", 310, -82)
  frame.combat = Value(frame, 380, -82, 100)

  Label(frame, "MH period/status:", 12, -100)
  frame.mh = Value(frame, 135, -100, 170)
  Label(frame, "OH period/status:", 310, -100)
  frame.oh = Value(frame, 435, -100, 165)

  Label(frame, "MH/OH phase origin:", 12, -118)
  frame.origins = Value(frame, 150, -118, 230)
  Label(frame, "Phase reason:", 390, -118)
  frame.phaseReason = Value(frame, 485, -118, 115)

  Label(frame, "Enabled / combat-only / OH / locked:", 12, -136)
  frame.settings = Value(frame, 245, -136, 355)

  local note = Label(
    frame,
    "Prediction state only. No overlay count, proc aura, range, action-slot, cast, or actual swing-hit evidence is collected.",
    12,
    -158,
    580
  )
  note:SetWordWrap(true)

  local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -196)
  scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 12)

  local edit = CreateFrame("EditBox", nil, scroll)
  edit:SetMultiLine(true)
  edit:SetFontObject(ChatFontNormal)
  edit:SetWidth(1)
  edit:SetAutoFocus(false)
  edit:EnableMouse(true)
  edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  scroll:SetScrollChild(edit)

  frame.scroll = scroll
  frame.edit = edit
  self.frame = frame
  frame:Hide()
end

function UI:Toggle()
  if not self.frame then self:Init() end
  if self.frame:IsShown() then
    self.frame:Hide()
  else
    self.frame:Show()
    if not ns.GetLatestSnapshot() then ns.CaptureSnapshot("ui-open") end
    self:Update()
  end
end

function UI:Update()
  if not self.frame or not self.frame:IsShown() then return end
  local snapshot = ns.GetLatestSnapshot() or {}

  self.frame.model:SetText(OrdinaryText(snapshot.model))
  self.frame.reason:SetText(OrdinaryText(snapshot.reason))
  self.frame.loaded:SetText(OrdinaryText(snapshot.mainLoaded))
  self.frame.combat:SetText(OrdinaryText(snapshot.inCombat))
  self.frame.mh:SetText(OrdinaryText(snapshot.mhPeriod) .. " / " .. OrdinaryText(snapshot.mhStatus))
  self.frame.oh:SetText(OrdinaryText(snapshot.ohPeriod) .. " / " .. OrdinaryText(snapshot.ohStatus))
  self.frame.origins:SetText(OrdinaryText(snapshot.t0MH) .. " / " .. OrdinaryText(snapshot.t0OH))
  self.frame.phaseReason:SetText(OrdinaryText(snapshot.phaseReason))
  self.frame.settings:SetText(table.concat({
    OrdinaryText(snapshot.enabled),
    OrdinaryText(snapshot.combatOnly),
    OrdinaryText(snapshot.showOffhand),
    OrdinaryText(snapshot.locked),
  }, " / "))

  self.frame.edit:SetText(ns.Format(50000))
  local width = self.frame.scroll:GetWidth()
  if type(width) == "number" and width > 50 then self.frame.edit:SetWidth(width - 10) end
end

function UI:ShowCopy()
  if not self.frame then self:Init() end
  if self.copy and self.copy:IsShown() then self.copy:Hide() end

  local panel = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
  panel:SetFrameStrata("FULLSCREEN_DIALOG")
  panel:SetPoint("CENTER")
  panel:SetSize(560, 380)
  ApplyBackdrop(panel)

  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -10)
  title:SetText("Copy sanitized log (Ctrl+C)")

  local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -2, -2)
  close:SetScript("OnClick", function() panel:Hide() end)

  local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -32)
  scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 12)

  local edit = CreateFrame("EditBox", nil, scroll)
  edit:SetMultiLine(true)
  edit:SetFontObject(ChatFontNormal)
  edit:SetAutoFocus(true)
  edit:SetWidth(1)
  edit:EnableMouse(true)
  edit:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    panel:Hide()
  end)
  scroll:SetScrollChild(edit)
  edit:SetText(ns.Format(100000))
  edit:HighlightText()

  panel:Show()
  self.copy = panel
end
