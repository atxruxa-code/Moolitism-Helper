-- MooHelper Moo-chievements: game event tracking (ported from Forever Achievements)
-- Turns game events into counters/flags and runs a retroactive scan on login.
--
-- WoW: Forever runs the modern (Midnight-era) addon API:
--   * COMBAT_LOG_EVENT_UNFILTERED is blocked, so nothing here uses the combat log.
--   * Some values handed to addons can be "secret"; those are skipped, never compared.
--   * Several legacy globals are gone, so every scanner prefers the modern
--     C_* API and falls back to the classic global only if that exists.

local _, MH = ...
MH.Ach = MH.Ach or {}
local ns = MH.Ach -- the achievement engine (ported from Forever Achievements)


local frame = CreateFrame("Frame")
local handlers = {}
frame:SetScript("OnEvent", function(_, event, ...)
  local h = handlers[event]
  -- Ignore anything that fires before saved variables are initialised.
  if h and (ns.char or event == "PLAYER_LOGIN") then h(...) end
end)

-- Registering an event the client doesn't know raises an error on modern
-- clients, so registration is guarded.
local function On(event, fn)
  if pcall(frame.RegisterEvent, frame, event) then
    handlers[event] = fn
  end
end

local IsSecret = issecretvalue or function() return false end
local function Usable(v) return v ~= nil and not IsSecret(v) end

local HEARTHSTONE_SPELL = 8690
local bgWinCounted = false -- reset on every loading screen, set once a match result is counted

-- Converts a GlobalStrings format ("You receive loot: %s.") into a Lua match pattern.
-- With openEnd, the pattern isn't anchored at the end (for messages with optional suffixes).
local function FormatToPattern(fmt, openEnd)
  fmt = fmt:gsub("%%%d*%$?s", "\001"):gsub("%%%d*%$?d", "\002")
  fmt = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1")
  fmt = fmt:gsub("\001", "(.+)"):gsub("\002", "(%%d+)")
  return "^" .. fmt .. (openEnd and "" or "$")
end

---------------------------------------------------------------------------
-- Scanners (safe to call any time; they only ever raise counters)
---------------------------------------------------------------------------

-- skillLine id -> key (stable across locales)
local SKILL_LINES = {
  [171] = "alchemy", [164] = "blacksmithing", [333] = "enchanting", [202] = "engineering",
  [182] = "herbalism", [165] = "leatherworking", [186] = "mining", [393] = "skinning",
  [197] = "tailoring", [185] = "cooking", [129] = "firstaid", [356] = "fishing",
}
local SECONDARY = { cooking = true, firstaid = true, fishing = true }
local ENGLISH_NAMES = {
  Alchemy = "alchemy", Blacksmithing = "blacksmithing", Enchanting = "enchanting",
  Engineering = "engineering", Herbalism = "herbalism", Leatherworking = "leatherworking",
  Mining = "mining", Skinning = "skinning", Tailoring = "tailoring",
  Cooking = "cooking", ["First Aid"] = "firstaid", Fishing = "fishing",
}

local function RecordSkills(found)
  local best, primaries, artisans = 0, 0, 0
  for key, rank in pairs(found) do
    ns:SetMax("skill:" .. key, rank)
    if not SECONDARY[key] then
      primaries = primaries + 1
      if rank > best then best = rank end
      if rank >= 300 then artisans = artisans + 1 end
    end
  end
  ns:SetMax("profMax", best)
  ns:SetMax("primaryProfs", primaries)
  ns:SetMax("artisanProfs", artisans)
end

local function ScanSkills()
  local found = {}
  if GetProfessions and GetProfessionInfo then
    -- Modern API: GetProfessions() returns indices (some may be nil).
    local indices = { GetProfessions() }
    for i = 1, select("#", GetProfessions()) do
      local idx = indices[i]
      if idx then
        local name, _, rank, _, _, _, skillLine = GetProfessionInfo(idx)
        local key = SKILL_LINES[skillLine] or ENGLISH_NAMES[name]
        if key and Usable(rank) then found[key] = rank end
      end
    end
  elseif GetNumSkillLines and GetSkillLineInfo then
    -- Classic API fallback.
    for i = 1, GetNumSkillLines() do
      local name, isHeader, _, rank = GetSkillLineInfo(i)
      local key = not isHeader and ENGLISH_NAMES[name]
      if key and rank then found[key] = rank end
    end
  end
  RecordSkills(found)
end

local function ScanLevel()
  ns:SetMax("level", UnitLevel("player"))
end

local function ScanMoney()
  local money = GetMoney()
  if Usable(money) then ns:SetMax("maxMoney", money) end
