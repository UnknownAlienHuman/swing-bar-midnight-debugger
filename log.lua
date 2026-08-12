-- SwingBarMidnight_Debugger/log.lua
local ADDON_NAME, ns = ...

SwingBarMidnightDebuggerDB = SwingBarMidnightDebuggerDB or {}
ns.DB = SwingBarMidnightDebuggerDB
local DB = ns.DB

local function Ensure()
  DB.log = DB.log or {}
  DB.maxLines = DB.maxLines or 6000
end

function ns.InitLogger()
  Ensure()
end

local function Trim()
  Ensure()
  local maxLines = DB.maxLines
  if #DB.log <= maxLines then return end
  local drop = #DB.log - maxLines
  for _=1, drop do table.remove(DB.log, 1) end
end

function ns.Log(tag, data)
  Ensure()
  table.insert(DB.log, { t = GetTime(), tag = tag, data = data })
  Trim()
end

function ns.Clear()
  DB.log = {}
end

function ns.Format(limitChars)
  Ensure()
  limitChars = limitChars or 12000
  local out, total = {}, 0

  local function add(s)
    total = total + #s + 1
    if total > limitChars then return false end
    out[#out+1] = s
    return true
  end

  for i = #DB.log, 1, -1 do
    local e = DB.log[i]
    local ts = string.format("%.3f", e.t or 0)
    local tag = tostring(e.tag or "?")
    local msg = ""

    if type(e.data) == "table" then
      local parts = {}
      for k,v in pairs(e.data) do
        if type(v) == "number" then
          parts[#parts+1] = k.."="..string.format("%.3f", v)
        else
          parts[#parts+1] = k.."="..tostring(v)
        end
      end
      table.sort(parts)
      msg = table.concat(parts, " ")
    elseif e.data ~= nil then
      msg = tostring(e.data)
    end

    local line = ts.."  "..tag..(msg~="" and ("  "..msg) or "")
    if not add(line) then break end
  end

  local rev = {}
  for i = #out, 1, -1 do rev[#rev+1] = out[i] end
  return table.concat(rev, "\n")
end
