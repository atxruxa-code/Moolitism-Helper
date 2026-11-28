-- MooHelper: the moo engine
-- Moo text, the Moo button / keybind action, translators, automatic moos, Tauren radar,
-- moo-chievements and slash commands.

local _, ns = ...

local Usable = ns.Usable
local random = math.random

local function Pick(list) return list[random(#list)] end

---------------------------------------------------------------------------
-- Moo text
---------------------------------------------------------------------------

ns.combo = 0
local lastMooAt = -1000
local COMBO_WINDOW = 4 -- seconds between presses to keep a combo going

function ns:BumpCombo()
  local now = ns.Now()
  if now - lastMooAt <= COMBO_WINDOW then self.combo = self.combo + 1 else self.combo = 1 end
  lastMooAt = now
  if self.combo > self.db.stats.bestCombo then self.db.stats.bestCombo = self.combo end
  if self.combo == 10 then self:Signal("combo10") end
  return self.combo
end

local CLASSIC = { "Moo.", "Moo!", "Mooo.", "Moo?", "Moooo.", "moo" }
local SUFFIX = { "!", "?!", "...", "~", "!!", "." }

-- n = how worked up we are (combo count or escalation level)
function ns.MooText(n, style)
  n = math.max(1, n or 1)
  style = style or ns.db.style
  if style == "classic" then return Pick(CLASSIC) end
  if style == "chaos" then
    local s = { "m" }
    for _ = 1, random(2, 4 + math.min(n, 20)) do s[#s + 1] = "o" end
    for i = 1, #s do
      if random() < 0.5 then s[i] = s[i]:upper() end
    end
    return table.concat(s) .. Pick(SUFFIX)
  end
  -- escalate
  local os = string.rep("o", math.min(2 + n * 2, 60))
  local word = "M" .. os
  if n >= 4 then word = word:upper() end
  local bangs = string.rep("!", math.min(n, 8))
  if n >= 10 then return word .. bangs .. " (x" .. n .. " MOO COMBO)" end
  return word .. bangs
end

local EMOTE_TEXT = {
  "moos.", "moos loudly.", "lets out a long, mournful moo.", "moos at nobody in particular.",
  "moos with great conviction.", "moos in a way that suggests something is deeply wrong.",
}
local EMOTE_BIG = {
  "MOOS WITH THE FORCE OF A THOUSAND KODOS.", "moos so hard the ground shakes.",
  "has entered a state of permanent mooing.",
}
function ns.EmoteText(n)
  if (n or 1) >= 6 then return Pick(EMOTE_BIG) end
  return Pick(EMOTE_TEXT)
end

---------------------------------------------------------------------------
-- Translators
---------------------------------------------------------------------------

local function LetterCount(s)
  return #(s:gsub("[\128-\191]", "")) -- count UTF-8 characters, not bytes
end

local function MooWord(word)
  if word:find("[\001\002{]") then return word end -- protected link, or a raid marker like {rt1}
  local pre, core, post = word:match("^([^%w\128-\255]*)(.-)([^%w\128-\255]*)$")
  if not core or core == "" or not core:find("[%a\128-\255]") then return word end
  local n = LetterCount(core)
  local moo = n <= 1 and "m" or ("m" .. string.rep("o", n - 1))
  -- A-Z only: %u depends on the system locale for accented letters
  if n > 1 and core:find("[A-Z]") and not core:find("[a-z]") then
    moo = moo:upper()
  elseif core:sub(1, 1):find("[A-Z]") then
    moo = "M" .. moo:sub(2)
  end
  return pre .. moo .. post
end

-- "Hello, LEADER!" -> "Moooo, MOOOOO!"  Links, textures and markers are left untouched.
function ns.MooTranslate(text)
  if type(text) ~= "string" then return text end
  local saved = {}
  local function protect(chunk)
    saved[#saved + 1] = chunk
    return "\001" .. #saved .. "\002"
  end
  text = text:gsub("|c[^|]*|H.-|h.-|h|r", protect)
  text = text:gsub("|H.-|h.-|h", protect)
  text = text:gsub("|T.-|t", protect)
  text = text:gsub("|A.-|a", protect)
  text = text:gsub("%S+", MooWord)
  text = text:gsub("\001(%d+)\002", function(i) return saved[tonumber(i)] end)
  return text
end

local MORSE = {
  a = ".-", b = "-...", c = "-.-.", d = "-..", e = ".", f = "..-.", g = "--.", h = "....",
  i = "..", j = ".---", k = "-.-", l = ".-..", m = "--", n = "-.", o = "---", p = ".--.",
  q = "--.-", r = ".-.", s = "...", t = "-", u = "..-", v = "...-", w = ".--", x = "-..-",
  y = "-.--", z = "--..", ["0"] = "-----", ["1"] = ".----", ["2"] = "..---", ["3"] = "...--",
  ["4"] = "....-", ["5"] = ".....", ["6"] = "-....", ["7"] = "--...", ["8"] = "---..", ["9"] = "----.",
}
-- dot = "moo", dash = "MOOO", letters split by spaces, words by " / "
function ns.MooMorse(text)
  local words = {}
  for word in tostring(text):lower():gmatch("%S+") do
    local letters = {}
    for ch in word:gmatch(".") do
      local code = MORSE[ch]
      if code then
        letters[#letters + 1] = code:gsub("%.", "moo,"):gsub("%-", "MOOO,"):gsub(",$", ""):gsub(",", " ")
      end
    end
    if #letters > 0 then words[#words + 1] = table.concat(letters, "  ") end
  end
  return table.concat(words, " / ")
end

---------------------------------------------------------------------------
-- The Moo button / keybind / slash action (always a hardware event)
---------------------------------------------------------------------------

local MAX_PER_PRESS = 12
local lastSentAt = {}
local lastHint = -1000

function ns:SelectedChannels()
  local list = {}
  for _, c in ipairs(ns.FIXED_CHANNELS) do
    if self.db.channels[c.key] then list[#list + 1] = c.key end
  end
  for _, c in ipairs(self:JoinedChannels()) do
    if self.db.channels[c.key] then list[#list + 1] = c.key end
  end
  return list
end

local function Cooldown(key)
  if key:sub(1, 3) == "CH:" then return ns.db.publicCooldown end
  return 0.5
end

function ns:Moo()
  local combo = self:BumpCombo()
  local now = ns.Now()
  local sent = 0
  if self.forceYell then -- lost a game of Moo-lette: this press yells, like it or not
    self.forceYell = false
    if self:SendNow("YELL", "MOOOOOOOOOOOOOOOOO!!! (I lost Moo-lette)") then sent = sent + 1 end
  end
  for _, key in ipairs(self:SelectedChannels()) do
    if sent >= MAX_PER_PRESS then break end
    if self:ChannelAvailable(key) and now - (lastSentAt[key] or -1000) >= Cooldown(key) then
      local text = key == "EMOTE" and ns.EmoteText(combo) or ns.MooText(combo)
      if self:SendNow(key, text) then
        lastSentAt[key] = now
        sent = sent + 1
      end
    end
  end
  if sent == 0 and now - lastHint > 30 then
    lastHint = now
    self:Print("Nothing mooed: pick channels with /moo options (some are on cooldown or unavailable here).")
  end
  if self.ShowCombo then self:ShowCombo(combo) end
  if self.db.effects.cowRain and self.CowRain and (combo == 1 or combo % 5 == 0) then
    self:CowRain(math.min(4 + combo, 30))
  end
  if combo % 10 == 0 then
    if self.Stampede then self:Stampede(10 + combo / 2) end
    if self.MooVision then self:MooVision() end
  end
  return sent
end

local function PerformEmote(token, unit)
  if ns:IsMuted("EMOTE") then return false end -- HARD MUTE covers emotes too
  local emote = (C_ChatInfo and C_ChatInfo.PerformEmote) or DoEmote
  if emote then pcall(emote, token, unit) end
end

function ns:MooAtTarget()
  if self:IsMuted("EMOTE") then
    self:Print("Emote is HARD MUTED, so no /moo emote. Unmute it in the Barn (Channels).")
    return
  end
  if UnitExists("target") then
    PerformEmote("MOO", "target")
  else
    PerformEmote("MOO")
  end
  self:BumpCombo()
  if self.ShowCombo then self:ShowCombo(self.combo) end
end

-- Keybinding globals (Bindings.xml)
BINDING_HEADER_MOOHELPER = "MooHelper"
BINDING_NAME_MOOHELPER_MOO = "Moo! (all selected channels)"
BINDING_NAME_MOOHELPER_MOO_TARGET = "/moo at your target"
function MooHelper_Moo() ns:Moo() end
function MooHelper_MooAtTarget() ns:MooAtTarget() end

---------------------------------------------------------------------------
-- Automatic moos
---------------------------------------------------------------------------

local function Trigger(name) return ns.db.triggers[name] and not ns.db.panic end
local function ToGroup(text)
  local ch = ns:GroupChannel()
  if ch then ns:Queue(ch, text) end
end

ns:On("PLAYER_DEAD", function()
  if not Trigger("death") then return end
  ToGroup(Pick({
    "moo... (the cow has fallen)", "Moooooo... tell the herd I loved them.", "*final moo*",
    "M o o . . .", "The moo has left my body. Please moo on my behalf.",
  }))
end)

ns:On("PLAYER_LEVEL_UP", function(level)
  if not Trigger("levelUp") or not Usable(level) then return end
  local text = ("LEVEL %d! %s"):format(level, ns.MooText(math.max(3, math.floor(level / 6)), "escalate"))
  ToGroup(text)
  if IsInGuild() then ns:Queue("GUILD", text) end
end)

ns:On("READY_CHECK", function()
  if Trigger("readyCheck") then ToGroup(Pick({ "Moo. (ready)", "Moo-dy and ready.", "Ready to moo." })) end
end)

ns:On("ENCOUNTER_END", function(_, encounterName, _, _, success)
  if not Trigger("bossKill") or not (success == 1 or success == true) or not Usable(encounterName) then return end
  ToGroup(Pick({
    "VICTORY MOO! %s has been moo-tralized.", "MOOOOOOOO! %s is down! The herd is victorious!",
    "%s has been defeated. Moo.",
  }):format(ns.Clean(encounterName)))
end)

ns:On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
  if unit == "player" and Usable(spellID) and spellID == 8690 and Trigger("hearth") then
    ToGroup(Pick({ "Moo-ving out.", "Mooooo (going home).", "The cow returns to the barn." }))
  end
end)

-- Epic (and legendary) loot, from your own loot messages
local function FormatToPattern(fmt)
  fmt = fmt:gsub("%%%d*%$?s", "\001"):gsub("%%%d*%$?d", "\002")
  fmt = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1")
  return "^" .. fmt:gsub("\001", "(.+)"):gsub("\002", "(%%d+)") .. "$"
end
ns.FormatToPattern = FormatToPattern
local LOOT_PATTERNS = {}
for _, fmt in ipairs({ LOOT_ITEM_SELF_MULTIPLE, LOOT_ITEM_SELF }) do
  if fmt then LOOT_PATTERNS[#LOOT_PATTERNS + 1] = FormatToPattern(fmt) end
end
local EPIC_COLORS = { ffa335ee = 4, ffff8000 = 5 }
function ns.LinkQuality(msg)
  local q = msg:match("|cnIQ(%d):")
  if q then return tonumber(q) end
  local hex = msg:match("|c(%x%x%x%x%x%x%x%x)|H")
  return hex and (EPIC_COLORS[hex:lower()] or 0) or nil
end
ns:On("CHAT_MSG_LOOT", function(msg)
  if not Trigger("epicLoot") or not Usable(msg) then return end
  for _, p in ipairs(LOOT_PATTERNS) do
    if msg:match(p) then
      if (ns.LinkQuality(msg) or 0) >= 4 then
        local item = msg:match("%[(.-)%]") or "something shiny"
        ToGroup(("MOO! Epic loot: [%s]! The herd provides."):format(ns.Clean(item)))
      end
      return
    end
  end
end)

-- Party deaths: watch group members' units for alive -> dead.
-- Cheap on purpose: UNIT_HEALTH fires many times a second in a raid, so each event checks
-- only the unit it's about (one name and one dead/alive lookup). The whole group is only
-- rescanned when the roster changes, which is also when people who left are forgotten.
local wasDead = {}
local function GroupUnits()
  local units = {}
  if IsInRaid() then
    for i = 1, (GetNumGroupMembers() or 0) do units[#units + 1] = "raid" .. i end
  elseif IsInGroup() then
    for i = 1, 4 do units[#units + 1] = "party" .. i end
  end
  return units
end

-- party1-4 and raid1-40 only (not partypet1, raidpet3, ...)
local function IsGroupUnit(unit)
  return type(unit) == "string" and (unit:match("^party%d+$") ~= nil or unit:match("^raid%d+$") ~= nil)
end

-- Mournful moo-poetry (GitHub issue #6). Short, original, and a little sad. %s is the fallen.
ns.MOURN_POEMS = {
  { "Here lies %s, who stood where they should not;", "the grass grows moo-ver the spot where they fought. Moo." },
  { "O %s, fallen in the fray,", "the herd will moo for you today. ...Mooooo." },
  { "Gone is %s, to pastures far,", "beneath the moo-nlight and the star. We mourn. We moo." },
  { "Rest now, %s, your health is spent;", "the healer saw, and yet you went. ...moo." },
  { "A haiku for %s:", "the floor was glowing red / they did not moo-ve away / now they eat the grass" },
  { "%s mooed once, and mooed no more;", "their hit points lie upon the floor. Moo." },
  { "Farewell, %s. The bell of the cow now tolls;", "it tolls for thee, and also for the floor you stood on. Moo." },
  { "%s has left the herd. The pasture weeps.", "The hay is quiet. The milk is cold. Moooo... (a moment of silence)" },
}

-- Deaths are gathered for a moment, so a wipe is one line, not twenty.
local MOURN_WAIT, POEM_GAP = 2.5, 90
local mourning, lastPoem = nil, -1000

local function ListNames(names)
  if #names == 1 then return names[1] end
  local shown = {}
  for i = 1, math.min(#names, 5) do shown[#shown + 1] = names[i] end
  local text = table.concat(shown, ", ", 1, #shown - 1) .. " and " .. shown[#shown]
  if #names > 5 then text = table.concat(shown, ", ") .. (" and %d more"):format(#names - 5) end
  return text
end

local function MournNow()
  local names = mourning
  mourning = nil
  if not names or #names == 0 or not Trigger("partyDeath") then return end
  table.sort(names)
  local who = ListNames(names)
  -- Whether it's a wipe counts everyone who died, you included: each copy's list leaves its own
  -- player out, so counting only the list let copies disagree about the same wipe (issue #20).
  local selfDead = UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")
  local isWipe = #names + ((Usable(selfDead) and selfDead) and 1 or 0) >= 5
  local text
  if isWipe then
    text = ("A MOO OF MOURNING for the fallen herd: %s. That was a wipe. Moooooo."):format(who)
  elseif #names == 1 then
    text = Pick({
      "MOO OF MOURNING for %s. Mooooooooo.", "%s has fallen. The herd moos as one.",
      "A single, respectful moo for %s.", "%s has gone to the great pasture in the sky. Moo.",
    }):format(who)
  else
    text = ("MOO OF MOURNING for %s. The herd moos as one. Moooo."):format(who)
  end
  local poem
  local now = ns.Now()
  if ns.db.triggers.mournPoetry and now - lastPoem >= POEM_GAP then
    lastPoem = now
    poem = Pick(ns.MOURN_POEMS)
  end
  -- Every copy names a death the same way ("mourn:Bob"), so whichever copy hosts, the others
  -- stand down, even if they gathered the deaths into different batches. A wipe is one claim
  -- instead of one per name (issue #17). It needs no timestamp in it: hosting only counts claims
  -- made after this copy asked, so an earlier wipe's claim can't stand in for this one, and a
  -- per-minute id split a wipe that crossed the minute into two (issue #20).
  local ids = {}
  if isWipe then
    ids[1] = "mourn:wipe"
  else
    for _, n in ipairs(names) do ids[#ids + 1] = "mourn:" .. n end
  end
  ns:RunAsHostMany("group", ids, function(mine)
    -- if another copy already mourned some of them, say only the rest
    if #mine < #ids and not isWipe then
      local left = {}
      for _, id in ipairs(mine) do left[#left + 1] = id:sub(7) end
      who = ListNames(left)
      text = (#left == 1 and "MOO OF MOURNING for %s. Mooooooooo." or "MOO OF MOURNING for %s. The herd moos as one. Moooo."):format(who)
    end
    ToGroup(text)
    if poem then
      for _, line in ipairs(poem) do
        local ch = ns:GroupChannel()
        if ch then ns:Queue(ch, ns.Fit((line:find("%%s") and line:format(who) or line)), 2, 30) end
      end
      ns:Bump("poemsRecited")
    end
  end)
end

local function Mourn(name)
  ns:Signal("friendDeath", name)
  if not mourning then
    mourning = {}
    C_Timer.After(MOURN_WAIT, MournNow)
  end
  for _, n in ipairs(mourning) do if n == name then return end end
  mourning[#mourning + 1] = name
end

-- returns the unit's name when it was looked at
-- Deaths are tracked per player (their GUID), not per name: two players shown as "Unknown", or
-- with the same name on different realms, used to share one entry and flip it back and forth,
-- mourning the same death over and over (issue #17).
local lastMourned = {}
local MOURN_AGAIN = 60 -- never mourn the same player twice within a minute
local function CheckUnit(unit)
  if not UnitExists(unit) or UnitIsUnit(unit, "player") then return nil end
  local name = UnitName(unit)
  local dead = UnitIsDeadOrGhost(unit)
  if not ns.KnownName(name) or not Usable(dead) then return nil end
  local guid = UnitGUID and UnitGUID(unit)
  local key = (Usable(guid) and type(guid) == "string" and guid ~= "") and guid or name
  dead = dead and true or false
  local before = wasDead[key]
  if before == dead then return key end -- nothing changed: the common case, nothing to do
  wasDead[key] = dead
  -- the first look at someone only records them (they may have been dead before we arrived)
  if dead and before == false then
    local now = ns.Now()
    if now - (lastMourned[key] or -1000) >= MOURN_AGAIN then
      lastMourned[key] = now
      Mourn(ns.ShortName(name))
    end
  end
  return key
end

-- full scan: on roster changes (and for tests)
function ns:CheckPartyDeaths()
  local seen = {}
  for _, unit in ipairs(GroupUnits()) do
    local name = CheckUnit(unit)
    if name then seen[name] = true end
  end
  for key in pairs(wasDead) do
    if not seen[key] then wasDead[key] = nil end
  end
end

local function OnUnitEvent(unit)
  if IsGroupUnit(unit) then CheckUnit(unit) end
end
ns:On("UNIT_HEALTH", OnUnitEvent)
ns:On("UNIT_FLAGS", OnUnitEvent)
ns:On("GROUP_ROSTER_UPDATE", function() ns:CheckPartyDeaths() end)

-- Moo-backs: someone says "moo" in a group or guild channel, we moo back, harder each time
local MOO_BACK_EVENTS = {
  CHAT_MSG_PARTY = "PARTY", CHAT_MSG_PARTY_LEADER = "PARTY", CHAT_MSG_RAID = "RAID",
  CHAT_MSG_RAID_LEADER = "RAID", CHAT_MSG_INSTANCE_CHAT = "INSTANCE_CHAT",
  CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE_CHAT", CHAT_MSG_GUILD = "GUILD",
}
local mooBackLevel, lastMooBack = {}, {}
function ns.SaysMoo(msg)
  return type(msg) == "string" and msg:lower():find("%f[%a]mo[o]+%f[%A]") ~= nil
end
local MOO_COUNTING_GAMES = { "battle", "mooCheck", "boss", "draw" }
local function MooBack(sender, key)
  -- games that count moos (here, or hosted by another copy in this chat): don't answer every one.
  -- Only games in this chat count: a guild MOO-OFF doesn't silence party moo-backs (issue #20).
  local scope = key == "GUILD" and "guild" or "group"
  for _, field in ipairs(MOO_COUNTING_GAMES) do
    if ns[field] and (not ns.GameScopeOf or ns:GameScopeOf(field) == scope) then return end
  end
  if (ns.quietUntil and ns.quietUntil[scope] or 0) > ns.Now() then return end
  local now = ns.Now()
  if now - (lastMooBack[key] or -1000) < 3 then return end
  if not ns:AllowAutoReply(sender) then return end
  lastMooBack[key] = now
  local level = (mooBackLevel[sender] or 0) + 1
  mooBackLevel[sender] = level
  ns.db.stats.mooBacks = ns.db.stats.mooBacks + 1
  local text = ns.MooText(level + 1, "escalate")
  if level >= 3 then text = text .. (" (moo-back #%d, %s started this)"):format(level, ns.ShortName(sender)) end
  ns:Queue(key, text)
end

for event, key in pairs(MOO_BACK_EVENTS) do
  ns:On(event, function(msg, sender)
    if not Trigger("mooBack") or not Usable(msg) or not Usable(sender) then return end
    if ns.ShortName(sender) == UnitName("player") or not ns.SaysMoo(msg) then return end
    if ns:IsOwnOutput(msg, sender) then return end
    -- another copy of the addon mooing is not a person mooing: never moo back at it
    ns:GateChat(sender, msg, function() MooBack(sender, key) end)
  end)
end

-- Tauren radar: /moo at every Tauren you target, and count every Tauren you see
local mooedAt = {}
local function NoteTauren(unit)
  if not UnitExists(unit) or not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") then return false end
  local _, raceFile = UnitRace(unit)
  if not Usable(raceFile) or raceFile ~= "Tauren" then return false end
  local name = UnitName(unit)
  if not Usable(name) then return true end
  local s = ns.db.stats
  if not s.taurens[name] then
    s.taurens[name] = true
    s.taurenCount = s.taurenCount + 1
    if s.taurenCount % 25 == 0 then ns:Print(("Herd census: %d Taurens spotted. The herd grows."):format(s.taurenCount)) end
    if ns.CheckAchievements then ns:CheckAchievements() end
  end
  return true, name
end
ns:On("PLAYER_TARGET_CHANGED", function()
  local isTauren, name = NoteTauren("target")
  if isTauren and name and Trigger("taurenTarget") then
    local now = ns.Now()
    if now - (mooedAt[name] or -1000) >= 20 then
      mooedAt[name] = now
      PerformEmote("MOO", "target")
    end
  end
end)
ns:On("NAME_PLATE_UNIT_ADDED", function(unit) if type(unit) == "string" then NoteTauren(unit) end end)

-- Moo Alarm: a random moo in group chat every so often (never in combat)
local nextAlarm
local ALARM_LINES = {
  "Moo.", "Just checking in. Moo.", "This is your scheduled moo.", "Moo (automated, but heartfelt).",
  "It has been %d minutes since the last scheduled moo. Moo.", "Reminder to stay hydrated. Moo.",
}
function ns:AlarmTick()
  if not Trigger("alarm") or not self:GroupChannel() or InCombatLockdown() then return end
  if ns.InMercy and ns:InMercy() then return end
  local now = ns.Now()
  local period = self.db.alarmMinutes * 60
  if not nextAlarm then nextAlarm = now + period * (0.6 + random() * 0.8) return end
  if now >= nextAlarm then
    nextAlarm = now + period * (0.6 + random() * 0.8)
    ToGroup(Pick(ALARM_LINES):format(self.db.alarmMinutes))
  end
end

table.insert(ns.tickFns, function() ns:AlarmTick() end)
-- backstop for deaths the game sent no event for (values that were hidden, then readable):
-- a full scan every 5 seconds, and only in a group
local deathScan = 0
table.insert(ns.tickFns, function()
  deathScan = deathScan + 1
  if deathScan < 5 then return end
  deathScan = 0
  if IsInGroup() or IsInRaid() then ns:CheckPartyDeaths() end
end)

---------------------------------------------------------------------------
-- Hear Moo: everyone else's chat looks like moo (your screen only)
---------------------------------------------------------------------------

local HEAR_EVENTS = {
  "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID",
  "CHAT_MSG_RAID_LEADER", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_CHANNEL",
  "CHAT_MSG_WHISPER", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
}
local function HearMooFilter(_, _, msg, author, ...)
  if not ns.db or not ns.db.effects.hearMoo or not Usable(msg) or type(msg) ~= "string" then return false end
  -- Moo Cipher lines keep their spelling (it IS the message), so they can still be decoded,
  -- and Hear Moo is for everyone else's chat, not yours (issue #13)
  if msg:find("MOO-CIPHER:", 1, true) then return false end
  if Usable(author) and type(author) == "string" and ns.ShortName(author) == UnitName("player") then return false end
  local translate = ns.DialectTranslate and function(t) return ns.DialectTranslate(ns.db.hearDialect or "classic", t) end
    or ns.MooTranslate
  return false, translate(msg), author, ...
end
local function InstallChatFilter()
  local add = ChatFrame_AddMessageEventFilter or (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter)
  if not add then return false end
  for _, e in ipairs(HEAR_EVENTS) do pcall(add, e, HearMooFilter) end
  return true
end
ns.HearMooFilter = HearMooFilter

-- The moo-chievements now live in the full achievement system (Ach/ and MooAch.lua).
function ns:CheckAchievements() self:StatChanged() end

---------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------

ns:On("PLAYER_LOGIN", function()
  ns:InitDB()
  InstallChatFilter()
  if ns.CreateVisuals then ns:CreateVisuals() end
  local ticker = CreateFrame("Frame")
  local acc = 0
  ticker:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 1 then return end
    acc = 0
    for _, fn in ipairs(ns.tickFns) do
      local ok, err = pcall(fn)
      if not ok then table.insert(ns.errors, "tick: " .. tostring(err)) end
    end
  end)
  ns:Print("Loaded. Click the cow, or type /moo barn for the Barn. /moo help for commands, /moo off to stop the automatic moos.")
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local function OnOff(v) return v and "|cff20ff20on|r" or "|cffff4040off|r" end

local HELP = {
  "|cffffd100Mooing|r  /moo  (every selected channel)  |  /moo <say|yell|party|guild|raid|e|trade|2> [text]",
  "|cffffd100Launch|r  /moo launch <channel> [count] [text]  e.g. /moo launch guild 5",
  "|cffffd100Mute|r  /moo mute <channel>  |  /moo unmute <channel>  |  /moo mutes   (a hard-muted channel can never be posted to)",
  "|cffffd100Speak|r  /moo t [dialect] <text>  |  /moo dialects  |  /moo cipher [channel] <secret>  |  /moo decode <line>  |  /moo morse <text>",
  "|cffffd100Games|r  /moo battle | trivia | vote <q> | sing | roulette | check | draw | hangman | scramble | math | story | theater | tip [name]",
  "|cffffd100Guild games|r  add \"guild\" to any game: /moo trivia guild  (or set the default in the Barn's Games tab)",
  "|cffffd100Barnyard|r  /moo barn  |  /moo bessie [feed|pet|brush|show|name <name>]  |  /moo farm  |  /moo buy <thing>  |  /moo quests",
  "|cffffd100Herd & more|r  /moo herd  |  /moo ach [post]  |  /moo fm  |  /moo horoscope [name]  |  /moo echo <name|off>  |  /moo shame [post]",
  "|cffffd100Moo Meter|r  /moo meter  |  /moo meter <damage|healing|taken|avoidable|interrupts|deaths|moos>  |  /moo meter overall  |  /moo meter post [mode] [overall]",
  "|cffffd100Bingo & Market|r  /moo bingo [new]  |  /moo market  |  /moo invest <MILK|HAY|KODO> <amount|max>  |  /moo sell <stock> <amount|all>",
  "|cffffd100Yo Moo-ma|r  /moo mom [name]  (friends saying \"your mom\" in chat get one too)",
  "|cffffd100Not reacting to someone?|r  /moo heard  (what happened to the last lines people typed, and why)",
  "|cffffd100Moo-litism & GTFO|r  /moo shame [post]  |  /moo moolitism [check]  |  /moo gtfo [on|off|test|<percent>]  |  /moo longmoo [channel]",
  "|cffffd100Raid boss|r  /moo boss [guild]  (friends say \"raid boss\")  |  |cffffd100Moo Pass|r  /moo pass  |  /moo title [name|none]  |  |cffffd100Wrapped|r  /moo wrapped [post]",
  "|cffffd100MooScape|r  /mooscape (or /moo quest): an RPG with five zones, eight skills, gear, quests and a boss",
  "|cffffd100Herd Keepers|r  /moo keepers  (others with the addon)  |  /moo duel <name>  (Cow Duel)",
  "|cffffd100Settings|r  /moo hear [dialect]  |  /moo cooldown <s>  |  /moo alarm <min>  |  /moo button  |  /moo stats",
  "|cffffd100Panic|r  /moo off  (stop all automatic moos)  |  /moo on",
}

local GAME_CMDS = {
  battle = function(rest) return ns:StartMooOff(rest) end, trivia = function(rest) return ns:StartTrivia(rest) end,
  vote = function(rest) return ns:StartVote(rest) end, sing = function(rest) return ns:Sing(rest) end,
  roulette = function() return ns:Roulette() end, check = function() return ns:StartMooCheck() end,
  draw = function() return ns:StartQuickDraw() end, hangman = function() return ns:StartHangman() end,
  scramble = function() return ns:StartScramble() end, math = function() return ns:StartMath() end,
  story = function() return ns:StartTales() end, tales = function() return ns:StartTales() end,
  theater = function() return ns:StartTheater() end, play = function() return ns:StartTheater() end,
  tip = function(rest) return ns:CowTip(rest ~= "" and rest or nil) end,
}

local function SplitFirst(text)
  local first, rest = (text or ""):match("^(%S*)%s*(.-)$")
  return first or "", rest or ""
end

local function Result(ok, message)
  if message then ns:Print(message) elseif not ok then ns:Print("That didn't work.") end
end

SLASH_MOOHELPER1 = "/moo"
SLASH_MOOHELPER2 = "/moohelper"
SlashCmdList.MOOHELPER = function(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
  cmd = (cmd or ""):lower()

  if cmd == "" then
    ns:Moo()

  elseif cmd == "launch" or cmd == "l" then
    local chanWord, after = SplitFirst(rest)
    local key = ns:ResolveChannel(chanWord)
    if not key then ns:Print("Usage: /moo launch <channel> [count] [text]   e.g. /moo launch party 5") return end
    local countWord, text = SplitFirst(after)
    local count = tonumber(countWord)
    if not count then text, count = after, 1 end
    if text == "" then text = nil else text = ns.MooTranslate(text) end
    Result(ns:Launch(key, count, text))

  elseif cmd == "mute" or cmd == "unmute" then
    local key = ns:ResolveChannel(rest) or (rest:lower():find("^w") and "WHISPER") or nil
    if not key then ns:Print("Usage: /moo " .. cmd .. " <say|yell|emote|party|raid|instance|guild|officer|whisper|trade|...>") return end
    ns:SetMuted(key, cmd == "mute")
    ns:Print(("%s is now %s."):format(ns:ChannelLabel(key),
      cmd == "mute" and "|cffff4040HARD MUTED|r: nothing from MooHelper can be posted there" or "|cff20ff20unmuted|r"))
    if ns.RefreshBarn then ns:RefreshBarn() end

  elseif cmd == "mutes" then
    local list = {}
    for k, v in pairs(ns.db.muted) do if v == true then list[#list + 1] = ns:ChannelLabel(k) end end
    table.sort(list)
    ns:Print(#list > 0 and ("Hard muted: " .. table.concat(list, ", ")) or "No channels are hard muted.")

  elseif cmd == "t" or cmd == "translate" then
    local first, after = SplitFirst(rest)
    local dialect = ns.DIALECT_BY_KEY and ns.DIALECT_BY_KEY[first:lower()] and first:lower()
    local text = dialect and after or rest
    if text == "" then ns:Print("Usage: /moo t [dialect] <text>   (/moo dialects to list them)") return end
    ns:SendNow("SAY", ns:Speak(dialect or "classic", text))

  elseif cmd == "dialects" then
    for _, d in ipairs(ns.DIALECTS) do ns:Print(("  %s - %s  (e.g. \"%s\")"):format(d.key, d.name, d.sample)) end

  elseif cmd == "cipher" then
    local first, after = SplitFirst(rest)
    local key = ns:ResolveChannel(first)
    local text = key and after or rest
    local line = ns.CipherEncode(text)
    if not line then ns:Print(("Usage: /moo cipher [channel] <secret>  (up to %d letters)"):format(ns.CIPHER_MAX)) return end
    if ns:SendNow(key or "SAY", line) then ns:Bump("cipherEncoded") end

  elseif cmd == "decode" then
    local secret = ns.CipherDecode(rest)
    ns:Print(secret and ("Decoded: " .. secret) or "That isn't a Moo Cipher line.")

  elseif cmd == "morse" then
    if rest == "" then ns:Print("Usage: /moo morse <text> (short words work best)") return end
    ns:SendNow("SAY", ns.MooMorse(rest))

  elseif GAME_CMDS[cmd] then
    -- "/moo trivia guild" or "/moo guild trivia"-style: pick the chat for this one game
    local SCOPES = { guild = "guild", g = "guild", party = "group", group = "group", raid = "group", p = "group" }
    local first, after = SplitFirst(rest)
    local last = rest:match("(%S+)%s*$")
    if SCOPES[first:lower()] then
      ns.startScope, rest = SCOPES[first:lower()], after
    elseif cmd ~= "vote" and cmd ~= "tip" and last and SCOPES[last:lower()] then
      ns.startScope, rest = SCOPES[last:lower()], rest:gsub("%s*%S+%s*$", "")
    end
    local ok, why = GAME_CMDS[cmd](rest)
    ns.startScope = nil
    if not ok and why then ns:Print(why) end

  elseif cmd == "fm" or cmd == "radio" then
    local ok, why = ns:MooFM()
    if not ok then ns:Print(why) end

  elseif cmd == "horoscope" then
    local line = ns:Horoscope(rest ~= "" and rest or nil)
    if ns:GroupChannel() then ns:SendNow(ns:GroupChannel(), line) else ns:Print(line) end

  elseif cmd == "bessie" or cmd == "cow" then
    local action, arg = SplitFirst(rest)
    action = action:lower()
    if action == "feed" then Result(ns:BessieFeed())
    elseif action == "pet" then Result(ns:BessiePet())
    elseif action == "brush" then Result(ns:BessieBrush())
    elseif action == "show" then Result(ns:BessieShowOff())
    elseif action == "name" then Result(ns:BessieRename(arg))
    else
      local b = ns.db.bessie
      local _, mood = ns:BessieMood()
      ns:Print(("%s the %s: %d xp, hunger %d, happiness %d, energy %d. She %s"):format(b.name, ns:BessieStageName(),
        b.xp, b.hunger, b.happiness, b.energy, mood))
      if ns.OpenBarn then ns:OpenBarn("bessie") end
    end

  elseif cmd == "farm" or cmd == "shop" then
    ns:Print(("Milk: %s (%.1f a second)."):format(ns.FormatNumber(ns:Milk()), ns:MilkPerSecond()))
    if ns.OpenBarn then ns:OpenBarn("farm") end

  elseif cmd == "buy" then
    local key = rest:lower()
    if ns.GEN_BY_KEY[key] then Result(ns:BuyGenerator(key))
    elseif ns.UPG_BY_KEY[key] then Result(ns:BuyUpgrade(key))
    else
      local names = {}
      for _, g in ipairs(ns.GENERATORS) do names[#names + 1] = g.key end
      for _, u in ipairs(ns.UPGRADES) do names[#names + 1] = u.key end
      ns:Print("Buy what? " .. table.concat(names, ", "))
    end

  elseif cmd == "golden" then
    if ns:SpendMilk(1000) then ns:SpawnGoldenMoo() ns:Print("You summoned a Golden Moo (1,000 milk). Catch it!")
    else ns:Print("Summoning a Golden Moo costs 1,000 milk.") end

  elseif cmd == "quests" then
    for _, entry in ipairs(ns:QuestsForToday()) do
      local cur, goal, def = ns:QuestProgress(entry)
      if def then ns:Print(("  %s %s: %d/%d (+%d milk)"):format(entry.done and "|cff20ff20[done]|r" or "[ ]", def.text, cur, goal, def.reward)) end
    end

  elseif cmd == "herd" then
    local top = ns:HerdTop(5)
    if #top == 0 then ns:Print("Your herd is empty. Friends join by mooing, playing games and answering interviews.") end
    for i, e in ipairs(top) do ns:Print(("  %d. %s - %s (%d herd points)"):format(i, e.name, ns:HerdRankName(e.name), e.points)) end
    ns:Print(("Tauren census: %d spotted."):format(ns.db.stats.taurenCount))

  elseif cmd == "ach" or cmd == "achievements" then
    if rest == "post" and ns.Ach.char then
      local done, total, points = ns.Ach:GetSummary()
      local ch = ns:GroupChannel()
      if ch then ns:SendNow(ch, ("Moo-chievements: %d of %d earned, %d points. Moo."):format(done, total, points)) end
    elseif ns.OpenBarn then ns:OpenBarn("ach") end

  elseif cmd == "meter" or cmd == "dps" then
    local sub, after = SplitFirst(rest)
    sub = sub:lower()
    if sub == "post" then
      local mode, which = SplitFirst(after)
      local ok, why = ns:PostMeter(mode ~= "" and mode:lower() or nil, which:lower() == "overall" and "overall" or "last")
      if not ok and why then ns:Print(why) end
    elseif sub == "overall" or sub == "fight" or sub == "last" then
      ns:SetMeterView(nil, sub == "overall" and "overall" or "last")
      ns:ToggleMeter(true)
    elseif sub ~= "" then
      ns:SetMeterView(sub, nil)
      ns:ToggleMeter(true)
    else
      ns:ToggleMeter()
    end

  elseif cmd == "duel" then
    Result(ns:ChallengeDuel(rest))

  elseif cmd == "keepers" then
    local n = 0
    for name, p in pairs(ns.peers) do
      n = n + 1
      ns:Print(("  %s (v%s)%s"):format(name, p.version or "?", p.cow and (": cow " .. p.cow.name) or ""))
    end
    if n == 0 then ns:Print("No other Moolitism Helper users seen in your group or guild yet.") end

  elseif cmd == "boss" or cmd == "raid" then
    local scopeWord = rest:lower()
    if scopeWord == "guild" or scopeWord == "party" or scopeWord == "group" then
      ns.startScope = scopeWord == "guild" and "guild" or "group"
    end
    local ok, why = ns:StartBoss()
    ns.startScope = nil
    Result(ok, why)

  elseif cmd == "mom" or cmd == "yomama" then
    -- a Yo Moo-ma joke to your group (a slash command, so it's your own choice to send it)
    local ch = ns:GroupChannel() or (IsInGuild() and "GUILD") or nil
    if not ch then ns:Print(ns:MomJoke(rest ~= "" and rest or nil)) return end
    if not ns:SendNow(ch, ns:MomJoke(rest ~= "" and rest or nil)) then ns:Print(ns:ChannelLabel(ch) .. " is HARD MUTED.") end

  elseif cmd == "mooscape" or cmd == "quest" or cmd == "pasture" or cmd == "rpg" then
    if ns.RPG then ns.RPG:Toggle() end

  elseif cmd == "pass" then
    local p = ns.db.pass
    local xp, need = ns:PassProgress()
    ns:Print(("%s: tier %d of %d (%d/%d xp to the next), %d days left."):format(ns:PassSeasonName(), p.tier,
      ns.PASS_TIERS, xp, need, ns:PassDaysLeft()))
    if ns.OpenBarn then ns:OpenBarn("pass") end

  elseif cmd == "title" then
    if rest == "" then
      local list = ns:TitleList()
      ns:Print(#list > 0 and ("Your titles: " .. table.concat(list, ", ") .. ". /moo title <name> to wear one, /moo title none to remove.")
        or "No titles yet. Every 5 Moo Pass tiers unlocks one.")
    else
      Result(ns:SetTitle(rest))
    end

  elseif cmd == "wrapped" then
    if rest:lower() == "post" then
      local ok, why = ns:PostWrapped()
      if not ok then ns:Print(why) end
    else
      for _, line in ipairs(ns:WrappedLines()) do ns:Print(line) end
      if ns.OpenBarn then ns:OpenBarn("wrapped") end
    end

  elseif cmd == "bingo" then
    if rest:lower() == "new" then ns:NewBingoCard() ns:Print("Fresh Moo Bingo card. Good luck.") end
    if ns.OpenBarn then ns:OpenBarn("bingo") end

  elseif cmd == "market" or cmd == "stocks" then
    for _, s in ipairs(ns.STOCKS) do
      ns:Print(("  %s %s: %.2f milk (you own %d)"):format(s.key, s.name, ns:StockPrice(s.key), ns.db.market.shares[s.key]))
    end
    if ns.OpenBarn then ns:OpenBarn("market") end

  elseif cmd == "invest" or cmd == "sell" then
    local ticker, qty = SplitFirst(rest)
    qty = qty:lower()
    if qty == "" then qty = "1" end
    if cmd == "invest" then Result(ns:BuyStock(ticker:upper(), qty == "max" and "max" or qty))
    else Result(ns:SellStock(ticker:upper(), (qty == "all" or qty == "max") and "all" or qty)) end

  elseif cmd == "barn" or cmd == "options" or cmd == "config" then
    if ns.ToggleBarn then ns:ToggleBarn() end

  elseif cmd == "echo" then
    local _, msg2 = ns:StartEcho(rest)
    ns:Print(msg2)
  elseif cmd == "forecast" then
    ns.char.lastForecast = nil
    if not ns:Forecast() then ns:Print("No forecast: you need a guild (and the forecast turned on).") end
  elseif cmd == "cooldown" then
    local n = tonumber(rest)
    if not n then ns:Print(("Public channel cooldown is %ds. /moo cooldown <seconds> (1 or more)."):format(ns.db.publicCooldown)) return end
    ns.db.publicCooldown = math.max(1, math.floor(n))
    ns:Print(("Public channels now moo at most every %ds."):format(ns.db.publicCooldown))
  elseif cmd == "alarm" then
    local n = tonumber(rest)
    if not n then ns:Print(("Moo Alarm goes off roughly every %d minutes. /moo alarm <minutes> (1 or more)."):format(ns.db.alarmMinutes)) return end
    ns.db.alarmMinutes = math.max(1, math.floor(n))
    ns:Print(("Moo Alarm set to roughly every %d minutes."):format(ns.db.alarmMinutes))
  elseif cmd == "hear" then
    if ns.DIALECT_BY_KEY and ns.DIALECT_BY_KEY[rest:lower()] then
      ns.db.hearDialect = rest:lower()
      ns.db.effects.hearMoo = true
    else
      ns.db.effects.hearMoo = not ns.db.effects.hearMoo
    end
    ns:Print(("Hear Moo %s (%s)."):format(OnOff(ns.db.effects.hearMoo), ns.db.hearDialect or "classic"))
  elseif cmd == "off" then
    ns:SetPanic(true)
    ns:Print("All automatic moos " .. OnOff(false) .. ". The button, /moo and /moo launch still work. /moo on to resume.")
  elseif cmd == "on" then
    ns:SetPanic(false)
    ns:Print("Automatic moos " .. OnOff(true) .. ". You were warned.")
  elseif cmd == "heard" then
    -- what the addon did with the last lines other people typed (and why it ignored any)
    local lines = ns:HeardLines(tonumber(rest) or 10)
    if #lines == 0 then ns:Print("Nobody else has said anything in party, raid or guild chat yet.") end
    ns:Print("Last lines from other people, and what MooHelper did:")
    for _, line in ipairs(lines) do ns:Print("  " .. line) end

  elseif cmd == "moolitism" or cmd == "elitism" then
    for _, line in ipairs(ns:ShameStatus()) do ns:Print(line) end
    if rest:lower() == "check" then ns:ShameCheck() ns:Print("Checking the damage meter now...") end

  elseif cmd == "gtfo" then
    local g, arg = ns.db.gtfo, rest:lower()
    if arg == "on" or arg == "off" then g.enabled = arg == "on"
    elseif arg == "sound" then g.sound = not g.sound
    elseif arg == "flash" then g.flash = not g.flash
    elseif arg == "test" then ns:GTFOAlarm("test")
    elseif tonumber(arg) then g.threshold = math.max(5, math.min(tonumber(arg), 80))
    end
    ns:Print(("Moo GTFO is %s: alarm when you lose %d%% health in a second, sound %s, flash %s, party callouts %s%s.")
      :format(g.enabled and "ON" or "OFF", g.threshold, g.sound and "on" or "off", g.flash and "on" or "off",
        ns.db.triggers.gtfoCallout and "on" or "off", ns:RealGTFOHooked() and ", hooked into the GTFO addon" or ""))
    if arg == "" then ns:Print("/moo gtfo on|off|test|sound|flash|<percent>") end

  elseif cmd == "longmoo" then
    -- the longest moo chat allows (GitHub issue #4: "all moos aren't long enough")
    local key
    if rest ~= "" then key = ns:ResolveChannel(rest) else key = ns:GroupChannel() or "SAY" end
    if not key then ns:Print(("Unknown channel \"%s\". /moo longmoo <party|say|guild|2|...>"):format(ns.Clean(rest))) return end
    local line = "M" .. string.rep("O", 250) .. "!!!!"
    if ns:SendNow(key, line) then ns:Bump("longMoos") else ns:Print(ns:ChannelLabel(key) .. " is HARD MUTED (or not available).") end

  elseif cmd == "shame" then
    if ns.ShowShame then ns:ShowShame(rest == "post") end
  elseif cmd == "stats" then
    local s = ns.db.stats
    local done, total, points = 0, 0, 0
    if ns.Ach.char then done, total, points = ns.Ach:GetSummary() end
    ns:Print(("Total moos: %d  |  Rank: %s  |  Best combo: %d  |  Milk: %s  |  Moo-chievements: %d/%d (%d points)")
      :format(s.total, ns:RankName(), s.bestCombo, ns.FormatNumber(ns:Milk()), done, total, points))
    local keys = {}
    for k in pairs(s.byChannel) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return s.byChannel[a] > s.byChannel[b] end)
    for _, k in ipairs(keys) do ns:Print(("  %s: %d"):format((k:gsub("^CH:", "")), s.byChannel[k])) end
  elseif cmd == "button" then
    ns.db.hideButton = not ns.db.hideButton
    if ns.UpdateButton then ns:UpdateButton() end
    ns:Print("Moo button " .. OnOff(not ns.db.hideButton))

  else
    -- "/moo party", "/moo trade hello", "/moo 2"...: one moo (or your text, in moo) there
    local key = ns:ResolveChannel(cmd)
    if key then
      if not ns:ChannelAvailable(key) then ns:Print(ns:ChannelLabel(key) .. " isn't available right now.") return end
      if ns:IsMuted(key) then ns:Print(ns:ChannelLabel(key) .. " is HARD MUTED.") return end
      local combo = ns:BumpCombo()
      local text = rest ~= "" and ns.MooTranslate(rest) or (key == "EMOTE" and ns.EmoteText(combo) or ns.MooText(combo))
      ns:SendNow(key, text)
      if ns.ShowCombo then ns:ShowCombo(combo) end
    else
      for _, line in ipairs(HELP) do ns:Print(line) end
    end
  end
end
