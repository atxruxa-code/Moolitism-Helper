-- MooHelper: Moo Quest, The Pasture Lands
-- A small point-and-click RPG in its own window (/pasture). Click a tile to walk there, click a
-- tree, rock, pond or bush to gather, click a monster to fight it, click food to eat it, and
-- sell your haul to Trader Moo-rgan for real MooHelper milk. Six skills level from 1 to 50.
-- Everything is local: the game never posts to chat.

local _, ns = ...

local random = math.random
local R = {}
ns.RPG = R

---------------------------------------------------------------------------
-- The world
---------------------------------------------------------------------------

local W, H = 20, 14
-- .  grass   ,  path   @  start   ~  pond   T  pine   Y  ironbark   R  copper rock
-- I  iron rock   B  berry bush   F  campfire   $  Trader Moo-rgan   #  fence
-- w  b  k  where wolves, boars and kodos roam (grass underneath)
local MAP = {
  "~~~~~~..TT....RR..##",
  "~~~~~...TY..,..R..I#",
  "~~~~...T..,,,......#",
  "~~~......,,.....w..#",
  "~~...B..,,..T.T....#",
  "~~.....,,....T..w..#",
  "~~..F..,@,$.....b..#",
  "~~.....,,,.........#",
  "~~~....,..B....RR..#",
  "~~~~...,......Y...k#",
  "~~~~...,...TT......#",
  "~~~~~..,..TT...b...#",
  "~~~~~~.,.....B..I..#",
  "~~~~~~~,,,,,,,,,,,,#",
}
R.W, R.H, R.MAP = W, H, MAP

local TILES = {
  ["."] = { name = "Grass", walk = true, color = { 0.27, 0.5, 0.2 } },
  [","] = { name = "Path", walk = true, color = { 0.58, 0.47, 0.3 } },
  ["~"] = { name = "Pond", gather = "fish", color = { 0.15, 0.32, 0.62 }, glyph = "" },
  ["T"] = { name = "Pine tree", gather = "pine", color = { 0.1, 0.3, 0.1 }, glyph = "T" },
  ["Y"] = { name = "Ironbark tree", gather = "ironbark", color = { 0.2, 0.22, 0.14 }, glyph = "Y" },
  ["R"] = { name = "Copper rock", gather = "copper", color = { 0.55, 0.35, 0.2 }, glyph = "R" },
  ["I"] = { name = "Iron rock", gather = "iron", color = { 0.42, 0.42, 0.45 }, glyph = "I" },
  ["B"] = { name = "Moo-berry bush", gather = "berries", color = { 0.35, 0.15, 0.4 }, glyph = "B" },
  ["F"] = { name = "Campfire", use = "cook", color = { 0.85, 0.4, 0.1 }, glyph = "F" },
  ["$"] = { name = "Trader Moo-rgan", use = "sell", color = { 0.8, 0.68, 0.2 }, glyph = "$" },
  ["#"] = { name = "Fence", color = { 0.35, 0.25, 0.15 }, glyph = "#" },
  ["s"] = { name = "Tree stump", color = { 0.3, 0.42, 0.18 }, glyph = "." },
  ["r"] = { name = "Empty rock", color = { 0.3, 0.3, 0.3 }, glyph = "." },
  ["e"] = { name = "Picked bush", color = { 0.25, 0.35, 0.2 }, glyph = "." },
}
R.TILES = TILES

local SKILLS = { "combat", "woodcutting", "mining", "fishing", "cooking", "foraging" }
local SKILL_NAMES = { combat = "Combat", woodcutting = "Woodcutting", mining = "Mining", fishing = "Fishing",
  cooking = "Cooking", foraging = "Foraging" }
R.SKILLS, R.SKILL_NAMES = SKILLS, SKILL_NAMES
local MAX_LEVEL = 50

