-- MooHelper: party games and conversations
--
-- Everything here happens through ordinary party chat and whispers, so friends don't need
-- the addon. It reads what people say, asks them questions, and reacts to their replies.

local _, ns = ...

local Usable = ns.Usable
local random = math.random
local function Pick(list) return list[random(#list)] end

local GAME = 3 -- queue priority for game and conversation lines

---------------------------------------------------------------------------
-- Text helpers
---------------------------------------------------------------------------

-- lower case, punctuation turned into spaces, padded so " word " matches whole words
function ns.Normalize(text)
  local s = text:lower():gsub("[^%w\128-\255]+", " ")
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  return " " .. s .. " "
end

local function Has(norm, phrase) return norm:find(" " .. phrase .. " ", 1, true) ~= nil end
local function HasAny(norm, list)
  for _, p in ipairs(list) do if Has(norm, p) then return true end end
  return false
end

ns.TextHas, ns.TextHasAny = Has, HasAny

function ns.CountMoos(msg)
  local n = 0
  for _ in msg:lower():gmatch("%f[%a]mo[o]+%f[%A]") do n = n + 1 end
  return n
end

-- what someone said after a keyword: "vote should we pull" -> "should we pull"
local function After(msg, word)
  local lower = msg:lower()
  local s, e = lower:find(word, 1, true)
  if not s then return "" end
  return (msg:sub(e + 1):gsub("^[%s:,%-]+", ""):gsub("%s+$", ""))
end

---------------------------------------------------------------------------
-- Where games happen: "group" (party, raid or instance chat) or "guild"
---------------------------------------------------------------------------

ns.gameScope = "group" -- the chat the current (or last) game runs in
ns.recentSpeakers = { group = {}, guild = {} }

function ns:ScopeChannel(scope)
  if scope == "guild" then return IsInGuild() and "GUILD" or nil end
  return self:GroupChannel()
end
function ns:GameChannel() return self:ScopeChannel(self.gameScope) end

-- "party", "raid", "instance" or "guild": used in game text ("answer in guild chat")
function ns:ChatName(scope)
  scope = scope or self.gameScope
  if scope == "guild" then return "guild" end
  local ch = self:GroupChannel()
  return ch == "RAID" and "raid" or (ch == "INSTANCE_CHAT" and "instance" or "party")
end

function ns:AnyGameRunning()
  return self.battle or self.trivia or self.vote or self.mooCheck or (self.ArcadeBusy and self:ArcadeBusy())
end

-- Every game calls this first. Scope comes from where it was asked for (a guildmate saying
-- "trivia" in guild chat, "/moo trivia guild") or the default chosen in the Barn.
function ns:BeginGame(stateless)
  local scope = self.startScope or self.db.gameScope or "group"
  if self:AnyGameRunning() then
    -- one-off games (a song, a play) may join a running game's chat, but never move it
    if not stateless or scope ~= self.gameScope then
      return false, ("Another game is running in %s chat. Let it finish first."):format(self:ChatName())
    end
  end
  local ch = self:ScopeChannel(scope)
  if not ch then return false, scope == "guild" and "You need a guild for that." or "You need a group for that." end
  if self:IsMuted(ch) then return false, self:ChannelLabel(ch) .. " is HARD MUTED, so games can't run there." end
  self.gameScope = scope
  return true
end

-- Game lines go to the game's chat
local function Group(text, priority, maxAge)
  local ch = ns:GameChannel()
  if ch then return ns:Queue(ch, text, priority or GAME, maxAge or 60) end
  return false
end
ns.GroupSay = Group
ns.TextAfter = After

-- Interviews and other party-only talk always go to the group
local function GroupChat(text, priority, maxAge)
  local ch = ns:GroupChannel()
  if ch then return ns:Queue(ch, text, priority or GAME, maxAge or 60) end
  return false
end

-- Answers go back where the person spoke: "group", "guild" or "W:<sender>"
local function Reply(where, text)
  if where == "group" then return GroupChat(text) end
  if where == "guild" then return IsInGuild() and ns:Queue("GUILD", text, GAME) end
  return ns:Queue(where, text, GAME)
end

local function GroupMembers()
  local names = {}
  local prefix, count = "party", 4
  if IsInRaid() then prefix, count = "raid", GetNumGroupMembers() or 0 end
  for i = 1, count do
    local unit = prefix .. i
    if UnitExists(unit) and not UnitIsUnit(unit, "player") then
      local name = UnitName(unit)
      if Usable(name) and name then names[#names + 1] = name end
    end
  end
  return names
end
ns.GroupMembers = GroupMembers

-- Who's playing: the group, or guildmates who spoke in guild chat in the last 15 minutes
function ns:GameMembers()
  if self.gameScope ~= "guild" then return GroupMembers() end
  local names, now = {}, ns.Now()
  for name, t in pairs(self.recentSpeakers.guild) do
    if now - t < 900 and name ~= UnitName("player") then names[#names + 1] = name end
  end
  table.sort(names)
  return names
end

local function Busy() return ns:AnyGameRunning() end

---------------------------------------------------------------------------
-- Reading group chat
---------------------------------------------------------------------------

local CHAT_SOURCES = {
  CHAT_MSG_PARTY = "group", CHAT_MSG_PARTY_LEADER = "group", CHAT_MSG_RAID = "group",
  CHAT_MSG_RAID_LEADER = "group", CHAT_MSG_INSTANCE_CHAT = "group", CHAT_MSG_INSTANCE_CHAT_LEADER = "group",
  CHAT_MSG_GUILD = "guild",
}

-- Game listeners: (msg, shortName, isSelf, source). A listener hears the chat its game runs in,
-- unless it asks for a fixed one ("group" for the echo).
local listeners = {}
function ns:AddGroupListener(key, fn, scope) listeners[key] = { fn = fn, scope = scope } end
function ns:RemoveGroupListener(key) listeners[key] = nil end

for event, source in pairs(CHAT_SOURCES) do
  ns:On(event, function(msg, sender)
    if not Usable(msg) or not Usable(sender) or type(msg) ~= "string" then return end
    if ns:IsOwnOutput(msg) then return end -- our own addon lines echoing back
    local name = ns.ShortName(sender)
    local isSelf = name == UnitName("player")
    -- lines another copy of the addon posted are never answered or counted (no moo loops)
    ns:GateChat(sender, msg, function()
      ns.recentSpeakers[source][name] = ns.Now()
      for key, l in pairs(listeners) do
        if (l.scope or ns.gameScope) == source then
          local ok, err = pcall(l.fn, msg, name, isSelf, source)
          if not ok then table.insert(ns.errors, "listener " .. key .. ": " .. tostring(err)) end
        end
      end
      if source == "guild" and not ns.db.triggers.guildGames then return end
      ns:Converse(msg, name, isSelf, source)
    end)
  end)
end

---------------------------------------------------------------------------
-- MOO-OFF: type moo the most in N seconds
---------------------------------------------------------------------------

function ns:StartMooOff(seconds, starter)
  local ok, why = self:BeginGame()
  if not ok then return false, why end
  seconds = math.max(10, math.min(tonumber(seconds) or 30, 120))
  self.battle = { endsAt = ns.Now() + seconds, counts = {}, warned = false }
  self:Bump("played:battle")
  if self.OnGameHosted then self:OnGameHosted() end
  Group(("MOO-OFF! %sType MOO in %s chat for the next %d seconds. Most moos wins. GO! MOO!")
    :format(starter and (starter .. " has called a MOO-OFF. ") or "", self:ChatName(), seconds))
  if self.Stampede then self:Stampede(12) end
  if self.MooVision then self:MooVision() end
  self:AddGroupListener("battle", function(msg, name)
    local n = math.min(ns.CountMoos(msg), 5) -- a pasted wall of moo counts as 5
    if n > 0 and ns.battle then ns.battle.counts[name] = (ns.battle.counts[name] or 0) + n end
  end)
  return true
end

local function BattleTick()
  local battle = ns.battle
  if not battle then return end
  local left = battle.endsAt - ns.Now()
  if left <= 10 and not battle.warned then
    battle.warned = true
    Group("10 SECONDS LEFT! MOO HARDER!")
  end
  if left > 0 then return end
  ns:RemoveGroupListener("battle")
  ns.battle = nil
  local list = {}
  for name, c in pairs(battle.counts) do list[#list + 1] = { name = name, count = c } end
  table.sort(list, function(a, b) return a.count > b.count or (a.count == b.count and a.name < b.name) end)
  if #list == 0 then
    Group("MOO-OFF OVER. Nobody mooed. The herd is deeply ashamed.")
    return
  end
  local parts = {}
  for i = 1, math.min(5, #list) do parts[#parts + 1] = ("%d. %s (%d)"):format(i, list[i].name, list[i].count) end
  Group("MOO-OFF RESULTS: " .. table.concat(parts, "  "))
  local winner = list[1].name
  local wins = (ns.db.stats.mooOffWins[winner] or 0) + 1
  ns.db.stats.mooOffWins[winner] = wins
  ns:HerdAward(winner, 10, "wins")
  for i = 2, #list do ns:HerdAward(list[i].name, 2) end
  Group(("%s is the MOO-OFF CHAMPION (%d title%s). The herd bows. MOOOOOOOOO!"):format(winner, wins, wins == 1 and "" or "s"))
  if ns.CowRain then ns:CowRain(30) end
end

---------------------------------------------------------------------------
-- Cow & Tauren trivia
---------------------------------------------------------------------------

-- answers: any one matches (whole words, case and punctuation ignored)
ns.TRIVIA = {
  { q = "How many compartments does a cow's stomach have?", a = { "4", "four" }, show = "Four" },
  { q = "What do you call a baby cow?", a = { "calf" }, show = "A calf" },
  { q = "What is a group of cattle called?", a = { "herd" }, show = "A herd" },
  { q = "What is the Tauren capital city?", a = { "thunder bluff", "thunderbluff" }, show = "Thunder Bluff" },
  { q = "In which zone do Tauren start their adventures?", a = { "mulgore" }, show = "Mulgore" },
  { q = "Which camp is the very first Tauren starting area?", a = { "camp narache", "narache" }, show = "Camp Narache" },
  { q = "Who was High Chieftain of the Tauren, father of Baine?", a = { "cairne", "cairne bloodhoof" }, show = "Cairne Bloodhoof" },
  { q = "Which deity do the Tauren revere?", a = { "earth mother", "earthmother" }, show = "The Earth Mother" },
  { q = "What large beast do Tauren ride as a mount?", a = { "kodo", "kodos" }, show = "The kodo" },
  { q = "What is the Tauren racial ability that stuns nearby enemies?", a = { "war stomp", "warstomp" }, show = "War Stomp" },
  { q = "Which Tauren tribe follows Magatha Grimtotem?", a = { "grimtotem" }, show = "The Grimtotem" },
  { q = "Which Mulgore village is named after the Tauren chieftain's family?", a = { "bloodhoof", "bloodhoof village" }, show = "Bloodhoof Village" },
  { q = "What sound does a cow make?", a = { "moo" }, show = "MOO. Obviously." },
  { q = "What do you call an adult male of cattle kept for breeding?", a = { "bull" }, show = "A bull" },
  { q = "What do cows bring back up and chew again?", a = { "cud" }, show = "Cud" },
  { q = "How many legs does a cow have?", a = { "4", "four" }, show = "Four" },
  { q = "What is a young female cow that hasn't had a calf called?", a = { "heifer" }, show = "A heifer" },
  { q = "What do you get when you churn cream for long enough?", a = { "butter" }, show = "Butter" },
  { q = "What is the name for a cow's mammary gland?", a = { "udder" }, show = "The udder" },
  { q = "Which racial bonus gives Tauren extra base health: Endurance or Toughness?", a = { "endurance" }, show = "Endurance" },
}

function ns.TriviaCorrect(question, msg)
  local said = ns.Normalize(msg)
  for _, ans in ipairs(question.a) do
    if said:find(ns.Normalize(ans), 1, true) then return true end
  end
  return false
end

local function AskNext()
  local trivia = ns.trivia
  if not trivia then return end
  trivia.round = trivia.round + 1
  if trivia.round > trivia.rounds then
    ns:RemoveGroupListener("trivia")
    ns.trivia = nil
    local list = {}
    for name, p in pairs(trivia.scores) do list[#list + 1] = { name = name, p = p } end
    table.sort(list, function(a, b) return a.p > b.p or (a.p == b.p and a.name < b.name) end)
    if #list == 0 then Group("MOO TRIVIA OVER. Nobody scored. The herd needs to study.") return end
    local parts = {}
    for i, e in ipairs(list) do
      parts[#parts + 1] = ("%d. %s (%d)"):format(i, e.name, e.p)
      ns.db.stats.triviaPoints[e.name] = (ns.db.stats.triviaPoints[e.name] or 0) + e.p
    end
    Group("MOO TRIVIA FINAL SCORES: " .. table.concat(parts, "  ") .. ". " .. list[1].name .. " is the smartest cow. Moo.")
    return
  end
  local pool = {}
  for i in ipairs(ns.TRIVIA) do if not trivia.asked[i] then pool[#pool + 1] = i end end
  local i = Pick(pool)
  trivia.asked[i] = true
  trivia.current = ns.TRIVIA[i]
  trivia.deadline = ns.Now() + 30
  trivia.nextAt = nil
  Group(("MOO TRIVIA %d/%d: %s (answer in %s chat)"):format(trivia.round, trivia.rounds, trivia.current.q, ns:ChatName()))
end

function ns:StartTrivia(rounds, starter)
  local ok, why = self:BeginGame()
  if not ok then return false, why end
  rounds = math.max(1, math.min(tonumber(rounds) or 5, #ns.TRIVIA))
  self.trivia = { rounds = rounds, round = 0, scores = {}, asked = {}, nextAt = ns.Now() + 3 }
  self:Bump("played:trivia")
  if self.OnGameHosted then self:OnGameHosted() end
  Group(("MOO TRIVIA! %d questions about cows and Tauren. First correct answer in %s chat scores. Moo.%s")
    :format(rounds, self:ChatName(), starter and (" (requested by " .. starter .. ")") or ""))
  self:AddGroupListener("trivia", function(msg, name)
    local trivia = ns.trivia
    if not trivia or not trivia.current or trivia.nextAt then return end
    if ns.TriviaCorrect(trivia.current, msg) then
      trivia.scores[name] = (trivia.scores[name] or 0) + 1
      ns:HerdAward(name, 3)
      Group(Pick({ "Correct, %s! +1 moo point.", "MOO! %s got it!", "%s is correct. The herd is impressed." }):format(name))
      trivia.current = nil
      trivia.nextAt = ns.Now() + 5
    end
  end)
  return true
end

local function TriviaTick()
  local trivia = ns.trivia
  if not trivia then return end
  local now = ns.Now()
  if trivia.nextAt then
    if now >= trivia.nextAt then AskNext() end
  elseif trivia.current and now >= trivia.deadline then
    Group(("Time's up! The answer was: %s. Moo."):format(trivia.current.show))
    trivia.current = nil
    trivia.nextAt = now + 5
  end
end

---------------------------------------------------------------------------
-- The Rigged Vote: MOO always wins
---------------------------------------------------------------------------

function ns:StartVote(question, starter)
  local ok, why = self:BeginGame()
  if not ok then return false, why end
  question = ns.Clean(question ~= "" and question or "Should we moo?"):sub(1, 120)
  self.vote = { endsAt = ns.Now() + 20, yes = 0, no = 0, voted = {} }
  self:Bump("played:vote")
  if self.OnGameHosted then self:OnGameHosted() end
  Group(("OFFICIAL HERD VOTE: %s Type 1 for YES or 2 for NO. 20 seconds.%s")
    :format(question, starter and (" (called by " .. starter .. ")") or ""))
  self:AddGroupListener("vote", function(msg, name)
    local vote = ns.vote
    if not vote or vote.voted[name] then return end
    local m = ns.Normalize(msg)
    if m == " 1 " or m == " yes " then vote.yes = vote.yes + 1 vote.voted[name] = true
    elseif m == " 2 " or m == " no " then vote.no = vote.no + 1 vote.voted[name] = true end
    if vote.voted[name] then ns:HerdAward(name, 1) end
  end)
  return true
end

local function VoteTick()
  local vote = ns.vote
  if not vote or ns.Now() < vote.endsAt then return end
  ns:RemoveGroupListener("vote")
  ns.vote = nil
  Group(("VOTE RESULTS: YES %d, NO %d, MOO 0. After careful counting, the herd has decided: MOO.")
    :format(vote.yes, vote.no))
end

---------------------------------------------------------------------------
-- Moo Check: everyone must type moo within 20 seconds
---------------------------------------------------------------------------

function ns:StartMooCheck(starter)
  local ok, why = self:BeginGame()
  if not ok then return false, why end
  self.mooCheck = { endsAt = ns.Now() + 20, passed = {} }
  self:Bump("played:check")
  if self.OnGameHosted then self:OnGameHosted() end
  Group(("MOO CHECK!%s Everyone type moo in %s chat within 20 seconds. Failure will be noted.")
    :format(starter and (" (called by " .. starter .. ")") or "", self:ChatName()))
  self:AddGroupListener("mooCheck", function(msg, name)
    if ns.mooCheck and ns.CountMoos(msg) > 0 then ns.mooCheck.passed[name] = true end
  end)
  return true
end

local function MooCheckTick()
  local check = ns.mooCheck
  if not check or ns.Now() < check.endsAt then return end
  ns:RemoveGroupListener("mooCheck")
  ns.mooCheck = nil
  local failed, passed = {}, {}
  if ns.gameScope == "guild" then
    for name in pairs(check.passed) do passed[#passed + 1] = name ns:HerdAward(name, 2) end
    table.sort(passed)
    if #passed == 0 then Group("MOO CHECK RESULTS: nobody in the guild mooed. Disgraceful.")
    else Group(("MOO CHECK RESULTS: Passed: %s. Everyone else in the guild: shameful. MOO."):format(table.concat(passed, ", "))) end
    return
  end
  for _, name in ipairs(GroupMembers()) do
    if check.passed[name] then passed[#passed + 1] = name ns:HerdAward(name, 2) else failed[#failed + 1] = name end
  end
  if #failed == 0 then
    Group("MOO CHECK PASSED. Every member of this herd can moo. I've never been prouder.")
  else
    Group(("MOO CHECK RESULTS: Passed: %s. FAILED: %s. Shameful. MOO.")
      :format(#passed > 0 and table.concat(passed, ", ") or "nobody", table.concat(failed, ", ")))
  end
end

---------------------------------------------------------------------------
-- Moo Karaoke (original songs)
---------------------------------------------------------------------------

ns.SONGS = {
  { title = "The Ballad of Bloodhoof Village", lines = {
    "~ Down in Mulgore where the tall grass sways ~",
    "~ I mooed at the sunrise for forty days ~",
    "~ The kodos were lowing, the plainstriders ran ~",
    "~ And nobody asked me to stop, so I mooooo'd again ~",
    "~ MOOOOO, Bloodhoof, MOOOOO ~",
    "~ Moo moo moo moo, moo moo moo ~",
  } },
  { title = "Stampede of My Heart", lines = {
    "~ You stood in the fire, I stood by your side ~",
    "~ You pulled the whole room and I didn't even hide ~",
    "~ My heart is a stampede, it's thundering true ~",
    "~ Every single moo I moo, I moo it for you ~",
    "~ MOO-oo-OOO, stampede of my heart ~",
    "~ (moo) ~",
  } },
  { title = "Ninety-Nine Bottles of Milk (Abridged)", lines = {
    "~ Ninety-nine bottles of milk on the wall ~",
    "~ Ninety-nine bottles of milk ~",
    "~ Take one down, moo it around ~",
    "~ ...the band has been asked to stop. Moo. ~",
  } },
}

local singingUntil = 0
function ns:Sing(which, starter)
  if ns.Now() < singingUntil then return false, "A song is already being performed!" end
  local ok, why = self:BeginGame(true)
  if not ok then return false, why end
  local song = ns.SONGS[tonumber(which) or 0] or Pick(ns.SONGS)
  singingUntil = ns.Now() + 2 * #song.lines + 10
  self:Bump("played:sing")
  if self.OnGameHosted then self:OnGameHosted() end
  Group(("Now performing: \"%s\"%s"):format(song.title, starter and (" (requested by " .. starter .. ")") or ""), GAME, 120)
  for _, line in ipairs(song.lines) do Group(line, GAME, 120) end
  return true
end

---------------------------------------------------------------------------
-- Moo-lette
---------------------------------------------------------------------------

-- player = nil means you; otherwise the friend who asked
function ns:Roulette(player)
  local ok, why = self:BeginGame(true)
  if not ok then return false, why end
  self:Bump("played:roulette")
  if self.OnGameHosted then self:OnGameHosted() end
  if random(6) == 1 then
    if player and player ~= UnitName("player") then
      Group(("*spins the chamber* ... BANG. %s lost Moo-lette and owes the party one (1) ALL-CAPS MOO. Pay up."):format(player))
      self:Ask(player, ("%s, the herd is waiting for your ALL-CAPS MOO."):format(player), {
        react = function(msg)
          if msg:find("MOO") then ns:HerdAward(player, 2) return "Debt paid. The herd forgives you. Moo." end
          return "That was not an ALL-CAPS MOO. The debt grows. MOO."
        end,
        timeout = ("%s refused to pay their Moo-lette debt. Disgraceful. MOOOOO."):format(player),
        say = Group,
      })
    else
      ns.forceYell = true
      Group("*spins the chamber* ... BANG. I lost Moo-lette. My next moo will be a /yell. Moo.")
    end
    if self.MooVision then self:MooVision() end
  else
    Group(("*spins the chamber* ... click. %s survived Moo-lette. This time. Moo."):format(player or "I"))
  end
  return true
end

---------------------------------------------------------------------------
-- Echo victim: repeat everything someone says, in moo
---------------------------------------------------------------------------

local echo
function ns:StartEcho(name, minutes)
  if not name or name == "" or name:lower() == "off" then
    echo = nil
    self:RemoveGroupListener("echo")
    return true, "Echo stopped."
  end
  minutes = minutes or 10
  echo = { name = ns.ShortName(name):lower(), untilT = ns.Now() + minutes * 60, last = -1000 }
  self:AddGroupListener("echo", function(msg, who, _, source)
    if not echo or who:lower() ~= echo.name then return end
    if ns.Now() > echo.untilT then echo = nil ns:RemoveGroupListener("echo") return end
    if ns:InMercy() or ns.Now() - echo.last < 3 then return end
    echo.last = ns.Now()
    GroupChat(('%s said: "%s"'):format(who, ns.MooTranslate(ns.Clean(msg))), 2, 20)
  end, "group")
  return true, ("Echoing %s for %d minutes. /moo echo off to stop."):format(ns.ShortName(name), minutes)
end

---------------------------------------------------------------------------
-- Mercy: begging buys 10 quiet minutes from the ambient moos (sometimes)
---------------------------------------------------------------------------

ns.mercyUntil = 0
local lastMercy = -10000
function ns:InMercy() return ns.Now() < ns.mercyUntil end

local function BegForMercy(name)
  local now = ns.Now()
  if ns:InMercy() then
    return ("Mercy is already in effect for %d more minutes, %s. Enjoy the silence. ...moo."):format(math.ceil((ns.mercyUntil - now) / 60), name)
  end
  if now - lastMercy < 1800 or random(3) == 1 then
    ns:Bump("mercyDenied")
    return Pick({
      "Mercy denied, %s. MOOOOOOOOOOO.", "%s has begged for mercy. The herd has considered this and said: MOO.",
      "Request received, %s. Request moo'd. MOO!", "No.",
    }):format(name)
  end
  lastMercy = now
  ns.mercyUntil = now + 600
  ns:Bump("mercyGranted")
  -- the other copies in this chat go quiet too
  if ns.ShareMercy then ns:ShareMercy(600, ns.startScope or "group") end
  return ("%s has begged for mercy. The herd will hold back the ambient moos for 10 minutes. ...moo."):format(name)
end

---------------------------------------------------------------------------
-- Asking people things and waiting for their reply
---------------------------------------------------------------------------

-- pending[key] = { expires, react(msg) -> reply or nil, timeout = text or nil, where }
-- key: a short name for party questions, "W:<sender>" for whispers
local pending = {}
ns.pending = pending

function ns:Ask(name, question, opts)
  local say = opts.say or GroupChat
  pending[name] = { expires = ns.Now() + (opts.seconds or 45), react = opts.react, timeout = opts.timeout,
    ignored = opts.ignored, say = say }
  if question then say(question) end
end

local function AskWhisper(sender, text, opts)
  pending["W:" .. sender] = { expires = ns.Now() + (opts.seconds or 120), react = opts.react, where = "W:" .. sender }
  ns:Queue("W:" .. sender, text, GAME)
end

local function YesNo(msg)
  local n = ns.Normalize(msg)
  if HasAny(n, { "yes", "yeah", "yep", "y", "ya", "sure", "ok", "okay", "of course", "absolutely" }) then return "yes" end
  if HasAny(n, { "no", "nope", "nah", "n", "never", "absolutely not" }) then return "no" end
  return nil
end
ns.YesNo = YesNo

local function Mooified(name, msg)
  return ('%s says: "%s". The herd has noted it. Moo.'):format(name, ns.MooTranslate(ns.Clean(msg):sub(1, 120)))
end

ns.INTERVIEWS = {
  { q = "%s, important question: cows or kodos?", react = function(msg, name)
      local n = ns.Normalize(msg)
      if HasAny(n, { "cow", "cows" }) then return ("Correct answer, %s. MOO."):format(name) end
      if HasAny(n, { "kodo", "kodos" }) then return ("Kodos. A bold choice, %s. The herd will remember this."):format(name) end
      return ("That wasn't one of the options, %s. The herd chose for you: cows. MOO."):format(name)
    end },
  { q = "%s, on a scale of 1 to moo, how are you feeling right now?", react = function(msg, name)
      if ns.CountMoos(msg) > 0 then return ("A perfect moo out of moo. Wonderful, %s."):format(name) end
      local num = msg:match("%d+")
      if num then return ("%s is feeling a %s out of moo. Concerning. The herd will keep an eye on you."):format(name, num) end
      return ("The herd does not understand your feelings, %s, but respects them. Moo."):format(name)
    end },
  { q = "%s, have you mooed today? (yes/no)", react = function(msg, name)
      local yn = YesNo(msg)
      if ns.CountMoos(msg) > 0 then return ("I heard it. Thank you, %s. Moo."):format(name) end
      if yn == "yes" then return ("Prove it, %s. ...Fine. The herd trusts you. Moo."):format(name) end
      if yn == "no" then return ("Unacceptable, %s. Moo now. The herd is waiting."):format(name) end
      return Mooified(name, msg)
    end },
  { q = "%s, be honest: did you stand in something bad last fight? (yes/no)", react = function(msg, name)
      local yn = YesNo(msg)
      local shamed = (ns.db.stats.shame[name] or 0) > 0
      if yn == "yes" then return ("Honesty. The herd forgives you, %s. Moo."):format(name) end
      if yn == "no" and shamed then return ("The Hall of Moo-Shame says otherwise, %s (%d entries). MOO."):format(name, ns.db.stats.shame[name]) end
      if yn == "no" then return ("The herd believes you, %s. For now. Moo."):format(name) end
      return Mooified(name, msg)
    end },
  { q = "%s, would you like to hear a song? (yes/no)", react = function(msg, name)
      local yn = YesNo(msg)
      ns:Sing(nil, name)
      if yn == "no" then return ("Too bad, %s. The herd sings anyway."):format(name) end
      return nil
    end },
  { q = "%s, please type moo to confirm you are a member of the herd.", react = function(msg, name)
      if ns.CountMoos(msg) > 0 then return ("Herd membership confirmed for %s. Welcome. Moo."):format(name) end
      return ("That was not a moo, %s. Herd membership REVOKED."):format(name)
    end },
  { q = "%s, what is your favorite thing about cows?", react = function(msg, name) return Mooified(name, msg) end },
  { q = "%s, quick: say something nice about the person to your left.", react = function(msg, name) return Mooified(name, msg) end },
}

local nextInterview, nextMooCheck
local function InterviewTick()
  local now = ns.Now()
  -- answers that never came
  for key, p in pairs(pending) do
    if now > p.expires then
      pending[key] = nil
      if p.ignored then ns:Bump("interviewsIgnored") end
      if p.timeout then (p.say or GroupChat)(p.timeout, 2) end
    end
  end
  if ns.db.panic or not ns:GroupChannel() or InCombatLockdown() or ns:InMercy() or Busy() then return end
  if ns.db.triggers.interviews then
    local period = ns.db.interviewMinutes * 60
    if not nextInterview then nextInterview = now + period * (0.5 + random() * 0.5) end
    if now >= nextInterview then
      nextInterview = now + period * (0.7 + random() * 0.6)
      local members = GroupMembers()
      if #members > 0 then
        local name = Pick(members)
        if not pending[name] then
          local iv = Pick(ns.INTERVIEWS)
          ns:Bump("interviewsAsked")
          ns:Ask(name, ("MOO INTERVIEW: " .. iv.q):format(name), {
            react = function(msg)
              ns:Bump("interviewsAnswered")
              ns:HerdAward(name, 3, "answers")
              if ns.Ach and ns.Ach.char then ns.Ach:SetFlag("inspected") end
              return iv.react(msg, name)
            end,
            ignored = true,
            timeout = Pick({
              "%s did not answer the herd. The herd is offended. MOO MOO MOO.",
              "%s is ignoring the herd. Noted. Moo.",
              "Silence from %s. The herd will ask again. And again. Moo.",
            }):format(name),
          })
        end
      end
    end
  end
  if ns.db.triggers.mooCheck then
    local period = ns.db.mooCheckMinutes * 60
    if not nextMooCheck then nextMooCheck = now + period * (0.5 + random() * 0.5) end
    if now >= nextMooCheck then
      nextMooCheck = now + period * (0.7 + random() * 0.6)
      ns:StartMooCheck()
    end
  end
end

---------------------------------------------------------------------------
-- Understanding what people say
---------------------------------------------------------------------------

local FORTUNES = {
  "You will moo before the day is out.", "A great stampede approaches. Stand behind the tank.",
  "Your next loot will be green. Moo.", "Someone in this party secretly wants to moo. It's you.",
  "Beware the floor. The floor is not your friend.", "The grass is greener in Mulgore.",
  "You will soon receive a moo from an unexpected source.", "Today's lucky number is moo.",
}
local EIGHT_BALL = {
  "It is certain. Moo.", "Moo-st likely.", "Ask again after a moo.", "Moo.", "Absolutely not. Moo.",
  "The herd says yes.", "The herd says no.", "Cannot predict now, I'm grazing.", "Signs point to moo.",
}
local ROASTS = {
  "%s has the battle instincts of a confused calf.", "%s stands in fire like it's a warm bath.",
  "%s's dps meter is mostly decorative.", "Even a kodo pulls more carefully than %s.",
  "%s runs like a cow that just saw a fence.",
}
local COMPLIMENTS = {
  "%s has the heart of a kodo and the grace of a slightly smaller kodo.",
  "%s is the finest moo-er this herd has ever known.", "The Earth Mother smiles upon %s.",
  "%s smells faintly of fresh meadow. Moo.",
}

local function MyStats()
  local s = ns.db.stats
  return ("Lifetime moos: %d. Best combo: %d. Rank: %s. Taurens spotted: %d. Moo.")
    :format(s.total, s.bestCombo, ns.RankName and ns:RankName() or "Calf", s.taurenCount)
end

local function TheirStats(name)
  local s = ns.db.stats
  return ("%s: shamed %d times, %d trivia points, %d MOO-OFF titles. Moo.")
    :format(name, s.shame[name] or 0, s.triviaPoints[name] or 0, s.mooOffWins[name] or 0)
end

-- Each intent: match(norm, msg, mentionsMe) -> true; run(name, msg, where) -> reply text or nil.
-- groupOnly intents start a party game, so in whispers they point people to party chat.
local function GameStart(fn)
  return function(name, msg)
    local ok, why = fn(name, msg)
    return not ok and why or nil
  end
end

ns.INTENTS = {
  { id = "mercy", match = function(n, _, me)
      return HasAny(n, { "stop mooing", "stop the moo", "stop the moos", "no more moo", "no more moos",
        "make it stop", "enough moo", "please stop", "shut up" }) or (me and HasAny(n, { "stop", "please" }))
    end, run = function(name) return BegForMercy(name) end },
  { id = "battle", groupOnly = true, match = function(n) return HasAny(n, { "moo off", "mooff", "moo battle", "moooff" }) end,
    run = GameStart(function(name) return ns:StartMooOff(30, name) end) },
  { id = "check", groupOnly = true, match = function(n) return Has(n, "moo check") end,
    run = GameStart(function(name) return ns:StartMooCheck(name) end) },
  { id = "trivia", groupOnly = true, match = function(n) return Has(n, "trivia") end,
    run = GameStart(function(name) return ns:StartTrivia(5, name) end) },
  { id = "vote", groupOnly = true, match = function(n) return Has(n, "vote") end,
    run = GameStart(function(name, msg) return ns:StartVote(After(msg, "vote"), name) end) },
  { id = "sing", groupOnly = true, match = function(n) return HasAny(n, { "sing", "song", "karaoke" }) end,
    run = GameStart(function(name) return ns:Sing(nil, name) end) },
  { id = "roulette", groupOnly = true, match = function(n) return HasAny(n, { "roulette", "moolette", "moo lette" }) end,
    run = GameStart(function(name) return ns:Roulette(name) end) },
  { id = "fortune", match = function(n) return Has(n, "fortune") end,
    run = function(name) return ("%s's moo fortune: %s"):format(name, Pick(FORTUNES)) end },
  { id = "roast", match = function(n) return Has(n, "roast") end,
    run = function(name) return Pick(ROASTS):format(name) .. " Moo." end },
  { id = "compliment", match = function(n) return Has(n, "compliment") end,
    run = function(name) return Pick(COMPLIMENTS):format(name) end },
  { id = "shame", match = function(n) return HasAny(n, { "hall of shame", "moo shame", "shame list" }) end,
    run = function()
      local list = {}
      for n2, c in pairs(ns.db.stats.shame) do list[#list + 1] = { n = n2, c = c } end
      table.sort(list, function(a, b) return a.c > b.c or (a.c == b.c and a.n < b.n) end)
      if #list == 0 then return "The Hall of Moo-Shame is empty. Suspicious." end
      local parts = {}
      for i = 1, math.min(3, #list) do parts[#parts + 1] = ("%d. %s (%d)"):format(i, list[i].n, list[i].c) end
      return "Hall of Moo-Shame: " .. table.concat(parts, "  ")
    end },
  { id = "mystats", match = function(n) return HasAny(n, { "my stats", "my moo stats", "how am i doing" }) end,
    run = function(name) return TheirStats(name) end },
  { id = "stats", match = function(n) return HasAny(n, { "how many moos", "moo stats", "your stats", "moo count" }) end,
    run = function() return MyStats() end },
  { id = "translate", match = function(n) return HasAny(n, { "translate", "in moo" }) end,
    run = function(_, msg)
      local text = After(msg, "translate")
      if text == "" then text = msg end
      return ns.MooTranslate(ns.Clean(text):sub(1, 150))
    end },
  { id = "help", match = function(n) return HasAny(n, { "what can you do", "how does this work", "moo help", "moohelper" }) end,
    run = function() return "Say: moo off, moo check, trivia, vote <question>, sing, roulette, fortune, roast me, compliment me, hall of shame, my stats, how many moos, translate <text>. Begging also works. Sometimes." end },
  { id = "ask", personal = true, match = function(_, msg, me) return me and msg:find("%?%s*$") ~= nil end,
    run = function(name) return ("%s asks the Magic Moo-Ball... %s"):format(name, Pick(EIGHT_BALL)) end },
  { id = "mention", personal = true, match = function(_, _, me) return me end,
    run = function(name)
      return Pick({ "Moo? You rang, %s?", "MOO. (%s said my name)", "The cow hears you, %s. Moo.", "Yes, %s? ...Moo." }):format(name)
    end },
}

local talkCooldown = {}

-- where: "group", "guild" or "W:<sender>"
function ns:Converse(msg, name, isSelf, where)
  if self.db.panic or not self.db.triggers.interactions then return end
  local inChat = where == "group" or where == "guild"
  local key = inChat and name or where
  -- someone answering a question we asked them comes first
  local p = pending[key]
  if p and not isSelf then
    pending[key] = nil
    local reply = p.react(msg)
    if reply and self:AllowAutoReply(name) then
      if p.say and inChat then p.say(reply) else Reply(where, reply) end
    end
    return
  end

  local now = ns.Now()
  if now - (talkCooldown[key] or -1000) < 3 then return end
  local norm = ns.Normalize(msg)
  local me = UnitName("player")
  local mentionsMe = not isSelf and Usable(me) and me and Has(norm, me:lower())
  for _, intent in ipairs(ns.INTENTS) do
    if intent.match(norm, msg, mentionsMe) then
      talkCooldown[key] = now
      if intent.groupOnly and not inChat then
        local reply = "That's a party activity. Say it in party or guild chat and the whole herd can join. Moo."
        if isSelf or self:AllowAutoReply(name) then Reply(where, reply) end
        return intent.id
      end
      local function Run()
        -- a game asked for in guild chat runs in guild chat
        self.startScope = inChat and where or nil
        local ok, result = pcall(intent.run, name, msg, where)
        self.startScope = nil
        if not ok then error(result) end
        return result
      end
      local function Answer(reply)
        if reply and (isSelf or self:AllowAutoReply(name)) then Reply(where, reply) end
      end
      if not inChat or intent.personal or not self.RunAsHost then
        Answer(Run())
      else
        -- one copy in the chat does it, not one per copy
        self:RunAsHost(where, intent.id .. ":" .. name, isSelf and UnitName("player") or name, function() Answer(Run()) end)
      end
      return intent.id
    end
  end
end

---------------------------------------------------------------------------
-- Whisper conversations
---------------------------------------------------------------------------

local WHISPER_OPENERS = {
  { q = "Moo-tomatic reply: The cow you're trying to reach is grazing. While you wait: are you a cow? (yes/no)",
    react = function(msg)
      local yn = YesNo(msg)
      if ns.CountMoos(msg) > 0 then return "A fellow moo-er. Welcome to the herd." end
      if yn == "yes" then return "Welcome to the herd. Moo." end
      if yn == "no" then return "That's exactly what a cow would say. Moo." end
      return ('Moo-tomatic reply: I have translated your message for the cow: "%s"'):format(ns.MooTranslate(ns.Clean(msg):sub(1, 150)))
    end },
  { q = "Moo-tomatic reply: Your message is important to the herd. Please moo to continue.",
    react = function(msg)
      if ns.CountMoos(msg) > 0 then return "Thank you for mooing. Your call has been placed in the herd. Estimated wait: moo minutes." end
      return "Moo-tomatic reply: That was not a moo. Please moo to continue."
    end },
  { q = "Moo-tomatic reply: The cow is busy. Rate your experience with this cow from 1 to 5.",
    react = function(msg)
      local num = tonumber(msg:match("%d+") or "")
      if num and num >= 4 then return "Thank you! The cow has been informed of your " .. num .. "-star review. Moo." end
      if num then return "A " .. num .. "? The cow is devastated. MOOOOOO." end
      return "Moo-tomatic reply: The survey only accepts numbers. And moos."
    end },
}

local whisperedAt = {}
ns:On("CHAT_MSG_WHISPER", function(msg, sender, _, _, _, flags)
  if not Usable(msg) or not Usable(sender) or type(msg) ~= "string" then return end
  if flags == "GM" or flags == "DEV" then return end -- never auto-reply to Blizzard staff
  if not ns.db.triggers.autoReply or ns.db.panic then return end
  ns:GateChat(sender, msg, function() ns:WhisperIn(msg, sender) end)
end)

function ns:WhisperIn(msg, sender)
  local key = "W:" .. sender
  local name = ns.ShortName(sender)
  -- an answer to our question, or something we understand ("fortune", "roast me"...)
  if pending[key] then ns:Converse(msg, name, false, key) return end
  if ns:Converse(msg, name, false, key) then return end
  local now = ns.Now()
  if now - (whisperedAt[sender] or -1000) < 60 or not ns:AllowAutoReply(name) then return end
  whisperedAt[sender] = now
  ns.db.stats.autoReplies = ns.db.stats.autoReplies + 1
  local opener = Pick(WHISPER_OPENERS)
  AskWhisper(sender, opener.q, { react = opener.react })
end

---------------------------------------------------------------------------
-- Ticking
---------------------------------------------------------------------------

table.insert(ns.tickFns, BattleTick)
table.insert(ns.tickFns, TriviaTick)
table.insert(ns.tickFns, VoteTick)
table.insert(ns.tickFns, MooCheckTick)
table.insert(ns.tickFns, InterviewTick)
table.insert(ns.tickFns, function()
  local now = ns.Now()
  for text, t in pairs(ns.recentOutputs) do
    if now - t > 120 then ns.recentOutputs[text] = nil end
  end
end)
