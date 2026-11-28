-- MooHelper: MooScape
-- A point-and-click RPG in its own window (/mooscape, /moo quest, /pasture).
--   * five zones joined by gates: the Pasture Lands village, Whispering Woods, Thunder Ridge,
--     Moonwater Lake and the Kodo Graveyard, where the Bone Matriarch waits
--   * eight skills from 1 to 50: Combat, Woodcutting, Mining, Smithing, Fishing, Cooking,
--     Foraging, Crafting
--   * gather, smelt, forge, craft, cook; equip a weapon, armor and a charm
--   * a 28-slot pack and a bank chest; Trader Moo-rgan pays real MooHelper milk
--   * seven quests from four NPCs
--   * friends in your party who run the addon show up on your map as you play
-- The game never posts to chat. The only thing it sends is your position on the hidden addon
-- channel to your party, and only while the window is open and a Herd Keeper is in your group.

local _, ns = ...

local random = math.random
local R = {}
ns.RPG = R

local W, H = 20, 14
local PACK_SIZE = 28
local MAX_LEVEL = 50

---------------------------------------------------------------------------
-- The world
---------------------------------------------------------------------------
-- .  grass   ,  path   :  gate   ~  water   #  wall   X  bones   @  start
-- T  pine   Y  ironbark   E  elderwood   R  copper   I  iron   S  silverhorn   B  berry bush
-- F  campfire   U  furnace   A  anvil   W  workbench   $  trader   C  bank chest   n  NPC
-- monsters (grass underneath): w wolf  b boar  t stalker  g gnoll  G brute  s snapjaw
--   z bone kodo  M the Bone Matriarch

local ZONES = {
  pasture = { name = "The Pasture Lands", rows = {
    "###T..T..:..R..R.###",
    "#..TT............T.#",
    "#.T....B...,..R....#",
    "#.....n....,.....w.#",
    "#..C..$.F..,.......#",
    "#..........,...B...#",
    ":,,,,,,,,,,@,,,,,,,:",
    "#..........,.....w.#",
    "#..T..B....,...T...#",
    "#.TT.......,....b..#",
    "#..T..R....,..T....#",
    "#.....~~~..,.......#",
    "#....~~~~~.,...B...#",
    "####################" },
    exits = { { 10, 1, "ridge", 10, 13 }, { 1, 7, "lake", 19, 7 }, { 20, 7, "woods", 2, 7 } },
    npcs = { { 7, 4, "hoofwise" } } },
  woods = { name = "Whispering Woods", rows = {
    "####################",
    "#TTYT..TT.E..TT..YT#",
    "#T....t....B....t.T#",
    "#Y.TT.....TT..E...T#",
    "#..T..B.n......TT..#",
    "#T.....,,,,,,,..t..#",
    ":,,,,,,,......,,...#",
    "#TT....T..YT..,..TT#",
    "#..w..E.....B.,....#",
    "#T...TT..t....,..YT#",
    "#..B....T...T.,....#",
    "#TT..Y....E...,.TT.#",
    "#T..T..TT.....,..ET#",
    "##############:#####" },
    exits = { { 1, 7, "pasture", 19, 7 }, { 15, 14, "graveyard", 15, 2 } },
    npcs = { { 9, 5, "willowmoo" } } },
  ridge = { name = "Thunder Ridge", rows = {
    "####################",
    "#RR..I...SS...II..R#",
    "#R..g...I....G..S..#",
    "#..I....,,,,....I..#",
    "#.RR..,,,UA,,..R...#",
    "#..g..,..n..,...g..#",
    "#I....,.....,..S...#",
    "#..R..,,,W,,,..I...#",
    "#.S......,.....RR..#",
    "#..II..G.,.g......S#",
    "#R.......,.....I...#",
    "#..R..S..,..R...R..#",
    "#.......,,........I#",
    "#########:##########" },
    exits = { { 10, 14, "pasture", 10, 2 } },
    npcs = { { 10, 6, "brassbell" } } },
  lake = { name = "Moonwater Lake", rows = {
    "####################",
    "#~~~~~~~~~~~~~~~~~~#",
    "#~~~~~~~~~~~~~~~~~~#",
    "#~~~~~~~~~~~~~~~~~~#",
    "#~~~~~..~~~~..~~~~~#",
    "#...~~....s...~~...#",
    "#.F.....n........,,:",
    "#..s.....B..,,,,,..#",
    "#~~...........s..~~#",
    "#~~~~..T...B...~~~~#",
    "#~~~~~~.....~~~~~~~#",
    "#~~~~~~~~~~~~~~~~~~#",
    "#~~~~~~~~~~~~~~~~~~#",
    "####################" },
    exits = { { 20, 7, "pasture", 2, 7 } },
    npcs = { { 9, 7, "gilmoo" } } },
  graveyard = { name = "The Kodo Graveyard", dark = true, rows = {
    "##############:#####",
    "#X..z.....X.....,.X#",
    "#..X....X....X.,...#",
    "#.z...X.....z..,.X.#",
    "#X...X...X.....,...#",
    "#..X..,,,,,,,,,,..z#",
    "#....,,X....X...X..#",
    "#.z..,.....X.......#",
    "#X...,..X......z.X.#",
    "#..X.,,,,,,,,,,....#",
    "#.X.....X....,..X..#",
    "#....X...M....,....#",
    "#X.......X....X..X.#",
    "####################" },
    exits = { { 15, 1, "woods", 15, 13 } },
    npcs = {} },
}
local ZONE_ORDER = { "pasture", "woods", "ridge", "lake", "graveyard" }
R.ZONES, R.ZONE_ORDER, R.W, R.H = ZONES, ZONE_ORDER, W, H

local TILES = {
  ["."] = { name = "Grass", walk = true, color = { 0.27, 0.5, 0.2 } },
  [","] = { name = "Path", walk = true, color = { 0.58, 0.47, 0.3 } },
  [":"] = { name = "Gate", walk = true, color = { 0.85, 0.75, 0.35 }, glyph = ">" },
  ["~"] = { name = "Water", gather = "fish", color = { 0.15, 0.32, 0.62 } },
  ["#"] = { name = "Wall", color = { 0.3, 0.22, 0.14 }, glyph = "#" },
  ["X"] = { name = "Old bones", color = { 0.5, 0.48, 0.42 }, glyph = "x" },
  ["T"] = { name = "Pine tree", gather = "pine", color = { 0.1, 0.3, 0.1 }, glyph = "T" },
  ["Y"] = { name = "Ironbark tree", gather = "ironbark", color = { 0.2, 0.22, 0.14 }, glyph = "Y" },
  ["E"] = { name = "Elderwood tree", gather = "elderwood", color = { 0.12, 0.25, 0.3 }, glyph = "E" },
  ["R"] = { name = "Copper rock", gather = "copper", color = { 0.55, 0.35, 0.2 }, glyph = "R" },
  ["I"] = { name = "Iron rock", gather = "iron", color = { 0.42, 0.42, 0.45 }, glyph = "I" },
  ["S"] = { name = "Silverhorn rock", gather = "silverhorn", color = { 0.7, 0.72, 0.8 }, glyph = "S" },
  ["B"] = { name = "Moo-berry bush", gather = "berries", color = { 0.35, 0.15, 0.4 }, glyph = "B" },
  ["F"] = { name = "Campfire", station = "campfire", color = { 0.85, 0.4, 0.1 }, glyph = "F" },
  ["U"] = { name = "Furnace", station = "furnace", color = { 0.6, 0.2, 0.1 }, glyph = "U" },
  ["A"] = { name = "Anvil", station = "anvil", color = { 0.25, 0.25, 0.3 }, glyph = "A" },
  ["W"] = { name = "Workbench", station = "workbench", color = { 0.45, 0.3, 0.15 }, glyph = "W" },
  ["$"] = { name = "Trader Moo-rgan", use = "sell", color = { 0.8, 0.68, 0.2 }, glyph = "$" },
  ["C"] = { name = "Bank chest", use = "bank", color = { 0.55, 0.4, 0.15 }, glyph = "C" },
  ["n"] = { name = "Someone", use = "talk", color = { 0.27, 0.5, 0.2 } },
  ["s1"] = { name = "Tree stump", color = { 0.3, 0.42, 0.18 }, glyph = "." },
  ["r1"] = { name = "Empty rock", color = { 0.3, 0.3, 0.3 }, glyph = "." },
  ["e1"] = { name = "Picked bush", color = { 0.25, 0.35, 0.2 }, glyph = "." },
}
R.TILES = TILES

local SKILLS = { "combat", "woodcutting", "mining", "smithing", "fishing", "cooking", "foraging", "crafting" }
local SKILL_NAMES = { combat = "Combat", woodcutting = "Woodcutting", mining = "Mining", smithing = "Smithing",
  fishing = "Fishing", cooking = "Cooking", foraging = "Foraging", crafting = "Crafting" }
R.SKILLS, R.SKILL_NAMES = SKILLS, SKILL_NAMES

-- gathering spots; "into" is what the tile becomes for a while when it runs out
local GATHER = {
  pine = { skill = "woodcutting", item = "logs", req = 1, xp = 15, deplete = 0.15, into = "s1", respawn = 20 },
  ironbark = { skill = "woodcutting", item = "ironbark", req = 15, xp = 40, deplete = 0.2, into = "s1", respawn = 30 },
  elderwood = { skill = "woodcutting", item = "elderwood", req = 30, xp = 75, deplete = 0.25, into = "s1", respawn = 45 },
  copper = { skill = "mining", item = "copper", req = 1, xp = 17, deplete = 0.25, into = "r1", respawn = 15 },
  iron = { skill = "mining", item = "iron", req = 15, xp = 35, deplete = 0.3, into = "r1", respawn = 25 },
  silverhorn = { skill = "mining", item = "silverhorn", req = 30, xp = 70, deplete = 0.35, into = "r1", respawn = 40 },
  berries = { skill = "foraging", item = "berries", req = 1, xp = 8, deplete = 0.2, into = "e1", respawn = 20 },
  -- fish: the best catch you're able to land, tried from the top
  fish = { skill = "fishing", item = "minnow", req = 1, xp = 10,
    better = { { item = "glimmerfin", req = 30, xp = 70, chance = 0.25 }, { item = "trout", req = 10, xp = 25, chance = 0.4 } } },
}
R.GATHER = GATHER

