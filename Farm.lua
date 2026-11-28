-- MooHelper: The Farm
-- Milk is MooHelper's currency. You earn it by mooing, hosting games and earning
-- moo-chievements, and your farm produces it on its own once you buy generators.
-- Spend it in the Moo Shop, on Bessie's food, and complete daily Moo Quests for more.

local _, ns = ...

local random = math.random

ns.GENERATORS = {
  { key = "calf", name = "Hire a Calf", cost = 15, mps = 0.1, icon = "Ability_Hunter_Pet_Bear",
    desc = "A calf who moos for you. Badly." },
  { key = "stool", name = "Milking Stool", cost = 100, mps = 0.5, icon = "INV_Misc_Bag_10",
    desc = "Ergonomic. Bessie approves." },
  { key = "hay", name = "Hay Bale Stack", cost = 500, mps = 2, icon = "INV_Misc_Herb_10",
    desc = "Fuel for a very long moo." },
  { key = "barn", name = "Bigger Barn", cost = 2000, mps = 6, icon = "INV_Misc_Bag_11",
    desc = "Room for more cows, and better acoustics." },
  { key = "kodo", name = "Kodo Rental", cost = 7500, mps = 20, icon = "Ability_Mount_Kodo_01",
    desc = "A kodo on a short-term lease. Moos in bass." },
  { key = "pasture", name = "Mulgore Pasture", cost = 30000, mps = 75, icon = "INV_Misc_Map_01",
    desc = "The grass really is greener." },
  { key = "windmill", name = "Thunder Bluff Windmill", cost = 120000, mps = 250, icon = "Spell_Nature_Cyclone",
    desc = "Turns wind into moo. Somehow." },
  { key = "blessing", name = "Earth Mother's Blessing", cost = 500000, mps = 900, icon = "Spell_Holy_SealOfWisdom",
    desc = "The Earth Mother approves of your work." },
  { key = "engine", name = "Perpetual Stampede Engine", cost = 2000000, mps = 3000, icon = "Ability_Rogue_Sprint",
    desc = "Kodos on a treadmill, forever." },
  { key = "moonbase", name = "Moo-n Base", cost = 10000000, mps = 12000, icon = "Spell_Nature_StarFall",
    desc = "The cow finally jumped over the moon. And stayed." },
}
ns.GEN_BY_KEY = {}
for _, g in ipairs(ns.GENERATORS) do ns.GEN_BY_KEY[g.key] = g end

ns.UPGRADES = {
  { key = "loud", name = "Louder Moos", cost = 200, desc = "Every moo makes twice the milk." },
  { key = "diet", name = "Bessie's Diet Plan", cost = 1500, desc = "Feeding Bessie costs half." },
  { key = "cream", name = "Combo Cream", cost = 3000, desc = "Moos in a combo earn extra milk (+1 per 5 combo)." },
  { key = "party", name = "Party Dairy", cost = 4000, desc = "Party games earn three times the milk." },
  { key = "bell", name = "Golden Bell", cost = 8000, desc = "Golden Moos appear twice as often." },
  { key = "udders", name = "Industrial Udders", cost = 25000, desc = "All generators produce twice as much." },
  { key = "synergy", name = "Moo Synergy", cost = 250000, desc = "All generators produce twice as much. Again." },
  { key = "golden", name = "Golden Moo Button", cost = 50000, desc = "Your Moo button turns gold. Purely for status." },
}
ns.UPG_BY_KEY = {}
for _, u in ipairs(ns.UPGRADES) do ns.UPG_BY_KEY[u.key] = u end

local function F() return ns.db.farm end

function ns:FarmInit()
  self.db.farm = self.db.farm or { milk = 0, lifetime = 0, owned = {}, upgrades = {}, quests = {} }
  local f = F()
  f.owned, f.upgrades, f.quests = f.owned or {}, f.upgrades or {}, f.quests or {}
end

function ns:HasUpgrade(key) return F() ~= nil and F().upgrades[key] == true end

function ns:Milk() return F() and F().milk or 0 end

function ns:AddMilk(amount)
  local f = F()
  if not f or amount <= 0 then return end
  if self.inMoonsoon then amount = amount * 2 end
  f.milk = f.milk + amount
  f.lifetime = f.lifetime + amount
end

