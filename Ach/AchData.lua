-- MooHelper Moo-chievements: achievement definitions (ported from Forever Achievements)
-- Add your own with ns:Add{ ... } (see the field reference in Core.lua).

local _, MH = ...
MH.Ach = MH.Ach or {}
local ns = MH.Ach -- the achievement engine (ported from Forever Achievements)

local G = 10000 -- copper per gold

ns:AddCategory("general", "General")
ns:AddCategory("leveling", "Leveling")
ns:AddCategory("quests", "Quests")
ns:AddCategory("exploration", "Exploration")
ns:AddCategory("combat", "Combat")
ns:AddCategory("dungeons", "Dungeons")
ns:AddCategory("raids", "Raids")
ns:AddCategory("professions", "Professions")
ns:AddCategory("reputation", "Reputation")
ns:AddCategory("pvp", "Player vs. Player")
ns:AddCategory("feats", "Feats of Strength")

-- Tiered counter achievements: { id, name, desc, goal, points, icon }
local function Tiers(category, counter, tiers, format)
  for _, t in ipairs(tiers) do
    ns:Add({
      id = t[1], category = category, name = t[2], desc = t[3],
      counter = counter, goal = t[4], points = t[5], icon = t[6], format = format,
    })
  end
end

---------------------------------------------------------------------------
-- General
---------------------------------------------------------------------------
ns:Add({ id = "hello_azeroth", category = "general", name = "Hello, Azeroth",
  desc = "Install MooHelper.", points = 5, icon = "INV_Misc_Note_01",
  check = function() return true end })
ns:Add({ id = "party", category = "general", name = "Better Together",
  desc = "Join a party.", points = 5, icon = "Spell_Holy_PrayerOfFortitude", flag = "party" })
ns:Add({ id = "raid", category = "general", name = "Raid Night",
  desc = "Join a raid group.", points = 10, icon = "Spell_Holy_PrayerOfSpirit", flag = "raid" })
ns:Add({ id = "mounted", category = "general", name = "Saddle Up",
  desc = "Ride a mount.", points = 10, icon = "Ability_Mount_RidingHorse", flag = "mounted" })

Tiers("general", "hearths", {
  { "hearth1", "There's No Place Like Home", "Use your Hearthstone.", 1, 5, "INV_Misc_Rune_01" },
  { "hearth50", "Frequent Hearther", "Use your Hearthstone 50 times.", 50, 10, "INV_Misc_Rune_01" },
})
Tiers("general", "flights", {
  { "flight1", "Taking Flight", "Take a flight path.", 1, 5, "Ability_Mount_Wyvern_01" },
  { "flight50", "Frequent Flyer", "Take 50 flight paths.", 50, 10, "Ability_Mount_Wyvern_01" },
  { "flight200", "Sky Commuter", "Take 200 flight paths.", 200, 20, "Ability_Mount_Wyvern_01" },
})
Tiers("general", "emotes", {
  { "emote100", "Expressive", "Use 100 emotes.", 100, 5, "Spell_Holy_MindVision" },
})
Tiers("general", "dances", {
  { "dance50", "Dance Party", "/dance 50 times.", 50, 5, "Spell_Shadow_Charm" },
})
Tiers("general", "maxMoney", {
  { "gold1", "Pocket Change", "Hold 1 gold.", 1 * G, 5, "INV_Misc_Coin_03" },
  { "gold10", "Savings Account", "Hold 10 gold.", 10 * G, 10, "INV_Misc_Coin_03" },
  { "gold100", "Well Off", "Hold 100 gold.", 100 * G, 10, "INV_Misc_Coin_02" },
  { "gold500", "Wealthy", "Hold 500 gold.", 500 * G, 20, "INV_Misc_Coin_01" },
  { "gold1000", "Tycoon", "Hold 1,000 gold.", 1000 * G, 30, "INV_Misc_Coin_01" },
}, "money")
Tiers("general", "lootRare", {
  { "rare1", "Ooh, Shiny", "Loot a rare (blue) item.", 1, 5, "INV_Misc_Gem_Sapphire_01" },
  { "rare25", "Blue Collar", "Loot 25 rare items.", 25, 10, "INV_Misc_Gem_Sapphire_01" },
})
Tiers("general", "lootEpic", {
  { "epic1", "Epic Find", "Loot an epic (purple) item.", 1, 10, "INV_Misc_Gem_Amethyst_01" },
  { "epic10", "Purple Haze", "Loot 10 epic items.", 10, 25, "INV_Misc_Gem_Amethyst_01" },
})

