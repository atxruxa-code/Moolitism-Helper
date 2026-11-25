-- MooHelper: Moo Raid Boss
-- A co-op boss fight played in party (or guild) chat. Friends don't need the addon: every
-- moo anyone types hits the boss. The boss fights back with mechanics everyone has to read:
--   STAMPEDE      type moo within 10 seconds or get trampled (your moos don't count for 15 s)
--   SILENCE       don't moo for 8 seconds: every moo heals the boss
--   BULL'S-EYE    one named player must moo within 8 seconds, or the boss heals
-- At half health it enrages: mechanics come faster and big moos crit. If the boss isn't dead
-- after 3 minutes, it wipes the party.

local _, ns = ...

local random = math.random
local function Pick(list) return list[random(#list)] end
local GAME = 3

local FIGHT_TIME = 180      -- seconds before the boss enrages and wipes the party
local LINE_CAP = 10         -- at most 10 moos count from one line (pastes don't win fights)
local PER_MOO = 10          -- damage per moo
local SPAM_GAP = 1          -- one counted line a second per person
local TRAMPLE_TIME = 15

ns.BOSSES = {
  { name = "The Mad Cow", title = "Terror of the Barrens",
    loot = { "Udder Destruction", "Horns of the Mad Cow", "Hoof of Unending Stomping" } },
  { name = "Moo-gnaros the Firelord", title = "Lord of the Burning Pasture",
    loot = { "Sulfuron Milkpail", "Eye of Moo-gnaros", "Smoldering Cowbell" } },
  { name = "Kel'Moozad", title = "Archlich of the Dairy",
    loot = { "Phylactery of Cream", "Frostmoo Shoulders", "Cowl of the Undying Herd" } },
  { name = "The Lich Kine", title = "Master of the Frozen Herd",
    loot = { "Frostmoorne", "Crown of the Lich Kine", "Helm of Eternal Mooing" } },
  { name = "Deathmoo", title = "The Black Bull of Mulgore",
    loot = { "Scale of the Earth-Moover", "Deathmoo's Cud", "Molten Cowbell" } },
  { name = "Illidairy Stormrage", title = "You Are Not Prepared (to Moo)",
    loot = { "Warglaive of Moozinoth", "Blindfold of the Herd", "Twin Udders" } },
}

local function Group(text, priority) return ns.GroupSay(text, priority or GAME, 60) end

-- [##########----------] as plain text (chat lines can't carry color codes)
local function HPBar(boss)
  local pct = math.max(0, boss.hp) / boss.maxHP
  local filled = math.floor(pct * 20 + 0.5)
  return "[" .. string.rep("#", filled) .. string.rep("-", 20 - filled) .. ("] %d%%"):format(math.ceil(pct * 100))
end
ns.BossHPBar = HPBar

function ns:BossRunning() return self.boss ~= nil end

---------------------------------------------------------------------------
-- Damage
---------------------------------------------------------------------------

local function Damage(boss, name, amount)
  boss.hp = boss.hp - amount
  boss.dmg[name] = (boss.dmg[name] or 0) + amount
end

local function Heal(boss, amount)
  boss.hp = math.min(boss.maxHP, boss.hp + amount)
  boss.healed = boss.healed + amount
end

local function OnLine(msg, name, isSelf)
  local boss = ns.boss
  if not boss or boss.over then return end
  local n = math.min(ns.CountMoos(msg), LINE_CAP)
  if n == 0 then return end
  local now = ns.Now()
  boss.joined[name] = true
  local m = boss.mech
  -- mechanics read every moo, even ones too fast to do damage
  if m and m.open then
    if m.kind == "stampede" then m.safe[name] = true end
    if m.kind == "bullseye" and name == m.target and not m.done then
      m.done = true
      Damage(boss, name, 150)
      Group(("%s answers the BULL'S-EYE! A perfect moo for 150 damage. MOO!"):format(name))
    end
  end
  if (boss.trampled[name] or 0) > now then return end
  if now - (boss.lastHit[name] or -1000) < SPAM_GAP then return end
  boss.lastHit[name] = now
  local amount = n * PER_MOO
  -- an ALL-CAPS MOO crits in phase 2
  local loud = msg:find("MOO") ~= nil and msg:upper() == msg
  if boss.phase == 2 and loud then amount = amount * 2 end
  if m and m.open and m.kind == "silence" then
    Heal(boss, amount)
    m.healers[name] = (m.healers[name] or 0) + amount
    return
  end
  Damage(boss, name, amount)
  if isSelf then ns:Bump("bossDamage", amount) end
end

---------------------------------------------------------------------------
-- Mechanics
---------------------------------------------------------------------------

local MECHANICS = { "stampede", "silence", "bullseye" }

local function Announce(boss, kind)
  local members = ns:GameMembers()
  local everyone = {}
  for _, n in ipairs(members) do everyone[#everyone + 1] = n end
  everyone[#everyone + 1] = UnitName("player")
  local m = { kind = kind, queuedAt = ns.Now(), safe = {}, healers = {} }
  if kind == "stampede" then
    m.line = ("%s casts STAMPEDE! Type moo in the next 10 seconds or get trampled!"):format(boss.name)
    m.window = 10
  elseif kind == "silence" then
    m.line = ("%s casts SILENCE OF THE LAMBS! Don't moo for 8 seconds: every moo heals it!"):format(boss.name)
    m.window = 8
  else
    m.target = Pick(everyone)
    m.line = ("%s puts a BULL'S-EYE on %s! %s, type moo within 8 seconds or it heals!"):format(boss.name, m.target, m.target)
    m.window = 8
  end
  m.everyone = everyone
  boss.mech = m
  Group(m.line)
end

-- cast a mechanic now (testing, and /moo boss tricks): "stampede", "silence" or "bullseye"
function ns:BossMechanic(kind)
  local boss = self.boss
  if not boss or boss.mech then return false end
  Announce(boss, kind)
  return true
end

local function Resolve(boss)
  local m = boss.mech
  boss.mech = nil
  local now = ns.Now()
  if m.kind == "stampede" then
    local flat = {}
    for _, name in ipairs(m.everyone) do
      if not m.safe[name] then
        flat[#flat + 1] = name
        boss.trampled[name] = now + TRAMPLE_TIME
      end
    end
    if #flat == 0 then
      Group("Everyone dodged the STAMPEDE. The herd is nimble. Moo.")
    else
      boss.flawless = false
      Group(("TRAMPLED: %s. Your moos don't count for %d seconds."):format(table.concat(flat, ", "), TRAMPLE_TIME))
    end
  elseif m.kind == "silence" then
    local list, total = {}, 0
    for name, amount in pairs(m.healers) do list[#list + 1] = name total = total + amount end
    table.sort(list)
    if #list == 0 then
      Group("Perfect silence. The boss is furious. ...moo.")
    else
      boss.flawless = false
      Group(("%s mooed during the SILENCE and healed the boss for %d. Shame. Moo."):format(table.concat(list, ", "), total))
    end
  elseif m.kind == "bullseye" and not m.done then
    boss.flawless = false
    Heal(boss, math.floor(boss.maxHP * 0.1))
    Group(("%s missed the BULL'S-EYE. %s heals 10%%. %s"):format(m.target, boss.name, HPBar(boss)))
  end
end

---------------------------------------------------------------------------
-- The fight
---------------------------------------------------------------------------

local function Finish(boss, won)
  boss.over = true
  ns.boss = nil
  ns:RemoveGroupListener("boss")
  if ns.ShareQuiet then ns:ShareQuiet(0) end
  local list = {}
  for name, d in pairs(boss.dmg) do list[#list + 1] = { name = name, dmg = d } end
  table.sort(list, function(a, b) return a.dmg > b.dmg or (a.dmg == b.dmg and a.name < b.name) end)
  local parts = {}
  for i = 1, math.min(3, #list) do parts[#parts + 1] = ("%d. %s %d"):format(i, list[i].name, list[i].dmg) end
  local me = UnitName("player")
  local myDmg = boss.dmg[me] or 0
  local took = math.floor(ns.Now() - boss.started)
  ns.lastBoss = { name = boss.name, won = won, seconds = took, top = list, healed = boss.healed, flawless = won and boss.flawless }
  if won then
    -- loot goes to someone who fought, weighted by damage
    local total, roll, winner = 0, 0, list[1] and list[1].name or me
    for _, e in ipairs(list) do total = total + e.dmg end
    if total > 0 then
      roll = random() * total
      for _, e in ipairs(list) do
        roll = roll - e.dmg
        if roll <= 0 then winner = e.name break end
      end
    end
    local item = Pick(boss.loot)
    Group(("%s has been defeated in %d:%02d! The herd roars. MOO!"):format(boss.name, math.floor(took / 60), took % 60))
    if #parts > 0 then Group("Damage: " .. table.concat(parts, "  ")) end
    Group(("LOOT: [%s] goes to %s! Moo."):format(item, winner))
    ns.lastBoss.loot, ns.lastBoss.winner = item, winner
    ns:Bump("bossKills")
    if myDmg > 0 then ns:Bump("bossKillsJoined") end
    if list[1] and list[1].name == me then ns:Bump("bossTopDamage") end
    if winner == me then ns:Bump("bossLoot") end
    if boss.flawless then ns:Bump("bossFlawless") end
    if took <= 60 then ns:Bump("bossFast") end
    local best = ns:GetStat("bossFastest")
    if best == 0 or took < best then ns.db.stats.c.bossFastest = took ns:StatChanged() end
    if list[1] then ns:HerdAward(list[1].name, 10, "boss") end
    ns:AddMilk(500 + myDmg)
    if ns.Toast then ns:Toast("RAID BOSS DOWN", boss.name) end
    if ns.Stampede then ns:Stampede(25) end
  else
    Group(("%s enrages and stomps the whole party. WIPE. %s Moo..."):format(boss.name, HPBar(boss)))
    if #parts > 0 then Group("Damage: " .. table.concat(parts, "  ")) end
    ns:Bump("bossWipes")
  end
  if ns.RefreshBarn then ns:RefreshBarn() end
end

function ns:StartBoss(starter, which)
  local ok, why = self:BeginGame()
  if not ok then return false, why end
  local def = ns.BOSSES[tonumber(which) or 0] or Pick(ns.BOSSES)
  local players = #self:GameMembers() + 1
  local hp = 400 + 150 * players
  local now = ns.Now()
  self.boss = {
    name = def.name, title = def.title, loot = def.loot, maxHP = hp, hp = hp, phase = 1,
    started = now, nextMech = now + random(15, 20), dmg = {}, lastHit = {}, trampled = {}, joined = {},
    healed = 0, flawless = true, said = {},
  }
  ns:Bump("played:boss")
  if self.OnGameHosted then self:OnGameHosted() end
  Group(("RAID BOSS! %s, %s, has appeared%s! %d HP. Every moo you type in %s chat hits it. 3 minutes. GO!")
    :format(def.name, def.title, starter and (" (summoned by " .. starter .. ")") or "", hp, self:ChatName()))
  self:AddGroupListener("boss", OnLine)
  -- other copies in the chat hold their moo-backs for the fight (everyone's mooing at the boss)
  if self.ShareQuiet then self:ShareQuiet(FIGHT_TIME + 10) end
  return true
end

function ns:BossTick()
  local boss = self.boss
  if not boss or boss.over then return end
  if self.db.panic then
    boss.over = true
    self.boss = nil
    self:RemoveGroupListener("boss")
    if self.ShareQuiet then self:ShareQuiet(0) end
    return
  end
  local now = ns.Now()
  if boss.hp <= 0 then return Finish(boss, true) end
  if now - boss.started >= FIGHT_TIME then return Finish(boss, false) end

  -- phase 2 at half health
  if boss.phase == 1 and boss.hp <= boss.maxHP / 2 then
    boss.phase = 2
    Group(("%s is ENRAGED! %s Mechanics come faster, and ALL-CAPS MOOs crit for double. MOOOO!"):format(boss.name, HPBar(boss)))
  end
  -- health updates at 75% and 25%
  for _, mark in ipairs({ 75, 25 }) do
    if not boss.said[mark] and boss.hp <= boss.maxHP * mark / 100 then
      boss.said[mark] = true
      Group(("%s %s"):format(boss.name, HPBar(boss)), 2)
    end
  end
  local left = FIGHT_TIME - (now - boss.started)
  if not boss.said.warn and left <= 30 then
    boss.said.warn = true
    Group(("30 SECONDS until %s enrages! %s MOO HARDER!"):format(boss.name, HPBar(boss)))
  end

  local m = boss.mech
  if m then
    -- a mechanic's window opens when its line actually went out
    if not m.open then
      local sent = ns.recentOutputs[m.line]
      if sent and sent >= m.queuedAt then
        m.open, m.openedAt = true, sent
      elseif now - m.queuedAt > 20 then
        boss.mech = nil -- the line never went out (muted, panic): skip it
      end
    elseif now - m.openedAt >= m.window then
      Resolve(boss)
      boss.nextMech = now + (boss.phase == 2 and random(12, 16) or random(18, 24))
    end
  elseif now >= boss.nextMech and left > 15 then
    Announce(boss, Pick(MECHANICS))
  end
end

table.insert(ns.tickFns, function() ns:BossTick() end)

-- friends start it by saying so in party (or guild) chat; it's on the Barn's Games tab too
table.insert(ns.GAME_LIST, { key = "boss", name = "Moo Raid Boss", icon = "INV_Misc_Head_Dragon_01",
  desc = "A co-op boss fight. Every moo hits it.", start = function() return ns:StartBoss() end, say = "raid boss" })
local HasAny = ns.TextHasAny
local insertAt = #ns.INTENTS + 1
for i, intent in ipairs(ns.INTENTS) do
  if intent.id == "ask" then insertAt = i break end
end
table.insert(ns.INTENTS, insertAt, { id = "boss", groupOnly = true,
  match = function(n) return HasAny(n, { "raid boss", "world boss", "boss fight", "summon boss", "summon the boss", "mad cow" }) end,
  run = function(name) local ok, why = ns:StartBoss(name) return not ok and why or nil end })
