-- MooHelper: ambient annoyances
-- Moo ranks, the Moo Clock, the AFK stalker, guild welcomes, roll commentary,
-- mount and jump moos, the MOO-UNTDOWN and the daily guild moo forecast.

local _, ns = ...

local Usable = ns.Usable
local random = math.random
local function Pick(list) return list[random(#list)] end

local function On(name) return ns.db.triggers[name] and not ns.db.panic end
-- ambient things also go quiet while mercy is in effect
local function Ambient(name) return On(name) and not ns:InMercy() end
local function Group(text, priority)
  local ch = ns:GroupChannel()
  if ch then ns:Queue(ch, text, priority or 2) end
end

local function Duration(seconds)
  seconds = math.floor(seconds)
  if seconds < 60 then return seconds .. " seconds" end
  local m = math.floor(seconds / 60)
  return m .. (m == 1 and " minute" or " minutes")
end
ns.Duration = Duration

local function GroupUnits()
  local units = {}
  local prefix, count = "party", 4
  if IsInRaid() then prefix, count = "raid", GetNumGroupMembers() or 0 end
  for i = 1, count do
    local unit = prefix .. i
    if UnitExists(unit) and not UnitIsUnit(unit, "player") then units[#units + 1] = unit end
  end
  return units
end

---------------------------------------------------------------------------
-- Moo ranks
---------------------------------------------------------------------------

ns.RANKS = {
  { 0, "Calf" }, { 25, "Grazer" }, { 100, "Herd Member" }, { 250, "Pasture Patrol" },
  { 500, "Bellower" }, { 1000, "Stampede Leader" }, { 2500, "Herd Elder" }, { 5000, "Moo Sage" },
  { 10000, "Bovine Deity" },
}

function ns:RankIndex(total)
  local idx = 1
  for i, r in ipairs(ns.RANKS) do if total >= r[1] then idx = i end end
  return idx
end

function ns:RankName() return ns.RANKS[self:RankIndex(self.db.stats.total)][2] end

function ns:CheckRank()
  local idx = self:RankIndex(self.db.stats.total)
  if not self.db.rankIdx then self.db.rankIdx = idx return end
  if idx <= self.db.rankIdx then return end
  self.db.rankIdx = idx
  local name = ns.RANKS[idx][2]
  self:Print(("MOO RANK UP: you are now a %s."):format(name))
  if self.Toast then self:Toast("MOO RANK UP", name) end
  if self.Stampede then self:Stampede(20) end
  if On("rankUp") then
    local text = ("*ahem* I have been promoted to %s (%s lifetime moos). Moo."):format(name, ns.FormatNumber(ns.RANKS[idx][1]))
    Group(text)
    if IsInGuild() then ns:Queue("GUILD", text) end
  end
end

---------------------------------------------------------------------------
-- The Moo Clock: BONG on the hour, one moo per hour
---------------------------------------------------------------------------

local lastChime
local function ClockTick()
  if not GetGameTime then return end
  local h, m = GetGameTime()
  if not Usable(h) or not Usable(m) or type(h) ~= "number" then return end
  if lastChime == nil then lastChime = (m == 0) and h or -1 end -- no chime the moment you log in
  if m ~= 0 or h == lastChime then return end
  lastChime = h
  if not Ambient("mooClock") then return end
  local h12 = h % 12
  if h12 == 0 then h12 = 12 end
  local text = ("BONG. It is %d o'clock. %s"):format(h12, (string.rep("MOO ", h12):gsub(" $", "")))
  Group(text)
  if On("clockGuild") and IsInGuild() then ns:Queue("GUILD", text, 1) end
end

---------------------------------------------------------------------------
-- AFK stalker
---------------------------------------------------------------------------

local afk = {} -- name -> { since, nags, nextNag }
local NAG_EVERY, MAX_NAGS = 45, 8
local NAGS = {
  "Moo. (%s, are you back yet?)", "MOO. %s is still AFK. The herd waits.",
  "%s, the herd misses you. Moo.", "Moo? (%s)", "Day %d of waiting for %s. Moo.",
}

local function AfkTick()
  if not ns:GroupChannel() then wipe(afk) return end
  local now = ns.Now()
  local present = {}
  for _, unit in ipairs(GroupUnits()) do
    local name = UnitName(unit)
    local isAfk = UnitIsAFK and UnitIsAFK(unit)
    if Usable(name) and name and Usable(isAfk) then
      present[name] = true
      local st = afk[name]
      if isAfk and not st then
        afk[name] = { since = now, nags = 0, nextNag = now + NAG_EVERY }
        if Ambient("afkStalk") then
          Group(("%s has gone AFK. The herd will moo at them until they return. Moo."):format(name))
        end
      elseif isAfk and st then
        if now >= st.nextNag and st.nags < MAX_NAGS and Ambient("afkStalk") then
          st.nags = st.nags + 1
          st.nextNag = now + NAG_EVERY
          ns.db.stats.afkMoos = ns.db.stats.afkMoos + 1
          local line = Pick(NAGS)
          if line:find("Day %%d") then
            Group(line:format(st.nags, name), 1)
          else
            Group(line:format(name), 1)
          end
        end
      elseif not isAfk and st then
        afk[name] = nil
        if Ambient("afkStalk") then
          Group(("%s has returned after %s and missed %d moo%s. Welcome back. MOO!")
            :format(name, Duration(now - st.since), st.nags, st.nags == 1 and "" or "s"))
        end
      end
    end
  end
  for name in pairs(afk) do
    if not present[name] then afk[name] = nil end
  end
end

---------------------------------------------------------------------------
-- Guild (and friend) welcomes
---------------------------------------------------------------------------

local guildNames, welcomed = {}, {}
local ONLINE = ERR_FRIEND_ONLINE_SS and ns.FormatToPattern(ERR_FRIEND_ONLINE_SS)

local function RefreshGuild()
  if not IsInGuild() or not GetNumGuildMembers or not GetGuildRosterInfo then return end
  wipe(guildNames)
  for i = 1, GetNumGuildMembers() or 0 do
    local name = GetGuildRosterInfo(i)
    if Usable(name) and name then guildNames[ns.ShortName(name)] = true end
  end
end
ns:On("GUILD_ROSTER_UPDATE", RefreshGuild)

local WELCOMES = {
  "Welcome back, %s. The herd has missed you. Moo.", "%s has logged on. MOO! (that's a welcome moo)",
  "Everyone, %s is here. Act natural. Moo.", "%s! The herd rejoices. Moooo.",
}

ns:On("CHAT_MSG_SYSTEM", function(msg)
  if not ONLINE or not Usable(msg) or type(msg) ~= "string" then return end
  local full, shown = msg:match(ONLINE)
  if not full then return end
  local name = ns.ShortName(shown or full)
  if name == UnitName("player") or not Ambient("guildWelcome") then return end
  local now = ns.Now()
  if now - (welcomed[name] or -100000) < 3600 then return end
  welcomed[name] = now
  ns.db.stats.welcomes = ns.db.stats.welcomes + 1
  local text = Pick(WELCOMES):format(name)
  if guildNames[name] and IsInGuild() then
    ns:Queue("GUILD", text)
  else
    ns:Queue("W:" .. full, text)
  end
end)

---------------------------------------------------------------------------
-- Roll commentary
---------------------------------------------------------------------------

local ROLL = RANDOM_ROLL_RESULT and ns.FormatToPattern(RANDOM_ROLL_RESULT)
local lastRollComment = -1000
ns:On("CHAT_MSG_SYSTEM", function(msg)
  if not ROLL or not Usable(msg) or type(msg) ~= "string" or not Ambient("rollComment") then return end
  local who, roll, lo, hi = msg:match(ROLL)
  roll, lo, hi = tonumber(roll), tonumber(lo), tonumber(hi)
  if not who or not roll or not lo or not hi or hi <= lo then return end
  local name = ns.ShortName(who)
  local inGroup = name == UnitName("player")
  for _, member in ipairs(ns.GroupMembers()) do if member == name then inGroup = true end end
  if not inGroup then return end
  local now = ns.Now()
  if now - lastRollComment < 8 then return end
  local pct = (roll - lo) / (hi - lo)
  local text
  if roll == hi and hi - lo >= 19 then
    text = ("A PERFECT %d, %s! MOOOOOOOOOO!!"):format(roll, name)
  elseif roll == lo then
    text = ("A %d. Moo... I'm so sorry, %s."):format(roll, name)
  elseif pct <= 0.1 then
    text = ("Oof. A %d. The herd looks away, %s."):format(roll, name)
  elseif pct >= 0.9 then
    text = ("A %d! Strong roll, %s. Moo!"):format(roll, name)
  elseif random() < 0.4 then
    text = ("Moo (that's a %d, %s)."):format(roll, name)
  end
  if text then
    lastRollComment = now
    Group(text)
  end
end)

---------------------------------------------------------------------------
-- Mount and jump moos
---------------------------------------------------------------------------

local wasMounted, lastMountMoo = false, -1000
local function MountTick()
  local mounted = IsMounted and IsMounted() or false
  if not Usable(mounted) then return end
  if mounted and not wasMounted and Ambient("mountMoo") and ns.Now() - lastMountMoo > 300 then
    lastMountMoo = ns.Now()
    Group(Pick({ "Mooo-unted up.", "*climbs onto steed* Giddy-up. Moo.", "Mount acquired. Moo-ving fast now." }), 1)
  end
  wasMounted = mounted and true or false
end

local sessionJumps, lastJumpMoo = 0, -1000
local function OnJump()
  ns.db.stats.jumps = ns.db.stats.jumps + 1
  sessionJumps = sessionJumps + 1
  if sessionJumps % 25 == 0 and Ambient("jumpMoo") and ns.Now() - lastJumpMoo > 60 then
    lastJumpMoo = ns.Now()
    Group(("Jump #%d this session. Moo."):format(sessionJumps), 1)
  end
end

---------------------------------------------------------------------------
-- MOO-UNTDOWN after ready checks, daily guild forecast
---------------------------------------------------------------------------

ns:On("READY_CHECK_FINISHED", function()
  if On("countdown") then Group("MOO-UNTDOWN: 3... 2... 1... MOOOOOOOO!") end
end)

local FORECASTS = {
  "scattered moos in the afternoon", "heavy mooing after dark", "a stampede warning for the evening",
  "a light moo-zzle", "moo-derate winds from Mulgore",
}
function ns:Forecast()
  if not On("forecast") or not IsInGuild() then return false end
  local today = date("%Y-%m-%d")
  if self.char.lastForecast == today then return false end
  self.char.lastForecast = today
  local hour = tonumber(date("%H")) or 12
  local part = hour < 12 and "morning" or (hour < 18 and "afternoon" or "evening")
  self:Queue("GUILD", ("Good %s, herd. Today's moo forecast: %d%% chance of moo, with %s. Moo.")
    :format(part, random(60, 100), Pick(FORECASTS)))
  return true
end

---------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------

ns:On("PLAYER_LOGIN", function()
  ns:CheckRank() -- records your current rank quietly the first time
  if JumpOrAscendStart and hooksecurefunc then hooksecurefunc("JumpOrAscendStart", OnJump) end
  if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster)
  elseif GuildRoster then pcall(GuildRoster) end
  C_Timer.After(30, function() ns:Forecast() end)
end)

table.insert(ns.tickFns, ClockTick)
table.insert(ns.tickFns, AfkTick)
table.insert(ns.tickFns, MountTick)