function ns:SpendMilk(amount)
  local f = F()
  -- (amount ~= amount: NaN compares false with everything, so it would always "fit": issue #12)
  if not f or type(amount) ~= "number" or amount ~= amount or amount < 0 or f.milk < amount then return false end
  f.milk = f.milk - amount
  return true
end

function ns:MilkPerSecond()
  local f = F()
  if not f then return 0 end
  local total = 0
  for _, g in ipairs(ns.GENERATORS) do total = total + (f.owned[g.key] or 0) * g.mps end
  if self:HasUpgrade("udders") then total = total * 2 end
  if self:HasUpgrade("synergy") then total = total * 2 end
  return total
end

function ns:GeneratorCost(key)
  local g = ns.GEN_BY_KEY[key]
  return math.floor(g.cost * (1.15 ^ (F().owned[key] or 0)))
end

function ns:BuyGenerator(key)
  local g = ns.GEN_BY_KEY[key]
  if not g then return false, "No such thing on the farm." end
  local cost = self:GeneratorCost(key)
  if not self:SpendMilk(cost) then return false, ("You need %s milk for that."):format(ns.FormatNumber(cost)) end
  F().owned[key] = (F().owned[key] or 0) + 1
  self:StatChanged()
  return true, ("Bought %s (you have %d)."):format(g.name, F().owned[key])
end

function ns:BuyUpgrade(key)
  local u = ns.UPG_BY_KEY[key]
  if not u then return false, "No such upgrade." end
  if self:HasUpgrade(key) then return false, "You already have that." end
  if not self:SpendMilk(u.cost) then return false, ("You need %s milk for that."):format(ns.FormatNumber(u.cost)) end
  F().upgrades[key] = true
  if key == "golden" and self.UpdateButton then self:UpdateButton() end
  self:StatChanged()
  return true, ("Bought %s."):format(u.name)
end

-- milk from moos, games and achievements
table.insert(ns.mooListeners, function()
  local amount = 1
  if ns:HasUpgrade("loud") then amount = amount * 2 end
  if ns:HasUpgrade("cream") then amount = amount + math.floor((ns.combo or 0) / 5) end
  ns:AddMilk(amount)
end)
function ns:OnGameHosted()
  self:AddMilk(self:HasUpgrade("party") and 60 or 20)
end
function ns:OnAchievement(a)
  self:AddMilk(5 * (a.points or 0) + 10)
  for _, fn in ipairs(ns.achListeners) do
    local ok, err = pcall(fn, a)
    if not ok then table.insert(ns.errors, "achievement listener: " .. tostring(err)) end
  end
end

---------------------------------------------------------------------------
-- Daily Moo Quests: three a day, the same three for everyone on a given date
---------------------------------------------------------------------------

local function TotalShame() local n = 0 for _, c in pairs(ns.db.stats.shame) do n = n + c end return n end
local function GamesHosted()
  local n = 0
  for k, v in pairs(ns.db.stats.c) do if k:sub(1, 7) == "played:" then n = n + v end end
  return n
end
local function Dialects()
  local n = 0
  for k, v in pairs(ns.db.stats.c) do if k:sub(1, 8) == "dialect:" then n = n + v end end
  return n
end

ns.QUEST_POOL = {
  { key = "moo50", text = "Moo 50 times", goal = 50, reward = 150, value = function() return ns.db.stats.total end },
  { key = "moo200", text = "Moo 200 times", goal = 200, reward = 400, value = function() return ns.db.stats.total end },
  { key = "chan3", text = "Moo in 3 different channels", goal = 3, reward = 200, value = function() return ns:GetStat("dailyChannels") end, daily = true },
  { key = "game1", text = "Host a party game", goal = 1, reward = 250, value = GamesHosted },
  { key = "game3", text = "Host 3 party games", goal = 3, reward = 600, value = GamesHosted },
  { key = "back3", text = "Get 3 friends to moo back", goal = 3, reward = 200, value = function() return ns.db.stats.mooBacks end },
  { key = "iv1", text = "Interview a friend", goal = 1, reward = 200, value = function() return ns:GetStat("interviewsAsked") end },
  { key = "feed2", text = "Feed Bessie twice", goal = 2, reward = 150, value = function() return ns:GetStat("bessieFeeds") end },
  { key = "pet5", text = "Pet Bessie 5 times", goal = 5, reward = 120, value = function() return ns:GetStat("bessiePets") end },
  { key = "tauren", text = "Spot a new Tauren", goal = 1, reward = 150, value = function() return ns.db.stats.taurenCount end },
  { key = "combo10", text = "Reach a 10x moo combo", goal = 10, reward = 250, value = function() return ns:GetStat("dailyCombo") end, daily = true, max = true },
  { key = "barrage", text = "Launch a barrage of 5+ moos", goal = 1, reward = 200, value = function() return ns:GetStat("barrages") end },
  { key = "shame", text = "Shame a fire-stander", goal = 1, reward = 200, value = TotalShame },
  { key = "cipher", text = "Send a Moo Cipher message", goal = 1, reward = 150, value = function() return ns:GetStat("cipherEncoded") end },
  { key = "dialect", text = "Speak in a moo dialect", goal = 1, reward = 120, value = Dialects },
}

local function Today() return date("%Y-%m-%d") end

function ns:QuestsForToday()
  local q = F().quests
  local today = Today()
  if q.day ~= today then
    -- a new day: pick three quests from the date, record where each counter starts
    local seed = 0
    for i = 1, #today do seed = (seed * 31 + today:byte(i)) % 2147483647 end
    local picks, used = {}, {}
    local n = #ns.QUEST_POOL
    while #picks < 3 do
      seed = (seed * 1103515245 + 12345) % 2147483648
      local i = (seed % n) + 1
      if not used[i] then used[i] = true picks[#picks + 1] = i end
    end
    self.db.stats.c.dailyChannels, self.db.stats.c.dailyCombo = 0, 0
    q.channels = {}
    q.day, q.list, q.allDone = today, {}, false
    for _, i in ipairs(picks) do
      local def = ns.QUEST_POOL[i]
      q.list[#q.list + 1] = { key = def.key, start = def.daily and 0 or def.value(), done = false }
    end
  end
  return q.list
end

function ns:QuestProgress(entry)
  for _, def in ipairs(ns.QUEST_POOL) do
    if def.key == entry.key then
      return math.min(math.max(def.value() - entry.start, 0), def.goal), def.goal, def
    end
  end
  return 0, 1, nil
end

function ns:CheckQuests()
  if not F() then return end
  local list = self:QuestsForToday()
  local q = F().quests
  local allDone = true
  for _, entry in ipairs(list) do
    local cur, goal, def = self:QuestProgress(entry)
    if not entry.done and def and cur >= goal then
      entry.done = true
      self:AddMilk(def.reward)
      self:Bump("questsDone")
      self:Print(("Daily Moo Quest complete: %s (+%d milk)."):format(def.text, def.reward))
      if self.Toast then self:Toast("MOO QUEST COMPLETE", def.text) end
    end
    if not entry.done then allDone = false end
  end
  if allDone and not q.allDone then
    q.allDone = true
    local yesterday = date("%Y-%m-%d", time() - 86400)
    q.streak = (q.lastFullDay == yesterday) and ((q.streak or 0) + 1) or 1
    q.lastFullDay = q.day
    self:StatMax("questStreakBest", q.streak)
    self:AddMilk(500)
    self:Print(("All daily Moo Quests done! Streak: %d day%s (+500 milk)."):format(q.streak, q.streak == 1 and "" or "s"))
  end
end

-- quests that count "today only" things
-- (the list of today's channels is saved with the quests, so /reload can't count one twice: #16)
table.insert(ns.mooListeners, function(key)
  if not F() then return end
  ns:QuestsForToday()
  local q = F().quests
  q.channels = q.channels or {}
  if not q.channels[key] then
    q.channels[key] = true
    ns.db.stats.c.dailyChannels = (ns.db.stats.c.dailyChannels or 0) + 1
  end
  if (ns.combo or 0) > (ns.db.stats.c.dailyCombo or 0) then ns.db.stats.c.dailyCombo = ns.combo end
end)

local questAcc = 0
table.insert(ns.tickFns, function()
  if not F() then return end
  ns:AddMilk(ns:MilkPerSecond())
  questAcc = questAcc + 1
  if questAcc >= 3 then questAcc = 0 ns:CheckQuests() end
end)

ns:On("PLAYER_LOGIN", function()
  ns:FarmInit()
  -- milk the farm made while you were away (half rate, at most 8 hours)
  local f = F()
  if f.lastSeen then
    local away = math.min(math.max(time() - f.lastSeen, 0), 8 * 3600)
    local earned = math.floor(ns:MilkPerSecond() * away / 2)
    if earned > 0 then
      ns:AddMilk(earned)
      C_Timer.After(5, function() ns:Print(("Your farm made %s milk while you were away."):format(ns.FormatNumber(earned))) end)
    end
  end
end)
table.insert(ns.tickFns, function() if F() then F().lastSeen = time() end end)