-- what each gathering spot gives; "into" is what the tile turns into for a while when it runs out
local GATHER = {
  pine = { skill = "woodcutting", req = 1, xp = 15, item = "logs", deplete = 0.15, into = "s", respawn = 20 },
  ironbark = { skill = "woodcutting", req = 15, xp = 40, item = "ironbark", deplete = 0.2, into = "s", respawn = 30 },
  copper = { skill = "mining", req = 1, xp = 17, item = "copper", deplete = 0.25, into = "r", respawn = 15 },
  iron = { skill = "mining", req = 15, xp = 35, item = "iron", deplete = 0.3, into = "r", respawn = 25 },
  berries = { skill = "foraging", req = 1, xp = 8, item = "berries", deplete = 0.2, into = "e", respawn = 20 },
  fish = { skill = "fishing", req = 1, xp = 10, item = "minnow", better = { req = 10, xp = 25, item = "trout", chance = 0.4 } },
}
R.GATHER = GATHER

local ITEMS = {
  logs = { name = "Pine Logs", price = 3 },
  ironbark = { name = "Ironbark Logs", price = 12 },
  copper = { name = "Copper Ore", price = 4 },
  iron = { name = "Iron Ore", price = 14 },
  minnow = { name = "Raw Minnow", price = 2, cook = "cminnow", cookReq = 1, cookXp = 20 },
  trout = { name = "Raw Trout", price = 6, cook = "ctrout", cookReq = 10, cookXp = 40 },
  cminnow = { name = "Cooked Minnow", price = 5, heal = 3 },
  ctrout = { name = "Cooked Trout", price = 12, heal = 6 },
  burnt = { name = "Burnt Fish", price = 0 },
  berries = { name = "Moo-berries", price = 1, heal = 2 },
  pelt = { name = "Wolf Pelt", price = 10 },
  tusk = { name = "Boar Tusk", price = 20 },
  horn = { name = "Kodo Horn", price = 60 },
}
R.ITEMS = ITEMS
local ITEM_ORDER = { "logs", "ironbark", "copper", "iron", "minnow", "trout", "cminnow", "ctrout", "burnt", "berries",
  "pelt", "tusk", "horn" }
R.ITEM_ORDER = ITEM_ORDER

local MOBS = {
  w = { name = "Prairie Wolf", level = 2, hp = 8, maxHit = 2, xp = 20, drop = "pelt", icon = "Interface\\Icons\\Ability_Hunter_Pet_Wolf" },
  b = { name = "Bristleback Boar", level = 6, hp = 16, maxHit = 3, xp = 45, drop = "tusk", icon = "Interface\\Icons\\Ability_Hunter_Pet_Boar" },
  k = { name = "Wild Kodo", level = 14, hp = 34, maxHit = 5, xp = 120, drop = "horn", icon = "Interface\\Icons\\Ability_Mount_Kodo_01" },
}
R.MOBS = MOBS

local STEP_TIME, GATHER_TIME, COOK_TIME, FIGHT_TIME = 0.22, 2.0, 1.6, 1.4
local MOB_RESPAWN, REGEN_TIME = 30, 8
local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

---------------------------------------------------------------------------
-- Levels
---------------------------------------------------------------------------

-- total xp needed to reach a level
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

function R:Level(skill) return R.LevelFor(S().xp[skill] or 0) end
function R:TotalLevel()
  local n = 0
  for _, s in ipairs(SKILLS) do n = n + self:Level(s) end
  return n
end
function R:MaxHP() return 10 + self:Level("combat") end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

R.log = {}
function R:Say(text)
  table.insert(self.log, text)
  while #self.log > 6 do table.remove(self.log, 1) end
  self.dirty = true
end

local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

