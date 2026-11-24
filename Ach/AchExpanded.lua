-- MooHelper Moo-chievements: expanded achievement set (ported from Forever Achievements)
-- Loaded after Data.lua. Everything here uses criteria the tracker can actually detect
-- (see the counter list in README.md); tests/validate.lua checks that.

local _, MH = ...
MH.Ach = MH.Ach or {}
local ns = MH.Ach -- the achievement engine (ported from Forever Achievements)

local G = 10000 -- copper per gold
local DAY = 86400

ns:AddCategory("social", "Social")
ns:AddCategory("account", "Account")

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
Tiers("general", "hearths", {
  { "hearth10", "Homebody", "Use your Hearthstone 10 times.", 10, 5, "INV_Misc_Rune_01" },
  { "hearth100", "Home Is Where the Hearth Is", "Use your Hearthstone 100 times.", 100, 10, "INV_Misc_Rune_01" },
  { "hearth250", "Innkeeper's Favorite", "Use your Hearthstone 250 times.", 250, 15, "INV_Misc_Rune_01" },
})
Tiers("general", "flights", {
  { "flight10", "Window Seat", "Take 10 flight paths.", 10, 5, "Ability_Mount_Wyvern_01" },
  { "flight100", "Gryphon Miles", "Take 100 flight paths.", 100, 15, "Ability_Mount_Wyvern_01" },
  { "flight500", "Cloud Dweller", "Take 500 flight paths.", 500, 25, "Ability_Mount_Wyvern_01" },
})
Tiers("general", "maxMoney", {
  { "gold50", "Nest Egg", "Hold 50 gold.", 50 * G, 10, "INV_Misc_Coin_02" },
  { "gold250", "Comfortable", "Hold 250 gold.", 250 * G, 15, "INV_Misc_Coin_02" },
  { "gold2500", "Magnate", "Hold 2,500 gold.", 2500 * G, 40, "INV_Misc_Coin_01" },
  { "gold5000", "Golden Hoard", "Hold 5,000 gold.", 5000 * G, 50, "INV_Misc_Coin_01" },
}, "money")
Tiers("general", "lootUncommon", {
  { "green1", "Green Means Go", "Loot an uncommon (green) item.", 1, 5, "INV_Misc_Gem_Emerald_01" },
  { "green100", "Green Thumb", "Loot 100 uncommon items.", 100, 10, "INV_Misc_Gem_Emerald_01" },
  { "green500", "Green With Envy", "Loot 500 uncommon items.", 500, 15, "INV_Misc_Gem_Emerald_01" },
  { "green1000", "Evergreen", "Loot 1,000 uncommon items.", 1000, 20, "INV_Misc_Gem_Emerald_01" },
})
Tiers("general", "lootRare", {
  { "rare100", "Feeling Blue", "Loot 100 rare items.", 100, 15, "INV_Misc_Gem_Sapphire_01" },
  { "rare250", "Into the Blue", "Loot 250 rare items.", 250, 20, "INV_Misc_Gem_Sapphire_01" },
})
Tiers("general", "lootEpic", {
  { "epic25", "Royal Purple", "Loot 25 epic items.", 25, 30, "INV_Misc_Gem_Amethyst_01" },
  { "epic50", "Epic Hoarder", "Loot 50 epic items.", 50, 40, "INV_Misc_Gem_Amethyst_01" },
})
Tiers("general", "jumps", {
  { "jump100", "Bunny Hop", "Jump 100 times.", 100, 5, "Ability_Rogue_Sprint" },
  { "jump1000", "Spring in Your Step", "Jump 1,000 times.", 1000, 10, "Ability_Rogue_Sprint" },
  { "jump10000", "Can't Stop, Won't Stop", "Jump 10,000 times.", 10000, 15, "Ability_Rogue_Sprint" },
})
Tiers("general", "played", {
  { "played1", "Settling In", "Play this character for 1 day in total.", DAY, 10, "INV_Misc_PocketWatch_01" },
  { "played7", "Dedicated", "Play this character for 7 days in total.", 7 * DAY, 20, "INV_Misc_PocketWatch_01" },
  { "played30", "Lifer", "Play this character for 30 days in total.", 30 * DAY, 30, "INV_Misc_PocketWatch_01" },
}, "time")
for _, f in ipairs({
  { "bank", "Safe Keeping", "Open your bank.", "INV_Misc_Bag_10" },
  { "auction", "Going Once, Going Twice", "Browse an auction house.", "INV_Misc_Coin_04" },
  { "barber", "A Fresh Look", "Sit in a barber's chair.", "Ability_Rogue_Disguise" },
  { "mailbox", "You've Got Mail", "Open a mailbox.", "INV_Letter_01" },
}) do
  ns:Add({ id = "visit_" .. f[1], category = "general", name = f[2], desc = f[3],
    points = 5, icon = f[4], flag = f[1] })
