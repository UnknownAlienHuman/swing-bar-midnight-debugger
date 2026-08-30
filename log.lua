-- SwingBarMidnight_Debugger/log.lua
-- Bounded ordinary-data logger for the Retail 12.1 prediction debugger.

local ADDON_NAME, ns = ...

SwingBarMidnightDebuggerDB = type(SwingBarMidnightDebuggerDB) == "table" and SwingBarMidnightDebuggerDB or {}
ns.DB = SwingBarMidnightDebuggerDB
local DB = ns.DB

local DEFAULT_MAX_ENTRIES = 500
local MAX_ENTRIES_LIMIT = 2000
local MAX_FIELDS = 24
local MAX_DEPTH = 3
local MAX_STRING = 240

local function CanAccess(value)
  if type(canaccessvalue) == "function" then
    local ok, accessible = pcall(canaccessvalue, value)
    return ok and accessible == true
  end
  if type(issecretvalue) == "function" then
    local ok, secret = pcall(issecretvalue, value)
    return ok and secret ~= true
  end
  return true
end

local function SafeBoolean(value)
  if not CanAccess(value) or type(value) ~= "boolean" then return nil end
  return value
end

local function SafeNumber(value)
  if not CanAccess(value) or type(value) ~= "number" or value ~= value then return nil end
  return value
end

local function SafeString(value)
  if not CanAccess(value) or type(value) ~= "string" then return nil end
  if #value > MAX_STRING then return value:sub(1, MAX_STRING) .. "…" end
  return value
end

local function IsSafeTable(value)
  if not CanAccess(value) or type(value) ~= "table" then return false end
  if type(issecrettable) == "function" then
    local ok, secret = pcall(issecrettable, value)
    if not ok or secret == true then return false end
  end
  return true
end

local function SanitizeKey(value)
  if not CanAccess(value) then return "<inaccessible-key>" end
  local valueType = type(value)
  if valueType == "string" then return SafeString(value) or "<invalid-key>" end
  if valueType == "number" then
    local number = SafeNumber(value)
    return number and tostring(number) or "<invalid-key>"
  end
  if valueType == "boolean" then return value and "true" or "false" end
  return "<" .. valueType .. "-key>"
end

local function Sanitize(value, depth, seen)
  if not CanAccess(value) then return "<inaccessible>" end
  local valueType = type(value)
  if value == nil then return nil end
  if valueType == "string" then return SafeString(value) end
  if valueType == "number" then return SafeNumber(value) end
  if valueType == "boolean" then return SafeBoolean(value) end
  if valueType ~= "table" then return "<" .. valueType .. ">" end
  if not IsSafeTable(value) then return "<secret-table>" end

  depth = depth or 0
  if depth >= MAX_DEPTH then return "<max-depth>" end
  seen = seen or {}
  if seen[value] then return "<cycle>" end
  seen[value] = true

  local result = {}
  local count = 0
  for key, child in pairs(value) do
    count = count + 1
    if count > MAX_FIELDS then
      result["<truncated>"] = count - 1
      break
    end
    result[SanitizeKey(key)] = Sanitize(child, depth + 1, seen)
  end
  seen[value] = nil
  return result
end

local function Ensure()
  DB.version = 2
  DB.log = IsSafeTable(DB.log) and DB.log or {}
  local maxEntries = SafeNumber(DB.maxEntries) or SafeNumber(DB.maxLines) or DEFAULT_MAX_ENTRIES
  if maxEntries < 50 then maxEntries = 50 elseif maxEntries > MAX_ENTRIES_LIMIT then maxEntries = MAX_ENTRIES_LIMIT end
  DB.maxEntries = math.floor(maxEntries + 0.5)
  DB.maxLines = nil
end

function ns.InitLogger()
  Ensure()
end

local function Trim()
  Ensure()
  local overflow = #DB.log - DB.maxEntries
  if overflow <= 0 then return end
  for _ = 1, overflow do table.remove(DB.log, 1) end
end

function ns.Log(tag, data)
  Ensure()
  local timestamp = 0
  if type(GetTime) == "function" then
    local ok, value = pcall(GetTime)
    if ok then timestamp = SafeNumber(value) or 0 end
  end
  DB.log[#DB.log + 1] = {
    t = timestamp,
    tag = SafeString(tag) or "?",
    data = Sanitize(data),
  }
  Trim()
end

function ns.Clear()
  Ensure()
  DB.log = {}
end

local function ScalarText(value)
  local valueType = type(value)
  if value == nil then return "nil" end
  if valueType == "string" then return value end
  if valueType == "number" then return string.format("%.3f", value) end
  if valueType == "boolean" then return value and "true" or "false" end
  return "<" .. valueType .. ">"
end

local function Flatten(prefix, value, output, depth)
  depth = depth or 0
  if type(value) ~= "table" or depth >= MAX_DEPTH then
    output[#output + 1] = prefix .. "=" .. ScalarText(value)
    return
  end

  local keys = {}
  for key in pairs(value) do keys[#keys + 1] = key end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  for _, key in ipairs(keys) do
    local childPrefix = prefix == "" and tostring(key) or (prefix .. "." .. tostring(key))
    Flatten(childPrefix, value[key], output, depth + 1)
  end
end

function ns.Format(limitChars)
  Ensure()
  limitChars = SafeNumber(limitChars) or 50000
  if limitChars < 1000 then limitChars = 1000 elseif limitChars > 200000 then limitChars = 200000 end

  local reversed = {}
  local total = 0
  for index = #DB.log, 1, -1 do
    local entry = DB.log[index]
    local parts = {}
    if type(entry.data) == "table" then
      Flatten("", entry.data, parts, 0)
    elseif entry.data ~= nil then
      parts[1] = ScalarText(entry.data)
    end
    local suffix = #parts > 0 and ("  " .. table.concat(parts, " ")) or ""
    local line = string.format("%.3f  %s%s", SafeNumber(entry.t) or 0, SafeString(entry.tag) or "?", suffix)
    total = total + #line + 1
    if total > limitChars then break end
    reversed[#reversed + 1] = line
  end

  local output = {}
  for index = #reversed, 1, -1 do output[#output + 1] = reversed[index] end
  return table.concat(output, "\n")
end

ns.Safe = {
  CanAccess = CanAccess,
  SafeBoolean = SafeBoolean,
  SafeNumber = SafeNumber,
  SafeString = SafeString,
  Sanitize = Sanitize,
}
