-- MooHelper: Bessie, your virtual cow
-- She gets hungry, gets bored, grows up as you moo, reacts to what happens in your party,
-- and occasionally speaks up in group chat. Feed her with milk from the Farm.

local _, ns = ...

local random = math.random
local function Pick(list) return list[random(#list)] end

ns.BESSIE_STAGES = {
  { name = "Calf", xp = 0 }, { name = "Yearling", xp = 150 }, { name = "Grown Cow", xp = 500 },
  { name = "Prize Cow", xp = 1500 }, { name = "Champion of the Fair", xp = 4000 },
  { name = "Legendary Moo Beast", xp = 10000 },
}
local FEED_COST = 10
local COOLDOWN = { pet = 5, brush = 20, show = 60 }

local function B() return ns.db.bessie end

local function Clamp(v) return math.max(0, math.min(100, v)) end

function ns:BessieInit()
  self.db.bessie = self.db.bessie or {
    name = "Bessie", xp = 0, stage = 1, hunger = 80, happiness = 70, energy = 100,
    born = time(), last = time(), lastAction = {},
  }
  local b = B()
  b.lastAction = b.lastAction or {}
  -- time away: she got hungrier and lonelier while you were gone (capped so she never "dies")
  local away = math.max(0, time() - (b.last or time()))
  local minutes = math.min(away / 60, 600)
  b.hunger = Clamp(b.hunger - minutes / 3)
  b.happiness = Clamp(b.happiness - minutes / 2)
  b.energy = Clamp(b.energy + minutes)
  b.last = time()
end

function ns:BessieMood()
  local b = B()
  if b.hunger < 20 then return "starving", "is staring at you and at the hay. Mostly the hay." end
  if b.happiness < 20 then return "sad", "looks sad. Someone should pet her." end
  if b.energy < 20 then return "sleepy", "is falling asleep standing up." end
  if b.happiness >= 90 and b.hunger >= 70 then return "ecstatic", "is the happiest cow in Azeroth." end
  return "content", "is chewing contentedly."
end

function ns:BessieStageName() return ns.BESSIE_STAGES[B().stage].name end

-- XP from everything; growing up is announced
function ns:BessieXP(amount)
  local b = B()
  if not b then return end
  b.xp = b.xp + amount
  local stage = b.stage
  while ns.BESSIE_STAGES[stage + 1] and b.xp >= ns.BESSIE_STAGES[stage + 1].xp do stage = stage + 1 end
  if stage > b.stage then
    b.stage = stage
    local name = ns.BESSIE_STAGES[stage].name
    self:Print(("%s has grown into a %s!"):format(b.name, name))
    if self.Toast then self:Toast(b.name .. " GREW UP", name) end
    if self.Stampede then self:Stampede(15) end
    local ch = self:GroupChannel()
    if ch and self.db.triggers.bessieTalk then
      self:Queue(ch, ("BIG NEWS: %s, my cow, has grown into a %s. Please congratulate her. Moo."):format(b.name, name), 2)
    end
    self:StatChanged()
  end
end

local function OnCooldown(action)
  local b = B()
  local last = b.lastAction[action] or -1000
  if ns.Now() - last < (COOLDOWN[action] or 0) then return true end
  b.lastAction[action] = ns.Now()
  return false
end

-- returns ok, message
function ns:BessieFeed()
  local b = B()
  if b.hunger >= 100 then return false, b.name .. " is full. She gives you a look." end
  local cost = FEED_COST
  if self.HasUpgrade and self:HasUpgrade("diet") then cost = math.ceil(cost / 2) end
  if not self.SpendMilk or not self:SpendMilk(cost) then
    return false, ("You need %d milk to feed %s. Moo to earn milk."):format(cost, b.name)
  end
  b.hunger = Clamp(b.hunger + 25)
  b.happiness = Clamp(b.happiness + 5)
  self:Bump("bessieFeeds")
  self:BessieXP(5)
  return true, Pick({ "%s munches happily.", "%s inhales the hay.", "%s eats it all and looks at you for more." }):format(b.name)
end

function ns:BessiePet()
  local b = B()
  if OnCooldown("pet") then return false, b.name .. " is still enjoying the last pet." end
  b.happiness = Clamp(b.happiness + 8)
  self:Bump("bessiePets")
  self:BessieXP(2)
  return true, Pick({ "%s leans into your hand. Moo.", "%s closes her eyes, content.", "%s moos softly." }):format(b.name)
end

function ns:BessieBrush()
  local b = B()
  if OnCooldown("brush") then return false, b.name .. "'s coat is already gleaming." end
  b.happiness = Clamp(b.happiness + 5)
  b.energy = Clamp(b.energy + 5)
  self:Bump("bessieBrushes")
  self:BessieXP(3)
  return true, ("%s's coat now shines like the Mulgore sunrise."):format(b.name)
end

function ns:BessieShowOff()
  local b = B()
  local ch = self:GroupChannel()
  if not ch then return false, "Find a party to show her off to." end
  if OnCooldown("show") then return false, "Give the party a minute to recover from the last showing." end
  local _, mood = self:BessieMood()
  self:Queue(ch, ("Behold my cow, %s the %s (%d xp). She %s Moo."):format(b.name, self:BessieStageName(), b.xp,
    mood:gsub("%.$", ".")), 3)
  self:Bump("bessieShows")
  self:BessieXP(3)
  return true, "The party has been shown your cow."
end

function ns:BessieRename(name)
  name = ns.Clean(name or ""):gsub("[^%a%s'%-]", ""):gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" or #name > 20 then return false, "Cow names are 1 to 20 letters." end
  B().name = name
  self:Bump("bessieNamed")
  return true, ("Your cow is now called %s. She seems to like it."):format(name)
end

-- every second: slowly get hungry and bored, rest while you're not mooing
local tickAcc = 0
local lastTalk
local TALK = {
  starving = { "(%s is very hungry. Moo.)", "(%s is eyeing your backpack.)" },
  sad = { "(%s looks lonely. Someone pet the cow.)", "(%s sighs a long, sad moo.)" },
  sleepy = { "(%s yawns. Mooo-zzz.)" },
  ecstatic = { "(%s does a little dance. MOO!)", "(%s is having the best day of her life.)" },
  content = { "(%s chews thoughtfully.)", "(%s moos at a butterfly.)", "(%s says hi. Moo.)" },
}
table.insert(ns.tickFns, function()
  local b = B()
  if not b then return end
  tickAcc = tickAcc + 1
  if tickAcc >= 60 then
    tickAcc = 0
    b.hunger = Clamp(b.hunger - 1 / 3)
    b.happiness = Clamp(b.happiness - 0.5)
    b.energy = Clamp(b.energy + 1)
    b.last = time()
  end
  -- Bessie speaks up in group chat now and then (never in combat, never during mercy)
  if not ns.db.triggers.bessieTalk or ns.db.panic or InCombatLockdown() or (ns.InMercy and ns:InMercy()) then return end
  local ch = ns:GroupChannel()
  if not ch then return end
  local now = ns.Now()
  if not lastTalk then lastTalk = now return end
  if now - lastTalk >= 900 + random(0, 600) then
    lastTalk = now
    local mood = ns:BessieMood()
    ns:Queue(ch, Pick(TALK[mood]):format(b.name), 1)
  end
end)

-- XP and moods from what happens
table.insert(ns.mooListeners, function()
  local b = B()
  if b then
    ns:BessieXP(1)
    b.energy = Clamp(b.energy - 0.2)
  end
end)
ns:On("ENCOUNTER_END", function(_, _, _, _, success)
  if B() and (success == 1 or success == true) then ns:BessieXP(20) B().happiness = Clamp(B().happiness + 5) end
end)
ns:On("PLAYER_DEAD", function()
  if B() then B().happiness = Clamp(B().happiness - 10) end
end)
ns:On("PLAYER_LOGIN", function() ns:BessieInit() end)
