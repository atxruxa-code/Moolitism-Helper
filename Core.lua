-- MooHelper: core
-- Settings, the event bus, channel discovery, and the two ways a moo leaves your keyboard:
--   * SendNow  - immediately, used only from a click, key press or slash command
--   * Queue    - automatic moos (deaths, loot, moo-backs...), rate limited
--
-- WoW only lets addons talk in Say, Yell and numbered channels (General, Trade, LFG...)
-- during a hardware event (a click or key press). Calling them from anything automatic
-- gets the addon blocked, so automatic moos never use those channels.

local _, ns = ...

ns.version = "1.0.0"
ns.errors = {}

local IsSecret = issecretvalue or function() return false end
function ns.Usable(v) return v ~= nil and not IsSecret(v) end
function ns.Now() return GetTime() end

function ns:Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffd9b26fMooHelper:|r " .. tostring(msg))
end

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------

local DEFAULTS = {
  -- where the Moo button / keybind / "/moo" sends
  channels = { SAY = true, YELL = false, EMOTE = false, PARTY = true, RAID = true,
    INSTANCE_CHAT = true, GUILD = false, OFFICER = false },
  -- automatic moos
  triggers = { death = true, partyDeath = true, levelUp = true, epicLoot = true, bossKill = true,
    readyCheck = true, hearth = true, mooBack = true, autoReply = true, taurenTarget = true,
    alarm = true, shame = true,
    -- talking with people
    interactions = true, interviews = true, mooCheck = true,
    -- extra annoyance
    mooClock = true, clockGuild = true, afkStalk = true, guildWelcome = true, rankUp = true,
    rollComment = true, mountMoo = true, jumpMoo = true, countdown = true, forecast = true,
    -- the barnyard
    herdPromotions = true, bessieTalk = true, mooFM = true, events = true, goldenMoo = true,
    guildGames = true,        -- guildmates can start and play games (and chat with the herd) in guild chat
    cowDuels = true,          -- accept Cow Duels from friends who also run the addon
    bingoAnnounce = true,     -- announce BINGO in group chat
    meterAutoPost = false },  -- post the Moo Meter to group after each boss kill
  gameScope = "group",        -- where games you start run: "group" or "guild"
  interviewMinutes = 6,   -- how often the herd interviews a random party member
  mooCheckMinutes = 12,   -- how often everyone must prove they can moo
  effects = { combo = true, cowRain = true, hearMoo = false, stampede = true, mooVision = true },
  style = "escalate",     -- "escalate" (faster clicking = longer moos), "classic", "chaos"
  alarmMinutes = 5,       -- random group moo roughly this often
  publicCooldown = 5,     -- seconds between moos in each numbered channel (General, Trade...)
  shameMinDamage = 1,     -- ignore avoidable hits smaller than this
  shameMaxLines = 3,      -- most offenders named per fight
  panic = false,          -- /moo off: no automatic moos at all
  -- HARD MUTE: nothing from MooHelper can ever be sent to these channels, no matter
  -- which feature asks (button, games, clock, welcomes, achievements, replies...).
  -- Keys: SAY YELL EMOTE PARTY RAID INSTANCE_CHAT GUILD OFFICER WHISPER, or "CH:<name>".
  muted = { OFFICER = true },
  achAnnounce = true,     -- announce earned achievements in group chat
  achAnnounceGuild = false,
  buttonScale = 1,
  hideButton = false,
  stats = {},
}

local function Merge(t, d)
  for k, v in pairs(d) do
    if t[k] == nil then
      if type(v) == "table" then t[k] = {} Merge(t[k], v) else t[k] = v end
    elseif type(v) == "table" and type(t[k]) == "table" then
      Merge(t[k], v)
    end
  end
end