---------------------------------------------------------------------------
-- Leveling
---------------------------------------------------------------------------
Tiers("leveling", "level", {
  { "level10", "Level 10", "Reach level 10.", 10, 10, "Spell_Holy_HolyBolt" },
  { "level20", "Level 20", "Reach level 20.", 20, 10, "Spell_Holy_HolyBolt" },
  { "level30", "Level 30", "Reach level 30.", 30, 10, "Spell_Holy_HolyBolt" },
  { "level40", "Level 40", "Reach level 40.", 40, 10, "Spell_Holy_InnerFire" },
  { "level50", "Level 50", "Reach level 50.", 50, 10, "Spell_Holy_InnerFire" },
  { "level60", "Level 60", "Reach the maximum level of 60.", 60, 25, "Spell_Holy_SurgeOfLight" },
})

-- A Hardcore character that's still alive has provably never died, so it qualifies even
-- if the addon was installed late.
local function deathlessFailed(n)
  if n:Get("deaths") > 0 then return true end
  return (n.char.firstSeenLevel or 99) > 1 and not n:IsHardcore()
end
for _, t in ipairs({ { 10, "Careful Adventurer", 10 }, { 30, "Untouchable", 25 }, { 60, "Immortal", 50 } }) do
  local level = t[1]
  ns:Add({
    id = "deathless" .. level, category = "leveling", name = t[2], points = t[3],
    desc = ("Reach level %d without dying."):format(level),
    hint = "Only counts if MooHelper was installed at level 1. Hardcore characters get this naturally.",
    icon = "Spell_Holy_DivineIntervention",
    counter = "level", goal = level,
    check = function(n) return n:Get("level") >= level and not deathlessFailed(n) end,
    failed = deathlessFailed,
  })
end

---------------------------------------------------------------------------
-- Quests
---------------------------------------------------------------------------
Tiers("quests", "quests", {
  { "quests1", "A Hero Is Born", "Complete a quest.", 1, 5, "INV_Misc_Note_01" },
  { "quests50", "Helping Hand", "Complete 50 quests.", 50, 10, "INV_Scroll_03" },
  { "quests100", "Errand Runner", "Complete 100 quests.", 100, 10, "INV_Scroll_03" },
  { "quests250", "Quest Journeyman", "Complete 250 quests.", 250, 15, "INV_Misc_Book_09" },
  { "quests500", "Quest Master", "Complete 500 quests.", 500, 20, "INV_Misc_Book_09" },
  { "quests1000", "Loremaster of Azeroth", "Complete 1,000 quests.", 1000, 30, "INV_Misc_Book_11" },
})

---------------------------------------------------------------------------
-- Exploration
---------------------------------------------------------------------------
Tiers("exploration", "zones", {
  { "zones10", "Wanderer", "Visit 10 different zones.", 10, 10, "INV_Misc_Map_01" },
  { "zones20", "Traveler", "Visit 20 different zones.", 20, 15, "INV_Misc_Map_01" },
  { "zones35", "Globetrotter", "Visit 35 different zones.", 35, 25, "INV_Misc_Map_01" },
})
Tiers("exploration", "subzones", {
  { "sub50", "Sightseer", "Discover 50 different areas.", 50, 10, "Ability_Hunter_Pathfinding" },
  { "sub150", "Cartographer", "Discover 150 different areas.", 150, 15, "Ability_Hunter_Pathfinding" },
  { "sub300", "Explorer of Azeroth", "Discover 300 different areas.", 300, 30, "Ability_Hunter_Pathfinding" },
})

