-- SwingBarMidnight_Debugger/ui.lua
local ADDON_NAME, ns = ...

ns.UI = ns.UI or {}
local UI = ns.UI

local _id=0
local function NextName(prefix) _id=_id+1; return prefix.."_".._id end

local function Backdrop(f)
  f:SetBackdrop({
    bgFile="Interface/Tooltips/UI-Tooltip-Background",
    edgeFile="Interface/Tooltips/UI-Tooltip-Border",
    tile=true, tileSize=16, edgeSize=16,
    insets={left=4,right=4,top=4,bottom=4},
  })
  f:SetBackdropColor(0,0,0,0.85)
  f:SetBackdropBorderColor(0.6,0.6,0.6,0.9)
end

local function Label(parent, text, x, y)
  local fs = parent:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
  fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  fs:SetText(text)
  return fs
end

local function Value(parent, x, y)
  local fs = parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
  fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  fs:SetText("")
  return fs
end

local function Button(parent, text, w, h)
  local b = CreateFrame("Button", NextName("SwingDbgBtn"), parent, "UIPanelButtonTemplate")
  b:SetText(text)
  b:SetSize(w,h)
  return b
end

function UI:Init()
  if self.frame then return end

  local f = CreateFrame("Frame", "SwingBarMidnightDebuggerFrame", UIParent, "BackdropTemplate")
  f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true)
  f:SetSize(560, 420)
  f:SetPoint("CENTER")
  Backdrop(f)

  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

  local title = f:CreateFontString(nil,"OVERLAY","GameFontNormal")
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
  title:SetText("SwingBarMidnight Debugger")

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)

  local bClear = Button(f,"Clear",70,20)
  bClear:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -32)
  bClear:SetScript("OnClick", function()
    ns.Clear()
    UI:Update()
  end)

  local bCopy = Button(f,"Copy",70,20)
  bCopy:SetPoint("LEFT", bClear, "RIGHT", 6, 0)
  bCopy:SetScript("OnClick", function()
    UI:ShowCopy()
  end)

  Label(f, "In combat:", 12, -62)
  local vCombat = Value(f, 90, -62)

  Label(f, "Speed (mh/oh):", 12, -78)
  local vSpeed = Value(f, 110, -78)

  Label(f, "Last anchor:", 12, -94)
  local vAnchor = Value(f, 110, -94)

  Label(f, "Suppress until:", 12, -110)
  local vSupp = Value(f, 110, -110)

  Label(f, "Overlay count:", 12, -126)
  local vOv = Value(f, 110, -126)

  local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -148)
  sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 12)

  local eb = CreateFrame("EditBox", nil, sf)
  eb:SetMultiLine(true)
  eb:SetFontObject(ChatFontNormal)
  eb:SetWidth(1)
  eb:SetAutoFocus(false)
  eb:EnableMouse(true)
  eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  sf:SetScrollChild(eb)

  f._vCombat = vCombat
  f._vSpeed = vSpeed
  f._vAnchor = vAnchor
  f._vSupp  = vSupp
  f._vOv    = vOv
  f._scroll = sf
  f._edit = eb

  self.frame = f
  f:Hide()
end

function UI:Toggle()
  if not self.frame then self:Init() end
  if self.frame:IsShown() then
    self.frame:Hide()
  else
    self.frame:Show()
    self:Update()
  end
end

function UI:Update()
  if not self.frame or not self.frame:IsShown() then return end

  local st = _G.SwingBarMidnightState
  local inCombat = (st and st.inCombat) and true or false
  self.frame._vCombat:SetText(tostring(inCombat))

  local mh, oh = GetSwingSpeeds()
  self.frame._vSpeed:SetText(string.format("%.3f / %.3f", mh or 0, oh or 0))

  if st and st.lastAnchor and st.lastAnchor > 0 then
    self.frame._vAnchor:SetText(string.format("%.3f", st.lastAnchor))
  else
    self.frame._vAnchor:SetText("-")
  end

  if st and st.suppressUntil and st.suppressUntil > 0 then
    self.frame._vSupp:SetText(string.format("%.3f", st.suppressUntil))
  else
    self.frame._vSupp:SetText("-")
  end

  if st and st.overlayCount ~= nil then
    self.frame._vOv:SetText(tostring(st.overlayCount))
  else
    self.frame._vOv:SetText("-")
  end

  self.frame._edit:SetText(ns.Format(12000))
  local w = self.frame._scroll:GetWidth()
  if w and w > 50 then self.frame._edit:SetWidth(w - 10) end
end

function UI:ShowCopy()
  if not self.frame then return end
  if self.copy and self.copy:IsShown() then self.copy:Hide() end

  local p = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
  p:SetFrameStrata("FULLSCREEN_DIALOG")
  p:SetPoint("CENTER")
  p:SetSize(520, 360)
  Backdrop(p)

  local title = p:CreateFontString(nil,"OVERLAY","GameFontNormal")
  title:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -10)
  title:SetText("Copy log (Ctrl+C)")

  local close = CreateFrame("Button", nil, p, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", p, "TOPRIGHT", -2, -2)
  close:SetScript("OnClick", function() p:Hide() end)

  local sf = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", p, "TOPLEFT", 12, -32)
  sf:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -30, 12)

  local eb = CreateFrame("EditBox", nil, sf)
  eb:SetMultiLine(true)
  eb:SetFontObject(ChatFontNormal)
  eb:SetAutoFocus(true)
  eb:SetWidth(1)
  eb:EnableMouse(true)
  eb:SetScript("OnEscapePressed", function(self) self:ClearFocus(); p:Hide() end)
  sf:SetScrollChild(eb)

  eb:SetText(ns.Format(200000))
  eb:HighlightText()

  p:Show()
  self.copy = p
end
