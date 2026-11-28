-- MooHelper: moo world events, Moo FM and Moo-roscopes
--
--   Moo-nsoon      every so often, 5 minutes of double milk, announced to the party
--   Stampede Hour  5 minutes of kodos thundering across your screen
--   Golden Moo     a golden kodo floats across your screen; click it for a pile of milk
--   Moo FM         a radio DJ segment in group chat every ~15 minutes
--   Moo-roscope    a daily horoscope for anyone who asks, from the Moo-diac

local _, ns = ...

local random = math.random
local function Pick(list) return list[random(#list)] end

local function Group(text, priority)
  local ch = ns:GroupChannel()
  if ch then ns:Queue(ch, text, priority or 1) end
end
local function Allowed(trigger)
  return ns.db.triggers[trigger] and not ns.db.panic and not (ns.InMercy and ns:InMercy())
end

---------------------------------------------------------------------------
-- Moo-nsoon and Stampede Hour
---------------------------------------------------------------------------

local EVENT_EVERY = 600 -- seconds between chances for a world event
local nextRoll, monsoonEnds, stampedeEnds, nextStampedeBurst

function ns:StartMoonsoon()
  ns.inMoonsoon = true
  monsoonEnds = ns.Now() + 300
  self:Bump("moonsoons")
  if self.Toast then self:Toast("WEATHER ALERT", "MOO-NSOON: double milk for 5 minutes") end
  if self.MooVision then self:MooVision() end
  if Allowed("events") then
    Group("WEATHER ALERT: A Moo-nsoon is rolling in. All moos count double for 5 minutes. MOOOOO!", 2)
  end
end

function ns:StartStampedeHour()
  stampedeEnds = ns.Now() + 300
  nextStampedeBurst = ns.Now()
  self:Bump("stampedeHours")
  if self.Toast then self:Toast("STAMPEDE HOUR", "Kodos incoming. Hold onto something.") end
  if Allowed("events") then Group("STAMPEDE HOUR HAS BEGUN. Kodos everywhere. This is not a drill. MOO!", 2) end
end

local function EventTick()
  local now = ns.Now()
  if ns.inMoonsoon and now >= monsoonEnds then
    ns.inMoonsoon = false
    if Allowed("events") then Group("The Moo-nsoon has passed. Moos are back to normal value. Moo.") end
  end
  if stampedeEnds then
    if now >= stampedeEnds then
      stampedeEnds = nil
    elseif now >= nextStampedeBurst then
      nextStampedeBurst = now + 30
      if ns.Stampede then ns:Stampede(14) end
    end
  end
  if not ns.db.triggers.events then return end
  if not nextRoll then nextRoll = now + EVENT_EVERY return end
  if now < nextRoll then return end
  nextRoll = now + EVENT_EVERY
  local r = random()
  if r < 0.15 and not ns.inMoonsoon then ns:StartMoonsoon()
  elseif r < 0.25 and not stampedeEnds then ns:StartStampedeHour() end
end

---------------------------------------------------------------------------
-- Golden Moo
---------------------------------------------------------------------------

local golden
local function CreateGolden()
  golden = CreateFrame("Button", "MooHelperGoldenMoo", UIParent)
  golden:SetSize(56, 56)
  golden:SetFrameStrata("FULLSCREEN_DIALOG")
  golden.tex = golden:CreateTexture(nil, "ARTWORK")
  golden.tex:SetAllPoints()
  golden.tex:SetTexture("Interface\\Icons\\Ability_Mount_Kodo_01")
  golden.tex:SetVertexColor(1, 0.85, 0.15)
  golden.glow = golden:CreateTexture(nil, "BACKGROUND")
  golden.glow:SetPoint("CENTER")
  golden.glow:SetSize(84, 84)
  golden.glow:SetColorTexture(1, 0.8, 0.1, 0.35)
  golden:Hide()
  golden:SetScript("OnClick", function() ns:CatchGoldenMoo() end)
  golden:SetScript("OnUpdate", ns.Safe("Events.lua OnUpdate line 90", function(self, elapsed)
    self.t = self.t + elapsed
    if self.t > 9 then self:Hide() return end
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    local x = self.x0 + self.vx * self.t
    local y = self.y0 + math.sin(self.t * 2.4) * 60
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    if x < -60 or x > w + 60 or y < 0 or y > h then self:Hide() end
  end))
end

function ns:SpawnGoldenMoo()
  if not golden then return false end
  local w, h = UIParent:GetWidth(), UIParent:GetHeight()
  golden.t = 0
  golden.x0 = -40
  golden.vx = w / 8
  golden.y0 = h * (0.3 + random() * 0.4)
  golden:Show()
  return true
end

function ns:CatchGoldenMoo()
  if not golden or not golden:IsShown() then return false end
  golden:Hide()
  local prize = math.floor(100 + self:MilkPerSecond() * 120)
  self:AddMilk(prize)
  self:Bump("goldenMoos")
  self:Print(("You caught a GOLDEN MOO! +%s milk."):format(ns.FormatNumber(prize)))
  if self.Toast then self:Toast("GOLDEN MOO!", "+" .. ns.FormatNumber(prize) .. " milk") end
  if self.CowRain then self:CowRain(30) end
  if Allowed("events") then Group("I just caught a GOLDEN MOO. Witness my fortune. MOOOOOOOOO!", 2) end
  return true
end

local goldenAcc = 0
local function GoldenTick()
  if not ns.db.triggers.goldenMoo or (golden and golden:IsShown()) then return end
  goldenAcc = goldenAcc + 1
  if goldenAcc < 60 then return end
  goldenAcc = 0
  local odds = ns:HasUpgrade("bell") and 22 or 45
  if random(odds) == 1 then ns:SpawnGoldenMoo() end
end

---------------------------------------------------------------------------
-- Moo FM
---------------------------------------------------------------------------

local INTROS = {
  "You're listening to MOO FM, 101.moo, all moo all the time.",
  "MOO FM. The station your mother warned you about. Moo.",
  "Good evening, herd. This is MOO FM, broadcasting live from the barn.",
}
local function Segment()
  local kinds = {
    function()
      return Pick({ "Traffic: heavy stampede traffic near Thunder Bluff. Expect moos.",
        "Traffic: a kodo has jackknifed on the road to Camp Narache. Moo-ve carefully.",
        "Traffic: all lanes clear. Suspiciously clear. Moo." })
    end,
    function()
      if ns.inMoonsoon then return "Weather: Moo-nsoon in progress. Double moos. Stay inside." end
      return Pick({ "Weather: sunny with a 90% chance of moo.", "Weather: overcast, light moo-zzle by evening.",
        "Weather: high winds from Mulgore. Hold onto your hay." })
    end,
    function()
      local top = ns.HerdTop and ns:HerdTop(1)[1]
      if top then return ("Herd report: %s leads the herd with %d herd points. Moo."):format(top.name, top.points) end
      return "Herd report: the herd is quiet tonight. Too quiet. Moo."
    end,
    function()
      local worst, count
      for name, c in pairs(ns.db.stats.shame) do if not count or c > count then worst, count = name, c end end
      if worst then return ("Fire safety: %s has stood in bad things %d times. Be like not-%s. Moo."):format(worst, count, worst) end
      return "Fire safety: nobody has stood in fire yet. Keep it that way."
    end,
    function()
      local members = ns.GroupMembers and ns.GroupMembers() or {}
      if #members > 0 then return ("This next moo goes out to %s. MOOOOO. You're welcome."):format(Pick(members)) end
      return "This next moo goes out to everyone listening. MOOOOO."
    end,
    function()
      local g = Pick(ns.GENERATORS)
      return ("This segment is brought to you by %s. %s"):format(g.name, g.desc)
    end,
  }
  return Pick(kinds)()
end

function ns:MooFM()
  local ch = self:GroupChannel()
  if not ch then return false, "Moo FM needs listeners (a group)." end
  self:Queue(ch, Pick(INTROS), 2)
  self:Queue(ch, Segment(), 2)
  self:Bump("fmSegments")
  return true
end

local nextFM
local function FMTick()
  if not Allowed("mooFM") or not ns:GroupChannel() or InCombatLockdown() then return end
  local now = ns.Now()
  if not nextFM then nextFM = now + 600 + random(0, 600) return end
  if now >= nextFM then
    nextFM = now + 720 + random(0, 480)
    ns:MooFM()
  end
end

---------------------------------------------------------------------------
-- Moo-roscopes
---------------------------------------------------------------------------

ns.MOODIAC = { "The Calf", "The Kodo", "The Plainstrider", "The Windmill", "The Hay Bale", "The Milk Pail",
  "The Totem", "The Bell", "The Barn Door", "The Thunder Bluff", "The Stampede", "The Earth Mother" }
local READINGS = {
  "A stranger will moo at you. Moo back.", "Avoid standing in anything glowing today.",
  "Your loot rolls will be humbling. Accept this.", "Someone in your party is secretly a cow.",
  "Today is a good day to pull. Ask the tank first.", "The grass is greener. Go and eat it.",
  "You will find something shiny. It will be grey quality.", "A great moo is building inside you.",
  "Beware of falling. Especially off of things.", "Your hearthstone will betray you. Walk.",
  "Love is in the air. So is hay. Mostly hay.", "Do not trust the floor today.",
  "Your next death will be dramatic. Make it count.", "The herd believes in you. Mostly.",
}
local function Hash(s)
  local h = 5381
  for i = 1, #s do h = (h * 33 + s:byte(i)) % 2147483647 end
  return h
end

function ns:Horoscope(name)
  name = ns.ShortName(name or UnitName("player") or "you")
  local sign = ns.MOODIAC[Hash(name:lower()) % #ns.MOODIAC + 1]
  local seed = Hash(name:lower() .. date("%Y-%m-%d"))
  local reading = READINGS[seed % #READINGS + 1]
  local lucky = (seed % 99) + 1
  if name == UnitName("player") and self.char.lastHoroscope ~= date("%Y-%m-%d") then
    self.char.lastHoroscope = date("%Y-%m-%d")
    self:Bump("horoscopes")
  end
  return ("Moo-roscope for %s (%s): %s Lucky number: %d. Moo."):format(name, sign, reading, lucky)
end

ns:On("PLAYER_LOGIN", function() CreateGolden() end)
table.insert(ns.tickFns, EventTick)
table.insert(ns.tickFns, GoldenTick)
table.insert(ns.tickFns, FMTick)
