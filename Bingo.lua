-- MooHelper: Moo Bingo
-- A 5x5 card of things that happen while you play (a wipe, someone rolls a 1, someone says
-- "sorry", a Golden Moo...). Squares mark themselves. A full line is BINGO, announced to
-- the party; the whole card is a BLACKOUT.

local _, ns = ...

local Usable = ns.Usable
local random = math.random

ns.BINGO_SQUARES = {
  { "you_die", "You die" }, { "friend_dies", "A friend dies" }, { "wipe", "A wipe" },
  { "boss_kill", "Boss down" }, { "ready_check", "Ready check" }, { "level_up", "You level up" },
  { "quest", "Quest turned in" }, { "roll_1", "Someone rolls a 1" }, { "roll_100", "Someone rolls 100" },
  { "hearth", "Hearthstone" }, { "epic_loot", "Epic loot" }, { "says_moo", "Someone says moo" },
  { "says_lol", "Someone says lol" }, { "says_sorry", "Someone says sorry" }, { "says_pull", "Someone says pull" },
  { "says_brb", "Someone says brb" }, { "golden_moo", "Golden Moo" }, { "moonsoon", "Moo-nsoon" },
  { "stampede", "Stampede Hour" }, { "feed_bessie", "Feed Bessie" }, { "barrage", "Launch a barrage" },
  { "cipher", "Send a cipher" }, { "promotion", "Herd promotion" }, { "moo_fm", "Moo FM plays" },
  { "interview", "Interview answered" }, { "game", "A party game" }, { "cow_duel", "Cow Duel" },
  { "fire", "Someone stands in fire" }, { "afk", "Someone goes AFK" }, { "combo10", "10x moo combo" },
  { "achievement", "Moo-chievement" }, { "mount", "Mount up" }, { "tauren", "Spot a Tauren" },
  { "raid_boss", "Slay a Moo Raid Boss" },
}
local LABEL = {}
for _, s in ipairs(ns.BINGO_SQUARES) do LABEL[s[1]] = s[2] end
ns.BINGO_LABEL = LABEL

