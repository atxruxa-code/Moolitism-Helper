-- MooHelper: the Moo Pass
-- A season track: 50 tiers, a new season every month. Everything you already do earns pass
-- XP (moos, games, bingo, raid bosses, duels, trades, Bessie, quests, achievements). Every tier
-- pays milk; every fifth tier unlocks a title; tier 50 is Season Champion.

local _, ns = ...

ns.PASS_TIERS = 50
ns.PASS_XP_PER_TIER = 200

ns.PASS_TITLES = {
  [5] = "the Calf", [10] = "Moo-vice", [15] = "Grass Enthusiast", [20] = "the Udderly Dedicated",
  [25] = "Keeper of the Cowbell", [30] = "Moo-ster of Ceremonies", [35] = "the Bovine Brain",
  [40] = "Herd Commander", [45] = "Moo-gnificent", [50] = "Season Champion",
}

local SEASON_NAMES = {
  "Season of the Stampede", "Season of the Golden Moo", "Season of Endless Grass", "Season of the Kodo",
  "Season of Thunder Bluff", "Season of the Moo-nsoon", "Season of the Cowbell", "Season of the Mad Cow",
  "Season of the Long Cud", "Season of the Barn Dance", "Season of the Milk Moon", "Season of the Great Herd",
}

-- what earns XP, and how much (moos and trades have a daily cap so pastes can't max the pass)
local XP_FOR = {
  bingos = 50, bingoBlackouts = 200, bossKills = 100, bossTopDamage = 50, bossFlawless = 75,
  cowDuels = 30, cowDuelWins = 30, bessieFeeds = 10, bessiePets = 2, bessieBrushes = 5, bessieShows = 10,
  interviewsAnswered = 10, meterPosts = 10, goldenMoos = 40, questsDone = 75, quickdrawWins = 20,
  moonsoons = 25, stampedeHours = 25, peersMet = 50, promotions = 20, cipherEncoded = 5, trades = 5,
}
local DAILY_CAP = { moo = 300, trades = 100 }
local GAME_XP = 25
local ACH_XP = 20

local function SeasonKey() return date("%Y-%m") end

function ns:PassSeasonName(key)
  local y, m = (key or SeasonKey()):match("(%d+)%-(%d+)")
  local n = ((tonumber(y) or 2026) * 12 + (tonumber(m) or 1)) % #SEASON_NAMES + 1
  return SEASON_NAMES[n]
end

local function P() return ns.db and ns.db.pass end

function ns:PassInit()
  local p = self.db.pass or {}
  self.db.pass = p
  p.titles = p.titles or {}
  local season = SeasonKey()
  if p.season ~= season then
    if p.season and (p.tier or 0) > 0 then
      self:Print(("The Moo Pass season ended at tier %d. A new season begins: %s."):format(p.tier, self:PassSeasonName(season)))
    end
    p.season, p.xp, p.tier, p.claimed = season, 0, 0, {}
    p.day, p.dayXP = nil, {}
  end
  p.xp, p.tier, p.claimed, p.dayXP = p.xp or 0, p.tier or 0, p.claimed or {}, p.dayXP or {}
end

local function Reward(tier)
  return 100 * tier
end
ns.PassReward = Reward

local function ClaimUpTo(p, tier)
  for t = 1, tier do
    if not p.claimed[t] then
      p.claimed[t] = true
      ns:AddMilk(Reward(t))
      local title = ns.PASS_TITLES[t]
      if title then
        p.titles[title] = true
        ns:Print(("Moo Pass tier %d: new title |cffffd100%s|r (/moo title to wear it)."):format(t, title))
      end
      if t == ns.PASS_TIERS then
        ns:Bump("passComplete")
        if ns.Stampede then ns:Stampede(40) end
      end
    end
  end
end

-- add pass XP; source is a daily-capped bucket ("moo", "trades") or nil
function ns:PassXP(amount, source)
  local p = P()
  if not p or not p.season or amount <= 0 then return 0 end
  if p.season ~= SeasonKey() then self:PassInit() end
  if source and DAILY_CAP[source] then
    local today = date("%Y-%m-%d")
    if p.day ~= today then p.day, p.dayXP = today, {} end
    local used = p.dayXP[source] or 0
    amount = math.min(amount, DAILY_CAP[source] - used)
    if amount <= 0 then return 0 end
    p.dayXP[source] = used + amount
  end
  p.xp = p.xp + amount
  local tier = math.min(ns.PASS_TIERS, math.floor(p.xp / ns.PASS_XP_PER_TIER))
  if tier > p.tier then
    local from = p.tier
    p.tier = tier
    ClaimUpTo(p, tier)
    self:StatMax("passBestTier", tier)
    if self.Toast then
      self:Toast("MOO PASS TIER " .. tier, tier - from > 1 and ("+" .. (tier - from) .. " tiers") or ("+" .. ns.FormatNumber(Reward(tier)) .. " milk"))
    end
  end
  if self.RefreshBarn then self:RefreshBarn() end
  return amount
end

-- progress inside the current tier: xp, needed
function ns:PassProgress()
  local p = P()
  if not p then return 0, ns.PASS_XP_PER_TIER end
  if p.tier >= ns.PASS_TIERS then return ns.PASS_XP_PER_TIER, ns.PASS_XP_PER_TIER end
  return p.xp - p.tier * ns.PASS_XP_PER_TIER, ns.PASS_XP_PER_TIER
end

function ns:PassDaysLeft()
  local now = date("*t")
  local nextMonth = time({ year = now.month == 12 and now.year + 1 or now.year, month = now.month % 12 + 1, day = 1, hour = 0 })
  return math.max(0, math.ceil((nextMonth - time()) / 86400))
end

-- titles: earned for good, worn one at a time
function ns:Title() return self.db.title end
function ns:SetTitle(title)
  local p = P()
  if title == nil or title == "" or title == "none" then self.db.title = nil return true, "Title removed." end
  for t in pairs(p.titles) do
    if t:lower() == title:lower() then
      self.db.title = t
      if self.RefreshBarn then self:RefreshBarn() end
      return true, ("You are now %s %s."):format(UnitName("player") or "you", t)
    end
  end
  return false, "You haven't earned that title. Climb the Moo Pass."
end
function ns:TitleList()
  local list = {}
  for t in pairs(P().titles) do list[#list + 1] = t end
  table.sort(list)
  return list
end

---------------------------------------------------------------------------
-- Earning XP
---------------------------------------------------------------------------

table.insert(ns.mooListeners, function() ns:PassXP(1, "moo") end)
table.insert(ns.bumpListeners, function(key, n)
  if key == "passComplete" then return end
  if key:sub(1, 7) == "played:" then ns:PassXP(GAME_XP) return end
  local xp = XP_FOR[key]
  if xp then ns:PassXP(xp * (n or 1), key == "trades" and "trades" or nil) end
end)
table.insert(ns.achListeners, function() ns:PassXP(ACH_XP) end)

ns:On("PLAYER_LOGIN", function() ns:PassInit() end)
