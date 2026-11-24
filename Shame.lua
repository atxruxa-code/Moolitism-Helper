-- MooHelper: Moo-litism (an ElitismHelper-style "who stood in the fire" announcer)
--
-- Forever blocks the combat log, but its built-in damage meter (C_DamageMeter) has an
-- "Avoidable Damage Taken" view that addons can read once a fight is over (the numbers
-- are secret while you're in combat). After each fight this reads that view for the
-- fight that just ended and moos at whoever took the most avoidable damage.

local _, ns = ...

local Usable = ns.Usable
local POLL_EVERY, POLL_TRIES = 0.5, 18 -- keep trying for up to 9 s while the values unlock

local lastSession -- the newest session we've already shamed, so no fight is shamed twice

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

-- Returns "done", "retry" (values still secret / not there yet) or "unsupported".
function ns:ReadAvoidable()
  if not (C_DamageMeter and C_DamageMeter.GetAvailableCombatSessions and C_DamageMeter.GetCombatSessionFromID
      and Enum and Enum.DamageMeterType and Enum.DamageMeterType.AvoidableDamageTaken) then
    return "unsupported"
  end
  local TYPE = Enum.DamageMeterType.AvoidableDamageTaken

  local ok, sessions = pcall(C_DamageMeter.GetAvailableCombatSessions)
  if not ok or type(sessions) ~= "table" then return "retry" end
  local newest
  for _, s in ipairs(sessions) do
    if type(s) == "table" and Usable(s.sessionID) and type(s.sessionID) == "number" then
      if not newest or s.sessionID > newest then newest = s.sessionID end
    end
  end
  if not newest then return "retry" end
  if newest == lastSession then return "done" end

  local ok2, session = pcall(C_DamageMeter.GetCombatSessionFromID, newest, TYPE)
  if not ok2 or type(session) ~= "table" or type(session.combatSources) ~= "table" then return "retry" end

  local group = GroupNames()
  local offenders = {}
  for _, src in ipairs(session.combatSources) do
    if type(src) ~= "table" then return "retry" end
    if not Usable(src.totalAmount) or not Usable(src.name) then return "retry" end -- still locked
    local name = ns.ShortName(src.name)
    local mine = src.isLocalPlayer == true
    if type(src.totalAmount) == "number" and src.totalAmount >= self.db.shameMinDamage and (mine or group[name]) then
      local spellID, spellAmount, creature = nil, 0, nil
      if C_DamageMeter.GetCombatSessionSourceFromID and Usable(src.sourceGUID) then
        local ok3, detail = pcall(C_DamageMeter.GetCombatSessionSourceFromID, newest, TYPE, src.sourceGUID)
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
      offenders[#offenders + 1] = { name = mine and (UnitName("player") or name) or name, amount = src.totalAmount, spell = spell }
    end
  end
  lastSession = newest

  table.sort(offenders, function(a, b) return a.amount > b.amount end)
  local channel = self:GroupChannel()
  for i = 1, math.min(#offenders, self.db.shameMaxLines) do
    local o = offenders[i]
    self.db.stats.shame[o.name] = (self.db.stats.shame[o.name] or 0) + 1
    if channel then self:Queue(channel, ShameLine(ns.Clean(o.name), ns.Clean(o.spell), FormatNumber(o.amount))) end
  end
  if #offenders > 0 and self.CheckAchievements then self:CheckAchievements() end
  return "done"
end

local polling = false
local function Poll(tries)
  local result = ns:ReadAvoidable()
  if result == "retry" and tries < POLL_TRIES then
    C_Timer.After(POLL_EVERY, function() Poll(tries + 1) end)
  else
    polling = false
  end
end

ns:On("PLAYER_REGEN_ENABLED", function()
  if polling or ns.db.panic or not ns.db.triggers.shame or not ns:GroupChannel() then return end
  polling = true
  C_Timer.After(POLL_EVERY, function() Poll(1) end)
end)

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
