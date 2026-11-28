-- MooHelper Moo-chievements: core engine (ported from Forever Achievements)
-- Holds the achievement registry, saved variables, counters/flags, evaluation and awarding.

local _, MH = ...
MH.Ach = MH.Ach or {}
local ns = MH.Ach -- the achievement engine (ported from Forever Achievements)


ns.categories = {}     -- key -> { key, name }
ns.categoryOrder = {}  -- ordered category keys
ns.list = {}           -- ordered achievement definitions
ns.byId = {}           -- id -> definition
ns.bossNPCs = {}       -- npcID -> boss name (filled by Data.lua)

local ICON_PATH = "Interface\\Icons\\"
local DEFAULT_ICON = ICON_PATH .. "INV_Misc_QuestionMark"

local function Color(hex, text)
  return "|cff" .. hex .. tostring(text) .. "|r"
end
ns.Color = Color

function ns:Print(msg) MH:Print(msg) end

local function ApplyDefaults(t, d)
  for k, v in pairs(d) do
    if t[k] == nil then
      if type(v) == "table" then
        t[k] = {}
        ApplyDefaults(t[k], v)
      else
        t[k] = v
      end
    end
  end
  return t
end

function ns.NpcIDFromGUID(guid)
  if not guid then return nil end
  local unitType, _, _, _, _, npcID = strsplit("-", guid)
  if unitType == "Creature" or unitType == "Vehicle" then
    return tonumber(npcID)
  end
end

---------------------------------------------------------------------------
-- Registry
---------------------------------------------------------------------------

function ns:AddCategory(key, name)
  if not self.categories[key] then
    self.categories[key] = { key = key, name = name }
    table.insert(self.categoryOrder, key)
  end
end

--[[ Achievement definition fields:
  id        unique string id (required)
  category  category key (required)
  name, desc
  points    default 10
  icon      icon name under Interface\Icons\ or a full texture path
  hidden    true = not listed until earned (Feats of Strength style)
  hint      extra tooltip line

  Criteria (pick one; `check` wins if present, other fields still drive the progress bar):
  counter + goal     counter value >= goal
  flag               a single flag is set
  flags (+ goal)     `goal` (default: all) of the listed flags are set; `labels` names them
  meta               list of achievement ids that must all be complete
  check(ns)          custom function returning true when earned
  failed(ns)         optional: returns true when the achievement can no longer be earned
  format = "money"   render counter progress as gold
]]
function ns:Add(def)
  assert(def.id, "achievement without id")
  assert(not self.byId[def.id], "duplicate achievement id: " .. def.id)
  assert(self.categories[def.category], "unknown category for " .. def.id)
  def.points = def.points or 10
  if def.icon then
    if not def.icon:find("\\", 1, true) then def.icon = ICON_PATH .. def.icon end
  else
    def.icon = DEFAULT_ICON
  end
  self.byId[def.id] = def
  table.insert(self.list, def)
  return def
end

---------------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------------

function ns:InitDB()
  MooHelperAchDB = MooHelperAchDB or {}
  self.db = MooHelperAchDB
  ApplyDefaults(self.db, {
    settings = {
      announceGuild = false,
      announceParty = false,
      sound = true,
      toasts = true,
      minimapAngle = 220,
      hideMinimap = false,
    },
  })

  MooHelperAchCharDB = MooHelperAchCharDB or {}
  self.char = MooHelperAchCharDB
  ApplyDefaults(self.char, { completed = {}, counters = {}, flags = {}, sets = {} })

  -- Locale-independent identity, used by class/race achievements and the roster.
  local _, classFile = UnitClass("player")
  local raceName, raceFile = UnitRace("player")
  self.classFile, self.raceFile, self.raceName = classFile, raceFile, raceName
  self.playerName, self.realmName = UnitName("player"), GetRealmName()
  self.charKey = tostring(self.playerName) .. "-" .. tostring(self.realmName)
  self.db.characters = self.db.characters or {}

  if not self.char.firstSeenLevel then
    -- First time this addon runs on this character.
    self.char.firstSeenLevel = UnitLevel("player")
    self.char.firstSeenTime = time()
    self.isFirstRun = true
  end
end

---------------------------------------------------------------------------
-- Counters / flags / sets
---------------------------------------------------------------------------

function ns:Get(key)
  return self.char.counters[key] or 0
end

function ns:Inc(key, n)
  local c = self.char.counters
  c[key] = (c[key] or 0) + (n or 1)
  self:RequestEvaluate()
end

function ns:SetMax(key, value)
  if type(value) ~= "number" then return end
  local c = self.char.counters
  if value > (c[key] or 0) then
    c[key] = value
    self:RequestEvaluate()
  end
end

function ns:HasFlag(key)
  return self.char.flags[key] == true
end

