-- MooHelper: the Moo Meter, a damage meter measured in moos
--
-- Reads Forever's built-in damage meter (C_DamageMeter). The game hides its numbers from
-- addons while you're in combat, so the meter fills in as soon as each fight ends.
-- 1 moo = 1,000 damage, so 12,300 DPS is 12.3 MooPS (moos per second).
-- "Moos" mode is different: a live count of actual moos typed in chat by your party.

local _, ns = ...

local Usable = ns.Usable
local BAR = "Interface\\TargetingFrame\\UI-StatusBar"
local MOO = 1000          -- damage per moo
local ROWS = 8
local POLL_EVERY, POLL_TRIES = 0.5, 18

ns.METER_MODES = {
  { key = "damage", name = "Damage", type = "DamageDone", unit = "MooPS", rate = true },
  { key = "healing", name = "Healing", type = "HealingDone", unit = "Moo-heals/s", rate = true },
  { key = "taken", name = "Damage Taken", type = "DamageTaken", unit = "MooPS taken", rate = true },
  { key = "avoidable", name = "Avoidable", type = "AvoidableDamageTaken", unit = "moos of shame" },
  { key = "interrupts", name = "Interrupts", type = "Interrupts", unit = "interrupts", count = true },
  { key = "deaths", name = "Deaths", type = "Deaths", unit = "deaths", count = true },
  { key = "moos", name = "Moos", unit = "moos" },
}
local MODE_BY_KEY = {}
for _, m in ipairs(ns.METER_MODES) do MODE_BY_KEY[m.key] = m end

-- snapshots taken after each fight: data[session][mode] = { rows, duration, total, at }
local data = { last = {}, overall = {} }
ns.meterData = data
local moos = { fight = {}, session = {}, fightStart = nil, fightTime = 0, sessionStart = nil }

---------------------------------------------------------------------------
-- Reading the game's damage meter
---------------------------------------------------------------------------

function ns:MeterSupported()
  return C_DamageMeter ~= nil and C_DamageMeter.GetCombatSessionFromID ~= nil
    and Enum ~= nil and Enum.DamageMeterType ~= nil
end

-- returns a snapshot table, or nil plus "unsupported" / "secret" / "empty"
function ns:ReadMeter(modeKey, which)
  local mode = MODE_BY_KEY[modeKey]
  if not mode or not mode.type then return nil, "unsupported" end
  if not self:MeterSupported() then return nil, "unsupported" end
  local meterType = Enum.DamageMeterType[mode.type]
  if meterType == nil then return nil, "unsupported" end

  local ok, session
  if which == "overall" then
    if not (C_DamageMeter.GetCombatSessionFromType and Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Overall) then
      return nil, "unsupported"
    end
    ok, session = pcall(C_DamageMeter.GetCombatSessionFromType, Enum.DamageMeterSessionType.Overall, meterType)
  else
    local okList, sessions = pcall(C_DamageMeter.GetAvailableCombatSessions)
    if not okList or type(sessions) ~= "table" then return nil, "empty" end
    local newest
    for _, s in ipairs(sessions) do
      if type(s) == "table" and Usable(s.sessionID) and type(s.sessionID) == "number" then
        if not newest or s.sessionID > newest then newest = s.sessionID end
      end
    end
    if not newest then return nil, "empty" end
    ok, session = pcall(C_DamageMeter.GetCombatSessionFromID, newest, meterType)
  end
  if not ok or type(session) ~= "table" or type(session.combatSources) ~= "table" then return nil, "empty" end

  local rows, total = {}, 0
  for _, src in ipairs(session.combatSources) do
    if type(src) == "table" then
      if not Usable(src.totalAmount) or not Usable(src.name) then return nil, "secret" end
      if type(src.totalAmount) == "number" and type(src.name) == "string" and src.totalAmount > 0 then
        local class = Usable(src.classFilename) and src.classFilename or nil
        local perSec = Usable(src.amountPerSecond) and type(src.amountPerSecond) == "number" and src.amountPerSecond or nil
        rows[#rows + 1] = { name = ns.ShortName(src.name), class = class, amount = src.totalAmount, perSec = perSec,
          isMe = src.isLocalPlayer == true }
        total = total + src.totalAmount
      end
    end
  end
  local duration = Usable(session.durationSeconds) and type(session.durationSeconds) == "number" and session.durationSeconds or nil
  -- per-second numbers from the total and the fight length when we have it (the game's own
  -- per-second figure can be stale at the very start of a session)
  for _, r in ipairs(rows) do
    if duration and duration > 0 then r.perSec = r.amount / duration end
  end
  table.sort(rows, function(a, b) return a.amount > b.amount end)
  return { rows = rows, duration = duration, total = total, at = time() }