function R:Init()
  ns.db.rpg = ns.db.rpg or {}
  local s = ns.db.rpg
  s.xp = s.xp or {}
  s.inv = s.inv or {}
  for _, k in ipairs(SKILLS) do s.xp[k] = math.max(0, tonumber(s.xp[k]) or 0) end
  for k, v in pairs(s.inv) do
    if not ITEMS[k] or type(v) ~= "number" or v <= 0 then s.inv[k] = nil end
  end
  -- the map, and where monsters start
  self.grid, self.mobs, self.depleted = {}, {}, {}
  for y = 1, H do
    self.grid[y] = {}
    for x = 1, W do
      local c = MAP[y]:sub(x, x)
      if c == "@" then self.startX, self.startY = x, y c = "," end
      if MOBS[c] then
        self.mobs[#self.mobs + 1] = { kind = c, def = MOBS[c], x = x, y = y, homeX = x, homeY = y, hp = MOBS[c].hp, moveAt = 0 }
        c = "."
      end
      self.grid[y][x] = c
    end
  end
  if not (s.x and s.y and self:Walkable(s.x, s.y)) then s.x, s.y = self.startX, self.startY end
  s.hp = Clamp(tonumber(s.hp) or self:MaxHP(), 1, self:MaxHP())
  self.path, self.action = nil, nil
  self.moveT, self.actT, self.regenT, self.clock = 0, 0, 0, 0
  self.ready = true
end

function R:Tile(x, y)
  if x < 1 or y < 1 or x > W or y > H then return nil end
  return TILES[self.grid[y][x]]
end

function R:MobAt(x, y)
  for _, m in ipairs(self.mobs) do
    if not m.dead and m.x == x and m.y == y then return m end
  end
end

function R:Walkable(x, y, ignorePlayer)
  local t = self:Tile(x, y)
  if not t or not t.walk then return false end
  if self:MobAt(x, y) then return false end
  return true
end

local function Adjacent(ax, ay, bx, by) return math.abs(ax - bx) + math.abs(ay - by) == 1 end

-- Breadth-first path from the player to (tx, ty), or to a tile next to it when "next" is set.
-- Returns a list of {x, y} steps (empty when already there), or nil when there's no way.
function R:Path(tx, ty, nextTo)
  local s = S()
  local function Goal(x, y)
    if nextTo then return Adjacent(x, y, tx, ty) end
    return x == tx and y == ty
  end
  if Goal(s.x, s.y) then return {} end
  local key = function(x, y) return y * 100 + x end
  local from = { [key(s.x, s.y)] = false }
  local queue, head = { { s.x, s.y } }, 1
  while head <= #queue do
    local cx, cy = queue[head][1], queue[head][2]
    head = head + 1
    for _, d in ipairs(DIRS) do
      local nx, ny = cx + d[1], cy + d[2]
      local k = key(nx, ny)
      if from[k] == nil and self:Walkable(nx, ny) then
        from[k] = key(cx, cy)
        if Goal(nx, ny) then
          local path, at = {}, k
          while at and at ~= key(s.x, s.y) do
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
-- Inventory and xp
---------------------------------------------------------------------------

function R:Count(item) return S().inv[item] or 0 end

function R:AddItem(item, n)
  local inv = S().inv
  inv[item] = (inv[item] or 0) + (n or 1)
  self.dirty = true
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

function R:AddXP(skill, amount)
  local s = S()
  local before = self:Level(skill)
  s.xp[skill] = (s.xp[skill] or 0) + amount
  local after = self:Level(skill)
  if after > before then
    self:Say(("|cffffd100Level up!|r %s is now %d."):format(SKILL_NAMES[skill], after))
    if ns.Toast then ns:Toast("MOO QUEST LEVEL UP", ("%s %d"):format(SKILL_NAMES[skill], after)) end
    ns:Bump("rpgLevelUps", after - before)
    ns:StatMax("rpgTotalLevel", self:TotalLevel())
    if skill == "combat" then s.hp = math.min(self:MaxHP(), s.hp + (after - before)) end
  end
  self.dirty = true
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------

function R:Stop()
  self.path, self.action = nil, nil
end

-- what happens when you click a map tile
function R:Click(x, y)
  if not self.ready or not self:Tile(x, y) then return end
  local mob = self:MobAt(x, y)
  local t = self:Tile(x, y)
  if mob then
    self.action = { kind = "fight", mob = mob }
    self.path = self:Path(mob.x, mob.y, true)
    if not self.path then self:Say("You can't reach the " .. mob.def.name .. ".") self:Stop() end
    return
  end
  if t.walk then
    self.action = nil
    self.path = self:Path(x, y, false)
    if not self.path then self:Say("You can't get there.") end
    return
  end
  if t.gather or t.use then
    self.action = { kind = t.gather and "gather" or t.use, x = x, y = y }
    self.path = self:Path(x, y, true)
    if not self.path then self:Say("You can't reach that.") self:Stop() end
    self.actT = 0
    return
  end
  self:Say(("It's a %s."):format(t.name:lower()))
end

local function DoGather(self, a)
  local t = self:Tile(a.x, a.y)
  if not t or not t.gather then self:Stop() return end
  local g = GATHER[t.gather]
  local level = self:Level(g.skill)
  local item, xp, req = g.item, g.xp, g.req
  if g.better and level >= g.better.req and random() < g.better.chance then
    item, xp, req = g.better.item, g.better.xp, g.better.req
  end
  if level < req then
    self:Say(("You need %s level %d for that."):format(SKILL_NAMES[g.skill], req))
    self:Stop()
    return
  end
  local chance = Clamp(0.3 + 0.04 * (level - req), 0.3, 0.9)
  if random() < chance then
    self:AddItem(item)
    self:AddXP(g.skill, xp)
    ns:Bump("rpgGathered")
    self:Say(("You get some %s."):format(ITEMS[item].name))
    if g.deplete and random() < g.deplete then
      self.depleted[#self.depleted + 1] = { x = a.x, y = a.y, c = self.grid[a.y][a.x], at = self.clock + g.respawn }
      self.grid[a.y][a.x] = g.into
      self:Say(("The %s is used up for now."):format(t.name:lower()))
      self:Stop()
    end
  end
end

local function DoCook(self)
  local raw
  for _, k in ipairs(ITEM_ORDER) do
    if ITEMS[k].cook and self:Count(k) > 0 and self:Level("cooking") >= ITEMS[k].cookReq then raw = k break end
  end
  if not raw then
    self:Say("You have nothing you can cook.")
    self:Stop()
    return
  end
  local it = ITEMS[raw]
  self:TakeItem(raw)
  local burn = Clamp(0.5 - 0.04 * (self:Level("cooking") - it.cookReq), 0.05, 0.5)
  if random() < burn then
    self:AddItem("burnt")
    self:Say("You burn the fish. Moo...")
  else
    self:AddItem(it.cook)
    self:AddXP("cooking", it.cookXp)
    self:Say(("You cook a %s."):format(ITEMS[it.cook].name))
  end
end

function R:Sell()
  local total, sold = 0, 0
  for _, k in ipairs(ITEM_ORDER) do
    local it, n = ITEMS[k], self:Count(k)
    -- food you can eat is kept; everything else goes
    if n > 0 and not it.heal then
      total = total + it.price * n
      sold = sold + n
      S().inv[k] = nil
    end
  end
  self.dirty = true
  if sold == 0 then
    self:Say("Trader Moo-rgan: \"Bring me logs, ore, fish and hides, friend.\"")
    return 0
  end
  if total > 0 and ns.AddMilk then ns:AddMilk(total) end
  ns:Bump("rpgMilkEarned", total)
  self:Say(("Trader Moo-rgan buys %d items for %s milk."):format(sold, ns.FormatNumber and ns.FormatNumber(total) or total))
  return total
end

function R:Eat(item)
  local it = ITEMS[item]
  local s = S()
  if not it or not it.heal then self:Say("You can't eat that.") return false end
  if self:Count(item) == 0 then return false end
  if s.hp >= self:MaxHP() then self:Say("You're not hungry.") return false end
  self:TakeItem(item)
  s.hp = math.min(self:MaxHP(), s.hp + it.heal)
  self:Say(("You eat the %s. Health %d/%d."):format(it.name, s.hp, self:MaxHP()))
  return true
end

local function Die(self)
  local s = S()
  ns:Bump("rpgDeaths")
  s.x, s.y, s.hp = self.startX, self.startY, self:MaxHP()
  self:Stop()
  self:Say("|cffff4040You were knocked out!|r You wake up back on the path, keeping your things. Moo.")
end

local function DoFight(self, mob)
  local s = S()
  local my = self:Level("combat")
  local hitChance = Clamp(0.55 + 0.03 * (my - mob.def.level), 0.15, 0.9)
  if random() < hitChance then
    local dmg = random(1, 1 + math.floor(my / 3))
    mob.hp = mob.hp - dmg
    self:Say(("You hit the %s for %d."):format(mob.def.name, dmg))
  else
    self:Say(("You miss the %s."):format(mob.def.name))
  end
  if mob.hp <= 0 then
    mob.dead, mob.respawnAt = true, self.clock + MOB_RESPAWN
    self:AddXP("combat", mob.def.xp)
    self:AddItem(mob.def.drop)
    ns:Bump("rpgKills")
    if mob.kind == "k" then ns:Bump("rpgKodoKills") end
    self:Say(("The %s is defeated! It drops a %s."):format(mob.def.name, ITEMS[mob.def.drop].name))
    self:Stop()
    return
  end
  local mobChance = Clamp(0.5 + 0.03 * (mob.def.level - my), 0.15, 0.85)
  if random() < mobChance then
    local dmg = random(1, mob.def.maxHit)
    s.hp = s.hp - dmg
    if s.hp <= 0 then return Die(self) end
  end
  self.dirty = true
end

---------------------------------------------------------------------------
-- The clock
---------------------------------------------------------------------------

function R:Update(dt)
  if not self.ready then return end
  local s = S()
  self.clock = self.clock + dt
  -- used-up spots come back
  for i = #self.depleted, 1, -1 do
    local d = self.depleted[i]
    if self.clock >= d.at then
      self.grid[d.y][d.x] = d.c
      table.remove(self.depleted, i)
      self.dirty = true
    end
  end
  -- monsters respawn and wander (but not the one you're fighting)
  for _, m in ipairs(self.mobs) do
    if m.dead then
      if self.clock >= m.respawnAt and not (s.x == m.homeX and s.y == m.homeY) and not self:MobAt(m.homeX, m.homeY) then
        m.dead, m.hp, m.x, m.y = false, m.def.hp, m.homeX, m.homeY
        self.dirty = true
      end
    elseif not (self.action and self.action.mob == m) and self.clock >= m.moveAt then
      m.moveAt = self.clock + 2 + random() * 3
      local d = DIRS[random(4)]
      local nx, ny = m.x + d[1], m.y + d[2]
      -- they stay near home and never step onto you
      if math.abs(nx - m.homeX) <= 3 and math.abs(ny - m.homeY) <= 3 and self:Walkable(nx, ny)
        and not (nx == s.x and ny == s.y) then
        m.x, m.y = nx, ny
        self.dirty = true
      end
    end
  end
  -- walking
  if self.path and #self.path > 0 then
    self.moveT = self.moveT + dt
    while self.path and #self.path > 0 and self.moveT >= STEP_TIME do
      self.moveT = self.moveT - STEP_TIME
      local step = self.path[1]
      if self:Walkable(step[1], step[2]) then
        table.remove(self.path, 1)
        s.x, s.y = step[1], step[2]
        self.dirty = true
      else
        -- something stepped in the way: find another way
        local a = self.action
        if a and a.mob then self.path = self:Path(a.mob.x, a.mob.y, true)
        elseif a then self.path = self:Path(a.x, a.y, true)
        else
          local last = self.path[#self.path]
          self.path = self:Path(last[1], last[2], false)
        end
        if not self.path then self:Say("Something is in the way.") self:Stop() end
      end
    end
    return
  end
  self.moveT = 0
  -- doing things
  local a = self.action
  if a then
    if a.mob then
      if a.mob.dead then self:Stop() return end
      if not Adjacent(s.x, s.y, a.mob.x, a.mob.y) then
        self.path = self:Path(a.mob.x, a.mob.y, true)
        if not self.path then self:Stop() end
        return
      end
    elseif not Adjacent(s.x, s.y, a.x, a.y) then
      self.path = self:Path(a.x, a.y, true)
      if not self.path then self:Stop() end
      return
    end
    self.actT = self.actT + dt
    local need = (a.kind == "fight" and FIGHT_TIME) or (a.kind == "cook" and COOK_TIME) or GATHER_TIME
    if a.kind == "sell" then
      self:Sell()
      self:Stop()
    elseif self.actT >= need then
      self.actT = 0
      if a.kind == "gather" then DoGather(self, a)
      elseif a.kind == "cook" then DoCook(self)
      elseif a.kind == "fight" then DoFight(self, a.mob) end
    end
  else
    self.actT = 0
  end
  -- slow healing when not fighting
  if not (a and a.kind == "fight") and s.hp < self:MaxHP() then
    self.regenT = self.regenT + dt
    if self.regenT >= REGEN_TIME then
      self.regenT = 0
      s.hp = s.hp + 1
      self.dirty = true
    end
  end
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------

local TS = 26 -- tile size
local frame
local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

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

function R:Refresh()
  if not frame or not frame:IsShown() then return end
  self.dirty = false
  local s = S()
  for y = 1, H do
    for x = 1, W do
      local b = frame.tiles[y][x]
      local t = TILES[self.grid[y][x]]
      b.tex:SetColorTexture(t.color[1], t.color[2], t.color[3], 1)
      b.glyph:SetText(t.glyph or "")
    end
  end
  frame.player:ClearAllPoints()
  frame.player:SetPoint("TOPLEFT", frame.tiles[s.y][s.x], "TOPLEFT", 2, -2)
  for i, m in ipairs(self.mobs) do
    local icon = frame.mobIcons[i]
    if m.dead then
      icon:Hide()
    else
      icon:ClearAllPoints()
      icon:SetPoint("TOPLEFT", frame.tiles[m.y][m.x], "TOPLEFT", 2, -2)
      icon:Show()
    end
  end
  local max = self:MaxHP()
  frame.hp:SetMinMaxValues(0, max)
  frame.hp:SetValue(math.max(0, s.hp))
  frame.hp.text:SetText(("Health %d / %d"):format(math.max(0, s.hp), max))
  for i, skill in ipairs(SKILLS) do
    local row = frame.skills[i]
    local level, xp = self:Level(skill), s.xp[skill] or 0
    local from, to = R.XPFor(level), R.XPFor(level + 1)
    row:SetMinMaxValues(0, math.max(1, to - from))
    row:SetValue(level >= MAX_LEVEL and (to - from) or (xp - from))
    row.text:SetText(("%s  %d"):format(SKILL_NAMES[skill], level))
  end
  frame.total:SetText(("Total level %d"):format(self:TotalLevel()))
  local slot = 0
  for _, k in ipairs(ITEM_ORDER) do
    local n = self:Count(k)
    if n > 0 then
      slot = slot + 1
      local b = frame.slots[slot]
      if b then
        b.item = k
        b.name:SetText(ITEMS[k].name)
        b.count:SetText(n)
        b:Show()
      end
    end
  end
  for i = slot + 1, #frame.slots do frame.slots[i].item = nil frame.slots[i]:Hide() end
  frame.log:SetText(table.concat(self.log, "\n"))
  local a = self.action
  frame.doing:SetText(a and (a.kind == "fight" and ("Fighting: %s (%d hp)"):format(a.mob.def.name, math.max(0, a.mob.hp))
    or (a.kind == "gather" and ("Gathering: " .. self:Tile(a.x, a.y).name)) or (a.kind == "cook" and "Cooking")
    or "") or (self.path and #self.path > 0 and "Walking" or "Idle. Click something."))
end

local function CreateWindow()
  frame = CreateFrame("Frame", "MooHelperPasture", UIParent, BACKDROP_TEMPLATE)
  frame:SetSize(W * TS + 250, H * TS + 150)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("HIGH")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetClampedToScreen(true)
  Box(frame, { 0.1, 0.07, 0.04, 0.97 }, { 0.7, 0.55, 0.3 })
  tinsert(UISpecialFrames, "MooHelperPasture") -- Escape closes it
  local title = Text(frame, "GameFontNormalLarge", "TOPLEFT", 14, -12)
  title:SetText("Moo Quest: The Pasture Lands")
  local help = Text(frame, "GameFontDisableSmall", "TOPLEFT", 14, -32, W * TS)
  help:SetText("Click to walk. Click trees, rocks, the pond or bushes to gather, a beast to fight, the fire to cook, $ to sell.")
  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)

  frame.tiles = {}
  for y = 1, H do
    frame.tiles[y] = {}
    for x = 1, W do
      local b = CreateFrame("Button", nil, frame)
      b:SetSize(TS - 1, TS - 1)
      b:SetPoint("TOPLEFT", 14 + (x - 1) * TS, -50 - (y - 1) * TS)
      b.tex = b:CreateTexture(nil, "BACKGROUND")
      b.tex:SetAllPoints()
      b.glyph = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      b.glyph:SetPoint("CENTER")
      b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
      b:SetScript("OnClick", function() R:Click(x, y) R:Refresh() end)
      b:SetScript("OnEnter", function(self)
        local m = R:MobAt(x, y)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(m and ("%s (level %d)"):format(m.def.name, m.def.level) or R:Tile(x, y).name)
        GameTooltip:Show()
      end)
      b:SetScript("OnLeave", function() GameTooltip:Hide() end)
      frame.tiles[y][x] = b
    end
  end
  -- the cow and the beasts sit on a layer above the tiles (child frames draw over their parent's
  -- own textures); it takes no mouse clicks, so clicks still reach the tiles underneath
  frame.overlay = CreateFrame("Frame", nil, frame)
  frame.overlay:SetAllPoints()
  frame.overlay:SetFrameLevel((frame:GetFrameLevel() or 1) + 20)
  frame.overlay:EnableMouse(false)
  local function Icon(path)
    local t = frame.overlay:CreateTexture(nil, "OVERLAY")
    t:SetSize(TS - 5, TS - 5)
    t:SetTexture(path)
    return t
  end
  frame.player = Icon("Interface\\Icons\\Spell_Nature_Polymorph_Cow")
  frame.mobIcons = {}
  for i, m in ipairs(R.mobs) do frame.mobIcons[i] = Icon(m.def.icon) end

  -- the side panel
  local px = 14 + W * TS + 12
  frame.hp = CreateFrame("StatusBar", nil, frame)
  frame.hp:SetSize(220, 16)
  frame.hp:SetPoint("TOPLEFT", px, -50)
  frame.hp:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  frame.hp:SetStatusBarColor(0.8, 0.15, 0.15)
  frame.hp.text = frame.hp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.hp.text:SetPoint("CENTER")
  frame.skills = {}
  for i = 1, #SKILLS do
    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetSize(220, 14)
    bar:SetPoint("TOPLEFT", px, -72 - (i - 1) * 17)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.85, 0.65, 0.2)
    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.text:SetPoint("LEFT", 4, 0)
    frame.skills[i] = bar
  end
  frame.total = Text(frame, "GameFontNormalSmall", "TOPLEFT", px, -176)
  local invTitle = Text(frame, "GameFontNormal", "TOPLEFT", px, -196)
  invTitle:SetText("Pack (click food to eat)")
  frame.slots = {}
  for i = 1, #ITEM_ORDER do
    local b = CreateFrame("Button", nil, frame, BACKDROP_TEMPLATE)
    b:SetSize(108, 22)
    b:SetPoint("TOPLEFT", px + ((i - 1) % 2) * 112, -214 - math.floor((i - 1) / 2) * 24)
    Box(b, { 0.2, 0.13, 0.07, 0.95 }, { 0.5, 0.38, 0.2 })
    b.name = Text(b, "GameFontHighlightSmall", "LEFT", 6, 0, 76)
    b.count = Text(b, "GameFontNormalSmall", "RIGHT", -6, 0)
    b:SetScript("OnClick", function(self) if self.item then R:Eat(self.item) R:Refresh() end end)
    b:Hide()
    frame.slots[i] = b
  end
  frame.doing = Text(frame, "GameFontNormal", "TOPLEFT", 14, -56 - H * TS, W * TS)
  frame.log = Text(frame, "GameFontHighlightSmall", "TOPLEFT", 14, -76 - H * TS, W * TS + 220)
  frame.log:SetJustifyV("TOP")

  frame:SetScript("OnUpdate", function(_, elapsed)
    R:Update(math.min(elapsed, 0.5))
    if R.dirty then R:Refresh() end
  end)
  frame:SetScript("OnShow", function() R:Refresh() end)
  frame:Hide()
end

function R:Toggle(show)
  if not self.ready then self:Init() end
  if not frame then CreateWindow() end
  if show == nil then show = not frame:IsShown() end
  if show then
    frame:Show()
    ns:Bump("rpgOpened")
    if #self.log == 0 then self:Say("Welcome to the Pasture Lands. Chop a pine (T) to begin. Moo.") end
    self:Refresh()
  else
    frame:Hide()
  end
end

SLASH_MOOPASTURE1 = "/pasture"
SLASH_MOOPASTURE2 = "/mooquest"
SlashCmdList.MOOPASTURE = function() R:Toggle() end

ns:On("PLAYER_LOGIN", function() R:Init() end)