end

---------------------------------------------------------------------------
-- Leveling
---------------------------------------------------------------------------
Tiers("leveling", "level", {
  { "level5", "Level 5", "Reach level 5.", 5, 5, "Spell_Holy_HolyBolt" },
  { "level15", "Level 15", "Reach level 15.", 15, 5, "Spell_Holy_HolyBolt" },
  { "level25", "Level 25", "Reach level 25.", 25, 5, "Spell_Holy_HolyBolt" },
  { "level35", "Level 35", "Reach level 35.", 35, 5, "Spell_Holy_InnerFire" },
  { "level45", "Level 45", "Reach level 45.", 45, 5, "Spell_Holy_InnerFire" },
  { "level55", "Level 55", "Reach level 55.", 55, 5, "Spell_Holy_SurgeOfLight" },
})

-- classFile values are the same in every game language.
ns.CLASSES = {
  { "WARRIOR", "Warrior", "INV_Sword_27" }, { "PALADIN", "Paladin", "Spell_Holy_SealOfMight" },
  { "HUNTER", "Hunter", "INV_Weapon_Bow_07" }, { "ROGUE", "Rogue", "Ability_Stealth" },
  { "PRIEST", "Priest", "Spell_Holy_PowerWordShield" }, { "SHAMAN", "Shaman", "Spell_Nature_BloodLust" },
  { "MAGE", "Mage", "Spell_Frost_IceStorm" }, { "WARLOCK", "Warlock", "Spell_Shadow_ShadowBolt" },
  { "DRUID", "Druid", "Ability_Druid_Maul" },
}
for _, c in ipairs(ns.CLASSES) do
  local classFile = c[1]
  ns:Add({ id = "class60_" .. classFile:lower(), category = "leveling", name = "Champion " .. c[2],
    desc = "Reach level 60 as a " .. c[2] .. ".", points = 10, icon = c[3],
    check = function(n) return n.classFile == classFile and n:Get("level") >= 60 end })
end

-- raceFile values are locale-independent; Skyborne is new in Forever, so its
-- English race name is accepted too in case its raceFile differs.
local RACES = {
  { "Human", "Human" }, { "Dwarf", "Dwarf" }, { "NightElf", "Night Elf" }, { "Gnome", "Gnome" },
  { "Orc", "Orc" }, { "Scourge", "Undead" }, { "Tauren", "Tauren" }, { "Troll", "Troll" },
  { "Skyborne", "Skyborne" },
}
for _, r in ipairs(RACES) do
  local raceFile, raceName = r[1], r[2]
  ns:Add({ id = "race60_" .. raceFile:lower(), category = "leveling", name = raceName .. " Paragon",
    desc = "Reach level 60 as a " .. raceName .. ".", points = 10, icon = "Spell_Holy_SurgeOfLight",
    hint = raceFile == "Skyborne" and "New in Forever" or nil,
    check = function(n)
      return (n.raceFile == raceFile or n.raceName == raceName) and n:Get("level") >= 60
    end })
end

---------------------------------------------------------------------------
-- Quests
---------------------------------------------------------------------------
Tiers("quests", "quests", {
  { "quests10", "Busy Bee", "Complete 10 quests.", 10, 5, "INV_Misc_Note_01" },
  { "quests25", "Odd Jobs", "Complete 25 quests.", 25, 5, "INV_Misc_Note_01" },
  { "quests750", "Adventurer for Hire", "Complete 750 quests.", 750, 25, "INV_Misc_Book_11" },
  { "quests1500", "Legend of the Quest Log", "Complete 1,500 quests.", 1500, 40, "INV_Misc_Book_11" },
})
Tiers("quests", "questsInDay", {
  { "questday10", "Productive Day", "Complete 10 quests in a single day.", 10, 5, "INV_Misc_PocketWatch_02" },
  { "questday25", "Overachiever", "Complete 25 quests in a single day.", 25, 10, "INV_Misc_PocketWatch_02" },
  { "questday50", "Quest Marathon", "Complete 50 quests in a single day.", 50, 20, "INV_Misc_PocketWatch_02" },
})