end

local function ScanReputation()
  local revered, exalted = 0, 0
  local function count(name, standing)
    if Usable(standing) then
      if standing >= 7 then revered = revered + 1 end
      if standing >= 8 then exalted = exalted + 1 end
      -- rep5 = Friendly, rep6 = Honored, rep7 = Revered, rep8 = Exalted
      if Usable(name) then
        for s = 5, math.min(standing, 8) do ns:SetFlag("rep" .. s .. ":" .. name) end
      end
    end
  end
  if C_Reputation and C_Reputation.GetFactionDataByIndex and C_Reputation.GetNumFactions then
    for i = 1, C_Reputation.GetNumFactions() do
      local d = C_Reputation.GetFactionDataByIndex(i)
      if d and (not d.isHeader or d.isHeaderWithRep) then count(d.name, d.reaction) end
    end
  elseif GetNumFactions and GetFactionInfo then
    for i = 1, GetNumFactions() do
      local name, _, standingID, _, _, _, _, _, isHeader, _, hasRep = GetFactionInfo(i)
      if name and (not isHeader or hasRep) then count(name, standingID) end
    end
  end
  ns:SetMax("revered", revered)
  ns:SetMax("exalted", exalted)
end

local function ScanZone()
  if IsInInstance() then
    -- Battlegrounds are instances of type "pvp"
    local name, instanceType = GetInstanceInfo()
    if instanceType == "pvp" and Usable(name) and name ~= "" then ns:SetFlag("bg:" .. name) end
    return
  end
  local zone = GetRealZoneText()
  if Usable(zone) and zone ~= "" then
    ns:AddToSet("zones", zone)
    ns:SetFlag("zone:" .. zone)
    local sub = GetSubZoneText()
    if Usable(sub) and sub ~= "" then ns:AddToSet("subzones", zone .. ":" .. sub) end
  end
end

local function ScanCompletedQuests()
  local n
  if C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs then
    local ids = C_QuestLog.GetAllCompletedQuestIDs()
    n = ids and #ids
  elseif GetQuestsCompleted then
    local t = GetQuestsCompleted()
    if t then
      n = 0
      for _ in pairs(t) do n = n + 1 end
    end
  end
  if n then ns:SetMax("quests", n) end
end

local function ScanPvP()
  if GetPVPLifetimeStats then
    local hk = GetPVPLifetimeStats()
    if type(hk) == "number" and Usable(hk) then ns:SetMax("hk", hk) end
  end
  -- Honor rank: UnitPVPRank returns 0 (none) or 5 + rank.
  if UnitPVPRank then
    local r = UnitPVPRank("player")
    if type(r) == "number" and Usable(r) and r >= 5 then ns:SetMax("pvpRank", r - 4) end
  end
end

local function ScanGroup()
  if IsInRaid() then
    ns:SetFlag("raid")
    ns:SetFlag("party")
  elseif IsInGroup() then
    ns:SetFlag("party")
  end
  if IsInGuild() then ns:SetFlag("guild") end
end

local function ScanAll()
  ScanLevel()
  ScanMoney()
  ScanSkills()
  ScanReputation()
  ScanZone()
  ScanCompletedQuests()
  ScanPvP()
  ScanGroup()
  if IsMounted() then ns:SetFlag("mounted") end
end
ns.ScanAll = ScanAll

---------------------------------------------------------------------------
-- Login / startup
---------------------------------------------------------------------------

local function HookEmotes()
  local function onEmote(token)
    ns:Inc("emotes")
    if type(token) == "string" and Usable(token) then
      token = token:upper()
      ns:Inc("emote:" .. token)
      ns:AddToSet("emotesUsed", token)
      if token == "DANCE" then ns:Inc("dances") end
    end
  end
  -- Hook exactly one so an emote isn't counted twice when one calls the other.
  if C_ChatInfo and C_ChatInfo.PerformEmote then
    hooksecurefunc(C_ChatInfo, "PerformEmote", onEmote)
  elseif DoEmote then
    hooksecurefunc("DoEmote", onEmote)
  end
end

On("PLAYER_LOGIN", function()
  ns:InitDB()
  HookEmotes()
  if JumpOrAscendStart then
    hooksecurefunc("JumpOrAscendStart", function() ns:Inc("jumps") end)
  end
end)