function ns:InitDB()
  MooHelperDB = MooHelperDB or {}
  self.db = MooHelperDB
  Merge(self.db, DEFAULTS)
  local s = self.db.stats
  s.total = s.total or 0
  s.byChannel = s.byChannel or {}
  s.bestCombo = s.bestCombo or 0
  s.taurens = s.taurens or {}
  s.taurenCount = s.taurenCount or 0
  s.mooBacks = s.mooBacks or 0
  s.autoReplies = s.autoReplies or 0
  s.shame = s.shame or {}
  s.achievements = s.achievements or {}
  s.mooOffWins = s.mooOffWins or {}
  s.triviaPoints = s.triviaPoints or {}
  s.jumps = s.jumps or 0
  s.welcomes = s.welcomes or 0
  s.afkMoos = s.afkMoos or 0
  s.c = s.c or {}            -- general counters every feature reports into (see Bump)
  s.launchSet = s.launchSet or {}
  MooHelperCharDB = MooHelperCharDB or {}
  self.char = MooHelperCharDB
end

-- General counters: games hosted, interviews answered, Bessie feedings, milk earned...
-- Moo-chievements and daily quests read these.
function ns:Bump(key, n)
  if not self.db then return end
  local c = self.db.stats.c
  c[key] = (c[key] or 0) + (n or 1)
  for _, fn in ipairs(ns.bumpListeners) do
    local ok, err = pcall(fn, key, n or 1)
    if not ok then table.insert(ns.errors, "bump listener: " .. tostring(err)) end
  end
  self:StatChanged()
end

function ns:StatMax(key, value)
  if not self.db or type(value) ~= "number" then return end
  local c = self.db.stats.c
  if value > (c[key] or 0) then
    c[key] = value
    self:StatChanged()
  end
end

function ns:GetStat(key)
  return self.db and self.db.stats.c[key] or 0
end

---------------------------------------------------------------------------
-- Event bus
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local handlers = {}
eventFrame:SetScript("OnEvent", function(_, event, ...)
  local list = handlers[event]
  if not list or (not ns.db and event ~= "PLAYER_LOGIN") then return end
  for _, fn in ipairs(list) do
    local ok, err = pcall(fn, ...)
    if not ok then
      table.insert(ns.errors, event .. ": " .. tostring(err))
      if ns.debug then ns:Print("error in " .. event .. ": " .. tostring(err)) end
    end
  end
end)

function ns:On(event, fn)
  if not handlers[event] then
    if not pcall(eventFrame.RegisterEvent, eventFrame, event) then return false end
    handlers[event] = {}
  end
  table.insert(handlers[event], fn)
  return true
end

---------------------------------------------------------------------------
-- Text safety
---------------------------------------------------------------------------

-- One chat message is at most 255 bytes; never cut a UTF-8 character in half.
function ns.Fit(text)
  text = tostring(text or "")
  if #text <= 255 then return text end
  local cut = 252
  while cut > 1 and text:byte(cut + 1) and text:byte(cut + 1) >= 0x80 and text:byte(cut + 1) < 0xC0 do
    cut = cut - 1
  end
  return text:sub(1, cut) .. "..."
end

-- Names and spell names from the game never carry escape codes into our messages.
function ns.Clean(s)
  return (tostring(s or ""):gsub("|", ""):gsub("%c", ""))
end

function ns.ShortName(name)
  name = tostring(name or "")
  return (name:match("^([^%-]+)")) or name
end

---------------------------------------------------------------------------
-- Channels
---------------------------------------------------------------------------

ns.FIXED_CHANNELS = {
  { key = "SAY", label = "Say", protected = true },
  { key = "YELL", label = "Yell", protected = true },
  { key = "EMOTE", label = "Emote" },
  { key = "PARTY", label = "Party" },
  { key = "RAID", label = "Raid" },
  { key = "INSTANCE_CHAT", label = "Instance" },
  { key = "GUILD", label = "Guild" },
  { key = "OFFICER", label = "Officer" },
}