-- Zones by continent (English names as the client reports them).
ns.ZONES_EK = {
  "Dun Morogh", "Elwynn Forest", "Tirisfal Glades", "Loch Modan", "Westfall", "Silverpine Forest",
  "Redridge Mountains", "Duskwood", "Wetlands", "Hillsbrad Foothills", "Alterac Mountains",
  "Arathi Highlands", "Stranglethorn Vale", "Badlands", "Swamp of Sorrows", "The Hinterlands",
  "Searing Gorge", "Blasted Lands", "Burning Steppes", "Western Plaguelands", "Eastern Plaguelands",
  "Deadwind Pass",
}
ns.ZONES_KALIMDOR = {
  "Durotar", "Mulgore", "Teldrassil", "Darkshore", "The Barrens", "Stonetalon Mountains", "Ashenvale",
  "Thousand Needles", "Desolace", "Dustwallow Marsh", "Feralas", "Tanaris", "Azshara", "Felwood",
  "Un'Goro Crater", "Silithus", "Winterspring", "Moonglade",
}
local CAPITALS = { "Stormwind City", "Ironforge", "Darnassus", "Orgrimmar", "Thunder Bluff", "Undercity" }

-- Quests turned in per zone (counted in the zone you're standing in at turn-in).
local NO_QUEST_ZONES = { ["Deadwind Pass"] = true, ["Moonglade"] = true }
local questZones = {}
for _, list in ipairs({ ns.ZONES_EK, ns.ZONES_KALIMDOR, { "Riverglades", "Zephras Isle" } }) do
  for _, zone in ipairs(list) do
    if not NO_QUEST_ZONES[zone] then questZones[#questZones + 1] = zone end
  end
end
for _, zone in ipairs(questZones) do
  ns:Add({ id = "zq_" .. zone:lower():gsub("[^%w]", ""), category = "quests",
    name = "Friend of " .. zone, desc = "Complete 10 quests in " .. zone .. ".",
    hint = "Counts quests turned in while you are in " .. zone .. ".",
    points = 5, icon = "INV_Scroll_03", counter = "questsIn:" .. zone, goal = 10 })
end

---------------------------------------------------------------------------
-- Exploration
---------------------------------------------------------------------------
local function ZoneFlags(list)
  local flags = {}
  for i, z in ipairs(list) do flags[i] = "zone:" .. z end
  return flags
end
ns:Add({ id = "explore_ek", category = "exploration", name = "Eastern Kingdoms Wanderer",
  desc = "Visit every zone in the Eastern Kingdoms.", points = 25, icon = "INV_Misc_Map_01",
  flags = ZoneFlags(ns.ZONES_EK), labels = ns.ZONES_EK })
ns:Add({ id = "explore_kalimdor", category = "exploration", name = "Kalimdor Wanderer",
  desc = "Visit every zone in Kalimdor.", points = 25, icon = "INV_Misc_Map_01",
  flags = ZoneFlags(ns.ZONES_KALIMDOR), labels = ns.ZONES_KALIMDOR })
ns:Add({ id = "explore_capitals", category = "exploration", name = "Grand Tour",
  desc = "Visit all six capital cities of Azeroth.", points = 20, icon = "INV_Misc_Map_01",
  flags = ZoneFlags(CAPITALS), labels = CAPITALS })
ns:Add({ id = "explore_world", category = "exploration", name = "World Wanderer",
  desc = "Visit every zone in both the Eastern Kingdoms and Kalimdor.", points = 50,
  icon = "Ability_Hunter_Pathfinding", meta = { "explore_ek", "explore_kalimdor" } })
Tiers("exploration", "zones", {
  { "zones45", "Seen It All", "Visit 45 different zones.", 45, 30, "INV_Misc_Map_01" },
})
Tiers("exploration", "subzones", {
  { "sub25", "Off the Beaten Path", "Discover 25 different areas.", 25, 5, "Ability_Hunter_Pathfinding" },
  { "sub500", "Every Nook and Cranny", "Discover 500 different areas.", 500, 40, "Ability_Hunter_Pathfinding" },
})

---------------------------------------------------------------------------
-- Combat
---------------------------------------------------------------------------
Tiers("combat", "kills", {
  { "kills10", "Getting Started", "Defeat 10 enemies that grant experience.", 10, 5, "INV_Sword_04" },
  { "kills250", "Monster Hunter", "Defeat 250 enemies that grant experience.", 250, 10, "INV_Sword_04" },
  { "kills2500", "Relentless", "Defeat 2,500 enemies that grant experience.", 2500, 15, "Ability_DualWield" },
  { "kills10000", "Bringer of Doom", "Defeat 10,000 enemies that grant experience.", 10000, 25, "Ability_Rogue_Eviscerate" },
  { "kills25000", "Unstoppable Force", "Defeat 25,000 enemies that grant experience.", 25000, 30, "Ability_Rogue_Eviscerate" },
})
Tiers("combat", "bossKills", {
  { "boss10", "Boss Basher", "Defeat 10 dungeon or raid bosses.", 10, 5, "Ability_Warrior_BattleShout" },
  { "boss25", "Boss Bruiser", "Defeat 25 dungeon or raid bosses.", 25, 10, "Ability_Warrior_BattleShout" },
  { "boss50", "Boss Brawler", "Defeat 50 dungeon or raid bosses.", 50, 10, "Ability_Warrior_BattleShout" },
  { "boss250", "Boss Crusher", "Defeat 250 dungeon or raid bosses.", 250, 20, "Ability_Warrior_BattleShout" },
  { "boss1000", "Boss Annihilator", "Defeat 1,000 dungeon or raid bosses.", 1000, 30, "Ability_Warrior_BattleShout" },
})
Tiers("combat", "deaths", {
  { "death10", "Repeat Customer", "Die 10 times.", 10, 5, "INV_Misc_Bone_HumanSkull_01" },
  { "death100", "Spirit Healer's Best Friend", "Die 100 times.", 100, 10, "INV_Misc_Bone_HumanSkull_01" },
  { "death250", "Durability Damage", "Die 250 times.", 250, 15, "INV_Misc_Bone_HumanSkull_01" },
})

-- More named kills (classic rares and hunting-quest targets).
local MORE_RARES = {
  { "princess", "Princess", "Pork Belly", "Elwynn Forest" },
  { "murkeye", "Old Murk-Eye", "Murk-Eye's Bane", "Westfall" },
  { "morladim", "Mor'Ladim", "Laid to Rest", "Duskwood" },
  { "sindall", "Sin'Dall", "Cat Burglar", "Stranglethorn Vale" },
  { "bhagthera", "Bhag'thera", "Panther Hunter", "Stranglethorn Vale" },
  { "bangalash", "King Bangalash", "Tiger King", "Stranglethorn Vale" },
}
for _, r in ipairs(MORE_RARES) do
  local flag = "kill:" .. r[1]
  ns.namedKills[r[2]:lower()] = flag
  ns:Add({ id = "rare_" .. r[1], category = "combat", name = r[3],
    desc = ("Defeat %s in %s."):format(r[2], r[4]),
    hint = "Only counts if the kill gives you experience.",
    points = 10, icon = "Ability_Hunter_SniperShot", flag = flag })
end
ns:Add({ id = "nesingwary", category = "combat", name = "Nesingwary's Trophies",
  desc = "Defeat Sin'Dall, Bhag'thera and King Bangalash.", points = 15,
  icon = "INV_Weapon_Rifle_01", meta = { "rare_sindall", "rare_bhagthera", "rare_bangalash" } })

---------------------------------------------------------------------------
-- Dungeons
---------------------------------------------------------------------------
Tiers("dungeons", "dungeonClears", {
  { "clears10", "Regular", "Defeat a dungeon's final boss 10 times.", 10, 10, "INV_Misc_Key_04" },
  { "clears50", "Dungeon Farmer", "Defeat a dungeon's final boss 50 times.", 50, 15, "INV_Misc_Key_04" },
  { "clears100", "Run It Back", "Defeat a dungeon's final boss 100 times.", 100, 20, "INV_Misc_Key_10" },
  { "clears250", "Dungeon Dweller", "Defeat a dungeon's final boss 250 times.", 250, 30, "INV_Misc_Key_10" },
})
ns:Add({ id = "underdog", category = "dungeons", name = "Underdog",
  desc = "Defeat a dungeon's final boss while below its recommended level range.",
  points = 15, icon = "Ability_Warrior_Challange", flag = "underdog" })
ns:Add({ id = "smallgroup", category = "dungeons", name = "Three's Company",
  desc = "Defeat a dungeon's final boss with three or fewer players.",
  points = 20, icon = "Ability_Warrior_Challange", flag = "smallgroup" })

---------------------------------------------------------------------------
-- Raids: one achievement per boss (the final bosses already have one)
---------------------------------------------------------------------------
for _, r in ipairs(ns.RAID_DATA) do
  for i = 1, #r.bosses - 1 do
    local boss = r.bosses[i]
    ns:Add({ id = "rb_" .. r.key .. "_" .. i, category = "raids", name = boss,
      desc = ("Defeat %s in %s."):format(boss, r.name), points = 10, icon = r.icon,
      flag = "boss:" .. boss:lower() })
  end
end
Tiers("raids", "raidBossKills", {
  { "raidboss10", "Raider", "Defeat 10 raid bosses.", 10, 10, "INV_Misc_Head_Dragon_Black" },
  { "raidboss50", "Raid Regular", "Defeat 50 raid bosses.", 50, 20, "INV_Misc_Head_Dragon_Black" },
  { "raidboss100", "Raid Veteran", "Defeat 100 raid bosses.", 100, 30, "INV_Misc_Head_Dragon_Black" },
})
Tiers("raids", "encounter:onyxia", {
  { "ony10", "More Dots!", "Defeat Onyxia 10 times.", 10, 20, "INV_Misc_Head_Dragon_01" },
})

---------------------------------------------------------------------------
-- Professions
---------------------------------------------------------------------------
local PROFS = {
  { "alchemy", "Alchemy", "Trade_Alchemy" }, { "blacksmithing", "Blacksmithing", "Trade_BlackSmithing" },
  { "enchanting", "Enchanting", "Trade_Engraving" }, { "engineering", "Engineering", "Trade_Engineering" },
  { "herbalism", "Herbalism", "Trade_Herbalism" }, { "leatherworking", "Leatherworking", "Trade_LeatherWorking" },
  { "mining", "Mining", "Trade_Mining" }, { "skinning", "Skinning", "INV_Misc_Pelt_Wolf_01" },
  { "tailoring", "Tailoring", "Trade_Tailoring" }, { "cooking", "Cooking", "INV_Misc_Food_15" },
  { "firstaid", "First Aid", "Spell_Holy_Heal" }, { "fishing", "Fishing", "Trade_Fishing" },
}
local RANKS = { { 75, "Apprentice" }, { 150, "Journeyman" }, { 225, "Expert" }, { 300, "Artisan" } }
local EXISTING_300 = { cooking = true, firstaid = true, fishing = true } -- cook300 / aid300 / fish300
for _, p in ipairs(PROFS) do
  for _, rank in ipairs(RANKS) do
    if not (rank[1] == 300 and EXISTING_300[p[1]]) then
      ns:Add({ id = ("p_%s_%d"):format(p[1], rank[1]), category = "professions",
        name = rank[2] .. " " .. p[2], desc = ("Reach %d skill in %s."):format(rank[1], p[2]),
        points = rank[1] == 300 and 15 or 5, icon = p[3],
        counter = "skill:" .. p[1], goal = rank[1] })
    end
  end
end
Tiers("professions", "primaryProfs", {
  { "prof_two", "Double Duty", "Learn two primary professions.", 2, 5, "Trade_BlackSmithing" },
})
ns:Add({ id = "secondary300", category = "professions", name = "Master of the Basics",
  desc = "Reach 300 in Cooking, Fishing and First Aid.", points = 25, icon = "INV_Misc_Food_15",
  meta = { "cook300", "fish300", "aid300" } })
Tiers("professions", "fishCaught", {
  { "fish1", "Gone Fishin'", "Catch a fish.", 1, 5, "Trade_Fishing" },
  { "fish100", "Reel Talent", "Catch 100 fish.", 100, 10, "Trade_Fishing" },
  { "fish500", "Master Baiter", "Catch 500 fish.", 500, 15, "Trade_Fishing" },
  { "fish1000", "The Old Man and the Sea", "Catch 1,000 fish.", 1000, 20, "Trade_Fishing" },
})

---------------------------------------------------------------------------
-- Reputation (Exalted with each faction; Tracking sets "rep<standing>:<name>")
---------------------------------------------------------------------------
local FACTIONS = {
  -- name, side ("A", "H" or nil for neutral)
  { "Stormwind", "A" }, { "Ironforge", "A" }, { "Darnassus", "A" }, { "Gnomeregan Exiles", "A" },
  { "Orgrimmar", "H" }, { "Thunder Bluff", "H" }, { "Undercity", "H" }, { "Darkspear Trolls", "H" },
  { "Argent Dawn" }, { "Timbermaw Hold" }, { "Cenarion Circle" }, { "Thorium Brotherhood" },
  { "Hydraxian Waterlords" }, { "Booty Bay" }, { "Gadgetzan" }, { "Everlook" }, { "Ratchet" },
  { "Ravenholdt" }, { "Shen'dralar" }, { "Gelkis Clan Centaur" }, { "Magram Clan Centaur" },
  { "Wintersaber Trainers", "A" }, { "Stormpike Guard", "A" }, { "Silverwing Sentinels", "A" },
  { "League of Arathor", "A" }, { "Frostwolf Clan", "H" }, { "Warsong Outriders", "H" },
  { "The Defilers", "H" },
}
local SIDE = { A = "Alliance", H = "Horde" }
for _, f in ipairs(FACTIONS) do
  ns:Add({ id = "ex_" .. f[1]:lower():gsub("[^%w]", ""), category = "reputation",
    name = "Exalted: " .. f[1], desc = "Reach Exalted with " .. f[1] .. ".",
    hint = f[2] and (SIDE[f[2]] .. " only") or nil,
    points = 10, icon = "INV_Shirt_GuildTabard_01", flag = "rep8:" .. f[1] })
end
ns:Add({ id = "ex_capitals", category = "reputation", name = "Ambassador of the Realm",
  desc = "Reach Exalted with all four home cities of your faction.", points = 25,
  icon = "INV_BannerPVP_02",
  check = function(n)
    local function all(list)
      for _, name in ipairs(list) do
        if not n:HasFlag("rep8:" .. name) then return false end
      end
      return true
    end
    return all({ "Stormwind", "Ironforge", "Darnassus", "Gnomeregan Exiles" })
        or all({ "Orgrimmar", "Thunder Bluff", "Undercity", "Darkspear Trolls" })
  end })
ns:Add({ id = "honored_bloodsail", category = "reputation", name = "Yarr!",
  desc = "Reach Honored with the Bloodsail Buccaneers.", points = 10,
  icon = "INV_Misc_Bandana_03", flag = "rep6:Bloodsail Buccaneers" })
Tiers("reputation", "exalted", {
  { "exalted10", "Beloved", "Reach Exalted with 10 factions.", 10, 40, "INV_Shirt_GuildTabard_01" },
  { "exalted15", "The Insane", "Reach Exalted with 15 factions.", 15, 50, "INV_Shirt_GuildTabard_01" },
})

---------------------------------------------------------------------------
-- PvP
---------------------------------------------------------------------------
Tiers("pvp", "hk", {
  { "hk10", "First Taste", "Earn 10 honorable kills.", 10, 5, "INV_BannerPVP_01" },
  { "hk2500", "Seasoned Fighter", "Earn 2,500 honorable kills.", 2500, 25, "INV_BannerPVP_02" },
  { "hk10000", "Ten Thousand Strong", "Earn 10,000 honorable kills.", 10000, 40, "INV_BannerPVP_02" },
  { "hk25000", "Gladiator of Azeroth", "Earn 25,000 honorable kills.", 25000, 50, "INV_BannerPVP_02" },
})
Tiers("pvp", "duelWins", {
  { "duel5", "Practice Makes Perfect", "Win 5 duels.", 5, 5, "Ability_Parry" },
  { "duel50", "Dueling Champion", "Win 50 duels.", 50, 15, "Ability_Parry" },
})
local EXISTING_RANKS = { [1] = true, [6] = true, [11] = true }
for rank = 2, 14 do
  if not EXISTING_RANKS[rank] then
    ns:Add({ id = "rank" .. rank, category = "pvp", name = "Honor Rank " .. rank,
      desc = ("Reach PvP rank %d."):format(rank), points = rank >= 12 and 25 or (rank >= 7 and 15 or 10),
      icon = rank >= 12 and "INV_BannerPVP_02" or "INV_BannerPVP_01", counter = "pvpRank", goal = rank })
  end
end
Tiers("pvp", "bgPlayed", {
  { "bgplay10", "Reporting for Duty", "Enter 10 battlegrounds.", 10, 5, "INV_BannerPVP_01" },
  { "bgplay100", "Career Soldier", "Enter 100 battlegrounds.", 100, 15, "INV_BannerPVP_01" },
})
for _, bg in ipairs({ "Warsong Gulch", "Arathi Basin", "Alterac Valley", "Darkspear Islands" }) do
  local key = bg:lower():gsub("[^%w]", "")
  ns:Add({ id = "bgw1_" .. key, category = "pvp", name = bg .. " Victory",
    desc = "Win " .. bg .. ".", points = 10, icon = "INV_BannerPVP_01",
    counter = "bgWins:" .. bg, goal = 1 })
  ns:Add({ id = "bgw25_" .. key, category = "pvp", name = bg .. " Veteran",
    desc = "Win " .. bg .. " 25 times.", points = 20, icon = "INV_BannerPVP_02",
    counter = "bgWins:" .. bg, goal = 25 })
end

---------------------------------------------------------------------------
-- Social
---------------------------------------------------------------------------
local EMOTES = {
  { "HUG", "Free Hugs", "/hug 25 times." }, { "WAVE", "Friendly Neighbor", "/wave 25 times." },
  { "CHEER", "Cheerleader", "/cheer 25 times." }, { "CHICKEN", "Bwaak!", "/chicken 25 times." },
  { "KISS", "Smooch", "/kiss 25 times." }, { "LAUGH", "Laugh It Off", "/laugh 25 times." },
  { "FLEX", "Gym Rat", "/flex 25 times." }, { "BOW", "Courteous", "/bow 25 times." },
  { "SALUTE", "Ten-Hut!", "/salute 25 times." }, { "ROAR", "King of the Jungle", "/roar 25 times." },
  { "CRY", "Drama Queen", "/cry 25 times." }, { "THANK", "Much Obliged", "/thank 25 times." },
  { "APPLAUD", "Standing Ovation", "/applaud 25 times." },
}
for _, e in ipairs(EMOTES) do
  ns:Add({ id = "emote_" .. e[1]:lower(), category = "social", name = e[2], desc = e[3],
    points = 5, icon = "Spell_Holy_MindVision", counter = "emote:" .. e[1], goal = 25 })
end
Tiers("social", "dances", {
  { "dance250", "Dancing Machine", "/dance 250 times.", 250, 10, "Spell_Shadow_Charm" },
})
Tiers("social", "emotes", {
  { "emote500", "Body Language", "Use 500 emotes.", 500, 10, "Spell_Holy_MindVision" },
  { "emote2500", "Never Stops Talking", "Use 2,500 emotes.", 2500, 15, "Spell_Holy_MindVision" },
})
Tiers("social", "emotesUsed", {
  { "emotes10", "Expressive Range", "Use 10 different emotes.", 10, 5, "Spell_Holy_MindVision" },
  { "emotes25", "Thespian", "Use 25 different emotes.", 25, 10, "Spell_Holy_MindVision" },
  { "emotes50", "Master of Mime", "Use 50 different emotes.", 50, 20, "Spell_Holy_MindVision" },
})
ns:Add({ id = "guild", category = "social", name = "Guilded",
  desc = "Join a guild.", points = 10, icon = "INV_Shirt_GuildTabard_01", flag = "guild" })
Tiers("social", "whispers", {
  { "whisper1", "Psst!", "Send a whisper.", 1, 5, "INV_Letter_02" },
  { "whisper100", "Social Butterfly", "Send 100 whispers.", 100, 10, "INV_Letter_02" },
  { "whisper1000", "Chatterbox", "Send 1,000 whispers.", 1000, 15, "INV_Letter_02" },
})
Tiers("social", "mailSent", {
  { "mail1", "Pen Pal", "Send a letter.", 1, 5, "INV_Letter_01" },
  { "mail50", "Postmaster", "Send 50 letters.", 50, 10, "INV_Letter_01" },
})
ns:Add({ id = "inspect1", category = "social", name = "Show and Tell",
  desc = "View another player's achievements with /ach inspect.", points = 5,
  icon = "INV_Misc_Spyglass_02", flag = "inspected" })
Tiers("social", "playersSeen", {
  { "seen5", "Among Friends", "Have 5 different friends interact with the herd.", 5, 5, "Spell_Holy_PrayerOfFortitude" },
  { "seen25", "Achievement Society", "Have 25 different friends interact with the herd.", 25, 10, "Spell_Holy_PrayerOfFortitude" },
})

---------------------------------------------------------------------------
-- Account (uses every character you've logged in with the addon)
---------------------------------------------------------------------------
local function Characters(n) return n.db.characters or {} end
local function CountChars(n, pred)
  local c = 0
  for _, rec in pairs(Characters(n)) do
    if pred(rec) then c = c + 1 end
  end
  return c
end
for _, t in ipairs({ { 2, "Twice the Hero", 15 }, { 3, "Hat Trick", 20 }, { 5, "Army of Alts", 30 }, { 9, "Legion", 50 } }) do
  local goal = t[1]
  ns:Add({ id = "acct60_" .. goal, category = "account", name = t[2],
    desc = ("Have %d characters at level 60."):format(goal), points = t[3], icon = "Spell_Holy_SurgeOfLight",
    progress = function(n)
      return math.min(CountChars(n, function(r) return (r.level or 0) >= 60 end), goal), goal
    end })
end
for _, t in ipairs({ { 3, "Altoholic", 5 }, { 10, "Full Roster", 15 } }) do
  local goal = t[1]
  ns:Add({ id = "acctchars_" .. goal, category = "account", name = t[2],
    desc = ("Log in %d different characters with MooHelper."):format(goal),
    points = t[3], icon = "INV_Misc_GroupNeedMore",
    progress = function(n) return math.min(CountChars(n, function() return true end), goal), goal end })
end
ns:Add({ id = "acct_allclasses", category = "account", name = "Master of All Trades",
  desc = "Have a level 60 character of every class.", points = 75, icon = "Spell_Holy_SurgeOfLight",
  progress = function(n)
    local have = {}
    for _, r in pairs(Characters(n)) do
      if (r.level or 0) >= 60 and r.class then have[r.class] = true end
    end
    local c = 0
    for _, cl in ipairs(ns.CLASSES) do
      if have[cl[1]] then c = c + 1 end
    end
    return c, #ns.CLASSES
  end })
for _, t in ipairs({ { 1000, "Point Collector", 10 }, { 2500, "Point Hoarder", 20 }, { 5000, "Point Tycoon", 30 } }) do
  local goal = t[1]
  ns:Add({ id = "acctpts_" .. goal, category = "account", name = t[2],
    desc = ("Earn %d achievement points across all your characters."):format(goal),
    points = t[3], icon = "INV_Misc_Coin_01",
    progress = function(n)
      local total = 0
      for _, r in pairs(Characters(n)) do total = total + (r.points or 0) end
      return math.min(total, goal), goal
    end })
end

---------------------------------------------------------------------------
-- Feats of Strength
---------------------------------------------------------------------------
ns:Add({ id = "launch_month", category = "feats", hidden = true, name = "Founding Adventurer",
  desc = "Play World of Warcraft: Forever in its launch month (November 2026).",
  points = 0, icon = "INV_Misc_Note_01",
  check = function(n)
    local t = n.char.firstSeenTime or time()
    return t >= time({ year = 2026, month = 11, day = 1, hour = 0 })
       and t < time({ year = 2026, month = 12, day = 1, hour = 0 })
  end })
ns:Add({ id = "raid_opening", category = "feats", hidden = true, name = "Opening Night",
  desc = "Defeat a raid boss during the first week raids were open (December 9-15, 2026).",
  points = 0, icon = "INV_Misc_Head_Dragon_Black", flag = "raidOpeningWeek" })