On("PLAYER_ENTERING_WORLD", function(_, isReloadingUi)
  bgWinCounted = false
  local instanceName, instanceType = GetInstanceInfo()
  if instanceType == "pvp" and Usable(instanceName) then
    ns.currentBG = instanceName
    if not isReloadingUi then ns:Inc("bgPlayed") end -- a /reload inside a battleground isn't a new match
  else
    ns.currentBG = nil
  end
  ScanZone()
  if ns.ready or ns.starting then return end
  ns.starting = true
  -- Give the client a moment so skills / reputation / quest data are populated.
  C_Timer.After(3, MH.Safe("AchTracking.lua timer line 248", function()
    ScanAll()
    ns.silent = ns.isFirstRun -- don't spam toasts for retroactive awards on first install
    ns.ready = true
    ns:Evaluate()
    if ns.silent then
      ns:Print(("Welcome! %d achievements were awarded retroactively from your character's progress. Type %s to view them.")
        :format(ns.silentCount or 0, ns.Color("ffff00", "/moo ach")))
    end
    ns.silent = false
  end))
end)

---------------------------------------------------------------------------
-- Live tracking
---------------------------------------------------------------------------

On("PLAYER_LEVEL_UP", function(newLevel)
  if Usable(newLevel) then ns:SetMax("level", newLevel) end
end)

On("PLAYER_MONEY", ScanMoney)
On("SKILL_LINES_CHANGED", ScanSkills)
On("CHAT_MSG_SKILL", ScanSkills)
On("UPDATE_FACTION", ScanReputation)
On("ZONE_CHANGED", ScanZone)
On("ZONE_CHANGED_NEW_AREA", ScanZone)
On("ZONE_CHANGED_INDOORS", ScanZone)
On("GROUP_ROSTER_UPDATE", ScanGroup)
On("PLAYER_PVP_KILLS_CHANGED", ScanPvP)

On("QUEST_TURNED_IN", function()
  ns:Inc("quests")

  -- quests in a single (local calendar) day
  local today = date("%Y-%m-%d")
  if ns.char.questDay ~= today then
    ns.char.questDay = today
    ns.char.questDayCount = 0
  end
  ns.char.questDayCount = ns.char.questDayCount + 1
  ns:SetMax("questsInDay", ns.char.questDayCount)

  -- quests per zone (the zone you're standing in when you turn it in)
  if not IsInInstance() then
    local zone = GetRealZoneText()
    if Usable(zone) and zone ~= "" then ns:Inc("questsIn:" .. zone) end
  end
end)

On("TIME_PLAYED_MSG", function(totalSeconds)
  if Usable(totalSeconds) and type(totalSeconds) == "number" then ns:SetMax("played", totalSeconds) end
end)

On("LOOT_OPENED", function()
  if IsFishingLoot and IsFishingLoot() then ns:Inc("fishCaught") end
end)

On("BANKFRAME_OPENED", function() ns:SetFlag("bank") end)
On("AUCTION_HOUSE_SHOW", function() ns:SetFlag("auction") end)
On("BARBER_SHOP_OPEN", function() ns:SetFlag("barber") end)
On("MAIL_SHOW", function() ns:SetFlag("mailbox") end)
On("MAIL_SEND_SUCCESS", function() ns:Inc("mailSent") end)
On("CHAT_MSG_WHISPER_INFORM", function() ns:Inc("whispers") end)
On("PLAYER_GUILD_UPDATE", ScanGroup)

On("PLAYER_DEAD", function()
  ns:Inc("deaths")
end)

On("UNIT_AURA", function(unit)
  if unit == "player" and not ns:HasFlag("mounted") and IsMounted() then
    ns:SetFlag("mounted")
  end
end)

On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
  if unit == "player" and Usable(spellID) and spellID == HEARTHSTONE_SPELL then ns:Inc("hearths") end
end)

On("PLAYER_CONTROL_LOST", function()
  C_Timer.After(1.5, MH.Safe("AchTracking.lua timer line 329", function()
    if UnitOnTaxi("player") then ns:Inc("flights") end
  end))
end)

-- Boss kills. ENCOUNTER_END(encounterID, encounterName, difficultyID, groupSize, success)
local RAID_OPENING_START = time({ year = 2026, month = 12, day = 9, hour = 0 })
local RAID_OPENING_END = time({ year = 2026, month = 12, day = 16, hour = 0 })