-- Numbered channels you've joined (General, Trade, LookingForGroup...), as "CH:<name>".
function ns:JoinedChannels()
  local list = {}
  if not GetChannelList then return list end
  local values = { GetChannelList() }
  for i = 1, #values do
    local id, name = values[i], values[i + 1]
    if type(id) == "number" and type(name) == "string" and ns.Usable(name) then
      list[#list + 1] = { key = "CH:" .. name, label = name, protected = true, id = id }
    end
  end
  return list
end

function ns.IsProtected(key)
  return key == "SAY" or key == "YELL" or key:sub(1, 3) == "CH:"
end

-- Automatic moos also stay out of Emote: it isn't on Blizzard's protected list as far as
-- we know, but a blocked call shows an error popup, so it isn't worth the risk.
function ns.AutoAllowed(key)
  return not ns.IsProtected(key) and key ~= "EMOTE"
end

-- Functions run once a second (alarms, clocks, stalkers...). Modules add to this list.
ns.tickFns = {}

-- Is this channel usable right now?
function ns:ChannelAvailable(key)
  if key == "PARTY" then return IsInGroup(LE_PARTY_CATEGORY_HOME) and not IsInRaid() end
  if key == "RAID" then return IsInRaid() end
  if key == "INSTANCE_CHAT" then
    return LE_PARTY_CATEGORY_INSTANCE ~= nil and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) == true
  end
  if key == "GUILD" or key == "OFFICER" then return IsInGuild() end
  if key:sub(1, 3) == "CH:" then
    local id = GetChannelName(key:sub(4))
    return type(id) == "number" and id > 0
  end
  return true -- SAY, YELL, EMOTE
end

-- The channel your group talks in, or nil when solo.
function ns:GroupChannel()
  if IsInRaid() then return "RAID" end
  if LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
     and not IsInGroup(LE_PARTY_CATEGORY_HOME) then
    return "INSTANCE_CHAT"
  end
  if IsInGroup() then return "PARTY" end
  return nil
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------

local function RawSend(text, chatType, target)
  local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
  if not send then return false end
  local ok = pcall(send, text, chatType, nil, target)
  return ok
end

-- Anything that changes stats calls this, so achievements re-check themselves.
function ns:StatChanged()
  if ns.Ach and ns.Ach.RequestEvaluate then ns.Ach:RequestEvaluate() end
end

local function Count(key)
  local s = ns.db.stats
  s.total = s.total + 1
  s.byChannel[key] = (s.byChannel[key] or 0) + 1
  for _, fn in ipairs(ns.mooListeners) do
    local ok, err = pcall(fn, key)
    if not ok then table.insert(ns.errors, "moo listener: " .. tostring(err)) end
  end
  if ns.CheckRank then ns:CheckRank() end
  ns:StatChanged()
end

-- Modules add functions here to hear about every moo sent: fn(channelKey)
ns.mooListeners = {}
-- ...every counter bump: fn(key, amount)
ns.bumpListeners = {}
-- ...every achievement earned: fn(achievement)
ns.achListeners = {}

-- Named moments other modules can react to: ns:Signal("friendDeath", "Bob")
ns.signalListeners = {}
function ns:OnSignal(name, fn)
  self.signalListeners[name] = self.signalListeners[name] or {}
  table.insert(self.signalListeners[name], fn)
end
function ns:Signal(name, ...)
  for _, fn in ipairs(self.signalListeners[name] or {}) do
    local ok, err = pcall(fn, ...)
    if not ok then table.insert(ns.errors, "signal " .. name .. ": " .. tostring(err)) end
  end
end

---------------------------------------------------------------------------
-- HARD MUTE
---------------------------------------------------------------------------
-- Every message MooHelper sends goes through SendNow, and SendNow refuses muted channels.
-- There is no other code path to the game's chat, so a muted channel cannot be posted to.

function ns.MuteKey(key)
  if type(key) ~= "string" then return "?" end
  if key:sub(1, 2) == "W:" then return "WHISPER" end
  return key
end

function ns:IsMuted(key)
  return self.db ~= nil and self.db.muted[ns.MuteKey(key)] == true
end

function ns:SetMuted(key, muted)
  self.db.muted[ns.MuteKey(key)] = muted and true or nil
  if muted then
    -- also drop anything already waiting for that channel
    if self.DropQueued then self:DropQueued(key) end
  end