-- Zones new in Forever. Matched by the (English) zone name the client reports.
local NEW_ZONES = {
  { "zephras", "Zephras Isle", "Windswept Beginnings", "Set foot on Zephras Isle, the Skyborne homeland." },
  { "riverglades", "Riverglades", "Down by the River", "Visit the Riverglades." },
  { "shendralas", "Shen'dralas", "Shen'dralas Revealed", "Visit Shen'dralas." },
  { "hyjal", "Mount Hyjal", "Roots of the World Tree", "Climb Mount Hyjal." },
}
local zoneFlags, zoneLabels = {}, {}
for _, z in ipairs(NEW_ZONES) do
  local flag = "zone:" .. z[2]
  zoneFlags[#zoneFlags + 1] = flag
  zoneLabels[#zoneLabels + 1] = z[2]
  ns:Add({ id = "zone_" .. z[1], category = "exploration", name = z[3], desc = z[4],
    hint = "New in Forever", points = 10, icon = "INV_Misc_Map_01", flag = flag })
end
ns:Add({ id = "zone_new_all", category = "exploration", name = "New Horizons",
  desc = "Visit every zone added in World of Warcraft: Forever.", points = 20,
  icon = "Ability_Hunter_Pathfinding", flags = zoneFlags, labels = zoneLabels })

---------------------------------------------------------------------------
-- Combat
-- Forever blocks the combat log for addons, so kills are counted from the
-- "X dies, you gain N experience" message and bosses from ENCOUNTER_END.
---------------------------------------------------------------------------
Tiers("combat", "kills", {
  { "kills1", "First Blood", "Defeat an enemy that grants experience.", 1, 5, "INV_Sword_04" },
  { "kills100", "Slayer", "Defeat 100 enemies that grant experience.", 100, 10, "INV_Sword_04" },
  { "kills1000", "Executioner", "Defeat 1,000 enemies that grant experience.", 1000, 15, "Ability_DualWield" },
  { "kills5000", "Butcher", "Defeat 5,000 enemies that grant experience.", 5000, 20, "Ability_Rogue_Eviscerate" },
})
Tiers("combat", "bossKills", {
  { "boss1", "Boss Fight", "Defeat a dungeon or raid boss.", 1, 5, "Ability_Warrior_BattleShout" },
  { "boss100", "Boss Hunter", "Defeat 100 dungeon or raid bosses.", 100, 15, "Ability_Warrior_BattleShout" },
  { "boss500", "Boss Breaker", "Defeat 500 dungeon or raid bosses.", 500, 25, "Ability_Warrior_BattleShout" },
})
Tiers("combat", "deaths", {
  { "death1", "Welcome to the Spirit Healer", "Die.", 1, 5, "INV_Misc_Bone_HumanSkull_01" },
  { "death50", "Corpse Runner", "Die 50 times.", 50, 10, "INV_Misc_Bone_HumanSkull_01" },
})

-- Named kills: the experience message names the creature, so specific rares can be
-- tracked without the combat log. Only kills that grant you experience count.
ns.namedKills = {} -- lower-case creature name -> flag
local RARES = {
  { "hogger", "Hogger", "Hogger's Bane", "Elwynn Forest" },
  { "elmpaw", "Elmpaw", "Elm Street Nightmare", "Elwynn Forest", true },
  { "snapbeak", "Snapbeak the Quick", "Quicker Than Snapbeak", "Zephras Isle", true },
  { "rotheap", "Nightveiled Rotheap", "Heap of Trouble", "Wetlands", true },
  { "marinous", "Baron Marinous", "Lord of the Shore", "Darkshore", true },
}
local rareFlags, rareLabels = {}, {}
for _, r in ipairs(RARES) do
  local flag = "kill:" .. r[1]
  ns.namedKills[r[2]:lower()] = flag
  rareFlags[#rareFlags + 1] = flag
  rareLabels[#rareLabels + 1] = r[2] .. " (" .. r[4] .. ")"
  ns:Add({ id = "rare_" .. r[1], category = "combat", name = r[3],
    desc = ("Defeat %s in %s."):format(r[2], r[4]),
    hint = (r[5] and "New in Forever. " or "") .. "Only counts if the kill gives you experience.",
    points = 10, icon = "Ability_Hunter_SniperShot", flag = flag })
end
ns:Add({ id = "rare_all", category = "combat", name = "Rare Collector",
  desc = "Defeat every rare creature listed under Combat.", points = 20,
  icon = "Ability_Hunter_SniperShot", flags = rareFlags, labels = rareLabels })

---------------------------------------------------------------------------
-- Dungeons
-- Credit = a successful ENCOUNTER_END whose name matches one of `bosses`.
-- Final bosses of the new Forever dungeons come from launch-week guides and
-- may be wrong; `/ach bosses` lists the encounter names you have actually
-- killed so they can be corrected here.
--   key, dungeon, { final boss name(s) }, level range, new in Forever
---------------------------------------------------------------------------
local DUNGEONS = {
  { "thanes", "Hall of Thanes", { "Durgen Dirgehammer" }, "13-18", true },
  { "rfc", "Ragefire Chasm", { "Taragaman the Hungerer", "Bazzalan" }, "13-18" },
  { "ruins", "Ruins of Lordaeron", { "Rath'mael" }, "15-22", true },
  { "dm", "The Deadmines", { "Edwin VanCleef" }, "16-24" },
  { "wc", "Wailing Caverns", { "Mutanus the Devourer" }, "17-24" },
  { "sfk", "Shadowfang Keep", { "Archmage Arugal" }, "18-26" },
  { "bfd", "Blackfathom Deeps", { "Aku'mai" }, "22-30" },
  { "stocks", "The Stockade", { "Bazil Thredd" }, "23-30" },
  { "excavation", "Excavation Site", { "Relic Guardian" }, "24-29", true },
  { "rfk", "Razorfen Kraul", { "Charlga Razorflank" }, "24-32" },
  { "gnomer", "Gnomeregan", { "Mekgineer Thermaplugg" }, "25-34" },
  { "dalaran", "City of Dalaran", { "Shade of the Archmage" }, "28-33", true },
  { "smgy", "Scarlet Monastery: Graveyard", { "Bloodmage Thalnos" }, "30-38" },
  { "smlib", "Scarlet Monastery: Library", { "Arcanist Doan" }, "33-41" },
  { "smarm", "Scarlet Monastery: Armory", { "Herod" }, "36-44" },
  { "smcath", "Scarlet Monastery: Cathedral", { "High Inquisitor Whitemane" }, "38-46" },
  { "rfd", "Razorfen Downs", { "Amnennar the Coldbringer" }, "34-42" },
  { "drowned", "The Drowned City", { "Min'loth the Serpent" }, "35-40", true },
  { "ulda", "Uldaman", { "Archaedas" }, "35-45" },
  { "krol", "Krol'dok Stronghold", { "Overseer Mugg" }, "40-45", true },
  { "zf", "Zul'Farrak", { "Chief Ukorz Sandscalp" }, "42-48" },
  { "mara", "Maraudon", { "Princess Theradras" }, "42-52" },
  { "st", "Sunken Temple", { "Shade of Eranikus" }, "45-55" },
  { "alcaz", "Alcaz Prison", { "Blazeroar" }, "48-53", true },
  { "brd", "Blackrock Depths", { "Emperor Dagran Thaurissan" }, "48-60" },
  { "lbrs", "Lower Blackrock Spire", { "Overlord Wyrmthalak" }, "53-60" },
  { "dme", "Dire Maul: East", { "Alzzin the Wildshaper" }, "54-60" },
  { "blackmaw", "Blackmaw Hold", { "Unbound Spirit" }, "55-60", true },
  { "strat", "Stratholme", { "Baron Rivendare", "Balnazzar" }, "55-60" },
  { "dmw", "Dire Maul: West", { "Prince Tortheldrin" }, "56-60" },
  { "dmn", "Dire Maul: North", { "King Gordok" }, "56-60" },
  { "scholo", "Scholomance", { "Darkmaster Gandling" }, "57-60" },
  { "ubrs", "Upper Blackrock Spire", { "General Drakkisath" }, "58-60" },
  { "shaper", "Shaper's Terrace", { "Nanaya" }, "58-60", true },
}

-- encounter name (lower case) -> flag; filled here, read by Tracking.lua
ns.bossFlags = {}
-- dungeon flag -> minimum recommended level (used by the "Underdog" achievement)
ns.dungeonMinLevel = {}

local dungeonFlags, dungeonLabels, newDungeonIds = {}, {}, {}
for _, d in ipairs(DUNGEONS) do
  local flag = "dungeon:" .. d[1]
  ns.dungeonMinLevel[flag] = tonumber(d[4]:match("^(%d+)"))
  for _, boss in ipairs(d[3]) do ns.bossFlags[boss:lower()] = flag end
  dungeonFlags[#dungeonFlags + 1] = flag
  dungeonLabels[#dungeonLabels + 1] = d[2]
  local id = "dungeon_" .. d[1]
  if d[5] then newDungeonIds[#newDungeonIds + 1] = id end
  ns:Add({ id = id, category = "dungeons", name = d[2],
    desc = "Defeat " .. d[3][1] .. ".",
    hint = "Level " .. d[4] .. (d[5] and " - new in Forever" or ""),
    points = d[5] and 15 or 10, icon = d[5] and "INV_Misc_Key_10" or "INV_Misc_Key_04", flag = flag })
end
ns:Add({ id = "dungeon_5", category = "dungeons", name = "Dungeon Crawler",
  desc = "Complete 5 different dungeons.", points = 10, icon = "INV_Misc_Key_03",
  flags = dungeonFlags, labels = dungeonLabels, goal = 5 })
ns:Add({ id = "dungeon_20", category = "dungeons", name = "Dungeon Veteran",
  desc = "Complete 20 different dungeons.", points = 25, icon = "INV_Misc_Key_03",
  flags = dungeonFlags, labels = dungeonLabels, goal = 20 })
ns:Add({ id = "dungeon_all", category = "dungeons", name = "Dungeon Master",
  desc = "Complete every dungeon in Azeroth.", points = 50, icon = "INV_Misc_Key_10",
  flags = dungeonFlags, labels = dungeonLabels })
ns:Add({ id = "dungeon_new", category = "dungeons", name = "Forever and a Day",
  desc = "Complete all nine dungeons added in World of Warcraft: Forever.", points = 30,
  icon = "INV_Misc_Key_10", meta = newDungeonIds })

---------------------------------------------------------------------------
-- Raids (open December 9, 2026)
-- Encounter lists from the Warcraft Wiki (Nov 2026). Paths branch, so a full
-- clear is earned EITHER by killing every named boss below OR by killing that
-- many different encounters inside the raid instance. The second way still
-- works if a boss name here turns out to be wrong.
---------------------------------------------------------------------------
local RAIDS = {
  { key = "barrow", name = "Barrow Deeps", size = 10, points = 25, icon = "Spell_Shadow_RaiseDead",
    bosses = { "Deepscar Matriarch", "Khalith the Dreadspinner", "Amethrax", "Ravus and Darlissa",
      "Elder Tangleclaw", "Well of Sorrow", "Del'lynar Songwood", "Sonya Darkhallow" } },
  { key = "hyjal", name = "Hyjal Summit", size = 20, points = 30, icon = "INV_Misc_Herb_Felblossom",
    bosses = { "Bandalar", "Time-Lost Battalion", "Old Gloomlurker", "Kathris the Haunted",
      "Elder Minderel", "Council of Thorns", "The Wild King", "Ancient of Decay", "Sylvesteris Dusksong",
      "Gharalis the Abyssal", "Anara Chillwind", "Tracker Stillwind", "Nythus the Dreambound" } },
  { key = "ony", name = "Onyxia's Lair", size = 40, points = 25, icon = "INV_Misc_Head_Dragon_01",
    bosses = { "Onyxia" } },
}
ns.RAID_DATA = RAIDS -- reused by Expanded.lua for per-boss achievements
local raidIds = {}
for _, r in ipairs(RAIDS) do
  local flags = {}
  for i, boss in ipairs(r.bosses) do
    flags[i] = "boss:" .. boss:lower()
    ns.bossFlags[boss:lower()] = flags[i]
  end
  local final = r.bosses[#r.bosses]
  local id = "raid_" .. r.key
  raidIds[#raidIds + 1] = id
  ns:Add({ id = id, category = "raids", name = r.name,
    desc = "Defeat " .. final .. ".", hint = r.size .. "-player raid",
    points = r.points, icon = r.icon, flag = flags[#flags] })
  if #r.bosses > 1 then
    local count, counter = #r.bosses, "enc:" .. r.name
    raidIds[#raidIds + 1] = id .. "_full"
    ns:Add({ id = id .. "_full", category = "raids", name = r.name .. ": Full Clear",
      desc = ("Defeat all %d bosses in %s."):format(count, r.name), points = r.points,
      icon = r.icon, flags = flags, labels = r.bosses,
      check = function(n)
        if n:Get(counter) >= count then return true end
        for _, f in ipairs(flags) do
          if not n:HasFlag(f) then return false end
        end
        return true
      end })
  end
end
ns:Add({ id = "raid_all", category = "raids", name = "Conqueror of Azeroth",
  desc = "Fully clear every raid available at launch.", points = 100,
  icon = "INV_Misc_Head_Dragon_Black", meta = raidIds })

---------------------------------------------------------------------------
-- Professions
---------------------------------------------------------------------------
Tiers("professions", "primaryProfs", {
  { "prof_learn", "Tradesman", "Learn a primary profession.", 1, 5, "Trade_BlackSmithing" },
})
Tiers("professions", "profMax", {
  { "prof75", "Apprentice", "Reach 75 skill in a primary profession.", 75, 5, "Trade_BlackSmithing" },
  { "prof150", "Journeyman", "Reach 150 skill in a primary profession.", 150, 10, "Trade_BlackSmithing" },
  { "prof225", "Expert", "Reach 225 skill in a primary profession.", 225, 10, "Trade_Engineering" },
  { "prof300", "Artisan", "Reach 300 skill in a primary profession.", 300, 20, "Trade_Engineering" },
})
Tiers("professions", "artisanProfs", {
  { "prof300x2", "Master of Two Trades", "Reach 300 skill in two primary professions.", 2, 25, "Trade_Alchemy" },
})
Tiers("professions", "skill:cooking", {
  { "cook300", "Chef", "Reach 300 Cooking.", 300, 15, "INV_Misc_Food_15" },
})
Tiers("professions", "skill:fishing", {
  { "fish300", "Angler", "Reach 300 Fishing.", 300, 15, "Trade_Fishing" },
})
Tiers("professions", "skill:firstaid", {
  { "aid300", "Field Medic", "Reach 300 First Aid.", 300, 15, "Spell_Holy_Heal" },
})
ns:Add({ id = "secondary150", category = "professions", name = "Well Rounded",
  desc = "Reach 150 in Cooking, Fishing and First Aid.", points = 10, icon = "INV_Misc_Food_15",
  check = function(n)
    return n:Get("skill:cooking") >= 150 and n:Get("skill:fishing") >= 150 and n:Get("skill:firstaid") >= 150
  end })

---------------------------------------------------------------------------
-- Reputation
---------------------------------------------------------------------------
Tiers("reputation", "revered", {
  { "revered1", "Trusted Friend", "Reach Revered with a faction.", 1, 10, "INV_Shirt_GuildTabard_01" },
})
Tiers("reputation", "exalted", {
  { "exalted1", "Exalted", "Reach Exalted with a faction.", 1, 15, "INV_Shirt_GuildTabard_01" },
  { "exalted3", "Ambassador", "Reach Exalted with 3 factions.", 3, 20, "INV_Shirt_GuildTabard_01" },
  { "exalted5", "Diplomat", "Reach Exalted with 5 factions.", 5, 30, "INV_Shirt_GuildTabard_01" },
})

-- New Forever factions; each pair is the Alliance/Horde version, either counts.
-- Tracking sets "rep<standing>:<faction name>" flags (7 = Revered, 8 = Exalted).
local function EitherFlag(standing, a, b)
  return function(n) return n:HasFlag("rep" .. standing .. ":" .. a) or n:HasFlag("rep" .. standing .. ":" .. b) end
end
local TRADE_A, TRADE_H = "Azeroth Commerce Authority", "Durotar Supply and Logistics"
ns:Add({ id = "rep_trade7", category = "reputation", name = "Valued Supplier",
  desc = "Reach Revered with the " .. TRADE_A .. " or " .. TRADE_H .. ".",
  hint = "New in Forever", points = 10, icon = "INV_Misc_Coin_02", check = EitherFlag(7, TRADE_A, TRADE_H) })
ns:Add({ id = "rep_trade8", category = "reputation", name = "Merchant Prince",
  desc = "Reach Exalted with the " .. TRADE_A .. " or " .. TRADE_H .. ".",
  hint = "New in Forever", points = 20, icon = "INV_Misc_Coin_01", check = EitherFlag(8, TRADE_A, TRADE_H) })
local BG_A, BG_H = "Theramore Expeditionary Force", "Darkspear Raiders"
ns:Add({ id = "rep_darkspear8", category = "reputation", name = "Hero of the Darkspear Isles",
  desc = "Reach Exalted with the " .. BG_A .. " or the " .. BG_H .. ".",
  hint = "Darkspear Islands battleground reputation", points = 20, icon = "INV_BannerPVP_02",
  check = EitherFlag(8, BG_A, BG_H) })

---------------------------------------------------------------------------
-- PvP
---------------------------------------------------------------------------
Tiers("pvp", "duelWins", {
  { "duel1", "En Garde!", "Win a duel.", 1, 5, "Ability_Parry" },
  { "duel25", "Duelist", "Win 25 duels.", 25, 10, "Ability_Parry" },
  { "duel100", "Undefeated", "Win 100 duels.", 100, 20, "Ability_Parry" },
})
Tiers("pvp", "hk", {
  { "hk1", "Blood Feud", "Earn an honorable kill.", 1, 5, "INV_BannerPVP_01" },
  { "hk100", "Honorable", "Earn 100 honorable kills.", 100, 10, "INV_BannerPVP_01" },
  { "hk1000", "Veteran Soldier", "Earn 1,000 honorable kills.", 1000, 20, "INV_BannerPVP_01" },
  { "hk5000", "Grand Marshal of Mayhem", "Earn 5,000 honorable kills.", 5000, 30, "INV_BannerPVP_02" },
})

-- Battlegrounds (matched by instance name)
local BATTLEGROUNDS = { "Warsong Gulch", "Arathi Basin", "Alterac Valley", "Darkspear Islands" }
local bgFlags = {}
for i, bg in ipairs(BATTLEGROUNDS) do bgFlags[i] = "bg:" .. bg end
ns:Add({ id = "bg_darkspear", category = "pvp", name = "Island Hopping",
  desc = "Fight in the Darkspear Islands battleground.", hint = "New in Forever (15v15, level 30+)",
  points = 10, icon = "INV_BannerPVP_02", flag = "bg:Darkspear Islands" })
ns:Add({ id = "bg_all", category = "pvp", name = "Tour of Duty",
  desc = "Fight in every battleground.", points = 15, icon = "INV_BannerPVP_01",
  flags = bgFlags, labels = BATTLEGROUNDS })
Tiers("pvp", "bgWins", {
  { "bgwin1", "Victory!", "Win a battleground.", 1, 5, "INV_BannerPVP_01" },
  { "bgwin25", "Battle Tested", "Win 25 battlegrounds.", 25, 10, "INV_BannerPVP_01" },
  { "bgwin100", "Warlord of the Field", "Win 100 battlegrounds.", 100, 25, "INV_BannerPVP_02" },
})

-- Honor ranks. Forever's Legacy system already rewards ranks 3/7/10/13/14,
-- so these fill the gaps.
Tiers("pvp", "pvpRank", {
  { "rank1", "Enlisted", "Reach PvP rank 1.", 1, 5, "INV_BannerPVP_01" },
  { "rank6", "Officer Material", "Reach PvP rank 6.", 6, 10, "INV_BannerPVP_01" },
  { "rank11", "Black War Rider", "Reach PvP rank 11 and earn the right to a black war mount.", 11, 25, "INV_BannerPVP_02" },
})

---------------------------------------------------------------------------
-- Feats of Strength (hidden until earned)
---------------------------------------------------------------------------
Tiers("feats", "lootLegendary", {
  { "legendary", "Legendary!", "Loot a legendary item.", 1, 0, "INV_Hammer_Unique_Sulfuras" },
})
ns.byId.legendary.hidden = true
ns:Add({ id = "launch_week", category = "feats", hidden = true, name = "Day One",
  desc = "Play World of Warcraft: Forever during launch week (Nov 4-11, 2026).",
  points = 0, icon = "INV_Misc_Note_01",
  check = function(n)
    local t = n.char.firstSeenTime or time()
    return t >= time({ year = 2026, month = 11, day = 4, hour = 0 })
       and t < time({ year = 2026, month = 11, day = 12, hour = 0 })
  end })

---------------------------------------------------------------------------
-- Meta
---------------------------------------------------------------------------
ns:Add({ id = "hero", category = "general", name = "Hero of Azeroth",
  desc = "Reach 60, complete 500 quests, complete 20 dungeons, become an Artisan and reach Exalted.",
  points = 100, icon = "INV_Misc_Head_Dragon_01",
  meta = { "level60", "quests500", "dungeon_20", "prof300", "exalted1" } })
