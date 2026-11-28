-- MooHelper: other copies of the addon (Herd Keepers), the loop fix, and Cow Duels
--
-- Copies talk over hidden addon messages (prefix MOOH1), which never show in chat:
--   HI~version~cow~xp~stage~happiness    "I run Moolitism Helper too" (sent to group/guild)
--   SAID~hash                            sent right before each line we post in party/raid/
--                                        guild/whisper: "that line is from my addon"
--   DUEL~id~cow~xp~stage~happiness       a Cow Duel challenge (whisper)
--   DUELOK~id~cow~xp~stage~happiness     accepted; both copies compute the same fight
--   QUIET~seconds                        I'm hosting a moo-counting game: hold your moo-backs
--   MERCY~seconds                        someone begged and my cow granted mercy: all go quiet
--   HOST~scope~id                        "I'm doing this one" (a game someone asked for, a roll
--                                        comment, a welcome): the other copies stand down
--
-- Loop fix: a line another copy marked as its own is never answered, counted or mooed back.
-- Lines people actually type still are, so two players with the addon can play games together.
-- Backstop: never auto-reply to one person more than 8 times a minute.

local _, ns = ...

local Usable = ns.Usable
local random = math.random
local PREFIX = "MOOH1"
local SEP = "~"
local MARK_TTL = 30        -- seconds a SAID mark is remembered
local WAIT_FOR_MARK = 0.8  -- how long to wait for a mark that might arrive after the chat line

ns.peers = {}              -- short name -> { full, version, seen, cow = {...} }
local foreign = {}         -- line hash -> time another copy said it was theirs

local function Hash(text)
  local h = 5381
  for i = 1, #text do h = (h * 33 + text:byte(i)) % 4294967296 end
  return string.format("%x", h)
end
ns.LineHash = Hash

local function SendAddon(msg, channel, target)
  local send = C_ChatInfo and C_ChatInfo.SendAddonMessage or SendAddonMessage
  if not send or not channel then return false end
  local ok = pcall(send, PREFIX, msg, channel, target)
  return ok
end

local function Version()
  return (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("Moolitism-Helper", "Version")) or "3.6.0"
end

local function CowFields()
  local b = ns.db and ns.db.bessie
  if not b then return "Bessie", 0, 1, 50 end
  local name = (b.name or "Bessie"):gsub("[^%a%s'%-]", "")
  return name, math.floor(b.xp or 0), b.stage or 1, math.floor(b.happiness or 50)
end

local function Join(...)
  local t = { ... }
  for i = 1, select("#", ...) do t[i] = tostring(t[i]):gsub(SEP, "") end
  return table.concat(t, SEP)
end

---------------------------------------------------------------------------
-- Marking our own lines
---------------------------------------------------------------------------

-- for other modules (MooScape positions): group channels only
function ns:SendPeerMessage(msg, channel)
  if channel ~= "PARTY" and channel ~= "RAID" and channel ~= "INSTANCE_CHAT" then return false end
  return SendAddon(msg, channel)
end

local ADDON_CHANNEL = { PARTY = "PARTY", RAID = "RAID", INSTANCE_CHAT = "INSTANCE_CHAT", GUILD = "GUILD", OFFICER = "OFFICER" }

function ns:MarkOutgoing(key, text)
  if ADDON_CHANNEL[key] then
    SendAddon("SAID" .. SEP .. Hash(text), ADDON_CHANNEL[key])
  elseif key:sub(1, 2) == "W:" then
    SendAddon("SAID" .. SEP .. Hash(text), "WHISPER", key:sub(3))
  end
end

-- A line is another copy's only if THAT player's copy marked it: someone without the addon
-- typing the same words ("moo") a moment later is still a person talking.
function ns:IsForeignAddonLine(text, sender)
  local key = Hash(text)
  if sender then key = ns.ShortName(sender) .. "~" .. key end
  local t = foreign[key]
  return t ~= nil and ns.Now() - t < MARK_TTL
end

function ns:IsPeer(name) return self.peers[ns.ShortName(name)] ~= nil end

