-- MooHelper: Moo-litism (an ElitismHelper-style "who stood in the fire" announcer)
--
-- Forever blocks the combat log, but its built-in damage meter (C_DamageMeter) has an
-- "Avoidable Damage Taken" view that addons can read once a fight is over (the numbers
-- are secret while you're in combat). After each fight this reads that view for the
-- fight that just ended and moos at whoever took the most avoidable damage.

local _, ns = ...

local Usable = ns.Usable
local POLL_EVERY = 0.5


local function FormatNumber(n)
  local s = tostring(math.floor(n))
  local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  return (out:gsub("^,", ""))
end
ns.FormatNumber = FormatNumber

local function SpellName(spellID)
  if C_Spell and C_Spell.GetSpellName then
    local ok, name = pcall(C_Spell.GetSpellName, spellID)
    if ok and Usable(name) and name then return name end
  end
  if C_Spell and C_Spell.GetSpellInfo then
    local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
    if ok and type(info) == "table" and Usable(info.name) then return info.name end
  end
  if GetSpellInfo then
    local ok, name = pcall(GetSpellInfo, spellID)
    if ok and Usable(name) and name then return name end
  end
  return nil
end

local function GroupNames()
  local names = {}
  local me = UnitName("player")
  if Usable(me) then names[me] = true end
  local prefix, count = "party", 4
  if IsInRaid() then prefix, count = "raid", GetNumGroupMembers() or 0 end
  for i = 1, count do
    local unit = prefix .. i
    if UnitExists(unit) then
      local name = UnitName(unit)
      if Usable(name) and name then names[name] = true end
    end
  end
  return names
end

local LINES = {
  "MOO! %s stood in %s for %s. Moo-ve!",
  "%s took %s damage from %s. The herd is disappointed. Moo.",
  "MOO-LITISM ALERT: %s ate %s from %s.",
  "Moo. %s, that was %s from %s. Please moo-ve out of it next time.",
}
-- each line's argument order: name, spell, amount (1 and 4) or name, amount, spell (2 and 3)
local function ShameLine(name, spell, amount)
  local i = math.random(#LINES)
  if i == 1 then return LINES[1]:format(name, spell, amount) end
  if i == 4 then return LINES[4]:format(name, amount, spell) end
  return LINES[i]:format(name, amount, spell)
end
ns.ShameLine = ShameLine

-- What the last read found, for /moo moolitism (so a player can tell us what their client does)
ns.shameDiag = { result = "not run yet" }

-- How much avoidable damage each player had already been shamed for, per session. The game
-- may start a new session each fight or keep adding to one; either way only what's new since
-- the last read counts, and nothing is lost if a read had to wait.
local counted = {}      -- sessionID -> { [name] = amount already counted }
local sessionOrder = {}

local function Counted(id)
  if not counted[id] then
    counted[id] = {}
    sessionOrder[#sessionOrder + 1] = id
    while #sessionOrder > 6 do counted[table.remove(sessionOrder, 1)] = nil end
  end
  return counted[id]
end

local function NewestSession()
  local ok, sessions = pcall(C_DamageMeter.GetAvailableCombatSessions)
  if not ok or type(sessions) ~= "table" then return nil, 0 end
  local newest, n = nil, 0
  for _, s in ipairs(sessions) do
    n = n + 1
    if type(s) == "table" and Usable(s.sessionID) and type(s.sessionID) == "number" then
      if not newest or s.sessionID > newest then newest = s.sessionID end
    end
  end
  return newest, n
end

-- Returns "done", "retry" (values still secret / not there yet) or "unsupported".
function ns:ReadAvoidable()
  local diag = { at = time(), sessions = 0 }
  ns.shameDiag = diag
  if not (C_DamageMeter and C_DamageMeter.GetCombatSessionFromID and Enum and Enum.DamageMeterType
      and Enum.DamageMeterType.AvoidableDamageTaken) then
    diag.result = "unsupported: this client has no C_DamageMeter avoidable-damage view"
    return "unsupported"
  end
  local TYPE = Enum.DamageMeterType.AvoidableDamageTaken

  -- the newest fight; if the client has no session list, its "current" session
  local id, session, ok2
  if C_DamageMeter.GetAvailableCombatSessions then id, diag.sessions = NewestSession() end
  if id then
    ok2, session = pcall(C_DamageMeter.GetCombatSessionFromID, id, TYPE)
  elseif C_DamageMeter.GetCombatSessionFromType and Enum.DamageMeterSessionType then
    id = "current"
    ok2, session = pcall(C_DamageMeter.GetCombatSessionFromType, Enum.DamageMeterSessionType.Current, TYPE)
  end
  diag.session = id
  if not id then diag.result = "no fights recorded yet" return "retry" end
  if not ok2 or type(session) ~= "table" or type(session.combatSources) ~= "table" then
    diag.result = "the session couldn't be read: " .. tostring(ok2 and "no data" or session)
    return "retry"
  end
  diag.sources = #session.combatSources

  local group = GroupNames()
  local seen = Counted(id)
  local offenders, rows = {}, {}
  for _, src in ipairs(session.combatSources) do
    if type(src) ~= "table" then diag.result = "odd data" return "retry" end
    if not Usable(src.totalAmount) or not Usable(src.name) then
      diag.result = "values are still hidden (secret) by the game"
      return "retry"
    end
    if type(src.totalAmount) == "number" and type(src.name) == "string" then
      rows[#rows + 1] = src
    end
  end
  for _, src in ipairs(rows) do
    local name = ns.ShortName(src.name)
    local mine = src.isLocalPlayer == true
    local key = mine and (UnitName("player") or name) or name
    local new = src.totalAmount - (seen[key] or 0)
    seen[key] = math.max(seen[key] or 0, src.totalAmount)
    if new >= self.db.shameMinDamage and (mine or group[name]) then
      local spellID, spellAmount, creature = nil, 0, nil
      if C_DamageMeter.GetCombatSessionSourceFromID and type(id) == "number" and Usable(src.sourceGUID) then
        local ok3, detail = pcall(C_DamageMeter.GetCombatSessionSourceFromID, id, TYPE, src.sourceGUID)
        if ok3 and type(detail) == "table" and type(detail.combatSpells) == "table" then
          for _, sp in ipairs(detail.combatSpells) do
            if type(sp) == "table" and Usable(sp.spellID) and Usable(sp.totalAmount)
               and type(sp.totalAmount) == "number" and sp.isAvoidable ~= false and sp.totalAmount > spellAmount then
              spellID, spellAmount = sp.spellID, sp.totalAmount
              creature = Usable(sp.creatureName) and sp.creatureName or nil
            end
          end
        end
      end
      local spell = spellID and SpellName(spellID) or nil
      if not spell then spell = creature and (creature .. "'s nonsense") or "something on the floor" end
      offenders[#offenders + 1] = { name = key, amount = new, spell = spell }
    end
  end
  diag.result = ("read %d players, %d stood in something"):format(#rows, #offenders)
  diag.offenders = #offenders

  table.sort(offenders, function(a, b) return a.amount > b.amount or (a.amount == b.amount and a.name < b.name) end)
  local channel = self:GroupChannel()
  for i = 1, math.min(#offenders, self.db.shameMaxLines) do
    local o = offenders[i]
    self.db.stats.shame[o.name] = (self.db.stats.shame[o.name] or 0) + 1
    self:Signal("shamed", o.name)
    if channel and not self.db.panic then
      local line = ShameLine(ns.Clean(o.name), ns.Clean(o.spell), FormatNumber(o.amount))
      -- with several copies in the party, one of them says it
      self:RunAsHost("group", "shame:" .. o.name .. ":" .. o.amount, nil, function() self:Queue(channel, line) end)
    end
  end
  if #offenders > 0 and self.CheckAchievements then self:CheckAchievements() end
  return "done"
end

-- Reading after a fight: quickly at first (values usually unlock within seconds), then every
-- 5 seconds for up to 2 minutes in case this client keeps them hidden for longer.
local pollToken = 0
local function Poll(token, tries)
  if token ~= pollToken or ns.db.panic then return end
  local result = ns:ReadAvoidable()
  if result ~= "retry" then return end
  if tries < 20 then
    C_Timer.After(POLL_EVERY, function() Poll(token, tries + 1) end)
  elseif tries < 44 then
    C_Timer.After(5, function() Poll(token, tries + 1) end)
  end
end

function ns:ShameCheck()
  if self.db.panic or not self.db.triggers.shame or not self:GroupChannel() then return end
  pollToken = pollToken + 1 -- a newer check replaces an older one
  local token = pollToken
  C_Timer.After(POLL_EVERY, function() Poll(token, 1) end)
end

function ns:StopShameChecks() pollToken = pollToken + 1 end

ns:On("PLAYER_REGEN_ENABLED", function() ns:ShameCheck() end)
ns:On("ENCOUNTER_END", function() ns:ShameCheck() end)
ns:On("ZONE_CHANGED_NEW_AREA", function() ns:ShameCheck() end)

-- /moo moolitism: what the last read found, so a player can see (and report) what their client does
function ns:ShameStatus()
  local d = ns.shameDiag
  local lines = { "Moo-litism status:" }
  lines[#lines + 1] = ("  shaming is %s; you're %s"):format(self.db.triggers.shame and "ON" or "OFF (Barn > Triggers)",
    self:GroupChannel() and "in a group" or "NOT in a group (it only runs in groups)")
  lines[#lines + 1] = ("  damage meter API: %s"):format((C_DamageMeter and C_DamageMeter.GetCombatSessionFromID) and "present" or "MISSING")
  lines[#lines + 1] = ("  last read: %s%s"):format(d.result or "?", d.at and (" (%d s ago)"):format(time() - d.at) or "")
  if d.session then
    lines[#lines + 1] = ("  session %s of %d, %s sources"):format(tostring(d.session), d.sessions or 0, tostring(d.sources or "?"))
  end
  return lines
end

-- Hall of Moo-Shame
function ns:ShowShame(post)
  local list = {}
  for name, count in pairs(self.db.stats.shame) do list[#list + 1] = { name = name, count = count } end
  table.sort(list, function(a, b) return a.count > b.count or (a.count == b.count and a.name < b.name) end)
  if #list == 0 then self:Print("The Hall of Moo-Shame is empty. Suspicious.") return end
  local parts = {}
  for i = 1, math.min(5, #list) do
    parts[#parts + 1] = ("%d. %s (%d)"):format(i, ns.Clean(list[i].name), list[i].count)
  end
  local line = "Hall of Moo-Shame: " .. table.concat(parts, "  ")
  self:Print(line)
  if post then
    local channel = self:GroupChannel()
    if channel then self:SendNow(channel, line .. "  Moo.") else self:Print("Join a group to post it.") end
  end
end
