-- MooHelper: the Moo Arcade
-- More party games, all played through ordinary party chat:
--   Quick Draw Moo   first to type MOO after DRAW wins; too early and you're out
--   Moo-gman         hangman with cow words; guess letters in chat
--   Cow Scramble     unscramble a cow word
--   Moo Math         first right answer wins
--   Moo Tales        each friend adds a line to a story, then the herd performs it
--   Moo Theater      a short play, starring your party
--   Cow Tipping      sneak up on a friend and try to tip them over

local _, ns = ...

local random = math.random
local function Pick(list) return list[random(#list)] end
local GAME = 3

local function Group(text, priority, maxAge) return ns.GroupSay(text, priority or GAME, maxAge or 90) end
local function Hosted(key)
  ns:Bump("played:" .. key)
  if ns.OnGameHosted then ns:OnGameHosted() end
end

function ns:ArcadeBusy()
  return self.draw or self.hangman or self.scramble or self.mathq or self.tales
end
local function CanStart(stateless, key) return ns:BeginGame(stateless, key) end

---------------------------------------------------------------------------
-- Quick Draw Moo
---------------------------------------------------------------------------

local DRAW_LINE = "DRAW!!! TYPE MOO NOW!"

function ns:StartQuickDraw(starter)
  local ok, why = CanStart(false, "draw")
  if not ok then return false, why end
  self.draw = { phase = "wait", drawAt = ns.Now() + random(4, 9), out = {} }
  if self.ShareQuiet then self:ShareQuiet(30) end
  Hosted("draw")
  Group(("QUICK DRAW MOO!%s When I say DRAW, the first to type MOO wins. Type early and you're OUT. Get ready...")
    :format(starter and (" " .. starter .. " wants a showdown.") or ""))
  self:AddGroupListener("draw", function(msg, name, isSelf)
    local d = ns.draw
    if not d or ns.CountMoos(msg) == 0 then return end
    if d.phase == "wait" then
      if not d.out[name] then
        d.out[name] = true
        Group(("%s drew too early and is DISQUALIFIED. Moo."):format(name))
      end
    elseif d.phase == "draw" and not d.out[name] then
      local secs = ns.Now() - d.drawnAt
      ns.draw = nil
      ns:RemoveGroupListener("draw")
      Group(("%s wins the Quick Draw in %.1f seconds! Fastest moo in the west. MOO!"):format(name, secs))
      ns:HerdAward(name, 5, "wins")
      if isSelf then ns:Bump("quickdrawWins") end
    end
  end)
  return true
end

local function DrawTick()
  ns:UseGameScope("draw")
  local d = ns.draw
  if not d then return end
  local now = ns.Now()
  if d.phase == "wait" and now >= d.drawAt and not d.queued then
    d.queued = true
    Group(DRAW_LINE)
  end
  -- the draw only counts from the moment the line actually went out
  if d.phase == "wait" and d.queued and ns.recentOutputs[DRAW_LINE] then
    d.phase = "draw"
    d.drawnAt = ns.recentOutputs[DRAW_LINE]
  end
  if d.phase == "draw" and now - d.drawnAt > 15 then
    ns.draw = nil
    ns:RemoveGroupListener("draw")
    Group("Nobody drew. Tumbleweeds roll through the pasture. Moo.")
  end
end

---------------------------------------------------------------------------
-- Moo-gman (hangman)
---------------------------------------------------------------------------

ns.COW_WORDS = { "calf", "bull", "herd", "kodo", "udder", "barn", "milk", "pasture", "stampede", "bovine",
  "heifer", "mulgore", "cowbell", "dairy", "cheese", "butter", "grazing", "tauren", "totem", "windmill",
  "hayloft", "meadow", "cud", "moo", "bloodhoof", "thunderbluff", "rancher", "lasso" }

local function Pattern(h)
  local out = {}
  for ch in h.word:gmatch(".") do out[#out + 1] = h.guessed[ch] and ch or "_" end
  return table.concat(out, " ")
end

local function Solved(h)
  for ch in h.word:gmatch(".") do if not h.guessed[ch] then return false end end
  return true
end

function ns:StartHangman(starter)
  local ok, why = CanStart(false, "hangman")
  if not ok then return false, why end
  local h = { word = Pick(ns.COW_WORDS), guessed = {}, wrong = {}, maxWrong = 6, idleUntil = ns.Now() + 90 }
  self.hangman = h
  Hosted("hangman")
  Group(("MOO-GMAN!%s Guess the cow word: %s (%d letters). Type single letters or the whole word. %d wrong guesses and the cow gets it.")
    :format(starter and (" (" .. starter .. "'s idea)") or "", Pattern(h), #h.word, h.maxWrong))
  self:AddGroupListener("hangman", function(msg, name)
    local g = ns.hangman
    if not g then return end
    local guess = msg:lower():gsub("^%s+", ""):gsub("%s+$", "")
    if guess == g.word then
      ns.hangman = nil
      ns:RemoveGroupListener("hangman")
      Group(("%s solved it: %s! MOO!"):format(name, g.word:upper()))
      ns:HerdAward(name, 5, "wins")
      return
    end
    if not guess:find("^%a$") or g.guessed[guess] or g.wrong[guess] then return end
    g.idleUntil = ns.Now() + 90 -- someone's still playing
    if g.word:find(guess, 1, true) then
      g.guessed[guess] = true
      ns:HerdAward(name, 1)
      if Solved(g) then
        ns.hangman = nil
        ns:RemoveGroupListener("hangman")
        Group(("%s finished it: %s! The cow is saved. MOO!"):format(name, g.word:upper()))
        ns:HerdAward(name, 4, "wins")
        return
      end
    else
      g.wrong[guess] = true
      g.misses = (g.misses or 0) + 1
      if g.misses >= g.maxWrong then
        ns.hangman = nil
        ns:RemoveGroupListener("hangman")
        Group(("Out of guesses! The word was %s. The cow has been... mooed. RIP."):format(g.word:upper()))
        return
      end
    end
    local wrongList = {}
    for ch in pairs(g.wrong) do wrongList[#wrongList + 1] = ch end
    table.sort(wrongList)
    Group(("MOO-GMAN: %s   wrong: %s (%d/%d)"):format(Pattern(g), #wrongList > 0 and table.concat(wrongList, " ") or "-",
      g.misses or 0, g.maxWrong), GAME, 30)
  end)
  return true
end

---------------------------------------------------------------------------
-- Cow Scramble and Moo Math (first right answer wins)
---------------------------------------------------------------------------

local function Shuffle(word)
  for _ = 1, 10 do
    local t = {}
    for ch in word:gmatch(".") do t[#t + 1] = ch end
    for i = #t, 2, -1 do local j = random(i) t[i], t[j] = t[j], t[i] end
    local s = table.concat(t)
    if s ~= word then return s end
  end
  return word:reverse()
end

local function QuickQuestion(stateKey, question, check, reveal, points)
  ns[stateKey] = { endsAt = ns.Now() + 30, reveal = reveal }
  Group(question)
  ns:AddGroupListener(stateKey, function(msg, name)
    local st = ns[stateKey]
    if st and check(msg) then
      ns[stateKey] = nil
      ns:RemoveGroupListener(stateKey)
      Group(("%s got it: %s. MOO!"):format(name, reveal))
      ns:HerdAward(name, points, "wins")
    end
  end)
end

function ns:StartScramble(starter)
  local ok, why = CanStart(false, "scramble")
  if not ok then return false, why end
  local pool = {}
  for _, w in ipairs(ns.COW_WORDS) do if #w >= 4 then pool[#pool + 1] = w end end
  local word = Pick(pool)
  Hosted("scramble")
  QuickQuestion("scramble", ("COW SCRAMBLE%s: unscramble '%s' (30 seconds)"):format(starter and (" for " .. starter) or "", Shuffle(word)),
    function(msg) return ns.TextHas(ns.Normalize(msg), word) end, word:upper(), 4)
  return true
end

function ns:StartMath(starter)
  local ok, why = CanStart(false, "mathq")
  if not ok then return false, why end
  local a, b, op, answer
  local kind = random(3)
  if kind == 1 then a, b = random(12, 99), random(12, 99) op, answer = "+", a + b
  elseif kind == 2 then a, b = random(40, 99), random(2, 39) op, answer = "-", a - b
  else a, b = random(3, 12), random(3, 12) op, answer = "x", a * b end
  Hosted("math")
  QuickQuestion("mathq", ("MOO MATH%s: what is %d %s %d? (30 seconds)"):format(starter and (" for " .. starter) or "", a, op, b),
    function(msg) return tonumber(msg:match("%-?%d+")) == answer end, tostring(answer), 3)
  return true
end

-- a hangman game nobody is playing ends after 90 quiet seconds, so it can't block other games
local function HangmanTick()
  ns:UseGameScope("hangman")
  local h = ns.hangman
  if h and ns.Now() >= h.idleUntil then
    ns.hangman = nil
    ns:RemoveGroupListener("hangman")
    Group(("Nobody's guessing. Moo-gman is over; the word was %s. Moo."):format(h.word:upper()))
  end
end

local function QuickTick()
  for _, key in ipairs({ "scramble", "mathq" }) do
    local st = ns[key]
    ns:UseGameScope(key)
    if st and ns.Now() >= st.endsAt then
      ns[key] = nil
      ns:RemoveGroupListener(key)
      Group(("Time's up! The answer was %s. Moo."):format(st.reveal))
    end
  end
end

---------------------------------------------------------------------------
-- Moo Tales: a story written by the party, one line each
---------------------------------------------------------------------------

local OPENINGS = {
  "Once upon a time in Mulgore, a cow named %s looked up at the sky and said: moo.",
  "It was a dark and stormy night in Thunder Bluff. %s the cow could not sleep.",
  "Long ago, before the great stampede, a calf named %s found a mysterious bell.",
}

function ns:StartTales(starter)
  local ok, why = CanStart(false, "tales")
  if not ok then return false, why end
  local members = ns:GameMembers()
  if #members == 0 then
    return false, self.gameScope == "guild" and "Moo Tales needs guildmates who've spoken in guild chat recently."
      or "Moo Tales needs friends in your group to write it."
  end
  for i = #members, 2, -1 do local j = random(i) members[i], members[j] = members[j], members[i] end
  local order = {}
  for i = 1, math.min(4, #members) do order[i] = members[i] end
  local cowName = self.db.bessie and self.db.bessie.name or "Bessie"
  local opening = Pick(OPENINGS):format(cowName)
  self.tales = { order = order, idx = 0, lines = { { text = opening, by = "the narrator" } } }
  Hosted("tales")
  Group(("MOO TALES! The herd will write a story together%s. %s"):format(starter and (", as requested by " .. starter) or "", opening))
  local function Prompt()
    local t = ns.tales
    t.idx = t.idx + 1
    local who = t.order[t.idx]
    if not who then
      ns.tales = nil
      ns:RemoveGroupListener("tales")
      Group("THE END. Here is the tale, as told by the herd:", GAME, 180)
      for _, l in ipairs(t.lines) do Group(("  %s (%s)"):format(l.text, l.by), GAME, 180) end
      Group("And now, for our bovine readers, the moo edition: " .. ns.MooTranslate(t.lines[#t.lines].text), GAME, 180)
      return
    end
    t.waiting, t.deadline = who, ns.Now() + 45
    Group(("%s, what happens next? (reply in %s chat)"):format(who, ns:ChatName()))
  end
  self.tales.prompt = Prompt
  self:AddGroupListener("tales", function(msg, name)
    local t = ns.tales
    if not t or name ~= t.waiting then return end
    t.waiting = nil
    t.lines[#t.lines + 1] = { text = ns.Clean(msg):sub(1, 110), by = name }
    ns:HerdAward(name, 3, "answers")
    t.prompt()
  end)
  Prompt()
  return true
end

local function TalesTick()
  ns:UseGameScope("tales")
  local t = ns.tales
  if t and t.waiting and ns.Now() >= t.deadline then
    local who = t.waiting
    t.waiting = nil
    t.lines[#t.lines + 1] = { text = "And then nothing happened, because " .. who .. " fell asleep.", by = "the narrator" }
    t.prompt()
  end
end

---------------------------------------------------------------------------
-- Moo Theater: a short play starring your party
---------------------------------------------------------------------------

ns.PLAYS = {
  { title = "The Lost Calf", roles = { "the Farmer", "the Calf" }, lines = {
    "{1} (the Farmer): Has anyone seen my calf? She is small, she is brown, she says moo.",
    "{2} (the Calf): moo.",
    "{1} (the Farmer): That sounded close.",
    "{2} (the Calf): MOO.",
    "{1} (the Farmer): ...Have you been standing behind me this whole time?",
    "{2} (the Calf): moo (yes).",
  } },
  { title = "Stand Not In The Fire", roles = { "the Tank", "the Healer", "the Cow" }, lines = {
    "{1} (the Tank): I shall pull the whole room.",
    "{2} (the Healer): Please don't.",
    "{1} (the Tank): *pulls the whole room*",
    "{3} (the Cow): MOOOOOOOO!",
    "{2} (the Healer): Everyone, get out of the fire.",
    "{3} (the Cow): *stands in the fire* ...moo.",
  } },
  { title = "The Great Hay Heist", roles = { "the Mastermind", "the Getaway Kodo", "the Barn Guard" }, lines = {
    "{1} (the Mastermind): The hay is kept in the barn. Tonight, we take it.",
    "{2} (the Getaway Kodo): I'll keep the engine running. I am the engine.",
    "{3} (the Barn Guard): Halt! Who goes there?",
    "{1} (the Mastermind): ...Moo?",
    "{3} (the Barn Guard): Oh. Carry on, cow.",
    "{2} (the Getaway Kodo): *drives off with all the hay* MOOOOOO!",
  } },
}

function ns:StartTheater(starter)
  local ok, why = CanStart(true)
  if not ok then return false, why end
  local play = Pick(ns.PLAYS)
  local cast = ns:GameMembers()
  table.insert(cast, 1, UnitName("player") or "You")
  for i = #cast, 2, -1 do local j = random(i) cast[i], cast[j] = cast[j], cast[i] end
  local fillers = { self.db.bessie and self.db.bessie.name or "Bessie", "a confused kodo", "a passing plainstrider" }
  local actors, billing = {}, {}
  for i, role in ipairs(play.roles) do
    actors[i] = cast[i] or table.remove(fillers, 1)
    billing[#billing + 1] = actors[i] .. " as " .. role
  end
  Hosted("theater")
  Group(("MOO THEATER presents: \"%s\"%s. Starring %s."):format(play.title,
    starter and (" (by popular demand of " .. starter .. ")") or "", table.concat(billing, ", ")), GAME, 180)
  for _, line in ipairs(play.lines) do
    Group((line:gsub("{(%d)}", function(i) return actors[tonumber(i)] end)), GAME, 180)
  end
  Group("THE END. Please applaud. Moo.", GAME, 180)
  return true
end

---------------------------------------------------------------------------
-- Cow Tipping
---------------------------------------------------------------------------

function ns:CowTip(target, by)
  local ok, why = CanStart(true)
  if not ok then return false, why end
  by = by or UnitName("player") or "Someone"
  if not target or target == "" then
    local members = ns:GameMembers()
    target = #members > 0 and Pick(members) or (self.db.bessie and self.db.bessie.name or "Bessie")
  end
  target = ns.Clean(target):sub(1, 30)
  Hosted("tip")
  Group(("*%s sneaks up on %s in the moonlight...*"):format(by, target))
  local r = random()
  if r < 0.45 then
    Group(("TIP! %s has been tipped over. Moo."):format(target))
  elseif r < 0.9 then
    Group(("%s was awake the whole time and stares at %s. Awkward. Moo."):format(target, by))
  else
    Group(("%s tips over, rolls down the hill and lands somewhere in Mulgore. MOOOOOOO!"):format(target))
  end
  return true
end

---------------------------------------------------------------------------
-- The game list (the Barn's Games tab and the moo-chievements use it)
---------------------------------------------------------------------------

ns.GAME_LIST = {
  { key = "battle", name = "MOO-OFF", icon = "INV_Misc_Trophy_01", desc = "Most moos typed in 30 seconds wins.",
    start = function() return ns:StartMooOff() end, say = "moo off" },
  { key = "trivia", name = "Moo Trivia", icon = "INV_Misc_Book_09", desc = "Five cow and Tauren questions.",
    start = function() return ns:StartTrivia() end, say = "trivia" },
  { key = "vote", name = "The Rigged Vote", icon = "INV_Misc_Note_01", desc = "Everyone votes. MOO wins.",
    start = function() return ns:StartVote("") end, say = "vote <question>" },
  { key = "sing", name = "Moo Karaoke", icon = "INV_Misc_Drum_01", desc = "An original moo ballad.",
    start = function() return ns:Sing() end, say = "sing" },
  { key = "roulette", name = "Moo-lette", icon = "INV_Misc_Bomb_04", desc = "Lose and owe an ALL-CAPS MOO.",
    start = function() return ns:Roulette() end, say = "roulette" },
  { key = "check", name = "Moo Check", icon = "Spell_Holy_SealOfWisdom", desc = "Everyone types moo, or else.",
    start = function() return ns:StartMooCheck() end, say = "moo check" },
  { key = "draw", name = "Quick Draw Moo", icon = "INV_Weapon_Rifle_01", desc = "First MOO after DRAW wins.",
    start = function() return ns:StartQuickDraw() end, say = "quick draw" },
  { key = "hangman", name = "Moo-gman", icon = "INV_Misc_Note_02", desc = "Hangman with cow words.",
    start = function() return ns:StartHangman() end, say = "hangman" },
  { key = "scramble", name = "Cow Scramble", icon = "INV_Misc_Dice_01", desc = "Unscramble a cow word.",
    start = function() return ns:StartScramble() end, say = "scramble" },
  { key = "math", name = "Moo Math", icon = "INV_Misc_Dice_02", desc = "First right answer wins.",
    start = function() return ns:StartMath() end, say = "moo math" },
  { key = "tales", name = "Moo Tales", icon = "INV_Misc_Book_11", desc = "The party writes a story, line by line.",
    start = function() return ns:StartTales() end, say = "story time" },
  { key = "theater", name = "Moo Theater", icon = "INV_Misc_Head_Dragon_01", desc = "A short play starring your party.",
    start = function() return ns:StartTheater() end, say = "theater" },
  { key = "tip", name = "Cow Tipping", icon = "Ability_Mount_Kodo_01", desc = "Sneak up on a friend.",
    start = function() return ns:CowTip() end, say = "tip <name>" },
}

---------------------------------------------------------------------------
-- Things friends can say (added in front of the catch-all "ask" and "mention" intents)
---------------------------------------------------------------------------

local Has, HasAny = ns.TextHas, ns.TextHasAny
local function GameStart(fn)
  return function(name, msg) local ok, why = fn(name, msg) return not ok and why or nil end
end

local NEW_INTENTS = {
  { id = "draw", groupOnly = true, match = function(n) return HasAny(n, { "quick draw", "quickdraw", "duel", "high noon" }) end,
    run = GameStart(function(name) return ns:StartQuickDraw(name) end) },
  { id = "hangman", groupOnly = true, match = function(n) return HasAny(n, { "hangman", "moogman", "moo gman" }) end,
    run = GameStart(function(name) return ns:StartHangman(name) end) },
  { id = "scramble", groupOnly = true, match = function(n) return Has(n, "scramble") end,
    run = GameStart(function(name) return ns:StartScramble(name) end) },
  { id = "math", groupOnly = true, match = function(n) return HasAny(n, { "moo math", "math" }) end,
    run = GameStart(function(name) return ns:StartMath(name) end) },
  { id = "tales", groupOnly = true, match = function(n) return HasAny(n, { "story time", "tell a story", "moo tales", "story" }) end,
    run = GameStart(function(name) return ns:StartTales(name) end) },
  { id = "theater", groupOnly = true, match = function(n) return HasAny(n, { "theater", "theatre", "put on a play" }) end,
    run = GameStart(function(name) return ns:StartTheater(name) end) },
  { id = "tip", groupOnly = true, match = function(n) return HasAny(n, { "cow tip", "cow tipping", "tip" }) end,
    run = function(name, msg)
      local target = ns.TextAfter(msg, "tip"):match("^(%S+)")
      if target and target:lower() == "over" then target = nil end
      local ok, why = ns:CowTip(target, name)
      return not ok and why or nil
    end },
  { id = "horoscope", match = function(n) return HasAny(n, { "horoscope", "moo roscope", "mooroscope" }) end,
    run = function(name) return ns:Horoscope(name) end },
  { id = "herd", match = function(n) return HasAny(n, { "my rank", "herd rank", "herd ranks", "top herd", "the herd" }) end,
    run = function(name)
      local rank, points = ns:HerdRankName(name)
      local top = ns:HerdTop(3)
      local parts = {}
      for i, e in ipairs(top) do parts[#parts + 1] = ("%d. %s (%d)"):format(i, e.name, e.points) end
      return ("%s: %s, %d herd points. Top of the herd: %s. Moo."):format(name, rank, points,
        #parts > 0 and table.concat(parts, "  ") or "nobody yet")
    end },
  { id = "fm", match = function(n) return HasAny(n, { "moo fm", "radio" }) end,
    run = function() local ok, why = ns:MooFM() return not ok and why or nil end },
  { id = "bessie", match = function(n)
      local cow = ns.db.bessie and ns.db.bessie.name:lower() or "bessie"
      return HasAny(n, { "bessie", "your cow", "the cow", cow })
    end,
    run = function()
      local b = ns.db.bessie
      local _, mood = ns:BessieMood()
      return ("%s the %s (%d xp): she %s Moo."):format(b.name, ns:BessieStageName(), b.xp, mood)
    end },
  { id = "milk", match = function(n) return HasAny(n, { "how much milk", "your milk", "milk count" }) end,
    run = function()
      return ("I have %s milk and my farm makes %.1f milk a second. Moo."):format(ns.FormatNumber(ns:Milk()), ns:MilkPerSecond())
    end },
  { id = "achievements", match = function(n) return HasAny(n, { "achievements", "moo chievements", "moochievements", "achievement points" }) end,
    run = function()
      if not ns.Ach or not ns.Ach.char then return nil end
      local done, total, points = ns.Ach:GetSummary()
      return ("Moo-chievements: %d of %d earned, %d points. Moo."):format(done, total, points)
    end },
}

-- put them before the catch-alls so "anton, start a duel" starts a duel instead of a Moo-Ball answer
local insertAt = #ns.INTENTS + 1
for i, intent in ipairs(ns.INTENTS) do
  if intent.id == "ask" then insertAt = i break end
end
for i, intent in ipairs(NEW_INTENTS) do table.insert(ns.INTENTS, insertAt + i - 1, intent) end

table.insert(ns.tickFns, DrawTick)
table.insert(ns.tickFns, QuickTick)
table.insert(ns.tickFns, HangmanTick)
table.insert(ns.tickFns, TalesTick)