-- Fallback when addon messages can't get through (e.g. chat lockdown): lines another copy
-- of the addon writes start like this, so a known Herd Keeper's line that starts this way
-- is treated as theirs.
local ADDON_STARTS = { "Moo-tomatic reply", "MOO TRIVIA", "MOO-OFF", "MOO INTERVIEW", "HERD PROMOTION",
  "MOO-CHIEVEMENT", "VOTE RESULTS", "OFFICIAL HERD VOTE", "MOO CHECK", "QUICK DRAW", "DRAW!!!", "MOO-GMAN",
  "COW SCRAMBLE", "MOO MATH", "MOO TALES", "MOO THEATER", "MOO FM", "BONG.", "WEATHER ALERT", "STAMPEDE HOUR",
  "Moo-roscope", "Hall of Moo-Shame", "MOO METER", "Behold my cow", "COW DUEL", "BINGO! My Moo Bingo", "RAID BOSS!", "MOO WRAPPED", "TRAMPLED:", "LOOT: [", "Damage: ",
  "BINGO BLACKOUT!", "MOO-CIPHER:", "Now performing", "~ ", "THE END", "MOO! Epic loot", "Moo? You rang",
  "VICTORY MOO", "MOO OF MOURNING" }
function ns:LooksLikeAddonLine(text)
  for _, s in ipairs(ADDON_STARTS) do
    if text:sub(1, #s) == s then return true end
  end
  return false
end

-- Every reader of party/guild chat and whispers goes through this. fn runs only for lines
-- a person typed, never for lines another copy of the addon posted.
function ns:GateChat(sender, text, fn)
  if self:IsForeignAddonLine(text, sender) then return end
  local name = ns.ShortName(sender)
  if self:IsPeer(name) then
    if self:LooksLikeAddonLine(text) then return end
    -- the mark may arrive a moment after the chat line: wait for it before answering
    C_Timer.After(WAIT_FOR_MARK, function()
      if not ns:IsForeignAddonLine(text, sender) then fn() end
    end)
    return
  end
  fn()
end

---------------------------------------------------------------------------
-- Backstop: a reply budget per person
---------------------------------------------------------------------------

local replies, coolOff = {}, {}
function ns:AllowAutoReply(name)
  name = ns.ShortName(name or "?")
  local now = ns.Now()
  if coolOff[name] and now < coolOff[name] then return false end
  local list = replies[name] or {}
  for i = #list, 1, -1 do if now - list[i] > 60 then table.remove(list, i) end end
  if #list >= 8 then
    coolOff[name] = now + 120
    return false
  end
  list[#list + 1] = now
  replies[name] = list
  return true
end

---------------------------------------------------------------------------
-- Hosting: things the whole chat sees once
---------------------------------------------------------------------------
-- With several copies in one party or guild, a game someone asks for, a roast, a roll comment
-- or a welcome should happen once, not once per copy. Who does it:
--   * if the person who asked runs the addon (you, or a Herd Keeper), their own copy;
--   * otherwise the copy whose player's name sorts first.
-- The others stand by and step in, a couple of seconds apart, only if nobody claimed it
-- (say that player has games switched off).

local HOST_GAP = 2.5
local claims = {} -- "scope~id" -> when a peer claimed it

function ns:PeerInScope(name, scope)
  local p = self.peers[name]
  if not p or ns.Now() - p.seen > 3600 then return false end
  if scope == "guild" then return p.guild == true and IsInGuild() end
  for _, member in ipairs(ns.GroupMembers and ns.GroupMembers() or {}) do
    if ns.ShortName(member) == name then return true end
  end
  return false
end

-- how many copies go before ours (0 = we host)
function ns:HostRank(scope, asker)
  local me = UnitName("player") or ""
  if asker == me then return 0 end -- you asked: your copy does it
  local rank = 0
  if asker and self:PeerInScope(asker, scope) then rank = 1 end
  for name in pairs(self.peers) do
    if name ~= asker and name < me and self:PeerInScope(name, scope) then rank = rank + 1 end
  end
  return rank
end

-- scope: "group" or "guild"; id names the thing the same way on every copy ("trivia:Bob");
-- asker: who asked (nil when nobody did). fn runs here at most once, or not at all.
-- Returns "now", "later" (we'll step in if nobody does) or nothing.
function ns:RunAsHost(scope, id, asker, fn)
  local channel = scope == "guild" and (IsInGuild() and "GUILD" or nil) or self:GroupChannel()
  local key = scope .. "~" .. tostring(id):gsub(SEP, "")
  asker = asker and ns.ShortName(asker)
  local function Host()
    -- a hard-muted channel can't host: say nothing, so another copy can
    if channel and not self:IsMuted(channel) then SendAddon(Join("HOST", scope, id), channel) end
    fn()
  end
  local rank = self:HostRank(scope, asker)
  if rank == 0 then Host() return "now" end
  local asked = ns.Now()
  C_Timer.After(rank * HOST_GAP, function()
    if (claims[key] or -1000) >= asked - 1 then return end
    Host()
  end)
  return "later"
end

-- a moo-counting game started here: the other copies in its chat hold their moo-backs
-- (0 = it's over). Sent to the game's chat.
ns.quietUntil = 0
function ns:ShareQuiet(seconds)
  local channel = self.GameChannel and self:GameChannel() or self:GroupChannel()
  if channel and not self:IsMuted(channel) then SendAddon(Join("QUIET", math.floor(seconds)), channel) end
end

function ns:ShareMercy(seconds, scope)
  local channel = scope == "guild" and (IsInGuild() and "GUILD" or nil) or self:GroupChannel()
  if channel then SendAddon(Join("MERCY", math.floor(seconds)), channel) end
end

---------------------------------------------------------------------------
-- Hello: finding other Herd Keepers
---------------------------------------------------------------------------

local lastHelloGroup, helloTo = -1000, {}

local function Hello(channel, target)
  local cow, xp, stage, happy = CowFields()
  SendAddon(Join("HI", Version(), cow, xp, stage, happy), channel, target)
end

function ns:SayHello(force)
  local now = ns.Now()
  if not force and now - lastHelloGroup < 20 then return end
  lastHelloGroup = now
  local ch = self:GroupChannel()
  if ch then Hello(ch) end
  if IsInGuild() then Hello("GUILD") end
end

---------------------------------------------------------------------------
-- Sanitizing what other copies send. Another player's addon could be modified, so nothing in
-- an addon message is trusted: names are cut to letters, numbers are clamped, ids are checked.
---------------------------------------------------------------------------

-- a whole number in [lo, hi], or the fallback (also for "inf", "nan" and other junk)
function ns.SafeNumber(v, lo, hi, fallback)
  local n = tonumber(v)
  if not n or n ~= n then return fallback end
  return math.floor(math.max(lo, math.min(n, hi)))
end

-- a cow name: letters, spaces, ' and - only, at most 24 characters
function ns.SafeCowName(v)
  local name = ns.Clean(v):gsub("[^%a%s'%-]", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  name = name:sub(1, 24):gsub("%s+$", "")
  return name ~= "" and name or "Bessie"
end

local function SafeVersion(v)
  v = tostring(v or "")
  return v:match("^v?%d+%.%d+%.?%d*$") and v:sub(1, 12) or "?"
end

local function Stats(parts, first)
  return { name = ns.SafeCowName(parts[first]), xp = ns.SafeNumber(parts[first + 1], 0, 10000000, 0),
    stage = ns.SafeNumber(parts[first + 2], 1, 6, 1), happiness = ns.SafeNumber(parts[first + 3], 0, 100, 50) }
end

local function NotePeer(short, full, parts, channel)
  local p = ns.peers[short]
  local isNew = not p
  p = p or {}
  p.full, p.seen = full, ns.Now()
  if channel == "GUILD" then p.guild = true end
  if parts then
    p.version = SafeVersion(parts[2])
    p.cow = Stats(parts, 3)
  end
  ns.peers[short] = p
  if isNew then
    ns.db.peerSet = ns.db.peerSet or {}
    if not ns.db.peerSet[short] then
      ns.db.peerSet[short] = true
      ns:Bump("peersMet")
    end
    ns:Print(("%s also runs Moolitism Helper. Their lines won't set off yours (and Cow Duels are open: /moo duel %s)."):format(short, short))
  end
  return isNew
end

---------------------------------------------------------------------------
-- Cow Duels
---------------------------------------------------------------------------

local pendingDuels = {}


-- Deterministic: both copies get the same result from the same duel id and the same two cows.
function ns.FightCows(id, a, b)
  local seed = 0
  for i = 1, #id do seed = (seed * 31 + id:byte(i)) % 2147483647 end
  local function rnd(n)
    seed = (seed * 1103515245 + 12345) % 2147483648
    return seed % n
  end
  local cows = { a, b }
  local hp, power = {}, {}
  for i, c in ipairs(cows) do
    hp[i] = 60 + c.stage * 12
    power[i] = 8 + c.stage * 4 + math.min(math.floor(c.xp / 400), 20) + math.floor(c.happiness / 20)
  end
  local MOVES = { "headbutt", "hoof stomp", "tail whip", "mighty MOO", "charge", "grass toss" }
  local log, rounds = {}, 0
  while hp[1] > 0 and hp[2] > 0 and rounds < 12 do
    rounds = rounds + 1
    for attacker = 1, 2 do
      local defender = 3 - attacker
      if hp[attacker] > 0 then
        local dmg = math.floor(power[attacker] / 2) + rnd(math.floor(power[attacker] / 2) + 1)
        local crit = rnd(10) == 0
        if crit then dmg = dmg * 2 end
        hp[defender] = hp[defender] - dmg
        if crit or #log < 1 then
          log[#log + 1] = ("%s's %s hits for %d%s"):format(cows[attacker].name, MOVES[rnd(#MOVES) + 1], dmg, crit and " (CRITICAL MOO!)" or "")
        end
      end
    end
  end
  local winner
  if hp[1] > 0 and hp[2] <= 0 then winner = 1
  elseif hp[2] > 0 and hp[1] <= 0 then winner = 2
  else winner = hp[1] >= hp[2] and 1 or 2 end
  return winner, rounds, log
end

local function RecordDuel(won)
  ns.db.duels = ns.db.duels or { fought = 0, won = 0 }
  ns.db.duels.fought = ns.db.duels.fought + 1
  ns:Bump("cowDuels")
  if won then
    ns.db.duels.won = ns.db.duels.won + 1
    ns:Bump("cowDuelWins")
  end
end

function ns:ChallengeDuel(name)
  if not name or name == "" then return false, "Usage: /moo duel <name> (they need Moolitism Helper too)" end
  local short = ns.ShortName(name)
  local peer = self.peers[short]
  if not peer then return false, ("%s doesn't seem to run Moolitism Helper (or hasn't been seen yet). Cow Duels need both of you to have it."):format(short) end
  local id = ("%d%d"):format(time() % 100000, random(10000, 99999))
  local cow, xp, stage, happy = CowFields()
  pendingDuels[id] = { target = short, at = ns.Now(), mine = Stats({ cow, xp, stage, happy }, 1) }
  SendAddon(Join("DUEL", id, cow, xp, stage, happy), "WHISPER", peer.full or short)
  C_Timer.After(20, function()
    if pendingDuels[id] then
      pendingDuels[id] = nil
      ns:Print(("%s's cow didn't answer the challenge."):format(short))
    end
  end)
  return true, ("Challenge sent to %s's cow. Moo."):format(short)
end

local function Announce(id, mine, theirs, theirName, iChallenged)
  local a, b = mine, theirs
  local aOwner, bOwner = UnitName("player") or "Me", theirName
  if not iChallenged then a, b, aOwner, bOwner = theirs, mine, theirName, UnitName("player") or "Me" end
  local winner, rounds, log = ns.FightCows(id, a, b)
  local winnerCow, winnerOwner = (winner == 1 and a or b).name, winner == 1 and aOwner or bOwner
  local won = (winnerOwner == (UnitName("player") or "Me"))
  RecordDuel(won)
  if ns.Toast then ns:Toast("COW DUEL", won and ("Your cow won in " .. rounds .. " rounds!") or ("Your cow lost to " .. winnerCow)) end
  -- only the challenger announces, so the party sees it once
  if iChallenged then
    local ch = ns:GroupChannel()
    local lines = {
      ("COW DUEL! %s's %s (stage %d) vs %s's %s (stage %d)!"):format(aOwner, a.name, a.stage, bOwner, b.name, b.stage),
    }
    for i = 1, math.min(#log, 2) do lines[#lines + 1] = log[i] .. "!" end
    lines[#lines + 1] = ("%s's %s wins after %d rounds! The herd roars. MOO!"):format(winnerOwner, winnerCow, rounds)
    for _, line in ipairs(lines) do
      if ch then ns:Queue(ch, line, 3, 60) else ns:Print(line) end
    end
  end
  return winner
end

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------

local function Split(text)
  local parts = {}
  for field in (text .. SEP):gmatch("(.-)" .. SEP) do parts[#parts + 1] = field end
  return parts
end

local function OnAddonMessage(prefix, text, channel, sender)
  if prefix ~= PREFIX or not Usable(text) or not Usable(sender) or type(text) ~= "string" or type(sender) ~= "string" then return end
  if #text > 255 or text:find("|", 1, true) then return end -- nothing we send is longer or carries escape codes
  local full = (Ambiguate and Ambiguate(sender, "none")) or sender
  full = ns.Clean(full):sub(1, 64)
  local short = ns.ShortName(full)
  if short == "" or short == UnitName("player") then return end
  local parts = Split(text)
  if #parts > 8 then return end
  local kind = parts[1]

  if kind == "SAID" and parts[2] and parts[2]:match("^%x+$") and #parts[2] <= 8 then
    foreign[parts[2]] = ns.Now()               -- (kept for callers that don't know the sender)
    foreign[short .. "~" .. parts[2]] = ns.Now()
    NotePeer(short, full, nil, channel)
  elseif kind == "QUIET" and tonumber(parts[2]) then
    NotePeer(short, full, nil, channel)
    local seconds = math.max(0, math.min(tonumber(parts[2]), 240))
    ns.quietUntil = seconds > 0 and ns.Now() + seconds or 0
  elseif kind == "RPG" and (channel == "PARTY" or channel == "RAID" or channel == "INSTANCE_CHAT") then
    -- MooScape: where a party member's cow is. Every field is checked before it's used.
    local zone, x, y, total = parts[2], tonumber(parts[3]), tonumber(parts[4]), tonumber(parts[5])
    if ns.RPG and ns.RPG.OnPeer and type(zone) == "string" and zone:match("^%l+$") and #zone <= 16
      and x and y and total and x == math.floor(x) and y == math.floor(y) then
      ns.RPG:OnPeer(short, zone, x, y, ns.SafeNumber(total, 0, 1000, 0))
    end
  elseif kind == "MERCY" and tonumber(parts[2]) then
    NotePeer(short, full, nil, channel)
    local untilT = ns.Now() + math.max(0, math.min(tonumber(parts[2]), 600))
    if untilT > (ns.mercyUntil or 0) then
      ns.mercyUntil = untilT
      ns:Print(("%s's cow granted mercy, so yours is holding back its ambient moos too. ...moo."):format(short))
    end
  elseif kind == "HOST" and (parts[2] == "group" or parts[2] == "guild") and parts[3] and #parts[3] <= 80 then
    NotePeer(short, full, nil, channel)
    claims[parts[2] .. "~" .. parts[3]] = ns.Now()
  elseif kind == "HI" then
    local knewGuild = ns.peers[short] and ns.peers[short].guild
    local isNew = NotePeer(short, full, parts, channel)
    -- answer so they learn about us too: in guild chat for a guild hello (so they know we're in
    -- their guild), otherwise by whisper
    local key = short .. (channel == "GUILD" and "~g" or "")
    if (isNew or (channel == "GUILD" and not knewGuild)) and (helloTo[key] or -1000) < ns.Now() - 300 then
      helloTo[key] = ns.Now()
      if channel == "GUILD" then Hello("GUILD") else Hello("WHISPER", full) end
    end
  elseif kind == "DUEL" and parts[2] and parts[2]:match("^%d+$") and #parts[2] <= 12 then
    NotePeer(short, full, nil, channel)
    if not ns.db.triggers.cowDuels or ns.db.panic then return end
    local theirs = Stats(parts, 3)
    local cow, xp, stage, happy = CowFields()
    SendAddon(Join("DUELOK", parts[2], cow, xp, stage, happy), "WHISPER", full)
    local mine = Stats({ cow, xp, stage, happy }, 1)
    ns:Print(("%s's cow %s challenged %s to a Cow Duel!"):format(short, theirs.name, cow))
    Announce(parts[2], mine, theirs, short, false)
  elseif kind == "DUELOK" and parts[2] and pendingDuels[parts[2]] and pendingDuels[parts[2]].target == short then
    local duel = pendingDuels[parts[2]]
    pendingDuels[parts[2]] = nil
    Announce(parts[2], duel.mine, Stats(parts, 3), short, true)
  end
end

ns:On("PLAYER_LOGIN", function()
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
  elseif RegisterAddonMessagePrefix then
    pcall(RegisterAddonMessagePrefix, PREFIX)
  end
  C_Timer.After(10, function() ns:SayHello(true) end)
end)
ns:On("CHAT_MSG_ADDON", OnAddonMessage)
ns:On("GROUP_ROSTER_UPDATE", function() ns:SayHello() end)

table.insert(ns.tickFns, function()
  local now = ns.Now()
  for h, t in pairs(foreign) do if now - t > MARK_TTL then foreign[h] = nil end end
  for k, t in pairs(claims) do if now - t > 60 then claims[k] = nil end end
  for name, p in pairs(ns.peers) do if now - p.seen > 3600 then ns.peers[name] = nil end end
end)
