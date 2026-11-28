-- MooHelper: Moo GTFO
-- A "get out of the bad stuff" alarm, moo style. Forever blocks the combat log, so this can't
-- see which spell hit you; it watches your own health instead:
--   * a big hit: you lose a chunk of your health (15% by default) within a second in combat
--   * a meltdown: you lose 40% within 3 seconds
--   * low health: you drop under 25% in combat (once per fight)
-- The alarm plays the raid-warning sound, flashes MOO-VE! on your screen and (optionally,
-- rate-limited) moos about it in party chat.
-- If the real GTFO addon is installed, its alarms set off the moo too.

local _, ns = ...

local Usable = ns.Usable
local random = math.random
local function Pick(list) return list[random(#list)] end

local ALARM_GAP = 2          -- seconds between alarms
local CALLOUT_GAP = 20       -- seconds between party callouts
local MELTDOWN_WINDOW, MELTDOWN_PCT = 3, 40
local LOW_PCT = 25

local samples = {}           -- { t, pct } over the last few seconds
local lastAlarm, lastCallout = -1000, -1000
local lowWarned = false

local function G() return ns.db.gtfo end

local CALLOUTS = {
  big = { "MOO! Something just hit me HARD. Moo-ving!", "OW. MOO. Whatever that was, I'm moo-ving out of it.",
    "MOO-VE! (that one hurt)" },
  meltdown = { "MOOOOO! I'm melting! HEALS! Moo!", "I am standing in something VERY bad. MOOOOVING!",
    "MAYDAY MOO-DAY! I'm going down fast!" },
  low = { "Low health! Moo... moo... (please heal the cow)", "I'm at %d%% health. Send milk. And heals. Moo." },
  gtfo = { "GTFO says I'm standing in something. Moo-ving!", "The floor is lava and I am a cow. MOO-VE!" },
}
ns.GTFO_CALLOUTS = CALLOUTS

---------------------------------------------------------------------------
-- The alarm
---------------------------------------------------------------------------

local flash
local function Flash(text)
  if not G().flash or not UIParent then return end
  if not flash then
    flash = CreateFrame("Frame", "MooHelperGTFOFlash", UIParent)
    flash:SetAllPoints(UIParent)
    flash:SetFrameStrata("FULLSCREEN_DIALOG")
    flash.bg = flash:CreateTexture(nil, "BACKGROUND")
    flash.bg:SetAllPoints()
    flash.bg:SetColorTexture(1, 0.1, 0.05, 0.25)
    flash.text = flash:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    flash.text:SetPoint("CENTER", 0, 120)
    flash.text:SetTextColor(1, 0.25, 0.15)
    flash:EnableMouse(false)
    flash:SetScript("OnUpdate", ns.Safe("GTFO.lua OnUpdate line 56", function(self, elapsed)
      self.left = (self.left or 0) - elapsed
      local a = math.max(0, self.left / 1.2)
      self:SetAlpha(a)
      if self.left <= 0 then self:Hide() end
    end))
  end
  flash.text:SetText(text)
  flash.left = 1.2
  flash:SetAlpha(1)
  flash:Show()
end

local function Sound()
  if not G().sound or not PlaySound then return end
  local id = (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959
  pcall(PlaySound, id, "Master")
end

-- kind: "big", "meltdown", "low", "gtfo" (the real GTFO addon) or "test"
function ns:GTFOAlarm(kind, pct)
  local g = G()
  if not g.enabled then return false end
  local now = ns.Now()
  if kind ~= "test" and now - lastAlarm < ALARM_GAP then return false end
  lastAlarm = now
  if kind ~= "gtfo" then Sound() end -- GTFO already played its own
  Flash(kind == "low" and "LOW HEALTH. MOO!" or "MOO-VE!")
  if kind == "test" then return true end
  self:Bump("gtfoAlarms")
  self:Signal("shamed", UnitName("player") or "you") -- your own Bingo "stands in fire" square
  -- the party hears about it (not too often)
  local ch = self:GroupChannel()
  if ch and self.db.triggers.gtfoCallout and not self.db.panic and not self:InMercy() and now - lastCallout >= CALLOUT_GAP then
    lastCallout = now
    local line = Pick(CALLOUTS[kind] or CALLOUTS.big)
    if line:find("%%d") then line = line:format(math.floor(pct or LOW_PCT)) end
    self:Queue(ch, line, 2, 10)
  end
  return true
end

---------------------------------------------------------------------------
-- Watching your health
---------------------------------------------------------------------------

local function InCombat()
  if UnitAffectingCombat then
    local ok, v = pcall(UnitAffectingCombat, "player")
    if ok and Usable(v) then return v and true or false end
  end
  return InCombatLockdown and InCombatLockdown() or false
end

-- health as a percentage, or nil if the game hides it
local function HealthPct()
  if not UnitHealth or not UnitHealthMax then return nil end
  local okH, hp = pcall(UnitHealth, "player")
  local okM, max = pcall(UnitHealthMax, "player")
  if not okH or not okM or not Usable(hp) or not Usable(max) then return nil end
  if type(hp) ~= "number" or type(max) ~= "number" or max <= 0 then return nil end
  return hp / max * 100
end

function ns:GTFOCheck()
  local g = G()
  if not g or not g.enabled then return end
  local pct = HealthPct()
  if not pct then return end
  local now = ns.Now()
  samples[#samples + 1] = { t = now, pct = pct }
  while samples[1] and now - samples[1].t > MELTDOWN_WINDOW do table.remove(samples, 1) end
  if not InCombat() then
    lowWarned = false
    return
  end
  local maxRecent1, maxRecent3 = pct, pct
  for _, s in ipairs(samples) do
    if now - s.t <= 1 and s.pct > maxRecent1 then maxRecent1 = s.pct end
    if s.pct > maxRecent3 then maxRecent3 = s.pct end
  end
  if maxRecent3 - pct >= MELTDOWN_PCT then
    wipe(samples)
    samples[1] = { t = now, pct = pct }
    self:GTFOAlarm("meltdown", pct)
  elseif maxRecent1 - pct >= g.threshold then
    self:GTFOAlarm("big", pct)
  elseif pct > 0 and pct < LOW_PCT and not lowWarned then
    lowWarned = true
    self:GTFOAlarm("low", pct)
  end
end

ns:On("UNIT_HEALTH", function(unit) if unit == "player" then ns:GTFOCheck() end end)
ns:On("PLAYER_REGEN_ENABLED", function() wipe(samples) lowWarned = false end)

---------------------------------------------------------------------------
-- The real GTFO addon
---------------------------------------------------------------------------
-- If GTFO is installed and has its sound function, every GTFO alarm also moos. (Hooked
-- defensively: if GTFO's code looks different, nothing happens.)

local hookedGTFO = false
function ns:HookRealGTFO()
  if hookedGTFO or not hooksecurefunc then return hookedGTFO end
  if type(_G.GTFO_PlaySound) == "function" then
    hooksecurefunc("GTFO_PlaySound", function() ns:GTFOAlarm("gtfo") end)
    hookedGTFO = true
  end
  return hookedGTFO
end
function ns:RealGTFOHooked() return hookedGTFO end

ns:On("PLAYER_LOGIN", function() ns:HookRealGTFO() end)
ns:On("ADDON_LOADED", function() ns:HookRealGTFO() end)