-- equipment: atk adds to max hit, def cuts the monster's chance to hit you, hp adds health
local ITEMS = {
  logs = { name = "Pine Logs", price = 3 },
  ironbark = { name = "Ironbark Logs", price = 12 },
  elderwood = { name = "Elderwood Logs", price = 30 },
  copper = { name = "Copper Ore", price = 4 },
  iron = { name = "Iron Ore", price = 14 },
  silverhorn = { name = "Silverhorn Ore", price = 35 },
  copperbar = { name = "Copper Bar", price = 10 },
  ironbar = { name = "Iron Bar", price = 30 },
  silverbar = { name = "Silverhorn Bar", price = 80 },
  minnow = { name = "Raw Minnow", price = 2 },
  trout = { name = "Raw Trout", price = 6 },
  glimmerfin = { name = "Raw Glimmerfin", price = 15 },
  cminnow = { name = "Cooked Minnow", price = 5, heal = 3 },
  ctrout = { name = "Cooked Trout", price = 12, heal = 7 },
  cglimmer = { name = "Cooked Glimmerfin", price = 30, heal = 14 },
  burnt = { name = "Burnt Fish", price = 0 },
  berries = { name = "Moo-berries", price = 1, heal = 2 },
  pelt = { name = "Wolf Pelt", price = 10 },
  tusk = { name = "Boar Tusk", price = 20 },
  scale = { name = "Snapjaw Scale", price = 22 },
  thornhide = { name = "Thornback Hide", price = 35 },
  trinket = { name = "Gnoll Trinket", price = 30 },
  bone = { name = "Ancient Bone", price = 25 },
  mhorn = { name = "Matriarch's Horn", price = 0, quest = true },
  copperhammer = { name = "Copper Hoof-Hammer", price = 20, slot = "weapon", atk = 2, req = 1 },
  ironhammer = { name = "Iron Hoof-Hammer", price = 60, slot = "weapon", atk = 4, req = 10 },
  bruteclub = { name = "Brute's Club", price = 90, slot = "weapon", atk = 5, req = 15 },
  silverhammer = { name = "Silverhorn Hammer", price = 200, slot = "weapon", atk = 7, req = 25 },
  leatherbard = { name = "Leather Barding", price = 25, slot = "armor", def = 0.10, req = 1 },
  scalebard = { name = "Snapscale Barding", price = 70, slot = "armor", def = 0.18, req = 10 },
  ironbard = { name = "Iron Barding", price = 110, slot = "armor", def = 0.22, req = 15 },
  thornbard = { name = "Thornhide Barding", price = 150, slot = "armor", def = 0.28, req = 20 },
  silverbard = { name = "Silverhorn Barding", price = 300, slot = "armor", def = 0.34, req = 25 },
  tuskcharm = { name = "Tusk Charm", price = 40, slot = "charm", atk = 1, hp = 2, req = 1 },
  bonecharm = { name = "Bone Charm", price = 120, slot = "charm", atk = 2, hp = 6, req = 20 },
}
R.ITEMS = ITEMS
local ITEM_ORDER = { "logs", "ironbark", "elderwood", "copper", "iron", "silverhorn", "copperbar", "ironbar", "silverbar",
  "minnow", "trout", "glimmerfin", "cminnow", "ctrout", "cglimmer", "burnt", "berries", "pelt", "tusk", "scale",
  "thornhide", "trinket", "bone", "mhorn", "copperhammer", "ironhammer", "bruteclub", "silverhammer", "leatherbard",
  "scalebard", "ironbard", "thornbard", "silverbard", "tuskcharm", "bonecharm" }
R.ITEM_ORDER = ITEM_ORDER
local SLOTS = { "weapon", "armor", "charm" }

-- what you can make, and where
local RECIPES = {
  campfire = {
    { out = "cminnow", skill = "cooking", req = 1, xp = 20, need = { minnow = 1 }, burn = true },
    { out = "ctrout", skill = "cooking", req = 10, xp = 40, need = { trout = 1 }, burn = true },
    { out = "cglimmer", skill = "cooking", req = 30, xp = 80, need = { glimmerfin = 1 }, burn = true },
  },
  furnace = {
    { out = "copperbar", skill = "smithing", req = 1, xp = 12, need = { copper = 1 } },
    { out = "ironbar", skill = "smithing", req = 15, xp = 25, need = { iron = 1 } },
    { out = "silverbar", skill = "smithing", req = 30, xp = 50, need = { silverhorn = 2 } },
  },
  anvil = {
    { out = "copperhammer", skill = "smithing", req = 3, xp = 40, need = { copperbar = 3 } },
    { out = "ironhammer", skill = "smithing", req = 18, xp = 90, need = { ironbar = 3 } },
    { out = "ironbard", skill = "smithing", req = 20, xp = 120, need = { ironbar = 4 } },
    { out = "silverhammer", skill = "smithing", req = 33, xp = 220, need = { silverbar = 3 } },
    { out = "silverbard", skill = "smithing", req = 36, xp = 300, need = { silverbar = 5 } },
  },
  workbench = {
    { out = "leatherbard", skill = "crafting", req = 1, xp = 30, need = { pelt = 3 } },
    { out = "tuskcharm", skill = "crafting", req = 5, xp = 40, need = { tusk = 2 } },
    { out = "scalebard", skill = "crafting", req = 12, xp = 80, need = { scale = 4 } },
    { out = "thornbard", skill = "crafting", req = 22, xp = 150, need = { thornhide = 4 } },
    { out = "bonecharm", skill = "crafting", req = 28, xp = 200, need = { bone = 3 } },
  },
}
R.RECIPES = RECIPES
local STATION_NAMES = { campfire = "Campfire", furnace = "Furnace", anvil = "Anvil", workbench = "Workbench" }

local ICON = "Interface\\Icons\\"
local MOBS = {
  w = { name = "Prairie Wolf", level = 2, hp = 8, maxHit = 2, xp = 20, drop = "pelt", icon = ICON .. "Ability_Hunter_Pet_Wolf" },
  b = { name = "Bristleback Boar", level = 6, hp = 16, maxHit = 3, xp = 45, drop = "tusk", icon = ICON .. "Ability_Hunter_Pet_Boar" },
  g = { name = "Rocktusk Gnoll", level = 10, hp = 24, maxHit = 4, xp = 80, drop = "trinket", icon = ICON .. "Ability_Hunter_Pet_Hyena" },
  s = { name = "Snapjaw", level = 12, hp = 28, maxHit = 4, xp = 95, drop = "scale", icon = ICON .. "Ability_Hunter_Pet_Crocolisk" },
  t = { name = "Thornback Stalker", level = 18, hp = 40, maxHit = 6, xp = 160, drop = "thornhide", icon = ICON .. "Ability_Hunter_Pet_Spider" },
  G = { name = "Rocktusk Brute", level = 22, hp = 55, maxHit = 7, xp = 220, drop = "bruteclub", dropChance = 0.25,
    otherDrop = "trinket", icon = ICON .. "Ability_Hunter_Pet_Hyena", tint = { 1, 0.5, 0.4 } },
  z = { name = "Bone Kodo", level = 28, hp = 70, maxHit = 8, xp = 300, drop = "bone", icon = ICON .. "Ability_Mount_Kodo_01",
    tint = { 0.6, 0.6, 0.55 } },
  M = { name = "The Bone Matriarch", level = 40, hp = 220, maxHit = 11, xp = 1500, drop = "mhorn", boss = true,
    respawn = 300, icon = ICON .. "Ability_Mount_Kodo_01", tint = { 0.7, 0.4, 0.9 } },
}
R.MOBS = MOBS

-- "the Prairie Wolf", but "The Bone Matriarch" (her name already has it)
local function The(def, capital)
  if def.name:find("^The ") then return capital and def.name or def.name:gsub("^The", "the") end
  return (capital and "The " or "the ") .. def.name
end

local NPCS = {
  hoofwise = { name = "Elder Hoofwise", greet = "The herd grows strong when its calves work hard. Moo." },
  willowmoo = { name = "Ranger Willowmoo", greet = "Keep to the paths. The woods have teeth." },
  brassbell = { name = "Forgemaster Brassbell", greet = "Ore in, hammers out. That's the way of the Ridge." },
  gilmoo = { name = "Fisher Gilmoo", greet = "Moonwater gives to the patient. Mostly minnows." },
}
R.NPCS = NPCS

-- need.items are handed in when you finish; need.kills count while the quest is active
local QUESTS = {
  { id = "chop", giver = "hoofwise", name = "A Calf's First Chop",
    text = "Every calf starts with an axe. Bring me 5 Pine Logs.",
    need = { items = { logs = 5 } }, reward = { xp = { woodcutting = 150 }, items = { copperhammer = 1 }, milk = 100 } },
  { id = "wolves", giver = "hoofwise", name = "Wolves at the Fence", after = { "chop" },
    text = "Prairie wolves keep testing the fence. Drive off 3 of them.",
    need = { kills = { w = 3 } }, reward = { xp = { combat = 200 }, items = { leatherbard = 1 }, milk = 150 } },
  { id = "forge", giver = "brassbell", name = "Fire in the Belly",
    text = "Show me you can work the furnace. Smelt 5 Copper Bars and bring them here.",
    need = { items = { copperbar = 5 } }, reward = { xp = { smithing = 300 }, milk = 200 } },
  { id = "gnolls", giver = "brassbell", name = "Gnoll Problem", after = { "forge" },
    text = "Rocktusk gnolls are stealing our ore. Teach 6 of them a lesson.",
    need = { kills = { g = 6 } }, reward = { xp = { combat = 500 }, items = { tuskcharm = 1 }, milk = 300 } },
  { id = "supper", giver = "gilmoo", name = "Lake Supper",
    text = "The village is hungry. Bring me 5 Cooked Trout.",
    need = { items = { ctrout = 5 } }, reward = { xp = { cooking = 400, fishing = 200 }, milk = 300 } },
  { id = "thorns", giver = "willowmoo", name = "Thorns in Our Side",
    text = "Thornback stalkers prowl the woods. Bring down 5 of them.",
    need = { kills = { t = 5 } }, reward = { xp = { combat = 900 }, milk = 500 } },
  { id = "matriarch", giver = "hoofwise", name = "The Bone Matriarch", after = { "wolves", "thorns", "gnolls" },
    text = "Beyond the woods lies the Kodo Graveyard, where the Bone Matriarch stirs. End her restless reign and bring me her horn.",
    need = { items = { mhorn = 1 } }, reward = { xp = { combat = 3000 }, items = { silverhammer = 1 }, milk = 2500 } },
}
local QUEST_BY_ID = {}
for _, q in ipairs(QUESTS) do QUEST_BY_ID[q.id] = q end
R.QUESTS, R.QUEST_BY_ID = QUESTS, QUEST_BY_ID

local STEP_TIME, GATHER_TIME, MAKE_TIME, FIGHT_TIME = 0.22, 2.0, 1.6, 1.4
local MOB_RESPAWN, REGEN_TIME = 30, 8
local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

---------------------------------------------------------------------------
-- Levels, stats
---------------------------------------------------------------------------

function R.XPFor(level)
  if level <= 1 then return 0 end
  return math.floor(30 * (level - 1) ^ 2.2)
end
function R.LevelFor(xp)
  local level = 1
  while level < MAX_LEVEL and xp >= R.XPFor(level + 1) do level = level + 1 end
  return level
end

local function S() return ns.db.rpg end
local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

function R:Level(skill) return R.LevelFor(S().xp[skill] or 0) end
function R:TotalLevel()
  local n = 0
  for _, k in ipairs(SKILLS) do n = n + self:Level(k) end
  return n
end
local function Gear(self, field)
  local n = 0
  for _, slot in ipairs(SLOTS) do
    local it = ITEMS[S().equip[slot] or ""]
    if it and it[field] then n = n + it[field] end
  end
  return n
end
function R:MaxHP() return 10 + self:Level("combat") + Gear(self, "hp") end
function R:MaxHit() return 1 + math.floor(self:Level("combat") / 3) + Gear(self, "atk") end
function R:Defense() return Gear(self, "def") end

---------------------------------------------------------------------------
-- Messages and effects
---------------------------------------------------------------------------

R.log, R.splats = {}, {}
function R:Say(text)
  table.insert(self.log, text)
  while #self.log > 6 do table.remove(self.log, 1) end
  self.dirty = true