end

ns.blockedByMute = 0

-- Send right now. Only call from a click, key press or slash command when the channel
-- is protected (Say, Yell, numbered channels).
function ns:SendNow(key, text)
  if type(key) ~= "string" or self:IsMuted(key) then
    ns.blockedByMute = ns.blockedByMute + 1
    return false
  end
  text = ns.Fit(text)
  -- tell other copies of the addon "this line is mine", so they never answer it (no moo loops)
  if self.MarkOutgoing then self:MarkOutgoing(key, text) end
  if key:sub(1, 3) == "CH:" then
    local id = GetChannelName(key:sub(4))
    if type(id) ~= "number" or id == 0 then return false end
    if not RawSend(text, "CHANNEL", id) then return false end
  elseif key:sub(1, 2) == "W:" then
    if not RawSend(text, "WHISPER", key:sub(3)) then return false end
  else
    if not RawSend(text, key) then return false end
  end
  -- remember what we said, so our own lines echoing back in party chat aren't mistaken
  -- for a player's answer, vote or moo
  ns.recentOutputs[text] = ns.Now()
  Count(key:sub(1, 2) == "W:" and "WHISPER" or key)
  return true
end

ns.recentOutputs = {}
function ns:IsOwnOutput(text)
  local t = ns.recentOutputs[text]
  return t ~= nil and ns.Now() - t < 120
end

-- Automatic moos wait here: at least 1 s apart, at most 30 a minute, dropped when stale.
-- (The 1 s gap is what keeps the server from kicking you for chat flooding.)
-- Higher priority goes first: 3 = party games, 2 = normal, 1 = filler (alarms, jumps).
local MIN_GAP, PER_MINUTE, MAX_AGE = 1, 30, 45
local queue, sentTimes, lastSent = {}, {}, -1000

local function Locked()
  if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
    local ok, locked = pcall(C_ChatInfo.InChatMessagingLockdown)
    if ok and locked == true then return true end
  end
  return false
end

function ns:Queue(key, text, priority, maxAge)
  if not key or self.db.panic then return false end
  if not ns.AutoAllowed(key) then return false end -- never automatic in Say/Yell/Emote/numbered channels
  if self:IsMuted(key) then ns.blockedByMute = ns.blockedByMute + 1 return false end
  table.insert(queue, { key = key, text = text, created = ns.Now(), priority = priority or 2, maxAge = maxAge or MAX_AGE })
  return true
end

function ns:QueueSize() return #queue end

function ns:FlushQueue()
  local now = ns.Now()
  for i = #queue, 1, -1 do
    if now - queue[i].created > queue[i].maxAge then table.remove(queue, i) end
  end
  if #queue == 0 or Locked() then return end
  if now - lastSent < MIN_GAP then return end
  for i = #sentTimes, 1, -1 do
    if now - sentTimes[i] > 60 then table.remove(sentTimes, i) end
  end
  if #sentTimes >= PER_MINUTE then return end
  -- highest priority first, oldest first within a priority; while /moo off is on, only
  -- your own launched barrages go out
  local best
  for i = 1, #queue do
    local a = queue[i]
    if a.manual or not self.db.panic then
      local b = best and queue[best]
      if not b or a.priority > b.priority or (a.priority == b.priority and a.created < b.created) then best = i end
    end
  end
  if not best then return end
  local item = queue[best]
  if self:IsMuted(item.key) or (item.key:sub(1, 2) ~= "W:" and not self:ChannelAvailable(item.key)) then
    table.remove(queue, best) -- muted since it was queued, or e.g. left the party
    return
  end
  if self:SendNow(item.key, item.text) then
    table.remove(queue, best)
    lastSent = now
    table.insert(sentTimes, now)
  end
end

-- Drop everything queued (used when a party game is cancelled).
function ns:ClearQueue() wipe(queue) end

