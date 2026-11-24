-- MooHelper: moo achievements and the barnyard theme for the ported achievement system.
-- Loaded after the ported data files and every MooHelper module, so it can read their lists.

local _, MH = ...
local A = MH.Ach

---------------------------------------------------------------------------
-- Barnyard names for the ported categories
---------------------------------------------------------------------------

local THEME = {
  general = "Barnyard Basics", leveling = "Growing Up", quests = "Errands for the Farmer",
  exploration = "Open Pastures", combat = "Horns Out", dungeons = "Caves & Cellars",
  raids = "Stampedes", professions = "Farmhand Trades", reputation = "Herd Relations",
  pvp = "Bull Fights", social = "Herd Life", account = "The Whole Herd", feats = "Legendary Moos",
}
for key, name in pairs(THEME) do
  if A.categories[key] then A.categories[key].name = name end
end

-- Moo categories go first in the list
local MOO_CATS = {
  { "moo", "Moo Mastery" }, { "games", "Party Animal" }, { "farm", "The Farm" },
  { "bessie", "Bessie" }, { "herd", "The Herd" }, { "weird", "Strange Moos" },
}
for i, c in ipairs(MOO_CATS) do
  A:AddCategory(c[1], c[2])
  -- AddCategory appends; move it to the front, keeping the moo order
  for j, key in ipairs(A.categoryOrder) do
    if key == c[1] then table.remove(A.categoryOrder, j) break end
  end
  table.insert(A.categoryOrder, i, c[1])
end