local FREE = 13 -- the middle square
local LINES = {}
for r = 0, 4 do
  local row, col = {}, {}
  for c = 0, 4 do row[#row + 1] = r * 5 + c + 1 col[#col + 1] = c * 5 + r + 1 end
  LINES[#LINES + 1] = row
  LINES[#LINES + 1] = col
end
LINES[#LINES + 1] = { 1, 7, 13, 19, 25 }
LINES[#LINES + 1] = { 5, 9, 13, 17, 21 }
ns.BINGO_LINES = LINES

local function Card() return ns.db.bingo end

function ns:NewBingoCard()
  local pool = {}
  for _, s in ipairs(ns.BINGO_SQUARES) do pool[#pool + 1] = s[1] end
  for i = #pool, 2, -1 do local j = random(i) pool[i], pool[j] = pool[j], pool[i] end
  local squares = {}
  for i = 1, 25 do
    if i == FREE then squares[i] = "free" else squares[i] = table.remove(pool) end
  end
  self.db.bingo = { squares = squares, marked = { [FREE] = true }, lines = 0, blackout = false, created = time() }
  if self.RefreshBarn then self:RefreshBarn() end
  return self.db.bingo
end

local function CompletedLines(card)
  local n, cells = 0, {}
  for _, line in ipairs(LINES) do
    local full = true
    for _, i in ipairs(line) do if not card.marked[i] then full = false break end end
    if full then n = n + 1 cells[#cells + 1] = line end
  end
  return n, cells
end
ns.BingoLines = function() return CompletedLines(Card()) end

function ns:BingoMark(key)
  local card = Card()
  if not card or not LABEL[key] then return false end
  local changed = false
  for i, sq in ipairs(card.squares) do
    if sq == key and not card.marked[i] then
      card.marked[i] = true
      changed = true
    end
  end
  if not changed then return false end
  self:Print(("Moo Bingo: |cffffd100%s|r"):format(LABEL[key]))

  local lines, cells = CompletedLines(card)
  if lines > card.lines then
    -- one square can finish two lines at once: each one pays
    for _ = card.lines + 1, lines do
      self:Bump("bingos")
      self:AddMilk(1000)
    end
    card.lines = lines
    local labels = {}
    for _, i in ipairs(cells[#cells]) do
      local sq = card.squares[i]
      labels[#labels + 1] = sq == "free" and "FREE" or LABEL[sq]
    end
    if self.Toast then self:Toast("BINGO!", "+1,000 milk") end
    if self.Stampede then self:Stampede(20) end
    local ch = self:GroupChannel()
    if ch and self.db.triggers.bingoAnnounce and not self.db.panic then
      self:Queue(ch, ("BINGO! My Moo Bingo card just got a line: %s. MOO!"):format(table.concat(labels, ", ")), 2)
    end
  end
  local all = true
  for i = 1, 25 do if not card.marked[i] then all = false break end end
  if all and not card.blackout then
    card.blackout = true
    self:Bump("bingoBlackouts")
    self:AddMilk(5000)
    if self.Toast then self:Toast("BINGO BLACKOUT", "The whole card! +5,000 milk") end
    local ch = self:GroupChannel()
    if ch and self.db.triggers.bingoAnnounce and not self.db.panic then
      self:Queue(ch, "BINGO BLACKOUT! Every square on my Moo Bingo card. I need to go outside. MOO!", 2)
    end
  end
  if self.RefreshBarn then self:RefreshBarn() end
  return true
end

local function Mark(key) ns:BingoMark(key) end

---------------------------------------------------------------------------
-- What marks the squares
---------------------------------------------------------------------------

ns:On("PLAYER_DEAD", function() Mark("you_die") end)
ns:On("ENCOUNTER_END", function(_, _, _, _, success)
  if success == 1 or success == true then Mark("boss_kill") elseif success == 0 or success == false then Mark("wipe") end
end)
ns:On("READY_CHECK", function() Mark("ready_check") end)
ns:On("PLAYER_LEVEL_UP", function() Mark("level_up") end)
ns:On("QUEST_TURNED_IN", function() Mark("quest") end)
ns:On("UNIT_SPELLCAST_SUCCEEDED", function(unit, _, spellID)
  if unit == "player" and Usable(spellID) and spellID == 8690 then Mark("hearth") end
end)

local ROLL = RANDOM_ROLL_RESULT and ns.FormatToPattern and ns.FormatToPattern(RANDOM_ROLL_RESULT)
ns:On("CHAT_MSG_SYSTEM", function(msg)
  if not ROLL or not Usable(msg) or type(msg) ~= "string" then return end
  local _, roll, lo, hi = msg:match(ROLL)
  roll, lo, hi = tonumber(roll), tonumber(lo), tonumber(hi)
  if not roll then return end
  if roll == 1 and lo == 1 then Mark("roll_1") end
  if roll == 100 and hi == 100 then Mark("roll_100") end
end)

local LOOT = {}
for _, fmt in ipairs({ LOOT_ITEM_SELF_MULTIPLE, LOOT_ITEM_SELF }) do
  if fmt and ns.FormatToPattern then LOOT[#LOOT + 1] = ns.FormatToPattern(fmt) end
end
ns:On("CHAT_MSG_LOOT", function(msg)
  if not Usable(msg) or type(msg) ~= "string" then return end
  for _, p in ipairs(LOOT) do
    if msg:match(p) then
      if ns.LinkQuality and (ns.LinkQuality(msg) or 0) >= 4 then Mark("epic_loot") end
      return
    end
  end
end)

-- things people say (typed by people: lines from other copies of the addon don't count)
local SAYS = { { "says_lol", { "lol", "lmao", "rofl" } }, { "says_sorry", { "sorry", "my bad", "mb" } },
  { "says_pull", { "pull", "pulling" } }, { "says_brb", { "brb", "afk" } } }
for _, event in ipairs({ "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER" }) do
  ns:On(event, function(msg, sender)
    if not Usable(msg) or not Usable(sender) or type(msg) ~= "string" or ns:IsOwnOutput(msg, sender) then return end
    ns:GateChat(sender, msg, function()
      if ns.SaysMoo and ns.SaysMoo(msg) then Mark("says_moo") end
      local norm = ns.Normalize(msg)
      for _, s in ipairs(SAYS) do
        if ns.TextHasAny(norm, s[2]) then Mark(s[1]) end
      end
    end)
  end)
end

-- MooHelper's own moments
local BUMPS = { goldenMoos = "golden_moo", moonsoons = "moonsoon", stampedeHours = "stampede",
  bessieFeeds = "feed_bessie", barrages = "barrage", cipherEncoded = "cipher", promotions = "promotion",
  fmSegments = "moo_fm", interviewsAnswered = "interview", cowDuels = "cow_duel", bossKills = "raid_boss" }
table.insert(ns.bumpListeners, function(key)
  if BUMPS[key] then Mark(BUMPS[key]) end
  if key:sub(1, 7) == "played:" then Mark("game") end
end)
table.insert(ns.achListeners, function() Mark("achievement") end)
ns:OnSignal("friendDeath", function() Mark("friend_dies") end)
ns:OnSignal("shamed", function() Mark("fire") end)
ns:OnSignal("afk", function() Mark("afk") end)
ns:OnSignal("combo10", function() Mark("combo10") end)

local wasMounted = false
table.insert(ns.tickFns, function()
  local mounted = IsMounted and IsMounted() or false
  if Usable(mounted) then
    if mounted and not wasMounted then Mark("mount") end
    wasMounted = mounted and true or false
  end
end)
local lastTaurens
table.insert(ns.tickFns, function()
  local n = ns.db.stats.taurenCount
  if lastTaurens and n > lastTaurens then Mark("tauren") end
  lastTaurens = n
end)

ns:On("PLAYER_LOGIN", function()
  if not ns.db.bingo or not ns.db.bingo.squares then ns:NewBingoCard() end
end)