-- Drop everything queued for one channel (used when it gets muted).
function ns:DropQueued(key)
  local mk = ns.MuteKey(key)
  for i = #queue, 1, -1 do
    if ns.MuteKey(queue[i].key) == mk then table.remove(queue, i) end
  end
end

---------------------------------------------------------------------------
-- Launching moos on command
---------------------------------------------------------------------------

-- words people type -> channel keys
ns.CHANNEL_WORDS = {
  s = "SAY", say = "SAY", y = "YELL", yell = "YELL", e = "EMOTE", emote = "EMOTE", me = "EMOTE",
  p = "PARTY", party = "PARTY", r = "RAID", raid = "RAID", i = "INSTANCE_CHAT", instance = "INSTANCE_CHAT",
  bg = "INSTANCE_CHAT", g = "GUILD", guild = "GUILD", o = "OFFICER", officer = "OFFICER",
}

-- "party", "trade", "2", "General" -> a channel key (nil if unknown or not joined)
function ns:ResolveChannel(word)
  if type(word) ~= "string" or word == "" then return nil end
  local key = ns.CHANNEL_WORDS[word:lower()]
  if key then return key end
  local num = tonumber(word)
  if num then
    local _, name = GetChannelName(num)
    if ns.Usable(name) and type(name) == "string" and name ~= "" then return "CH:" .. name end
    return nil
  end
  for _, c in ipairs(self:JoinedChannels()) do
    if c.label:lower() == word:lower() or c.label:lower():find("^" .. word:lower():gsub("%p", "%%%0")) then
      return c.key
    end
  end
  return nil
end

function ns:ChannelLabel(key)
  if key:sub(1, 3) == "CH:" then return key:sub(4) end
  if key:sub(1, 2) == "W:" or key == "WHISPER" then return "Whispers" end
  for _, c in ipairs(ns.FIXED_CHANNELS) do if c.key == key then return c.label end end
  return key
end

-- Fire `count` moos into one channel. Must come from a click, key press or slash command.
-- Say/Yell/numbered channels can only take what one key press allows, so they get up to 3
-- at once; other channels get the whole barrage, one per second.
function ns:Launch(key, count, text)
  count = math.max(1, math.min(tonumber(count) or 1, 20))
  if self:IsMuted(key) then return false, ("%s is HARD MUTED. Unmute it in the Barn's Channels tab first."):format(self:ChannelLabel(key)) end
  if not self:ChannelAvailable(key) then return false, ("%s isn't available right now."):format(self:ChannelLabel(key)) end
  local sent, queued = 0, 0
  for i = 1, count do
    local combo = self.BumpCombo and self:BumpCombo() or i
    local line = text or (key == "EMOTE" and ns.EmoteText(combo) or ns.MooText(combo))
    if i == 1 or (ns.IsProtected(key) or key == "EMOTE") then
      if i > 3 then break end
      if self:SendNow(key, line) then sent = sent + 1 end
    else
      -- the rest of a barrage queues; it's yours, so /moo off (automatic moos) doesn't stop it,
      -- but a hard mute still does
      table.insert(queue, { key = key, text = line, created = ns.Now(), priority = 3, maxAge = 60, manual = true })
      queued = queued + 1
    end
  end
  if self.ShowCombo then self:ShowCombo(self.combo or count) end
  if sent + queued >= 5 then self:Bump("barrages") end
  local set = self.db.stats.launchSet
  if not set[key] then
    set[key] = true
    self:Bump("launchChannels")
  end
  return true, ("Launched %d moo%s into %s%s."):format(sent + queued, sent + queued == 1 and "" or "s",
    self:ChannelLabel(key), queued > 0 and " (the rest follow one a second)" or "")
end

local flusher = CreateFrame("Frame")
local acc = 0
flusher:SetScript("OnUpdate", function(_, elapsed)
  acc = acc + elapsed
  if acc < 0.5 or not ns.db then return end
  acc = 0
  local ok, err = pcall(ns.FlushQueue, ns)
  if not ok then table.insert(ns.errors, "flush: " .. tostring(err)) end
end)