end

local function SnapshotAll()
  local gotAny, secret = false, false
  for _, mode in ipairs(ns.METER_MODES) do
    if mode.type then
      for _, which in ipairs({ "last", "overall" }) do
        local snap, why = ns:ReadMeter(mode.key, which)
        if snap then
          data[which][mode.key] = snap
          gotAny = true
        elseif why == "secret" then
          secret = true
        end
      end
    end
  end
  return gotAny, secret
end

local function PollAfterFight(tries)
  local gotAny, secret = SnapshotAll()
  if secret and tries < POLL_TRIES then
    C_Timer.After(POLL_EVERY, ns.Safe("Meter.lua timer line 114", function() PollAfterFight(tries + 1) end))
    return
  end
  ns.meterPending = false
  if gotAny then
    ns:Bump("meterFights")
    if ns.RefreshMeter then ns:RefreshMeter() end
    if ns.meterAutoPostAfter then
      ns.meterAutoPostAfter = nil
      ns:PostMeter("damage", "last", true)
    end
  end
end

---------------------------------------------------------------------------
-- Live moo counting (moos typed in group chat, plus your own)
---------------------------------------------------------------------------

local function AddMoos(name, n)
  moos.fight[name] = (moos.fight[name] or 0) + n
  moos.session[name] = (moos.session[name] or 0) + n
  moos.sessionStart = moos.sessionStart or ns.Now()
end

-- Everyone is counted the same way: the moos in their group chat lines (at most 10 a line).
-- Your own lines count whether you typed them or MooHelper posted them; another copy of the
-- addon's lines don't count for its owner (only what they type does).
for _, event in ipairs({ "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER" }) do
  ns:On(event, function(msg, sender)
    if not Usable(msg) or not Usable(sender) or type(msg) ~= "string" then return end
    local n = ns.CountMoos and ns.CountMoos(msg) or 0
    if n == 0 then return end
    local name = ns.ShortName(sender)
    if name == UnitName("player") then AddMoos(name, math.min(n, 10)) return end
    if ns:IsOwnOutput(msg, sender) then return end
    ns:GateChat(sender, msg, function() AddMoos(name, math.min(n, 10)) end)
  end)
end