end
-- a floating number over a tile
function R:Splat(x, y, text, color)
  table.insert(self.splats, { x = x, y = y, text = text, color = color, born = self.clock })
  while #self.splats > 8 do table.remove(self.splats, 1) end
  self.dirty = true
end

---------------------------------------------------------------------------
-- Loading a zone
---------------------------------------------------------------------------

function R:LoadZone(key)
  local z = ZONES[key]
  self.zone, self.zdef = key, z
  self.grid, self.mobs, self.depleted, self.npcAt = {}, {}, {}, {}
  for y = 1, H do
    self.grid[y] = {}
    for x = 1, W do
      local c = z.rows[y]:sub(x, x)
      if c == "@" then c = "," end
      if MOBS[c] then
        local def = MOBS[c]
        self.mobs[#self.mobs + 1] = { kind = c, def = def, x = x, y = y, homeX = x, homeY = y, hp = def.hp, moveAt = 0 }
        c = "."
      end
      self.grid[y][x] = c
    end
  end
  for _, n in ipairs(z.npcs) do self.npcAt[n[2] * 100 + n[1]] = n[3] end
  self.path, self.action, self.splats = nil, nil, {}
  local seen = S().zonesSeen
  if not seen[key] then
    seen[key] = true
    local count = 0
    for _ in pairs(seen) do count = count + 1 end
    ns:StatMax("rpgZones", count)
  end
  self.dirty = true
end

function R:Init()
  ns.db.rpg = ns.db.rpg or {}
  local s = ns.db.rpg
  s.xp, s.inv, s.bank, s.equip = s.xp or {}, s.inv or {}, s.bank or {}, s.equip or {}
  s.quests, s.zonesSeen = s.quests or {}, s.zonesSeen or {}
  for _, k in ipairs(SKILLS) do s.xp[k] = math.max(0, tonumber(s.xp[k]) or 0) end
  for _, bag in ipairs({ s.inv, s.bank }) do
    for k, v in pairs(bag) do
      if not ITEMS[k] or type(v) ~= "number" or v < 1 then bag[k] = nil else bag[k] = math.floor(v) end
    end
  end
  for _, slot in ipairs(SLOTS) do
    local it = ITEMS[s.equip[slot] or ""]
    if not it or it.slot ~= slot then s.equip[slot] = nil end
  end
  for id, q in pairs(s.quests) do
    if not QUEST_BY_ID[id] or type(q) ~= "table" then s.quests[id] = nil end
  end
  if not ZONES[s.zone] then s.zone = "pasture" end
  self:LoadZone(s.zone)
  if not (tonumber(s.x) and tonumber(s.y) and self:Walkable(s.x, s.y)) then
    self:LoadZone("pasture")
    s.zone, s.x, s.y = "pasture", 12, 7
  end
  s.hp = Clamp(tonumber(s.hp) or self:MaxHP(), 1, self:MaxHP())
  self.moveT, self.actT, self.regenT, self.clock = 0, 0, 0, self.clock or 0
  self.peers = self.peers or {}
  self.ready = true
end

---------------------------------------------------------------------------
-- The map
---------------------------------------------------------------------------

function R:Tile(x, y)
  if x < 1 or y < 1 or x > W or y > H then return nil end
  return TILES[self.grid[y][x]]
end
function R:NPCAt(x, y) return self.npcAt[y * 100 + x] end
function R:MobAt(x, y)
  for _, m in ipairs(self.mobs) do
    if not m.dead and m.x == x and m.y == y then return m end
  end
end
function R:Walkable(x, y)
  local t = self:Tile(x, y)
  return t ~= nil and t.walk == true and not self:MobAt(x, y)
end
local function Adjacent(ax, ay, bx, by) return math.abs(ax - bx) + math.abs(ay - by) == 1 end

-- Breadth-first path from the player to (tx, ty), or to a tile beside it when nextTo is set.
-- A list of {x, y} steps (empty when already there), or nil when there's no way.
function R:Path(tx, ty, nextTo)
  local s = S()
  local function Goal(x, y)
    if nextTo then return Adjacent(x, y, tx, ty) end
    return x == tx and y == ty
  end
  if Goal(s.x, s.y) then return {} end
  local home = s.y * 100 + s.x
  local from, queue, head = { [home] = false }, { { s.x, s.y } }, 1
  while head <= #queue do
    local cx, cy = queue[head][1], queue[head][2]
    head = head + 1
    for _, d in ipairs(DIRS) do
      local nx, ny = cx + d[1], cy + d[2]
      local k = ny * 100 + nx
      if from[k] == nil and self:Walkable(nx, ny) then
        from[k] = cy * 100 + cx
        if Goal(nx, ny) then
          local path, at = {}, k
          while at and at ~= home do
            table.insert(path, 1, { at % 100, math.floor(at / 100) })
            at = from[at]
          end
          return path
        end
        queue[#queue + 1] = { nx, ny }
      end
    end
  end
  return nil
end

---------------------------------------------------------------------------
-- Pack, bank, gear
---------------------------------------------------------------------------

function R:Count(item) return S().inv[item] or 0 end
function R:PackUsed()
  local n = 0
  for _, v in pairs(S().inv) do n = n + v end
  return n
end
function R:PackFree() return PACK_SIZE - self:PackUsed() end

-- returns how many fit
function R:AddItem(item, n)
  n = math.min(n or 1, self:PackFree())
  if n <= 0 then return 0 end
  local inv = S().inv
  inv[item] = (inv[item] or 0) + n
  self.dirty = true
  return n
end
function R:TakeItem(item, n)
  local inv = S().inv
  n = n or 1
  if (inv[item] or 0) < n then return false end
  inv[item] = inv[item] - n
  if inv[item] <= 0 then inv[item] = nil end
  self.dirty = true
  return true
end

function R:Deposit()
  local s, moved = S(), 0
  for k, v in pairs(s.inv) do
    s.bank[k] = (s.bank[k] or 0) + v
    moved = moved + v
  end
  wipe(s.inv)
  self.dirty = true
  self:Say(moved > 0 and ("You put %d items in the bank."):format(moved) or "Your pack is already empty.")
  return moved
end
function R:Withdraw(item)
  local s = S()
  local have = s.bank[item] or 0
  local n = math.min(have, self:PackFree())
  if n <= 0 then self:Say(have > 0 and "Your pack is full." or "You have none of those in the bank.") return 0 end
  s.bank[item] = have - n
  if s.bank[item] <= 0 then s.bank[item] = nil end
  self:AddItem(item, n)
  return n
end

function R:Equip(item)
  local it, s = ITEMS[item], S()
  if not it or not it.slot then return false end
  if self:Count(item) < 1 then return false end
  if self:Level("combat") < it.req then
    self:Say(("You need Combat level %d to use the %s."):format(it.req, it.name))
    return false
  end
  self:TakeItem(item)
  local old = s.equip[it.slot]
  s.equip[it.slot] = item
  if old then self:AddItem(old) end -- always fits: we just took one out
  s.hp = math.min(s.hp, self:MaxHP())
  self:Say(("You equip the %s."):format(it.name))
  return true
end
function R:Unequip(slot)
  local s = S()
  local item = s.equip[slot]
  if not item then return false end
  if self:PackFree() < 1 then self:Say("Your pack is full.") return false end
  s.equip[slot] = nil
  self:AddItem(item)
  s.hp = math.min(s.hp, self:MaxHP())
  return true
end

-- click a pack item: equip it, eat it, or say what it is
function R:UseItem(item)
  local it = ITEMS[item]
  if not it then return end
  if it.slot then return self:Equip(item) end
  if it.heal then return self:Eat(item) end
  self:Say(("%s. Trader Moo-rgan pays %d milk for one."):format(it.name, it.price))
end

function R:Eat(item)
  local it, s = ITEMS[item], S()
  if not it or not it.heal then self:Say("You can't eat that.") return false end
  if self:Count(item) < 1 then return false end
  if s.hp >= self:MaxHP() then self:Say("You're not hungry.") return false end
  self:TakeItem(item)
  s.hp = math.min(self:MaxHP(), s.hp + it.heal)
  self:Splat(s.x, s.y, "+" .. it.heal, { 0.3, 1, 0.3 })
  self:Say(("You eat the %s. Health %d/%d."):format(it.name, s.hp, self:MaxHP()))
  return true
end

function R:AddXP(skill, amount)
  local s = S()
  local before = self:Level(skill)
  s.xp[skill] = (s.xp[skill] or 0) + amount
  local after = self:Level(skill)
  if after > before then
    self:Say(("|cffffd100Level up!|r %s is now %d."):format(SKILL_NAMES[skill], after))
    if ns.Toast then ns:Toast("MOOSCAPE LEVEL UP", ("%s %d"):format(SKILL_NAMES[skill], after)) end
    self.big = { text = ("LEVEL UP!  %s %d"):format(SKILL_NAMES[skill], after), born = self.clock }
    if PlaySound then pcall(PlaySound, 888) end
    ns:Bump("rpgLevelUps", after - before)
    ns:StatMax("rpgTotalLevel", self:TotalLevel())
    if skill == "combat" then s.hp = math.min(self:MaxHP(), s.hp + (after - before)) end
  end
  self.dirty = true
end

---------------------------------------------------------------------------
-- Quests
---------------------------------------------------------------------------

function R:QuestState(id)
  local q = S().quests[id]
  return q and q.state or nil
end

function R:QuestAvailable(q)
  if self:QuestState(q.id) then return false end
  for _, before in ipairs(q.after or {}) do
    if self:QuestState(before) ~= "done" then return false end
  end
  return true
end

function R:QuestProgress(q)
  local st = S().quests[q.id]
  local parts, ready = {}, true
  for item, n in pairs(q.need.items or {}) do
    local have = math.min(self:Count(item), n)
    parts[#parts + 1] = ("%s %d/%d"):format(ITEMS[item].name, have, n)
    if have < n then ready = false end
  end
  for kind, n in pairs(q.need.kills or {}) do
    local have = math.min(st and st.kills and st.kills[kind] or 0, n)
    parts[#parts + 1] = ("%s %d/%d"):format(MOBS[kind].name, have, n)
    if have < n then ready = false end
  end
  table.sort(parts)
  return ready, table.concat(parts, ", ")
end

function R:AcceptQuest(id)
  local q = QUEST_BY_ID[id]
  if not q or not self:QuestAvailable(q) then return false end
  S().quests[id] = { state = "active", kills = {} }
  self:Say(("|cffffd100Quest accepted:|r %s"):format(q.name))
  return true
end

function R:CompleteQuest(id)
  local q, s = QUEST_BY_ID[id], S()
  if not q or self:QuestState(id) ~= "active" then return false end
  local ready = self:QuestProgress(q)
  if not ready then return false end
  -- rewards that are items need room (after the hand-in frees some)
  local handIn, rewardItems = 0, 0
  for _, n in pairs(q.need.items or {}) do handIn = handIn + n end
  for _, n in pairs(q.reward.items or {}) do rewardItems = rewardItems + n end
  if self:PackFree() + handIn < rewardItems then self:Say("Make room in your pack for the reward first.") return false end
  for item, n in pairs(q.need.items or {}) do self:TakeItem(item, n) end
  s.quests[id] = { state = "done" }
  for skill, xp in pairs(q.reward.xp or {}) do self:AddXP(skill, xp) end
  for item, n in pairs(q.reward.items or {}) do self:AddItem(item, n) end
  if q.reward.milk and ns.AddMilk then ns:AddMilk(q.reward.milk) end
  ns:Bump("rpgQuests")
  if id == "matriarch" then ns:Bump("rpgMatriarchQuest") end
  self:Say(("|cff80ff80Quest complete:|r %s (+%d milk)"):format(q.name, q.reward.milk or 0))
  if ns.Toast then ns:Toast("QUEST COMPLETE", q.name) end
  return true
end

-- what an NPC has for you: list of { quest, kind = "offer" | "turnin" | "progress" }
function R:NPCQuests(npc)
  local list = {}
  for _, q in ipairs(QUESTS) do
    if q.giver == npc then
      local state = self:QuestState(q.id)
      if state == "active" then
        list[#list + 1] = { quest = q, kind = self:QuestProgress(q) and "turnin" or "progress" }
      elseif self:QuestAvailable(q) then
        list[#list + 1] = { quest = q, kind = "offer" }
      end
    end
  end
  return list
end

local function CountKill(self, kind)
  for id, st in pairs(S().quests) do
    local q = QUEST_BY_ID[id]
    if st.state == "active" and q.need.kills and q.need.kills[kind] then
      st.kills = st.kills or {}
      st.kills[kind] = (st.kills[kind] or 0) + 1
      local ready = self:QuestProgress(q)
      if ready then self:Say(("|cffffd100%s|r: done! Return to %s."):format(q.name, NPCS[q.giver].name)) end
    end
  end
end

---------------------------------------------------------------------------
-- Clicking the world
---------------------------------------------------------------------------


function R:Click(x, y)
  if not self.ready or not self:Tile(x, y) then return end
  self.popup = nil
  local mob = self:MobAt(x, y)
  if mob then
    self.action = { kind = "fight", mob = mob }
    self.path = self:Path(mob.x, mob.y, true)
    if not self.path then self:Say("You can't reach " .. The(mob.def) .. ".") self.action = nil end
    return
  end
  local t = self:Tile(x, y)
  local npc = self:NPCAt(x, y)
  if t.walk then
    self.action = nil
    self.path = self:Path(x, y, false)
    if not self.path then self:Say("You can't get there.") end
    return
  end
  if npc or t.gather or t.use or t.station then
    local kind = npc and "talk" or (t.gather and "gather") or t.use or "station"
    self.action = { kind = kind, x = x, y = y, npc = npc, station = t.station }
    self.path = self:Path(x, y, true)
    self.actT = 0
    if not self.path then self:Say("You can't reach that.") self.action = nil end
    return
  end
  self:Say(t.name .. ".")
end

local function DoGather(self, a)
  local t = self:Tile(a.x, a.y)
  if not t or not t.gather then self.action = nil return end
  if self:PackFree() < 1 then self:Say("Your pack is full. Bank or sell something.") self.action = nil return end
  local g = GATHER[t.gather]
  local level = self:Level(g.skill)
  local item, xp, req = g.item, g.xp, g.req
  for _, b in ipairs(g.better or {}) do
    if level >= b.req and random() < b.chance then item, xp, req = b.item, b.xp, b.req break end
  end
  if level < req then
    self:Say(("You need %s level %d for that."):format(SKILL_NAMES[g.skill], req))
    self.action = nil
    return
  end
  local chance = Clamp(0.3 + 0.04 * (level - req), 0.3, 0.9)
  if random() < chance then
    self:AddItem(item)
    self:AddXP(g.skill, xp)
    ns:Bump("rpgGathered")
    self:Splat(a.x, a.y, "+1 " .. ITEMS[item].name, { 1, 0.9, 0.5 })
    if g.deplete and random() < g.deplete then
      self.depleted[#self.depleted + 1] = { x = a.x, y = a.y, c = self.grid[a.y][a.x], at = self.clock + g.respawn }
      self.grid[a.y][a.x] = g.into
      self:Say(("The %s is used up for now."):format(t.name:lower()))
      self.action = nil
    end
  end
end

-- the recipes you can make right now at a station (all of them, with whether each is possible)
function R:StationRecipes(station)
  local out = {}
  for _, r in ipairs(RECIPES[station] or {}) do
    local can = self:Level(r.skill) >= r.req
    for item, n in pairs(r.need) do if self:Count(item) < n then can = false end end
    out[#out + 1] = { recipe = r, can = can }
  end
  return out
end

-- start making something (count: a number, or "all")
function R:Make(station, index, count)
  local r = RECIPES[station] and RECIPES[station][index]
  if not r then return false end
  if self:Level(r.skill) < r.req then
    self:Say(("You need %s level %d to make that."):format(SKILL_NAMES[r.skill], r.req))
    return false
  end
  local a = self.action
  if not (a and a.station == station) then return false end
  a.make, a.left = index, count == "all" and 999 or (tonumber(count) or 1)
  self.actT = MAKE_TIME -- the first one starts right away
  self.popup = nil
  return true
end

local function DoMake(self, a)
  local r = RECIPES[a.station][a.make]
  for item, n in pairs(r.need) do
    if self:Count(item) < n then
      self:Say(("You're out of %s."):format(ITEMS[item].name))
      a.make = nil
      return
    end
  end
  for item, n in pairs(r.need) do self:TakeItem(item, n) end
  local out = r.out
  if r.burn and random() < Clamp(0.5 - 0.04 * (self:Level(r.skill) - r.req), 0.05, 0.5) then
    out = "burnt"
    self:Say("You burn it. Moo...")
  else
    self:AddXP(r.skill, r.xp)
    self:Say(("You make a %s."):format(ITEMS[out].name))
    if out == "silverhammer" then ns:Bump("rpgSilverhammer") end
    ns:Bump("rpgCrafted")
  end
  self:AddItem(out) -- always fits: the ingredients just made room
  a.left = a.left - 1
  if a.left <= 0 then a.make = nil end
end

function R:Sell()
  local s = S()
  local total, sold = 0, 0
  for _, k in ipairs(ITEM_ORDER) do
    local it, n = ITEMS[k], self:Count(k)
    -- food and gear are kept; quest items can't be sold
    if n > 0 and not it.heal and not it.slot and not it.quest then
      total = total + it.price * n
      sold = sold + n
      s.inv[k] = nil
    end
  end
  self.dirty = true
  if sold == 0 then
    self:Say("Trader Moo-rgan: \"Bring me logs, ore, bars, fish and hides, friend.\"")
    return 0
  end
  if total > 0 and ns.AddMilk then ns:AddMilk(total) end
  ns:Bump("rpgMilkEarned", total)
  self:Say(("Trader Moo-rgan buys %d items for %s milk."):format(sold, ns.FormatNumber and ns.FormatNumber(total) or total))
  return total
end

local function KnockedOut(self)
  local s = S()
  ns:Bump("rpgDeaths")
  self:LoadZone("pasture")
  s.zone, s.x, s.y, s.hp = "pasture", 12, 7, self:MaxHP()
  self:Say("|cffff4040You were knocked out!|r You wake up in the village, keeping your things. Moo.")
end

local function DoFight(self, mob)
  local s = S()
  local my = self:Level("combat")
  if random() < Clamp(0.55 + 0.03 * (my - mob.def.level), 0.15, 0.9) then
    local dmg = random(1, self:MaxHit())
    mob.hp = mob.hp - dmg
    mob.flash = self.clock
    self:Splat(mob.x, mob.y, tostring(dmg), { 1, 1, 0.3 })
  else
    self:Splat(mob.x, mob.y, "miss", { 0.7, 0.7, 0.7 })
  end
  if mob.hp <= 0 then
    mob.dead, mob.respawnAt = true, self.clock + (mob.def.respawn or MOB_RESPAWN)
    self:AddXP("combat", mob.def.xp)
    local drop = mob.def.drop
    if mob.def.dropChance and random() > mob.def.dropChance then drop = mob.def.otherDrop end
    local got = self:AddItem(drop)
    ns:Bump("rpgKills")
    if mob.kind == "z" then ns:Bump("rpgKodoKills") end
    if mob.def.boss then
      ns:Bump("rpgBossKills")
      if ns.Toast then ns:Toast("BOSS DEFEATED", mob.def.name) end
      if ns.Stampede then ns:Stampede(30) end
    end
    CountKill(self, mob.kind)
    self:Say(("%s is defeated!%s"):format(The(mob.def, true),
      got > 0 and (" It drops a " .. ITEMS[drop].name .. ".") or " Your pack is too full for its loot."))
    self.action = nil
    return
  end
  local mobChance = Clamp(0.5 + 0.03 * (mob.def.level - my), 0.15, 0.85) * (1 - self:Defense())
  if random() < mobChance then
    local dmg = random(1, mob.def.maxHit)
    s.hp = s.hp - dmg
    self.playerFlash = self.clock
    self:Splat(s.x, s.y, "-" .. dmg, { 1, 0.3, 0.3 })
    if s.hp <= 0 then return KnockedOut(self) end
  end
  self.dirty = true
end

-- through a gate
local function Travel(self, exit)
  local s = S()
  self:LoadZone(exit[3])
  s.zone, s.x, s.y = exit[3], exit[4], exit[5]
  self:Say(("You enter %s."):format(ZONES[exit[3]].name))
  self:Broadcast(true)
end

---------------------------------------------------------------------------
-- The clock
---------------------------------------------------------------------------

function R:Update(dt)
  if not self.ready then return end
  local s = S()
  self.clock = self.clock + dt
  for i = #self.depleted, 1, -1 do
    local d = self.depleted[i]
    if self.clock >= d.at then
      self.grid[d.y][d.x] = d.c
      table.remove(self.depleted, i)
      self.dirty = true
    end
  end
  for _, m in ipairs(self.mobs) do
    if m.dead then
      if self.clock >= m.respawnAt and not (s.x == m.homeX and s.y == m.homeY) and not self:MobAt(m.homeX, m.homeY) then
        m.dead, m.hp, m.x, m.y = false, m.def.hp, m.homeX, m.homeY
        self.dirty = true
      end
    elseif not (self.action and self.action.mob == m) and self.clock >= m.moveAt then
      m.moveAt = self.clock + 2 + random() * 3
      if not m.def.boss then
        local d = DIRS[random(4)]
        local nx, ny = m.x + d[1], m.y + d[2]
        if math.abs(nx - m.homeX) <= 3 and math.abs(ny - m.homeY) <= 3 and self:Walkable(nx, ny)
          and not (nx == s.x and ny == s.y) and self.grid[ny][nx] ~= ":" then
          m.x, m.y = nx, ny
          self.dirty = true
        end
      end
    end
  end
  -- splats fade
  for i = #self.splats, 1, -1 do
    if self.clock - self.splats[i].born > 1.2 then table.remove(self.splats, i) self.dirty = true end
  end
  -- walking
  if self.path and #self.path > 0 then
    self.moveT = self.moveT + dt
    while self.path and #self.path > 0 and self.moveT >= STEP_TIME do
      self.moveT = self.moveT - STEP_TIME
      local step = self.path[1]
      if self:Walkable(step[1], step[2]) then
        table.remove(self.path, 1)
        if step[1] ~= s.x then self.face = step[1] < s.x and -1 or 1 end
        s.x, s.y = step[1], step[2]
        self.dirty = true
        -- a gate you meant to walk onto takes you through
        if #self.path == 0 and self.grid[s.y][s.x] == ":" and not self.action then
          for _, e in ipairs(self.zdef.exits) do
            if e[1] == s.x and e[2] == s.y then Travel(self, e) return end
          end
        end
      else
        local a = self.action
        if a and a.mob then self.path = self:Path(a.mob.x, a.mob.y, true)
        elseif a then self.path = self:Path(a.x, a.y, true)
        else
          local last = self.path[#self.path]
          self.path = self:Path(last[1], last[2], false)
        end
        if not self.path then self:Say("Something is in the way.") self.action = nil end
      end
    end
    self:Broadcast()
    return
  end
  self.moveT = 0
  local a = self.action
  if a then
    local tx, ty = a.x, a.y
    if a.mob then
      if a.mob.dead then self.action = nil return end
      tx, ty = a.mob.x, a.mob.y
    end
    if not Adjacent(s.x, s.y, tx, ty) then
      self.path = self:Path(tx, ty, true)
      if not self.path then self.action = nil end
      return
    end
    if a.kind == "sell" then self:Sell() self.action = nil
    elseif a.kind == "bank" or a.kind == "talk" or (a.kind == "station" and not a.make) then
      if not a.opened then
        a.opened = true
        self.popup = a.kind == "bank" and { kind = "bank" } or (a.kind == "talk" and { kind = "talk", npc = a.npc })
          or { kind = "station", station = a.station }
        self.dirty = true
      end
    else
      self.actT = self.actT + dt
      local need = (a.kind == "fight" and FIGHT_TIME) or (a.kind == "station" and MAKE_TIME) or GATHER_TIME
      if self.actT >= need then
        self.actT = 0
        if a.kind == "gather" then DoGather(self, a)
        elseif a.kind == "station" then DoMake(self, a)
        elseif a.kind == "fight" then DoFight(self, a.mob) end
      end
    end
  else
    self.actT = 0
  end
  if not (a and a.kind == "fight") and s.hp < self:MaxHP() then
    self.regenT = self.regenT + dt
    if self.regenT >= REGEN_TIME then
      self.regenT = 0
      s.hp = s.hp + 1
      self.dirty = true
    end
  end
  -- friends' cows that stopped reporting leave the map
  for name, p in pairs(self.peers) do
    if self.clock - p.at > 15 then self.peers[name] = nil self.dirty = true end
  end
end

---------------------------------------------------------------------------
-- Herd Keepers in your world
---------------------------------------------------------------------------
-- While the window is open, your position goes to your party's other copies on the hidden
-- addon channel (at most every 2 seconds, or right away when you change zone). Theirs show
-- up as cows on your map when you're in the same zone.

local lastSent, lastKey = -100, nil
function R:Broadcast(now)
  if not (self.frameShown and ns.SendPeerMessage and IsInGroup and IsInGroup()) then return end
  local anyone = false
  for name in pairs(ns.peers or {}) do
    if ns.PeerInScope and ns:PeerInScope(name, "group") then anyone = true break end
  end
  if not anyone then return end
  local s = S()
  local key = ("%s~%d~%d"):format(s.zone, s.x, s.y)
  if not now and (key == lastKey and self.clock - lastSent < 10 or self.clock - lastSent < 2) then return end
  lastSent, lastKey = self.clock, key
  ns:SendPeerMessage(("RPG~%s~%d~%d~%d"):format(s.zone, s.x, s.y, self:TotalLevel()), ns:GroupChannel())
end

-- from Peers.lua, already checked for shape: zone, x, y, total level
function R:OnPeer(name, zone, x, y, total)
  if not self.ready then return end
  if not ZONES[zone] or x < 1 or y < 1 or x > W or y > H then return end
  self.peers[name] = { zone = zone, x = x, y = y, total = total, at = self.clock }
  self.dirty = true
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------

local TS = 28
local MAP_X, MAP_Y = 14, -58
local PANEL_W = 268
local frame
local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil
local BAR = "Interface\\TargetingFrame\\UI-StatusBar"

local function Box(f, bg, border)
  if not f.SetBackdrop then return end
  f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
  f:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 0.95)
  f:SetBackdropBorderColor(border[1], border[2], border[3], 1)
end
local function Text(parent, font, point, x, y, width)
  local fs = parent:CreateFontString(nil, "OVERLAY", font)
  fs:SetPoint(point, x, y)
  if width then fs:SetWidth(width) fs:SetJustifyH("LEFT") end
  return fs
end
local function Button(parent, label, w, h, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, h)
  b:SetText(label)
  b:SetScript("OnClick", function(self) onClick(self) R:Refresh() end)
  return b
end
local function Bar(parent, w, h, r, g, b)
  local bar = CreateFrame("StatusBar", nil, parent)
  bar:SetSize(w, h)
  bar:SetStatusBarTexture(BAR)
  bar:SetStatusBarColor(r, g, b)
  local bg = bar:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.5)
  bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  bar.text:SetPoint("LEFT", 4, 0)
  return bar
end

local TABS = { { "skills", "Skills" }, { "pack", "Pack" }, { "gear", "Gear" }, { "quests", "Quests" }, { "world", "World" } }
R.tab = "skills"

-- the right-hand panel's rows are a pool of buttons reused by every tab
local function Row(i)
  local r = frame.rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, frame.panel, BACKDROP_TEMPLATE)
  r:SetSize(PANEL_W - 16, 20)
  r:SetPoint("TOPLEFT", 8, -64 - (i - 1) * 21)
  Box(r, { 0.2, 0.13, 0.07, 0.9 }, { 0.45, 0.34, 0.18 })
  r.bar = CreateFrame("StatusBar", nil, r)
  r.bar:SetPoint("TOPLEFT", 3, -3)
  r.bar:SetPoint("BOTTOMRIGHT", -3, 3)
  r.bar:SetStatusBarTexture(BAR)
  r.bar:SetStatusBarColor(0.85, 0.65, 0.2, 0.55)
  r.left = Text(r, "GameFontHighlightSmall", "LEFT", 7, 0, PANEL_W - 90)
  r.right = Text(r, "GameFontNormalSmall", "RIGHT", -7, 0)
  r:SetScript("OnClick", function(self) if self.onClick then self.onClick() R:Refresh() end end)
  r:SetScript("OnEnter", function(self)
    if not self.tip then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(self.tip, 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function() GameTooltip:Hide() end)
  frame.rows[i] = r
  return r
end

local function ItemTip(item)
  local it = ITEMS[item]
  local lines = { it.name }
  if it.slot then
    lines[#lines + 1] = ("%s (needs Combat %d)"):format((it.slot:gsub("^%l", string.upper)), it.req)
    if it.atk then lines[#lines + 1] = "+" .. it.atk .. " max hit" end
    if it.def then lines[#lines + 1] = ("%d%% fewer hits taken"):format(it.def * 100) end
    if it.hp then lines[#lines + 1] = "+" .. it.hp .. " health" end
  end
  if it.heal then lines[#lines + 1] = "Heals " .. it.heal end
  if it.quest then lines[#lines + 1] = "Quest item" elseif it.price > 0 then lines[#lines + 1] = "Sells for " .. it.price .. " milk" end
  return table.concat(lines, "\n")
end

local function FillPanel(self)
  local s = S()
  local rows = {}
  local tab = self.tab
  if tab == "skills" then
    for _, k in ipairs(SKILLS) do
      local level, xp = self:Level(k), s.xp[k] or 0
      local from, to = R.XPFor(level), R.XPFor(level + 1)
      rows[#rows + 1] = { left = SKILL_NAMES[k], right = tostring(level),
        fill = level >= MAX_LEVEL and 1 or (xp - from) / math.max(1, to - from),
        tip = level >= MAX_LEVEL and (SKILL_NAMES[k] .. ": mastered") or ("%s: %d xp, %d to level %d"):format(SKILL_NAMES[k], xp, to - xp, level + 1) }
    end
    rows[#rows + 1] = { left = "Total level", right = tostring(self:TotalLevel()) }
    rows[#rows + 1] = { left = ("Max hit %d, armor %d%%"):format(self:MaxHit(), self:Defense() * 100) }
  elseif tab == "pack" then
    rows[#rows + 1] = { left = ("Pack: %d / %d. Click to use."):format(self:PackUsed(), PACK_SIZE) }
    for _, k in ipairs(ITEM_ORDER) do
      local n = self:Count(k)
      if n > 0 then
        local it = ITEMS[k]
        rows[#rows + 1] = { left = it.name, right = "x" .. n, tip = ItemTip(k),
          click = function() R:UseItem(k) end, color = it.slot and { 0.6, 0.8, 1 } or (it.heal and { 0.6, 1, 0.6 }) }
      end
    end
  elseif tab == "gear" then
    for _, slot in ipairs(SLOTS) do
      local item = s.equip[slot]
      rows[#rows + 1] = { left = slot:gsub("^%l", string.upper) .. ": " .. (item and ITEMS[item].name or "nothing"),
        right = item and "remove" or "", tip = item and ItemTip(item), click = item and function() R:Unequip(slot) end }
    end
    rows[#rows + 1] = { left = ("Health %d, max hit %d, armor %d%%"):format(self:MaxHP(), self:MaxHit(), self:Defense() * 100) }
    rows[#rows + 1] = { left = "Equip gear from your pack." }
  elseif tab == "quests" then
    local any = false
    for _, q in ipairs(QUESTS) do
      local st = self:QuestState(q.id)
      if st == "active" then
        local ready, prog = self:QuestProgress(q)
        rows[#rows + 1] = { left = q.name, right = ready and "turn in" or "", tip = q.text .. "\n\n" .. prog ..
          "\nFrom " .. NPCS[q.giver].name, color = ready and { 0.5, 1, 0.5 } or { 1, 0.85, 0.3 } }
        any = true
      end
    end
    local done = 0
    for _, q in ipairs(QUESTS) do if self:QuestState(q.id) == "done" then done = done + 1 end end
    if not any then rows[#rows + 1] = { left = "No active quests. Look for ! over NPCs." } end
    rows[#rows + 1] = { left = ("Completed: %d / %d"):format(done, #QUESTS) }
  elseif tab == "world" then
    for _, key in ipairs(ZONE_ORDER) do
      local here = key == s.zone
      rows[#rows + 1] = { left = (here and "> " or "  ") .. ZONES[key].name, right = s.zonesSeen[key] and "" or "unexplored",
        color = here and { 1, 0.85, 0.3 } or nil }
    end
    local friends = 0
    for name, p in pairs(self.peers) do
      friends = friends + 1
      rows[#rows + 1] = { left = name .. " (total level " .. p.total .. ")", right = ZONES[p.zone].name, color = { 0.6, 0.9, 1 } }
    end
    if friends == 0 then rows[#rows + 1] = { left = "Party members with the addon appear here." } end
  end
  for i = 1, math.max(#rows, #frame.rows) do
    local data = rows[i]
    if data and i <= 15 then
      local r = Row(i)
      r.left:SetText(data.left)
      r.right:SetText(data.right or "")
      local c = data.color
      if c then r.left:SetTextColor(c[1], c[2], c[3]) else r.left:SetTextColor(1, 1, 1) end
      r.bar:SetMinMaxValues(0, 1)
      r.bar:SetValue(data.fill or 0)
      r.tip, r.onClick = data.tip, data.click
      r:Show()
    elseif frame.rows[i] then
      frame.rows[i]:Hide()
    end
  end
  for _, t in ipairs(frame.tabs) do
    if t.key == tab then t:LockHighlight() else t:UnlockHighlight() end
  end
end

-- the popup: talking to an NPC, the bank, a crafting station
local function FillPopup(self)
  local p = self.popup
  local pop = frame.popup
  for _, b in ipairs(pop.buttons) do b:Hide() end
  if not p then pop:Hide() return end
  local lines, buttons = {}, {}
  if p.kind == "talk" then
    local npc = NPCS[p.npc]
    pop.title:SetText(npc.name)
    local list = self:NPCQuests(p.npc)
    if #list == 0 then lines[#lines + 1] = npc.greet end
    for _, e in ipairs(list) do
      local q = e.quest
      if e.kind == "offer" then
        lines[#lines + 1] = ("|cffffd100%s|r\n%s"):format(q.name, q.text)
        buttons[#buttons + 1] = { "Accept: " .. q.name, function() R:AcceptQuest(q.id) end }
      elseif e.kind == "turnin" then
        lines[#lines + 1] = ("|cff80ff80%s|r\nYou did it! Moo."):format(q.name)
        buttons[#buttons + 1] = { "Complete: " .. q.name, function() R:CompleteQuest(q.id) end }
      else
        local _, prog = self:QuestProgress(q)
        lines[#lines + 1] = ("|cffffd100%s|r\n%s"):format(q.name, prog)
      end
    end
  elseif p.kind == "bank" then
    pop.title:SetText("Bank chest")
    lines[#lines + 1] = "Click an item to take it back out."
    buttons[#buttons + 1] = { "Deposit everything in your pack", function() R:Deposit() end }
    for _, k in ipairs(ITEM_ORDER) do
      local n = S().bank[k]
      if n and #buttons < 9 then
        buttons[#buttons + 1] = { ("%s x%d"):format(ITEMS[k].name, n), function() R:Withdraw(k) end }
      end
    end
  elseif p.kind == "station" then
    pop.title:SetText(STATION_NAMES[p.station])
    lines[#lines + 1] = "Pick something to make. Making stops when you run out."
    for i, e in ipairs(self:StationRecipes(p.station)) do
      local r = e.recipe
      local need = {}
      for item, n in pairs(r.need) do need[#need + 1] = n .. " " .. ITEMS[item].name end
      local label = ("%s  (%s, %s %d)"):format(ITEMS[r.out].name, table.concat(need, ", "), SKILL_NAMES[r.skill], r.req)
      buttons[#buttons + 1] = { label, function() R:Make(p.station, i, "all") end, not e.can }
    end
  end
  pop.text:SetText(table.concat(lines, "\n\n"))
  local textH = math.min(150, math.max(16, (pop.text.GetStringHeight and pop.text:GetStringHeight() or 40) or 40))
  for i, def in ipairs(buttons) do
    local b = pop.buttons[i]
    if b then
      b:SetText(def[1])
      b.onClick = def[2]
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", 12, -40 - textH - 8 - (i - 1) * 24)
      if def[3] then b:Disable() else b:Enable() end
      b:Show()
    end
  end
  pop:Show()
end

---------------------------------------------------------------------------
-- Drawing the world
---------------------------------------------------------------------------
-- Every texture here is a stock game file (icons, white squares, status bars), tinted and layered:
-- per-tile color noise, bevelled edges, grass flecks, icons for objects, animated water and fire,
-- round portraits with shadows, smooth walking, hit flashes, floating numbers, day and night.

local WHITE = "Interface\\Buttons\\WHITE8X8"
local ROUND = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local FANCY_FONT = "Fonts\\MORPHEUS.TTF"

-- what's drawn on top of each tile
local VIS = {
  T = { icon = ICON .. "Ability_Druid_TreeofLife", tint = { 0.75, 1, 0.7 } },
  Y = { icon = ICON .. "Ability_Druid_TreeofLife", tint = { 0.75, 0.6, 0.45 } },
  E = { icon = ICON .. "Ability_Druid_TreeofLife", tint = { 0.6, 0.9, 1 } },
  R = { icon = ICON .. "INV_Ore_Copper_01" },
  I = { icon = ICON .. "INV_Ore_Iron_01" },
  S = { icon = ICON .. "INV_Ore_Mithril_02" },
  B = { icon = ICON .. "INV_Misc_Herb_10", tint = { 0.9, 0.6, 1 } },
  F = { icon = ICON .. "Spell_Fire_Fire", fire = true },
  U = { icon = ICON .. "Spell_Fire_Incinerate", fire = true },
  A = { icon = ICON .. "Trade_BlackSmithing" },
  W = { icon = ICON .. "Trade_LeatherWorking" },
  ["$"] = { icon = ICON .. "INV_Misc_Coin_02" },
  C = { icon = ICON .. "INV_Box_01" },
  [":"] = { icon = ICON .. "Spell_Arcane_PortalThunderBluff", glow = true },
  X = { icon = ICON .. "INV_Misc_Bone_HumanSkull_01", tint = { 0.85, 0.82, 0.75 }, small = true },
  n = { icon = ICON .. "Achievement_Character_Tauren_Male", round = true },
}

-- a stable 0..1 number per tile, so the noise doesn't flicker
local function Noise(x, y, salt)
  local h = (x * 73856093 + y * 19349663 + (salt or 0) * 83492791) % 1000
  return h / 1000
end

local function SetFancyFont(fs, size)
  if fs.SetFont then pcall(fs.SetFont, fs, FANCY_FONT, size, "OUTLINE") end
end

local function Round(tex)
  if tex.SetMask then pcall(tex.SetMask, tex, ROUND) end
end

local function Gradient(tex, orientation, a1, a2)
  -- the gradient API changed over the years: try the new one, then the old one
  if CreateColor and tex.SetGradient then
    if pcall(tex.SetGradient, tex, orientation, CreateColor(0, 0, 0, a1), CreateColor(0, 0, 0, a2)) then return end
  end
  if tex.SetGradientAlpha then pcall(tex.SetGradientAlpha, tex, orientation, 0, 0, 0, a1, 0, 0, 0, a2) end
end

-- tile colors, with noise; water and fire are animated in Animate
local function PaintTile(self, b, x, y)
  local c = self.grid[y][x]
  local t = TILES[c]
  local col = c == "n" and TILES["."].color or t.color
  local n = (Noise(x, y) - 0.5) * 0.12
  local f = self.zdef.dark and 0.62 or 1
  b.base = { (col[1] + n) * f, (col[2] + n) * f, (col[3] + n * 0.6) * f }
  b.tex:SetColorTexture(b.base[1], b.base[2], b.base[3], 1)
  b.water = c == "~"
  -- grass flecks: little lighter and darker blades
  local grassy = c == "." or c == "n"
  for i, sp in ipairs(b.specks) do
    if grassy and Noise(x, y, i) < 0.7 then
      local g = 0.12 + Noise(x, y, i + 5) * 0.2
      sp:SetColorTexture(col[1] + g * (i == 2 and -1 or 1), col[2] + g, col[3], 0.8)
      sp:ClearAllPoints()
      sp:SetPoint("TOPLEFT", 3 + Noise(x, y, i + 9) * (TS - 9), -3 - Noise(x, y, i + 13) * (TS - 9))
      sp:Show()
    else
      sp:Hide()
    end
  end
  -- path pebbles
  if c == "," or c == ":" then
    b.specks[1]:SetColorTexture(0.42, 0.34, 0.22, 0.9)
    b.specks[1]:Show()
  end
  -- bevel: walls and rocks stand up, water sits low
  local raised = c == "#" or t.gather == "copper" or t.gather == "iron" or t.gather == "silverhorn"
  b.hi:SetColorTexture(1, 1, 1, raised and 0.16 or (b.water and 0 or 0.06))
  b.lo:SetColorTexture(0, 0, 0, raised and 0.35 or (b.water and 0.25 or 0.14))
  -- the object
  local vis = VIS[c]
  b.fire = vis and vis.fire or false
  b.glow = vis and vis.glow or false
  if vis then
    b.icon:SetTexture(vis.icon)
    local tint = vis.tint
    if tint then b.icon:SetVertexColor(tint[1], tint[2], tint[3]) else b.icon:SetVertexColor(1, 1, 1) end
    local size = vis.small and TS - 12 or TS - 4
    b.icon:SetSize(size, size)
    if vis.round then Round(b.icon) end
    b.icon:SetAlpha(self.zdef.dark and 0.85 or 1)
    b.icon:Show()
    b.iconShadow:Show()
  else
    b.icon:Hide()
    b.iconShadow:Hide()
  end
  -- quest marks over NPCs
  local npc = self:NPCAt(x, y)
  if npc then
    local mark = ""
    for _, e in ipairs(self:NPCQuests(npc)) do
      if e.kind == "turnin" then mark = "?" break elseif e.kind == "offer" then mark = "!" end
    end
    b.glyph:SetText(mark)
    b.glyph:SetTextColor(1, 0.85, 0.1)
  else
    b.glyph:SetText(c == "s1" and "." or "")
    b.glyph:SetTextColor(0.8, 0.75, 0.6)
  end
end

-- where a unit at (fractional) tile position x, y goes on screen
local function Place(tex, x, y, lift)
  tex:ClearAllPoints()
  tex:SetPoint("TOPLEFT", frame.mapAnchor, "TOPLEFT", (x - 1) * TS + 2, -(y - 1) * TS - 2 + (lift or 0))
end

-- glide a unit's drawn position toward its real tile
local function Glide(u, tx, ty, dt)
  if not u.dx or math.abs(u.dx - tx) + math.abs(u.dy - ty) > 2.5 then u.dx, u.dy = tx, ty return end
  local speed = dt / STEP_TIME
  local function Step(from, to)
    if from < to then return math.min(to, from + speed) end
    return math.max(to, from - speed)
  end
  u.dx, u.dy = Step(u.dx, tx), Step(u.dy, ty)
end

local function Lighting(self)
  if self.zdef.dark then return 0.28, 0.08, 0.35, 0.3 end
  local hour = GetGameTime and select(1, GetGameTime()) or 12
  if hour >= 21 or hour < 5 then return 0.05, 0.08, 0.3, 0.32 end -- night
  if hour >= 19 or hour < 7 then return 0.55, 0.25, 0.05, 0.14 end -- dusk, dawn
  return 0, 0, 0, 0
end

-- the per-frame part: water, fire, units gliding, flashes, numbers, big text
function R:Animate(dt)
  if not frame or not frame:IsShown() or not self.ready then return end
  local s = S()
  local t = self.clock
  for y = 1, H do
    for x = 1, W do
      local b = frame.tiles[y][x]
      if b.water then
        local w = math.sin(t * 1.7 + x * 0.8 + y * 0.55) * 0.05 + math.sin(t * 0.9 - x * 0.3) * 0.03
        b.tex:SetColorTexture(b.base[1] + w, b.base[2] + w, b.base[3] + w * 1.6, 1)
      elseif b.fire then
        local f = 0.75 + math.sin(t * 9 + x) * 0.12 + math.sin(t * 13.7 + y) * 0.1
        b.icon:SetVertexColor(1, f, f * 0.7)
      elseif b.glow then
        b.icon:SetAlpha(0.7 + math.sin(t * 2.4) * 0.3)
      end
    end
  end
  -- you
  self.me = self.me or {}
  Glide(self.me, s.x, s.y, dt)
  local moving = self.path and #self.path > 0
  local bob = moving and math.abs(math.sin(t * 14)) * 3 or math.sin(t * 2) * 0.8
  Place(frame.player, self.me.dx, self.me.dy, bob)
  Place(frame.playerShadow, self.me.dx, self.me.dy + 0.18, 0)
  if self.face == -1 then frame.player:SetTexCoord(0.92, 0.08, 0.08, 0.92) else frame.player:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
  local hurt = self.playerFlash and t - self.playerFlash < 0.25
  frame.player:SetVertexColor(1, hurt and 0.35 or 1, hurt and 0.35 or 1)
  -- monsters
  for i, icon in ipairs(frame.mobIcons) do
    local m = self.mobs[i]
    if m and not m.dead then
      Glide(m, m.x, m.y, dt)
      local mb = math.sin(t * 2.2 + i) * 0.8
      Place(icon, m.dx, m.dy, mb)
      Place(icon.shadow, m.dx, m.dy + 0.18, 0)
      icon.hp:ClearAllPoints()
      icon.hp:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 2, 0)
      local tint = m.def.tint or { 1, 1, 1 }
      local flash = m.flash and t - m.flash < 0.2
      icon:SetVertexColor(flash and 1 or tint[1], flash and 0.3 or tint[2], flash and 0.3 or tint[3])
    end
  end
  -- friends
  for _, icon in ipairs(frame.peerIcons) do
    if icon:IsShown() and icon.peer then
      Glide(icon.peer, icon.peer.x, icon.peer.y, dt)
      Place(icon, icon.peer.dx, icon.peer.dy, math.sin(t * 2.5) * 0.8)
    end
  end
  -- floating numbers
  for i, fs in ipairs(frame.splats) do
    local sp = self.splats[i]
    if sp then
      local age = t - sp.born
      fs:ClearAllPoints()
      fs:SetPoint("CENTER", frame.tiles[sp.y][sp.x], "CENTER", 0, 8 + age * 18)
      fs:SetText(sp.text)
      fs:SetTextColor(sp.color[1], sp.color[2], sp.color[3], math.max(0, 1 - age / 1.2))
      fs:Show()
    else
      fs:Hide()
    end
  end
  -- the big "LEVEL UP" text
  local big = self.big
  if big then
    local age = t - big.born
    if age > 2.5 then
      self.big = nil
      frame.big:Hide()
    else
      frame.big:SetText(big.text)
      frame.big:ClearAllPoints()
      frame.big:SetPoint("CENTER", frame.mapAnchor, "TOPLEFT", W * TS / 2, -H * TS / 2 + age * 12)
      frame.big:SetAlpha(age < 2 and 1 or (2.5 - age) * 2)
      frame.big:Show()
    end
  end
  -- light
  self.lightT = (self.lightT or 0) - dt
  if self.lightT <= 0 then
    self.lightT = 5
    local r, g, b, a = Lighting(self)
    frame.light:SetColorTexture(r, g, b, a)
  end
  if self.zdef.dark then frame.fog:SetAlpha(0.25 + math.sin(t * 0.7) * 0.12) frame.fog:Show() else frame.fog:Hide() end
end

function R:Refresh()
  if not frame or not frame:IsShown() then return end
  self.dirty = false
  local s = S()
  if frame.paintedZone ~= self.zone or self.repaint then
    frame.paintedZone, self.repaint = self.zone, false
    self.me = nil
    for _, m in ipairs(self.mobs) do m.dx = nil end
  end
  for y = 1, H do
    for x = 1, W do PaintTile(self, frame.tiles[y][x], x, y) end
  end
  for i, icon in ipairs(frame.mobIcons) do
    local m = self.mobs[i]
    if m and not m.dead then
      icon:SetTexture(m.def.icon)
      local size = m.def.boss and TS + 6 or TS - 4
      icon:SetSize(size, size)
      icon:Show()
      icon.shadow:Show()
      if m.hp < m.def.hp then
        icon.hp:SetMinMaxValues(0, m.def.hp)
        icon.hp:SetValue(math.max(0, m.hp))
        icon.hp:Show()
      else
        icon.hp:Hide()
      end
    else
      icon:Hide()
      icon.shadow:Hide()
      icon.hp:Hide()
    end
  end
  local pi = 0
  for name, p in pairs(self.peers) do
    if p.zone == s.zone and pi < #frame.peerIcons then
      pi = pi + 1
      local icon = frame.peerIcons[pi]
      icon.peer = p
      icon.label:SetText(name)
      icon:Show()
      icon.label:Show()
    end
  end
  for i = pi + 1, #frame.peerIcons do frame.peerIcons[i]:Hide() frame.peerIcons[i].label:Hide() end
  frame.zone:SetText(self.zdef.name)
  local max = self:MaxHP()
  frame.hp:SetMinMaxValues(0, max)
  frame.hp:SetValue(math.max(0, s.hp))
  frame.hp.text:SetText(("Health %d / %d"):format(math.max(0, s.hp), max))
  local pct = math.max(0, s.hp) / max
  frame.hp:SetStatusBarColor(pct < 0.3 and 0.9 or 0.75, pct < 0.3 and 0.1 or 0.18, 0.12)
  local a = self.action
  local doing = "Idle. Click something."
  if a then
    if a.kind == "fight" then doing = ("Fighting %s (%d hp)"):format(The(a.mob.def), math.max(0, a.mob.hp))
    elseif a.kind == "gather" then doing = "Gathering: " .. self:Tile(a.x, a.y).name
    elseif a.kind == "station" and a.make then doing = "Making " .. ITEMS[RECIPES[a.station][a.make].out].name
    elseif self.path and #self.path > 0 then doing = "Walking" end
  elseif self.path and #self.path > 0 then doing = "Walking"
  end
  frame.doing:SetText(doing)
  frame.log:SetText(table.concat(self.log, "\n"))
  FillPanel(self)
  FillPopup(self)
end

local function CreateWindow()
  local mapW, mapH = W * TS, H * TS
  frame = CreateFrame("Frame", "MooHelperPasture", UIParent, BACKDROP_TEMPLATE)
  frame:SetSize(mapW + PANEL_W + 40, mapH + 176)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("HIGH")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetClampedToScreen(true)
  if frame.SetBackdrop then
    frame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border", tile = true, tileSize = 32, edgeSize = 32,
      insets = { left = 11, right = 11, top = 11, bottom = 11 } })
    frame:SetBackdropColor(0.14, 0.09, 0.05, 1)
  end
  tinsert(UISpecialFrames, "MooHelperPasture")
  -- the header: cow crest, MOOSCAPE in the game's display font, zone name
  local crest = frame:CreateTexture(nil, "ARTWORK")
  crest:SetSize(40, 40)
  crest:SetPoint("TOPLEFT", 16, -10)
  crest:SetTexture(ICON .. "Spell_Nature_Polymorph_Cow")
  Round(crest)
  local title = Text(frame, "GameFontNormalHuge", "TOPLEFT", 62, -14)
  SetFancyFont(title, 28)
  title:SetText("MooScape")
  title:SetTextColor(1, 0.82, 0.25)
  frame.zone = Text(frame, "GameFontHighlightLarge", "TOPLEFT", 230, -22)
  SetFancyFont(frame.zone, 18)
  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -8, -8)

  -- the map: a dark frame, then the tiles
  local mapBack = frame:CreateTexture(nil, "BACKGROUND")
  mapBack:SetPoint("TOPLEFT", MAP_X - 3, MAP_Y + 3)
  mapBack:SetSize(mapW + 5, mapH + 5)
  mapBack:SetColorTexture(0.03, 0.02, 0.01, 1)
  frame.tiles = {}
  for y = 1, H do
    frame.tiles[y] = {}
    for x = 1, W do
      local b = CreateFrame("Button", nil, frame)
      b:SetSize(TS, TS)
      b:SetPoint("TOPLEFT", MAP_X + (x - 1) * TS, MAP_Y - (y - 1) * TS)
      b.tex = b:CreateTexture(nil, "BACKGROUND")
      b.tex:SetAllPoints()
      b.specks = {}
      for i = 1, 3 do
        local sp = b:CreateTexture(nil, "BORDER")
        sp:SetSize(i == 3 and 2 or 3, i == 3 and 4 or 3)
        sp:Hide()
        b.specks[i] = sp
      end
      b.hi = b:CreateTexture(nil, "BORDER")
      b.hi:SetPoint("TOPLEFT")
      b.hi:SetPoint("TOPRIGHT")
      b.hi:SetHeight(2)
      b.lo = b:CreateTexture(nil, "BORDER")
      b.lo:SetPoint("BOTTOMLEFT")
      b.lo:SetPoint("BOTTOMRIGHT")
      b.lo:SetHeight(2)
      b.iconShadow = b:CreateTexture(nil, "ARTWORK", nil, 1)
      b.iconShadow:SetSize(TS - 8, (TS - 8) / 2.5)
      b.iconShadow:SetPoint("BOTTOM", 1, 2)
      b.iconShadow:SetColorTexture(0, 0, 0, 0.35)
      Round(b.iconShadow)
      b.iconShadow:Hide()
      b.icon = b:CreateTexture(nil, "ARTWORK", nil, 2)
      b.icon:SetPoint("CENTER", 0, 1)
      b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      b.icon:Hide()
      b.glyph = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
      b.glyph:SetPoint("TOP", 0, 8)
      b:SetHighlightTexture(WHITE, "ADD")
      local hl = b:GetHighlightTexture()
      if hl then hl:SetVertexColor(1, 1, 0.7, 0.18) end
      b:SetScript("OnClick", function() R:Click(x, y) R:Refresh() end)
      b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local m = R:MobAt(x, y)
        local npc = R:NPCAt(x, y)
        local line = m and ("%s (level %d)"):format(m.def.name, m.def.level) or (npc and NPCS[npc].name) or R:Tile(x, y).name
        for name, p in pairs(R.peers) do
          if p.zone == S().zone and p.x == x and p.y == y then line = line .. "\n" .. name .. " (Herd Keeper)" end
        end
        GameTooltip:SetText(line)
        GameTooltip:Show()
      end)
      b:SetScript("OnLeave", function() GameTooltip:Hide() end)
      frame.tiles[y][x] = b
    end
  end
  frame.mapAnchor = frame.tiles[1][1]

  -- above the tiles: light, fog, vignette, then the units (a layer that takes no clicks)
  local fx = CreateFrame("Frame", nil, frame)
  fx:SetPoint("TOPLEFT", MAP_X, MAP_Y)
  fx:SetSize(mapW, mapH)
  fx:SetFrameLevel((frame:GetFrameLevel() or 1) + 15)
  fx:EnableMouse(false)
  frame.light = fx:CreateTexture(nil, "BACKGROUND")
  frame.light:SetAllPoints()
  frame.light:SetColorTexture(0, 0, 0, 0)
  frame.fog = fx:CreateTexture(nil, "BORDER")
  frame.fog:SetAllPoints()
  frame.fog:SetColorTexture(0.45, 0.35, 0.6, 1)
  frame.fog:SetAlpha(0)
  frame.fog:Hide()
  for _, edge in ipairs({ { "TOP", "VERTICAL", 0, 0.55 }, { "BOTTOM", "VERTICAL", 0.55, 0 } }) do
    local v = fx:CreateTexture(nil, "ARTWORK")
    v:SetPoint(edge[1] .. "LEFT")
    v:SetPoint(edge[1] .. "RIGHT")
    v:SetHeight(26)
    v:SetTexture(WHITE)
    Gradient(v, edge[2], edge[3], edge[4])
  end
  for _, edge in ipairs({ { "LEFT", 0.5, 0 }, { "RIGHT", 0, 0.5 } }) do
    local v = fx:CreateTexture(nil, "ARTWORK")
    v:SetPoint("TOP" .. edge[1])
    v:SetPoint("BOTTOM" .. edge[1])
    v:SetWidth(26)
    v:SetTexture(WHITE)
    Gradient(v, "HORIZONTAL", edge[2], edge[3])
  end

  local units = CreateFrame("Frame", nil, frame)
  units:SetAllPoints()
  units:SetFrameLevel((frame:GetFrameLevel() or 1) + 20)
  units:EnableMouse(false)
  frame.overlay = units
  local function Shadow()
    local sh = units:CreateTexture(nil, "BACKGROUND")
    sh:SetSize(TS - 8, (TS - 8) / 2.4)
    sh:SetColorTexture(0, 0, 0, 0.45)
    Round(sh)
    return sh
  end
  local function Portrait(path)
    local tex = units:CreateTexture(nil, "ARTWORK")
    tex:SetSize(TS - 4, TS - 4)
    tex:SetTexture(path)
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    Round(tex)
    return tex
  end
  frame.playerShadow = Shadow()
  frame.player = Portrait(ICON .. "Spell_Nature_Polymorph_Cow")
  frame.player:SetDrawLayer("OVERLAY")
  frame.mobIcons = {}
  for i = 1, 16 do
    local icon = Portrait(ICON .. "Ability_Hunter_Pet_Wolf")
    icon.shadow = Shadow()
    icon.hp = CreateFrame("StatusBar", nil, units)
    icon.hp:SetSize(TS - 8, 4)
    icon.hp:SetStatusBarTexture(BAR)
    icon.hp:SetStatusBarColor(0.9, 0.12, 0.1)
    local hpBack = icon.hp:CreateTexture(nil, "BACKGROUND")
    hpBack:SetAllPoints()
    hpBack:SetColorTexture(0, 0, 0, 0.7)
    icon.hp:Hide()
    icon.shadow:Hide()
    icon:Hide()
    frame.mobIcons[i] = icon
  end
  frame.peerIcons = {}
  for i = 1, 4 do
    local icon = Portrait(ICON .. "Spell_Nature_Polymorph_Cow")
    icon:SetVertexColor(0.6, 0.85, 1)
    icon.label = units:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    icon.label:SetPoint("BOTTOM", icon, "TOP", 0, 1)
    icon.label:SetTextColor(0.6, 0.85, 1)
    icon:Hide()
    icon.label:Hide()
    frame.peerIcons[i] = icon
  end
  frame.splats = {}
  for i = 1, 8 do
    local fs = units:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    SetFancyFont(fs, 16)
    fs:Hide()
    frame.splats[i] = fs
  end
  frame.big = units:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  SetFancyFont(frame.big, 34)
  frame.big:SetTextColor(1, 0.85, 0.2)
  frame.big:Hide()

  -- the side panel
  local panel = CreateFrame("Frame", nil, frame, BACKDROP_TEMPLATE)
  panel:SetSize(PANEL_W, mapH)
  panel:SetPoint("TOPLEFT", MAP_X + mapW + 12, MAP_Y)
  Box(panel, { 0.12, 0.08, 0.04, 0.96 }, { 0.75, 0.58, 0.3 })
  frame.panel = panel
  frame.hp = Bar(panel, PANEL_W - 16, 18, 0.75, 0.18, 0.12)
  frame.hp:SetPoint("TOPLEFT", 8, -8)
  frame.tabs = {}
  for i, t in ipairs(TABS) do
    local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    b:SetSize(50, 20)
    b:SetPoint("TOPLEFT", 8 + (i - 1) * 51, -32)
    b:SetText(t[2])
    b.key = t[1]
    b:SetScript("OnClick", function() R.tab = t[1] R:Refresh() end)
    frame.tabs[i] = b
  end
  frame.rows = {}

  frame.doing = Text(frame, "GameFontNormal", "TOPLEFT", MAP_X, MAP_Y - mapH - 10, mapW)
  frame.log = Text(frame, "GameFontHighlightSmall", "TOPLEFT", MAP_X, MAP_Y - mapH - 30, mapW + PANEL_W)
  frame.log:SetJustifyV("TOP")

  -- the popup over the map
  local pop = CreateFrame("Frame", nil, frame, BACKDROP_TEMPLATE)
  pop:SetSize(420, 330)
  pop:SetPoint("CENTER", frame.tiles[7][10], "CENTER", 0, 0)
  pop:SetFrameLevel((frame:GetFrameLevel() or 1) + 40)
  pop:EnableMouse(true)
  Box(pop, { 0.1, 0.07, 0.03, 0.98 }, { 0.9, 0.72, 0.3 })
  pop.title = Text(pop, "GameFontNormalLarge", "TOPLEFT", 12, -12)
  SetFancyFont(pop.title, 18)
  pop.text = Text(pop, "GameFontHighlightSmall", "TOPLEFT", 12, -38, 396)
  pop.text:SetJustifyV("TOP")
  local pclose = CreateFrame("Button", nil, pop, "UIPanelCloseButton")
  pclose:SetPoint("TOPRIGHT", -2, -2)
  pclose:SetScript("OnClick", function() R.popup = nil if R.action and not R.action.make then R.action = nil end R:Refresh() end)
  pop.buttons = {}
  for i = 1, 10 do
    local b = Button(pop, "", 396, 22, function(self) if self.onClick then self.onClick() end end)
    b:Hide()
    pop.buttons[i] = b
  end
  pop:Hide()
  frame.popup = pop

  frame:SetScript("OnUpdate", function(_, elapsed)
    local dt = math.min(elapsed, 0.5)
    R:Update(dt)
    if R.dirty then R:Refresh() end
    R:Animate(dt)
  end)
  frame:SetScript("OnShow", function() R.frameShown = true R:Refresh() R:Broadcast(true) end)
  frame:SetScript("OnHide", function() R.frameShown = false end)
  frame:Hide()
end

function R:Toggle(show)
  if not self.ready then self:Init() end
  if not frame then CreateWindow() end
  if show == nil then show = not frame:IsShown() end
  if show then
    frame:Show()
    self.frameShown = true
    ns:Bump("rpgOpened")
    if #self.log == 0 then
      self:Say("Welcome to MooScape! Elder Hoofwise (!) in the village has work for you. Moo.")
    end
    self:Refresh()
    self:Animate(0)
  else
    frame:Hide()
    self.frameShown = false
  end
end

SLASH_MOOPASTURE1 = "/mooscape"
SLASH_MOOPASTURE2 = "/pasture"
SLASH_MOOPASTURE3 = "/mooquest"
SlashCmdList.MOOPASTURE = function() R:Toggle() end

---------------------------------------------------------------------------
-- The banner: once, the first time you log in with MooScape, a giant PLAY MOOSCAPE NOW
-- button across the top of the screen. Click it (or close it) and it never comes back.
---------------------------------------------------------------------------

local banner
function R:ShowBanner()
  if banner then banner:Show() return banner end
  banner = CreateFrame("Button", "MooScapeBanner", UIParent, BACKDROP_TEMPLATE)
  banner:SetSize(820, 132)
  banner:SetPoint("TOP", UIParent, "TOP", 0, -48)
  banner:SetFrameStrata("DIALOG")
  if banner.SetBackdrop then
    banner:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border", tile = true, tileSize = 32, edgeSize = 32,
      insets = { left = 11, right = 11, top = 11, bottom = 11 } })
    banner:SetBackdropColor(0.22, 0.12, 0.04, 1)
  end
  -- a warm glow behind everything that breathes in and out
  local glow = banner:CreateTexture(nil, "BACKGROUND", nil, 1)
  glow:SetPoint("TOPLEFT", 12, -12)
  glow:SetPoint("BOTTOMRIGHT", -12, 12)
  glow:SetColorTexture(1, 0.65, 0.15, 0.25)
  -- the logo: the cow in a gold ring
  local ring = banner:CreateTexture(nil, "ARTWORK", nil, 1)
  ring:SetSize(112, 112)
  ring:SetPoint("LEFT", 18, 0)
  ring:SetColorTexture(1, 0.8, 0.25, 1)
  Round(ring)
  local logo = banner:CreateTexture(nil, "ARTWORK", nil, 2)
  logo:SetSize(100, 100)
  logo:SetPoint("CENTER", ring, "CENTER")
  logo:SetTexture(ICON .. "Spell_Nature_Polymorph_Cow")
  logo:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  Round(logo)
  local headline = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  headline:SetPoint("TOPLEFT", ring, "TOPRIGHT", 22, -6)
  SetFancyFont(headline, 46)
  headline:SetText("PLAY MOOSCAPE NOW")
  headline:SetTextColor(1, 0.84, 0.2)
  local sub = banner:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  sub:SetPoint("TOPLEFT", headline, "BOTTOMLEFT", 2, -8)
  sub:SetText("Five zones. Eight skills. Seven quests. One Bone Matriarch. Click to play!")
  local hint = banner:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("BOTTOMRIGHT", -18, 16)
  hint:SetText("(you'll only see this once: /mooscape any time)")
  banner:SetHighlightTexture(WHITE, "ADD")
  local hl = banner:GetHighlightTexture()
  if hl then
    hl:ClearAllPoints()
    hl:SetPoint("TOPLEFT", 12, -12)
    hl:SetPoint("BOTTOMRIGHT", -12, 12)
    hl:SetVertexColor(1, 0.9, 0.5, 0.12)
  end
  local function Done()
    ns.db.mooscapeBannerSeen = true
    banner:Hide()
  end
  banner:SetScript("OnClick", function()
    Done()
    ns:Bump("mooscapeBanner")
    R:Toggle(true)
  end)
  local x = CreateFrame("Button", nil, banner, "UIPanelCloseButton")
  x:SetPoint("TOPRIGHT", -6, -6)
  x:SetScript("OnClick", Done)
  local t = 0
  banner:SetScript("OnUpdate", function(_, elapsed)
    t = t + elapsed
    local pulse = (math.sin(t * 3) + 1) / 2
    glow:SetAlpha(0.15 + pulse * 0.3)
    ring:SetVertexColor(1, 0.7 + pulse * 0.3, 0.2 + pulse * 0.3)
    headline:SetTextColor(1, 0.78 + pulse * 0.2, 0.15 + pulse * 0.3)
  end)
  banner:Show()
  return banner
end

ns:On("PLAYER_LOGIN", function()
  R:Init()
  if not ns.db.mooscapeBannerSeen then
    C_Timer.After(6, function()
      if not ns.db.mooscapeBannerSeen and not InCombatLockdown() then R:ShowBanner() end
    end)
  end
end)