On("ENCOUNTER_END", function(encounterID, encounterName, _, groupSize, success)
  if not (success == 1 or success == true) then return end
  if not Usable(encounterName) or not Usable(encounterID) then return end
  ns:Inc("bossKills")
  ns:Inc("encounter:" .. encounterName:lower())

  local instanceName, instanceType = GetInstanceInfo()
  if instanceType == "raid" then
    ns:Inc("raidBossKills")
    local now = time()
    if now >= RAID_OPENING_START and now < RAID_OPENING_END then ns:SetFlag("raidOpeningWeek") end
  end
  if Usable(instanceName) and instanceName ~= "" then
    -- unique bosses per instance, used for raid full clears
    ns:AddToSet("enc:" .. instanceName, tostring(encounterID))
    ns:AddToSet("bossLog", instanceName .. " - " .. encounterName)
  else
    ns:AddToSet("bossLog", encounterName)
  end

  local flag = ns.bossFlags[encounterName:lower()]
  if not flag then return end
  ns:SetFlag(flag)

  -- dungeon final boss extras
  if flag:find("^dungeon:") then
    ns:Inc("dungeonClears")
    local minLevel = ns.dungeonMinLevel[flag]
    local level = UnitLevel("player")
    if minLevel and Usable(level) and level < minLevel then ns:SetFlag("underdog") end
    if Usable(groupSize) and type(groupSize) == "number" and groupSize > 0 and groupSize <= 3 then
      ns:SetFlag("smallgroup")
    end
  end
end)

-- Kills: "%s dies, you gain %d experience." (+ optional rested/group suffix)
local XP_PATTERN = FormatToPattern(COMBATLOG_XPGAIN_FIRSTPERSON or "%s dies, you gain %d experience.", true)
XP_PATTERN = XP_PATTERN:gsub("%%%.$", "") -- drop the trailing "." so suffixed messages match
On("CHAT_MSG_COMBAT_XP_GAIN", function(msg)
  if not Usable(msg) then return end
  local victim = msg:match(XP_PATTERN)
  if victim then
    ns:Inc("kills")
    local flag = ns.namedKills[victim:lower()]
    if flag then ns:SetFlag(flag) end
  end
end)

-- Battleground wins. Classic API: GetBattlefieldWinner() -> 0 Horde, 1 Alliance.
-- Modern API: PVP_MATCH_COMPLETE(winner). Counted once per match.
local function RecordBattlegroundWinner(winner)
  if bgWinCounted or not Usable(winner) or type(winner) ~= "number" then return end
  bgWinCounted = true
  local mine = UnitFactionGroup("player") == "Alliance" and 1 or 0
  if winner == mine then
    ns:Inc("bgWins")
    if ns.currentBG then ns:Inc("bgWins:" .. ns.currentBG) end
  end
end
On("UPDATE_BATTLEFIELD_SCORE", function()
  if GetBattlefieldWinner then RecordBattlegroundWinner(GetBattlefieldWinner()) end
end)
On("PVP_MATCH_COMPLETE", RecordBattlegroundWinner)
On("PLAYER_PVP_RANK_CHANGED", ScanPvP)

-- Duels: "%1$s has defeated %2$s in a duel"
local DUEL_PATTERN = DUEL_WINNER_KNOCKOUT and FormatToPattern(DUEL_WINNER_KNOCKOUT)
On("CHAT_MSG_SYSTEM", function(msg)
  if DUEL_PATTERN and Usable(msg) then
    local winner = msg:match(DUEL_PATTERN)
    local me = UnitName("player")
    if winner and Usable(me) and winner == me then ns:Inc("duelWins") end
  end
end)

-- Loot quality, read from the item link's colour code.
local LOOT_PATTERNS = {}
for _, fmt in ipairs({ LOOT_ITEM_SELF_MULTIPLE, LOOT_ITEM_SELF }) do
  if fmt then LOOT_PATTERNS[#LOOT_PATTERNS + 1] = FormatToPattern(fmt) end
end
local COUNTER_BY_QUALITY = { [2] = "lootUncommon", [3] = "lootRare", [4] = "lootEpic", [5] = "lootLegendary" }
local QUALITY_BY_COLOR = { ff1eff00 = 2, ff0070dd = 3, ffa335ee = 4, ffff8000 = 5 }
local function LinkQuality(msg)
  -- Modern links: |cnIQ4:|Hitem:...   Classic links: |cffa335ee|Hitem:...
  local q = msg:match("|cnIQ(%d):")
  if q then return tonumber(q) end
  local hex = msg:match("|c(%x%x%x%x%x%x%x%x)|Hitem:")
  return hex and QUALITY_BY_COLOR[hex:lower()]
end
On("CHAT_MSG_LOOT", function(msg)
  if not Usable(msg) then return end
  for _, pattern in ipairs(LOOT_PATTERNS) do
    if msg:match(pattern) then
      local counter = COUNTER_BY_QUALITY[LinkQuality(msg) or 0]
      if counter then ns:Inc(counter) end
      return
    end
  end
end)