-- The ported "seen other addon users" achievements now count the herd instead
if A.byId.inspect1 then
  A.byId.inspect1.desc = "Get a friend to answer a Moo Interview."
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function Stat(key) return function() return MH:GetStat(key) end end
local function Field(key) return function() return MH.db and MH.db.stats[key] or 0 end end
local function Sum(t) local n = 0 for _, v in pairs(t or {}) do n = n + v end return n end
local function CountKeys(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end

-- value(): current number; tiers: { id, name, desc, goal, points, icon }
local function Tiers(category, value, tiers)
  for _, t in ipairs(tiers) do
    local goal = t[4]
    A:Add({
      id = t[1], category = category, name = t[2], desc = t[3], points = t[5], icon = t[6],
      progress = function() return math.min(value(), goal), goal end,
    })
  end
end

local function Once(category, id, name, desc, points, icon, test, hidden)
  A:Add({ id = id, category = category, name = name, desc = desc, points = points, icon = icon,
    hidden = hidden, check = function() return MH.db ~= nil and test() end })
end

local MOO_ICON, KODO = "Spell_Holy_MindVision", "Ability_Mount_Kodo_01"

---------------------------------------------------------------------------
-- Moo Mastery
---------------------------------------------------------------------------

Tiers("moo", Field("total"), {
  { "m_moo1", "First Moo", "Moo for the first time.", 1, 5, KODO },
  { "m_moo10", "Finding Your Voice", "Moo 10 times.", 10, 5, KODO },
  { "m_moo50", "Moo-tivated", "Moo 50 times.", 50, 5, KODO },
  { "m_moo100", "Moo-ving Up", "Moo 100 times.", 100, 10, KODO },
  { "m_moo250", "Quarter Thousand Moos", "Moo 250 times.", 250, 10, KODO },
  { "m_moo500", "Moo-nificent", "Moo 500 times.", 500, 15, KODO },
  { "m_moo1000", "One Thousand Moos", "Moo 1,000 times.", 1000, 20, KODO },
  { "m_moo2500", "Moo-ssive", "Moo 2,500 times.", 2500, 25, KODO },
  { "m_moo5000", "Moo-numental", "Moo 5,000 times.", 5000, 30, KODO },
  { "m_moo10000", "Bovine Ascension", "Moo 10,000 times.", 10000, 40, KODO },
  { "m_moo25000", "The Moo That Never Ends", "Moo 25,000 times.", 25000, 50, KODO },
  { "m_moo100000", "Heat Death of the Moo-niverse", "Moo 100,000 times.", 100000, 100, KODO },
})
Tiers("moo", Field("bestCombo"), {
  { "m_combo5", "Combo Starter", "Reach a 5x moo combo.", 5, 5, "Ability_Rogue_Sprint" },
  { "m_combo10", "C-C-C-COMBO", "Reach a 10x moo combo.", 10, 10, "Ability_Rogue_Sprint" },
  { "m_combo25", "Moo-ltiplier", "Reach a 25x moo combo.", 25, 15, "Ability_Rogue_Sprint" },
  { "m_combo50", "Stampede", "Reach a 50x moo combo.", 50, 25, "Ability_Rogue_Sprint" },
  { "m_combo100", "Finger Cramp", "Reach a 100x moo combo.", 100, 40, "Ability_Rogue_Sprint" },
})
Tiers("moo", function() return CountKeys(MH.db and MH.db.stats.byChannel) end, {
  { "m_chan3", "Moo Around Town", "Moo in 3 different channels.", 3, 5, "INV_Letter_01" },
  { "m_chan5", "Moo-lti-channel", "Moo in 5 different channels.", 5, 10, "INV_Letter_01" },
  { "m_chan8", "Omnipresent Moo", "Moo in 8 different channels.", 8, 20, "INV_Letter_01" },
})
local function ChannelMoos(key) return function() return MH.db and MH.db.stats.byChannel[key] or 0 end end
Tiers("moo", ChannelMoos("SAY"), { { "m_say100", "Say It Loud", "Moo 100 times in /say.", 100, 10, MOO_ICON } })
Tiers("moo", ChannelMoos("YELL"), { { "m_yell100", "Outside Voice", "Moo 100 times in /yell.", 100, 15, MOO_ICON } })
Tiers("moo", ChannelMoos("PARTY"), { { "m_party250", "Party Pooper", "Moo 250 times in party chat.", 250, 15, MOO_ICON } })
Tiers("moo", ChannelMoos("GUILD"), { { "m_guild100", "Guild Moo-ster", "Moo 100 times in guild chat.", 100, 15, MOO_ICON } })
Tiers("moo", ChannelMoos("EMOTE"), { { "m_emote50", "Body Moo-vement", "Moo 50 times as an emote.", 50, 10, MOO_ICON } })
Tiers("moo", function()
  local n = 0
  for k, v in pairs(MH.db and MH.db.stats.byChannel or {}) do if k:sub(1, 3) == "CH:" then n = n + v end end
  return n
end, {
  { "m_public10", "Town Crier", "Moo 10 times in General, Trade or another public channel.", 10, 10, "INV_Misc_Horn_01" },
  { "m_public100", "Public Menace", "Moo 100 times in public channels.", 100, 25, "INV_Misc_Horn_01" },
})
Tiers("moo", Stat("barrages"), {
  { "m_barrage1", "Shock and Moo", "Launch a barrage of 5 or more moos.", 1, 10, "INV_Misc_Bomb_04" },
  { "m_barrage25", "Moo Artillery", "Launch 25 barrages.", 25, 20, "INV_Misc_Bomb_04" },
})
Tiers("moo", Stat("launchChannels"), { { "m_launch5", "Moo Logistics", "Launch moos into 5 different channels.", 5, 10, "INV_Misc_Bomb_04" } })
for i, r in ipairs(MH.RANKS) do
  if i > 1 then
    Once("moo", "m_rank" .. i, r[2], ("Reach the moo rank of %s (%d lifetime moos)."):format(r[2], r[1]),
      math.min(5 + i * 5, 50), "Spell_Holy_SurgeOfLight", function() return MH.db.stats.total >= r[1] end)
  end
end
Tiers("moo", Field("mooBacks"), {
  { "m_back1", "Moo-tual Respect", "Moo back at someone.", 1, 5, MOO_ICON },
  { "m_back50", "Call and Response", "Moo back 50 times.", 50, 15, MOO_ICON },
  { "m_back500", "Echo Chamber", "Moo back 500 times.", 500, 30, MOO_ICON },
})
Tiers("moo", Field("taurenCount"), {
  { "m_tauren1", "Kindred Spirit", "Spot another Tauren.", 1, 5, KODO },
  { "m_tauren25", "Herd Census", "Spot 25 different Taurens.", 25, 10, KODO },
  { "m_tauren100", "Census Taker", "Spot 100 different Taurens.", 100, 20, KODO },
  { "m_tauren500", "The Great Migration", "Spot 500 different Taurens.", 500, 40, KODO },
})
Tiers("moo", Stat("clockChimes"), {
  { "m_clock1", "BONG", "Hear the Moo Clock chime.", 1, 5, "INV_Misc_PocketWatch_01" },
  { "m_clock24", "Around the Clock", "Hear the Moo Clock chime 24 times.", 24, 20, "INV_Misc_PocketWatch_01" },
})
Tiers("moo", Field("autoReplies"), {
  { "m_reply1", "Moo-tomaton", "Hold a whisper conversation.", 1, 5, "INV_Letter_02" },
  { "m_reply50", "Call Center Cow", "Hold 50 whisper conversations.", 50, 20, "INV_Letter_02" },
})
Tiers("moo", function() return Sum(MH.db and MH.db.stats.shame) end, {
  { "m_shame1", "Fire Warden", "Shame a fire-stander with Moo-litism.", 1, 5, "Spell_Fire_Fire" },
  { "m_shame25", "Hall Monitor", "Shame 25 fire-standers.", 25, 15, "Spell_Fire_Fire" },
  { "m_shame100", "Elitist Bovine", "Shame 100 fire-standers.", 100, 25, "Spell_Fire_Fire" },
})
Once("moo", "m_selfshame", "Self-Moo-litism", "Get shamed by your own addon.", 10, "Spell_Fire_Fire",
  function() return (MH.db.stats.shame[UnitName("player") or "?"] or 0) > 0 end)

---------------------------------------------------------------------------
-- Party Animal (games)
---------------------------------------------------------------------------

for _, g in ipairs(MH.GAME_LIST or {}) do
  Tiers("games", Stat("played:" .. g.key), {
    { "g_" .. g.key .. "1", g.name, "Run a game of " .. g.name .. ".", 1, 5, g.icon or "INV_Misc_Dice_01" },
    { "g_" .. g.key .. "10", g.name .. " Regular", "Run " .. g.name .. " 10 times.", 10, 10, g.icon or "INV_Misc_Dice_01" },
    { "g_" .. g.key .. "50", g.name .. " Legend", "Run " .. g.name .. " 50 times.", 50, 20, g.icon or "INV_Misc_Dice_01" },
  })
end
A:Add({ id = "g_all", category = "games", name = "Game Night", desc = "Run every party game at least once.",
  points = 30, icon = "INV_Misc_Dice_02",
  progress = function()
    local n, total = 0, 0
    for _, g in ipairs(MH.GAME_LIST or {}) do
      total = total + 1
      if MH:GetStat("played:" .. g.key) > 0 then n = n + 1 end
    end
    return n, math.max(total, 1)
  end })
Once("games", "g_mooffwin", "Champion of the Herd", "Win your own MOO-OFF.", 15, "INV_Misc_Trophy_01",
  function() return (MH.db.stats.mooOffWins[UnitName("player") or "?"] or 0) > 0 end)
Tiers("games", Stat("quickdrawWins"), { { "g_draw_win", "Fastest Moo in the West", "Win Quick Draw Moo yourself.", 1, 15, "INV_Weapon_Rifle_01" } })
Tiers("games", Stat("interviewsAsked"), {
  { "g_iv1", "Hard-Hitting Journalism", "Hold a Moo Interview.", 1, 5, "INV_Misc_Note_01" },
  { "g_iv25", "Moo Times Reporter", "Hold 25 Moo Interviews.", 25, 15, "INV_Misc_Note_01" },
  { "g_iv100", "Pulitzer Moo", "Hold 100 Moo Interviews.", 100, 30, "INV_Misc_Note_01" },
})
Tiers("games", Stat("interviewsAnswered"), { { "g_ans25", "The People Have Spoken", "Get 25 interview answers.", 25, 15, "INV_Misc_Note_01" } })
Tiers("games", Stat("interviewsIgnored"), { { "g_ign10", "Talking to a Wall", "Get ignored in 10 interviews.", 10, 10, "INV_Misc_Note_01" } })
Tiers("games", Stat("mercyGranted"), { { "g_mercy1", "Merciful Cow", "Grant mercy to a begging friend.", 1, 5, "Spell_Holy_Heal" } })
Tiers("games", Stat("mercyDenied"), { { "g_nomercy10", "Heartless", "Deny mercy 10 times.", 10, 15, "Spell_Shadow_DeathScream" } })

---------------------------------------------------------------------------
-- The Farm
---------------------------------------------------------------------------

local function Milk() return MH.db and MH.db.farm and MH.db.farm.lifetime or 0 end
Tiers("farm", Milk, {
  { "f_milk100", "First Bucket", "Earn 100 milk.", 100, 5, "INV_Drink_Milk_01" },
  { "f_milk1k", "Dairy Farmer", "Earn 1,000 milk.", 1000, 10, "INV_Drink_Milk_01" },
  { "f_milk10k", "Milk Baron", "Earn 10,000 milk.", 10000, 20, "INV_Drink_Milk_01" },
  { "f_milk100k", "Milk Tycoon", "Earn 100,000 milk.", 100000, 30, "INV_Drink_Milk_01" },
  { "f_milk1m", "The Milky Way", "Earn 1,000,000 milk.", 1000000, 50, "INV_Drink_Milk_01" },
})
local function Owned()
  local n = 0
  for _, c in pairs(MH.db and MH.db.farm and MH.db.farm.owned or {}) do n = n + c end
  return n
end
Tiers("farm", Owned, {
  { "f_own1", "Hiring", "Buy your first farm upgrade.", 1, 5, "INV_Misc_Bag_10" },
  { "f_own25", "Growing Operation", "Own 25 farm upgrades.", 25, 15, "INV_Misc_Bag_10" },
  { "f_own100", "Industrial Dairy", "Own 100 farm upgrades.", 100, 30, "INV_Misc_Bag_10" },
})
for _, g in ipairs(MH.GENERATORS or {}) do
  Once("farm", "f_gen_" .. g.key, g.name, "Own at least one " .. g.name .. ".", 5, g.icon or "INV_Misc_Bag_10",
    function() return (MH.db.farm and MH.db.farm.owned[g.key] or 0) > 0 end)
end
Tiers("farm", Stat("questsDone"), {
  { "f_q1", "Daily Chores", "Complete a daily Moo Quest.", 1, 5, "INV_Scroll_03" },
  { "f_q10", "Reliable Farmhand", "Complete 10 daily Moo Quests.", 10, 10, "INV_Scroll_03" },
  { "f_q50", "Employee of the Month", "Complete 50 daily Moo Quests.", 50, 20, "INV_Scroll_03" },
  { "f_q100", "Lifetime Farmhand", "Complete 100 daily Moo Quests.", 100, 30, "INV_Scroll_03" },
})
Tiers("farm", Stat("questStreakBest"), {
  { "f_streak3", "Routine", "Finish all daily quests 3 days in a row.", 3, 10, "INV_Misc_PocketWatch_02" },
  { "f_streak7", "Week of Moo", "Finish all daily quests 7 days in a row.", 7, 20, "INV_Misc_PocketWatch_02" },
  { "f_streak30", "Dairy Devotion", "Finish all daily quests 30 days in a row.", 30, 50, "INV_Misc_PocketWatch_02" },
})

---------------------------------------------------------------------------
-- Bessie
---------------------------------------------------------------------------

Once("bessie", "b_adopt", "Adoption Day", "Give Bessie a name.", 5, KODO, function() return MH:GetStat("bessieNamed") > 0 end)
Tiers("bessie", Stat("bessieFeeds"), {
  { "b_feed10", "Snack Time", "Feed Bessie 10 times.", 10, 5, "INV_Misc_Food_19" },
  { "b_feed100", "Well Fed", "Feed Bessie 100 times.", 100, 15, "INV_Misc_Food_19" },
})
Tiers("bessie", Stat("bessiePets"), {
  { "b_pet10", "Good Cow", "Pet Bessie 10 times.", 10, 5, "Spell_Holy_Heal" },
  { "b_pet100", "Best Friends", "Pet Bessie 100 times.", 100, 15, "Spell_Holy_Heal" },
})
Tiers("bessie", Stat("bessieBrushes"), { { "b_brush50", "Shiny Coat", "Brush Bessie 50 times.", 50, 10, "INV_Misc_Comb_02" } })
Tiers("bessie", Stat("bessieShows"), { { "b_show10", "Proud Owner", "Show Bessie off to your party 10 times.", 10, 10, KODO } })
for i, stage in ipairs(MH.BESSIE_STAGES or {}) do
  if i > 1 then
    Once("bessie", "b_stage" .. i, stage.name, "Raise Bessie to " .. stage.name .. ".", 5 + i * 5, KODO,
      function() return (MH.db.bessie and MH.db.bessie.stage or 1) >= i end)
  end
end
Once("bessie", "b_happy", "Pure Joy", "Get Bessie to full happiness.", 10, "Spell_Holy_Heal",
  function() return MH.db.bessie and MH.db.bessie.happiness >= 100 end)

---------------------------------------------------------------------------
-- The Herd
---------------------------------------------------------------------------

local function HerdSize() return CountKeys(MH.db and MH.db.herd) end
Tiers("herd", HerdSize, {
  { "h_size1", "Herd of One", "Have a friend join your herd by talking to it.", 1, 5, "Spell_Holy_PrayerOfFortitude" },
  { "h_size5", "Small Herd", "Have 5 friends in your herd.", 5, 10, "Spell_Holy_PrayerOfFortitude" },
  { "h_size15", "Big Herd", "Have 15 friends in your herd.", 15, 20, "Spell_Holy_PrayerOfFortitude" },
  { "h_size40", "Moo Nation", "Have 40 friends in your herd.", 40, 40, "Spell_Holy_PrayerOfFortitude" },
})
Tiers("herd", Stat("promotions"), {
  { "h_promo1", "Middle Management", "Promote a herd member.", 1, 5, "INV_Misc_Trophy_01" },
  { "h_promo25", "HR Department", "Promote herd members 25 times.", 25, 20, "INV_Misc_Trophy_01" },
})
Once("herd", "h_legend", "Living Legend", "Have a herd member reach the top herd rank.", 30, "INV_Misc_Trophy_01",
  function() return MH:GetStat("herdLegend") > 0 end)

---------------------------------------------------------------------------
-- Strange Moos
---------------------------------------------------------------------------

for _, d in ipairs(MH.DIALECTS or {}) do
  Once("weird", "w_dialect_" .. d.key, d.name, "Speak in " .. d.name .. ".", 5, MOO_ICON,
    function() return MH:GetStat("dialect:" .. d.key) > 0 end)
end
A:Add({ id = "w_polyglot", category = "weird", name = "Polyglot of the Pasture", desc = "Speak in every moo dialect.",
  points = 20, icon = MOO_ICON, progress = function()
    local n = 0
    for _, d in ipairs(MH.DIALECTS or {}) do if MH:GetStat("dialect:" .. d.key) > 0 then n = n + 1 end end
    return n, math.max(#(MH.DIALECTS or {}), 1)
  end })
Tiers("weird", Stat("cipherEncoded"), {
  { "w_cipher1", "Secret Moo", "Send a message in the Moo Cipher.", 1, 10, "INV_Misc_Book_09" },
  { "w_cipher25", "Bovine Spy", "Send 25 Moo Cipher messages.", 25, 20, "INV_Misc_Book_09" },
})
Tiers("weird", Stat("cipherDecoded"), { { "w_decode1", "Code Breaker", "Decode a Moo Cipher message.", 1, 10, "INV_Misc_Book_09" } })
Tiers("weird", Stat("goldenMoos"), {
  { "w_golden1", "Golden Moo", "Catch a Golden Moo.", 1, 15, "INV_Misc_Coin_01" },
  { "w_golden10", "Midas Moo", "Catch 10 Golden Moos.", 10, 30, "INV_Misc_Coin_01" },
})
Tiers("weird", Stat("moonsoons"), { { "w_monsoon", "Moo-nsoon Season", "Live through a Moo-nsoon.", 1, 10, "Spell_Nature_Cyclone" } })
Tiers("weird", Stat("stampedeHours"), { { "w_stampedehour", "Stampede Hour", "Live through a Stampede Hour.", 1, 10, KODO } })
Tiers("weird", Stat("fmSegments"), {
  { "w_fm1", "Tune In", "Broadcast a Moo FM segment.", 1, 5, "INV_Misc_Horn_01" },
  { "w_fm50", "Radio Personality", "Broadcast 50 Moo FM segments.", 50, 20, "INV_Misc_Horn_01" },
})
Tiers("weird", Stat("horoscopes"), { { "w_horo7", "Written in the Stars", "Read 7 daily Moo-roscopes.", 7, 10, "Spell_Holy_SealOfWisdom" } })
Once("weird", "w_hear", "Selective Hearing", "Turn on Hear Moo.", 5, MOO_ICON, function() return MH.db.effects.hearMoo end)
Once("weird", "w_mute", "The Sound of Silence", "Hard mute a channel.", 5, "Spell_Holy_Silence",
  function() return next(MH.db.muted) ~= nil end)
Tiers("weird", Stat("panicUsed"), { { "w_panic", "Cold Hooves", "Use the panic button.", 1, 5, "Spell_Holy_Silence" } })
Tiers("weird", Field("afkMoos"), { { "w_afk50", "Patient Stalker", "Moo at AFK friends 50 times.", 50, 15, "Spell_Nature_Sleep" } })
Tiers("weird", Field("welcomes"), { { "w_welcome25", "Welcome Wagon", "Welcome 25 friends and guildmates.", 25, 15, "INV_Letter_01" } })

---------------------------------------------------------------------------
-- Barnyard Fun: the Moo Meter, Bingo, the Market, Herd Keepers and Cow Duels
---------------------------------------------------------------------------

A:AddCategory("fun", "Barnyard Fun")
for j, key in ipairs(A.categoryOrder) do
  if key == "fun" then table.remove(A.categoryOrder, j) break end
end
for j, key in ipairs(A.categoryOrder) do
  if key == "weird" then table.insert(A.categoryOrder, j + 1, "fun") break end
end

Tiers("fun", Stat("meterOpened"), { { "x_meter", "Moo-surement", "Open the Moo Meter.", 1, 5, "INV_Misc_PocketWatch_01" } })
Tiers("fun", Stat("meterFights"), {
  { "x_fights10", "Data Driven", "Have the Moo Meter measure 10 fights.", 10, 5, "INV_Misc_PocketWatch_01" },
  { "x_fights100", "Spreadsheet Cow", "Have the Moo Meter measure 100 fights.", 100, 15, "INV_Misc_PocketWatch_01" },
})
Tiers("fun", Stat("meterPosts"), {
  { "x_post1", "Meter Maid", "Post the Moo Meter to your party.", 1, 5, "INV_Misc_Note_01" },
  { "x_post25", "Parse Moo-nster", "Post the Moo Meter 25 times.", 25, 15, "INV_Misc_Note_01" },
})
Tiers("fun", Stat("bingos"), {
  { "x_bingo1", "BINGO!", "Complete a line on a Moo Bingo card.", 1, 10, "INV_Misc_Note_02" },
  { "x_bingo10", "Bingo Hall Regular", "Get 10 Moo Bingo lines.", 10, 20, "INV_Misc_Note_02" },
})
Tiers("fun", Stat("bingoBlackouts"), { { "x_blackout", "Blackout", "Mark every square on a Moo Bingo card.", 1, 30, "INV_Misc_Note_02" } })
Tiers("fun", Stat("trades"), {
  { "x_trade1", "Opening Bell", "Make a trade on the Moo Market.", 1, 5, "INV_Misc_Coin_02" },
  { "x_trade100", "Day Trader", "Make 100 trades.", 100, 20, "INV_Misc_Coin_02" },
})
Tiers("fun", Stat("marketProfitBest"), {
  { "x_profit1k", "Buy Low, Moo High", "Make 1,000 milk of profit on the Moo Market.", 1000, 15, "INV_Misc_Coin_01" },
  { "x_profit100k", "Wolf of Moo Street", "Make 100,000 milk of profit on the Moo Market.", 100000, 40, "INV_Misc_Coin_01" },
})
Tiers("fun", Stat("portfolioBest"), { { "x_portfolio", "Moo-lionaire", "Hold stocks worth 1,000,000 milk.", 1000000, 50, "INV_Misc_Coin_01" } })
Tiers("fun", Stat("peersMet"), {
  { "x_peer1", "Fellow Keeper", "Meet someone else running Moolitism Helper.", 1, 10, "Spell_Holy_PrayerOfFortitude" },
  { "x_peer10", "The Moo-vement", "Meet 10 other Moolitism Helper users.", 10, 25, "Spell_Holy_PrayerOfFortitude" },
})
Tiers("fun", Stat("cowDuels"), {
  { "x_duel1", "Cow Fight!", "Fight a Cow Duel.", 1, 10, KODO },
  { "x_duel25", "Cow Fight Club", "Fight 25 Cow Duels.", 25, 20, KODO },
})
Tiers("fun", Stat("cowDuelWins"), {
  { "x_duelwin1", "Bovine Champion", "Win a Cow Duel.", 1, 10, KODO },
  { "x_duelwin10", "Undefeated Udders", "Win 10 Cow Duels.", 10, 30, KODO },
})

-- re-check whenever MooHelper's numbers change, and every few seconds as a backstop
local acc = 0
table.insert(MH.tickFns, function()
  acc = acc + 1
  if acc >= 5 then acc = 0 MH:StatChanged() end
end)