local function MooRows(which)
  local src = which == "overall" and moos.session or moos.fight
  local rows, total = {}, 0
  for name, n in pairs(src) do
    rows[#rows + 1] = { name = name, amount = n, isMe = name == UnitName("player") }
    total = total + n
  end
  table.sort(rows, function(a, b) return a.amount > b.amount or (a.amount == b.amount and a.name < b.name) end)
  local duration
  if which == "overall" then
    duration = moos.sessionStart and (ns.Now() - moos.sessionStart) or nil
  else
    duration = moos.fightStart and (ns.Now() - moos.fightStart) or (moos.fightTime > 0 and moos.fightTime or nil)
  end
  for _, r in ipairs(rows) do
    r.perSec = (duration and duration > 0) and r.amount / duration or nil
  end
  return { rows = rows, total = total, duration = duration }
end

ns:On("PLAYER_REGEN_DISABLED", function()
  wipe(moos.fight)
  moos.fightStart = ns.Now()
  ns.inFight = true
  if ns.RefreshMeter then ns:RefreshMeter() end
end)

ns:On("PLAYER_REGEN_ENABLED", function()
  if moos.fightStart then moos.fightTime = ns.Now() - moos.fightStart end
  moos.fightStart = nil
  ns.inFight = false
  if not ns.meterPending then
    ns.meterPending = true
    C_Timer.After(POLL_EVERY, ns.Safe("Meter.lua timer line 187", function() PollAfterFight(1) end))
  end
end)

ns:On("ENCOUNTER_END", function(_, _, _, _, success)
  if (success == 1 or success == true) and ns.db.triggers.meterAutoPost and not ns.db.panic then
    ns.meterAutoPostAfter = true
  end
end)

---------------------------------------------------------------------------
-- Formatting
---------------------------------------------------------------------------

local function Short(n)
  if n >= 1e6 then return ("%.1fm"):format(n / 1e6) end
  if n >= 1e4 then return ("%.0fk"):format(n / 1e3) end
  if n >= 1e3 then return ("%.1fk"):format(n / 1e3) end
  return ("%d"):format(math.floor(n + 0.5))
end

-- the number shown for one row
function ns.MeterValue(modeKey, row)
  local mode = MODE_BY_KEY[modeKey]
  if mode.count or modeKey == "moos" then
    local s = ("%d"):format(row.amount)
    if modeKey == "moos" and row.perSec then s = s .. (" (%.2f/s)"):format(row.perSec) end
    return s
  end
  if mode.rate and row.perSec then
    return ("%.1f %s"):format(row.perSec / MOO, mode.unit)
  end
  return ("%s %s"):format(Short(row.amount / MOO), mode.unit)
end

function ns:MeterSnapshot(modeKey, which)
  if modeKey == "moos" then return MooRows(which) end
  return data[which][modeKey]
end

---------------------------------------------------------------------------
-- Posting to chat
---------------------------------------------------------------------------

function ns:PostMeter(modeKey, which, automatic)
  modeKey, which = modeKey or "damage", which or "last"
  local mode = MODE_BY_KEY[modeKey]
  if not mode then return false, "Modes: damage, healing, taken, avoidable, interrupts, deaths, moos" end
  local snap = self:MeterSnapshot(modeKey, which)
  if not snap or #snap.rows == 0 then return false, "Nothing to post yet: finish a fight first." end
  local ch = self:GroupChannel()
  if not ch then return false, "Join a group to post the Moo Meter." end
  local parts = {}
  for i = 1, math.min(5, #snap.rows) do
    parts[#parts + 1] = ("%d. %s %s"):format(i, snap.rows[i].name, ns.MeterValue(modeKey, snap.rows[i]))
  end
  local header = ("MOO METER (%s, %s%s):"):format(mode.name, which == "overall" and "overall" or "last fight",
    (mode.rate or modeKey == "avoidable") and ", 1 moo = 1,000" or "")
  local line = header .. " " .. table.concat(parts, "  ")
  local sent
  if automatic then sent = self:Queue(ch, line, 2) else sent = self:SendNow(ch, line) end
  if sent then
    self:Bump("meterPosts")
    return true
  end
  if self:IsMuted(ch) then return false, ns:ChannelLabel(ch) .. " is HARD MUTED." end
  if self.db.panic then return false, "Automatic posting is paused (/moo on to resume)." end
  return false, "Couldn't post to " .. ns:ChannelLabel(ch) .. " right now."
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------

local meter
local view = { mode = "damage", which = "last" }

local function ClassColor(class)
  local c = RAID_CLASS_COLORS and class and RAID_CLASS_COLORS[class]
  if c then return c.r, c.g, c.b end
  return 0.75, 0.6, 0.35
end

function ns:RefreshMeter()
  if not meter or not meter:IsShown() then return end
  local mode = MODE_BY_KEY[view.mode]
  meter.modeButton:SetText(mode.name)
  meter.whichButton:SetText(view.which == "overall" and "Overall" or "Last fight")
  local snap = self:MeterSnapshot(view.mode, view.which)
  local rows = snap and snap.rows or {}
  local top = rows[1] and rows[1].amount or 1
  for i = 1, ROWS do
    local bar, r = meter.bars[i], rows[i]
    if r then
      bar:SetMinMaxValues(0, top)
      bar:SetValue(r.amount)
      bar:SetStatusBarColor(ClassColor(r.class))
      bar.left:SetText(("%d. %s"):format(i, r.name))
      local pct = (snap.total and snap.total > 0) and (" (%d%%)"):format(math.floor(r.amount / snap.total * 100 + 0.5)) or ""
      bar.right:SetText(ns.MeterValue(view.mode, r) .. pct)
      bar:Show()
    else
      bar:Hide()
    end
  end
  local note
  if #rows == 0 then
    if view.mode ~= "moos" and not self:MeterSupported() then
      note = "This client doesn't share damage meter data with addons. Moos mode still works."
    elseif self.inFight and view.mode ~= "moos" then
      note = "Fight in progress. Forever reveals the numbers when it ends. Moo."
    elseif view.mode == "moos" then
      note = "Nobody has mooed yet. Fix that."
    else
      note = "No data yet. Fight something: the numbers appear when the fight ends."
    end
  elseif snap.duration then
    note = ("%d:%02d of fighting"):format(math.floor(snap.duration / 60), math.floor(snap.duration % 60))
  end
  meter.note:SetText(note or "")
end

local function CreateMeter()
  meter = CreateFrame("Frame", "MooHelperMeter", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  meter:SetSize(270, 74 + ROWS * 19)
  local pos = ns.db.meterPos
  if pos then meter:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y) else meter:SetPoint("RIGHT", -60, -40) end
  meter:SetFrameStrata("MEDIUM")
  meter:SetMovable(true)
  meter:SetClampedToScreen(true)
  meter:EnableMouse(true)
  meter:RegisterForDrag("LeftButton")
  meter:SetScript("OnDragStart", meter.StartMoving)
  meter:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    ns.db.meterPos = { point = point, relPoint = relPoint, x = x, y = y }
  end)
  if meter.SetBackdrop then
    meter:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
      insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    meter:SetBackdropColor(0.1, 0.06, 0.03, 0.9)
    meter:SetBackdropBorderColor(1, 0.82, 0.2, 1)
  end
  local icon = meter:CreateTexture(nil, "ARTWORK")
  icon:SetSize(18, 18)
  icon:SetPoint("TOPLEFT", 8, -7)
  icon:SetTexture("Interface\\Icons\\Ability_Mount_Kodo_01")
  local title = meter:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
  title:SetText("MOO METER")
  local close = CreateFrame("Button", nil, meter, "UIPanelCloseButton")
  close:SetSize(22, 22)
  close:SetPoint("TOPRIGHT", -2, -2)
  close:SetScript("OnClick", function() meter:Hide() ns.db.meterShown = false end)

  meter.modeButton = CreateFrame("Button", nil, meter, "UIPanelButtonTemplate")
  meter.modeButton:SetSize(96, 18)
  meter.modeButton:SetPoint("TOPLEFT", 8, -30)
  meter.modeButton:SetScript("OnClick", function()
    for i, m in ipairs(ns.METER_MODES) do
      if m.key == view.mode then view.mode = ns.METER_MODES[i % #ns.METER_MODES + 1].key break end
    end
    ns:RefreshMeter()
  end)
  meter.whichButton = CreateFrame("Button", nil, meter, "UIPanelButtonTemplate")
  meter.whichButton:SetSize(80, 18)
  meter.whichButton:SetPoint("LEFT", meter.modeButton, "RIGHT", 4, 0)
  meter.whichButton:SetScript("OnClick", function()
    view.which = view.which == "last" and "overall" or "last"
    ns:RefreshMeter()
  end)
  local post = CreateFrame("Button", nil, meter, "UIPanelButtonTemplate")
  post:SetSize(58, 18)
  post:SetPoint("LEFT", meter.whichButton, "RIGHT", 4, 0)
  post:SetText("Post")
  post:SetScript("OnClick", function()
    local ok, why = ns:PostMeter(view.mode, view.which)
    if not ok and why then ns:Print(why) end
  end)

  meter.bars = {}
  for i = 1, ROWS do
    local bar = CreateFrame("StatusBar", nil, meter)
    bar:SetSize(254, 17)
    bar:SetPoint("TOPLEFT", 8, -52 - (i - 1) * 19)
    bar:SetStatusBarTexture(BAR)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetColorTexture(0, 0, 0, 0.4)
    bar.left = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.left:SetPoint("LEFT", 4, 0)
    bar.right = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.right:SetPoint("RIGHT", -4, 0)
    bar:Hide()
    meter.bars[i] = bar
  end
  meter.note = meter:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  meter.note:SetPoint("BOTTOMLEFT", 8, 7)
  meter.note:SetWidth(254)
  meter.note:SetJustifyH("LEFT")
  meter:SetScript("OnShow", function() ns:RefreshMeter() end)
  local acc = 0
  meter:SetScript("OnUpdate", ns.Safe("Meter.lua OnUpdate line 391", function(_, elapsed)
    acc = acc + elapsed
    if acc >= 1 then acc = 0 ns:RefreshMeter() end
  end))
  meter:Hide()
  if ns.db.meterShown then meter:Show() end
end

function ns:ToggleMeter(show)
  if not meter then return end
  if show == nil then show = not meter:IsShown() end
  ns.db.meterShown = show
  if show then
    meter:Show()
    self:Bump("meterOpened")
  else
    meter:Hide()
  end
end

function ns:SetMeterView(modeKey, which)
  if modeKey and MODE_BY_KEY[modeKey] then view.mode = modeKey end
  if which == "last" or which == "overall" then view.which = which end
  self:RefreshMeter()
end
function ns:MeterView() return view.mode, view.which end

ns:On("PLAYER_LOGIN", function() CreateMeter() end)