function ns:SetFlag(key)
  if not self.char.flags[key] then
    self.char.flags[key] = true
    self:RequestEvaluate()
  end
end

-- Adds a unique member to a named set; the set's size is mirrored into a counter of the same name.
function ns:AddToSet(setName, member)
  local s = self.char.sets[setName]
  if not s then
    s = {}
    self.char.sets[setName] = s
  end
  if not s[member] then
    s[member] = true
    self.char.counters[setName] = (self.char.counters[setName] or 0) + 1
    self:RequestEvaluate()
  end
end

---------------------------------------------------------------------------
-- Evaluation
---------------------------------------------------------------------------

-- Hardcore ruleset check (Forever's C_GameRules; returns false anywhere it's missing).
function ns:IsHardcore()
  if C_GameRules and C_GameRules.IsHardcoreActive then
    local ok, active = pcall(C_GameRules.IsHardcoreActive)
    return ok and active == true
  end
  return false
end

function ns:IsComplete(id)
  return self.char.completed[id] ~= nil
end

-- Returns current, max for achievements that have measurable progress.
function ns:GetProgress(a)
  if a.progress then
    return a.progress(self)
  elseif a.counter then
    return math.min(self:Get(a.counter), a.goal), a.goal
  elseif a.flags then
    local n = 0
    for _, f in ipairs(a.flags) do
      if self.char.flags[f] then n = n + 1 end
    end
    local goal = a.goal or #a.flags
    return math.min(n, goal), goal
  elseif a.meta then
    local n = 0
    for _, id in ipairs(a.meta) do
      if self:IsComplete(id) then n = n + 1 end
    end
    return n, #a.meta
  elseif a.flag then
    return self.char.flags[a.flag] and 1 or 0, 1
  end
end

function ns:IsMet(a)
  if a.check then return a.check(self) and true or false end
  local cur, max = self:GetProgress(a)
  return cur ~= nil and max ~= nil and cur >= max
end

function ns:RequestEvaluate()
  if self.pending then return end
  self.pending = true
  -- from a timer, so outside the event bus's error handling: one broken check is logged
  -- instead of stopping every achievement (and erroring again on each re-check)
  C_Timer.After(0.1, function()
    local ok, err = pcall(ns.Evaluate, ns)
    if not ok and MH.errors then table.insert(MH.errors, "achievements: " .. tostring(err)) end
  end)
end

function ns:Evaluate()
  self.pending = false
  if not self.ready then return end
  local earnedAny = false
  local changed = true
  while changed do -- loop so meta achievements resolve in the same pass
    changed = false
    for _, a in ipairs(self.list) do
      if not self.char.completed[a.id] and self:IsMet(a) then
        self:Award(a)
        changed, earnedAny = true, true
      end
    end
  end
  self:UpdateCharacterRecord()
  if self.RefreshUI then self:RefreshUI() end
  if earnedAny and self.OnAchievementsChanged then self:OnAchievementsChanged() end
  return earnedAny
end

-- Account-wide roster of characters that have run the addon (for Account achievements
-- and the in-game character list).
function ns:UpdateCharacterRecord()
  if not self.charKey then return end
  local done, _, points = self:GetSummary()
  self.db.characters[self.charKey] = {
    name = self.playerName, realm = self.realmName,
    class = self.classFile, race = self.raceFile,
    level = self:Get("level"), points = points, count = done, updated = time(),
  }
end

function ns:Award(a)
  self.char.completed[a.id] = time()
  if self.silent then
    self.silentCount = (self.silentCount or 0) + 1
    return
  end
  self:Print(("MOO-CHIEVEMENT EARNED: %s %s"):format(
    Color("ffff00", "[" .. a.name .. "]"), Color("aaaaaa", "(" .. a.points .. " points)")))
  if MH.AchievementToast then MH:AchievementToast(a) end
  if MH.OnAchievement then MH:OnAchievement(a) end

  -- announcements go through MooHelper's queue: rate limited, and hard mutes apply
  local text = ("MOO-CHIEVEMENT EARNED: [%s] (%d points). Moo."):format(a.name, a.points)
  if MH.db and not a.hidden then
    local ch = MH:GroupChannel()
    if MH.db.achAnnounce and ch then MH:Queue(ch, text, 2) end
    if MH.db.achAnnounceGuild and IsInGuild() then MH:Queue("GUILD", text, 1) end
  end
end

-- done, total, points, maxPoints for a category (or everything when category is nil)
function ns:GetSummary(category)
  local done, total, points, maxPoints = 0, 0, 0, 0
  for _, a in ipairs(self.list) do
    if not category or a.category == category then
      local completed = self.char.completed[a.id]
      if completed or not a.hidden then
        total = total + 1
        maxPoints = maxPoints + a.points
      end
      if completed then
        done = done + 1
        points = points + a.points
      end
    end
  end
  return done, total, points, maxPoints
end

