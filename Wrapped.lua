-- MooHelper: Moo Wrapped
-- Your whole moo history on one card: /moo wrapped (or the Barn's Wrapped tab), and
-- /moo wrapped post to show it off in party chat.

local _, ns = ...

local function Fmt(n) return ns.FormatNumber and ns.FormatNumber(n or 0) or tostring(n or 0) end

local GAME_NAMES = {}
local function GameName(key)
  if not next(GAME_NAMES) and ns.GAME_LIST then
    for _, g in ipairs(ns.GAME_LIST) do GAME_NAMES[g.key] = g.name end
  end
  return GAME_NAMES[key] or key
end

-- the numbers, as a table the Barn and the chat lines both use
function ns:WrappedData()
  local s = self.db.stats
  local d = { moos = s.total, combo = s.bestCombo, taurens = s.taurenCount, mooBacks = s.mooBacks }
  -- favourite channel
  local topKey, topN = nil, 0
  for key, n in pairs(s.byChannel) do
    if n > topN or (n == topN and topKey and key < topKey) then topKey, topN = key, n end
  end
  d.channel, d.channelMoos = topKey and self:ChannelLabel(topKey) or "none yet", topN
  d.channelPct = s.total > 0 and math.floor(topN / s.total * 100 + 0.5) or 0
  -- games
  local hosted, favKey, favN = 0, nil, 0
  for key, n in pairs(s.c) do
    if key:sub(1, 7) == "played:" then
      hosted = hosted + n
      local g = key:sub(8)
      if n > favN or (n == favN and favKey and g < favKey) then favKey, favN = g, n end
    end
  end
  d.games, d.favGame, d.favGameN = hosted, favKey and GameName(favKey) or "none yet", favN
  -- your herd's most devoted member
  local top = self.HerdTop and self:HerdTop(1) or {}
  d.bestFriend = top[1] and top[1].name or nil
  d.milk = self.db.farm and self.db.farm.lifetime or 0
  d.bingos = self:GetStat("bingos")
  d.bossKills = self:GetStat("bossKills")
  d.bossFastest = self:GetStat("bossFastest")
  d.duels = self.db.duels or { fought = 0, won = 0 }
  d.peers = self:GetStat("peersMet")
  d.passTier = self.db.pass and self.db.pass.tier or 0
  d.season = self:PassSeasonName()
  if self.Ach and self.Ach.char then
    d.achDone, d.achTotal, d.achPoints = self.Ach:GetSummary()
  else
    d.achDone, d.achTotal, d.achPoints = 0, 0, 0
  end
  d.cow = self.db.bessie and self.db.bessie.name or "Bessie"
  d.cowStage = self.BessieStageName and self:BessieStageName() or ""
  -- a verdict, from the biggest number
  if s.total >= 10000 then d.verdict = "a LEGEND of the herd. Seek help. Moo."
  elseif hosted >= 50 then d.verdict = "the party's game show host. Nobody asked. Everybody played."
  elseif d.bossKills >= 10 then d.verdict = "a raid-boss slayer of the highest moo."
  elseif s.taurenCount >= 100 then d.verdict = "a dedicated Tauren watcher. They know."
  elseif s.total >= 1000 then d.verdict = "a seasoned mooer. The herd respects you."
  else d.verdict = "just getting started. The herd believes in you. Moo." end
  return d
end

-- three chat lines, each well under 255 characters
function ns:WrappedLines()
  local d = self:WrappedData()
  local me = UnitName("player") or "Me"
  local title = self.db.title and (" " .. self.db.title) or ""
  local lines = {
    ("MOO WRAPPED for %s%s: %s moos (%d%% in %s), best combo %d, %s Taurens spotted, %s moo-backs."):format(
      me, title, Fmt(d.moos), d.channelPct, d.channel, d.combo, Fmt(d.taurens), Fmt(d.mooBacks)),
    ("Games hosted: %d (favourite: %s). Bingos: %d. Raid bosses slain: %d. Cow Duels: %d won of %d. Milk made: %s."):format(
      d.games, d.favGame, d.bingos, d.bossKills, d.duels.won, d.duels.fought, Fmt(d.milk)),
    ("Moo-chievements: %d of %d. Moo Pass tier %d. %s the %s says hi. Verdict: %s"):format(
      d.achDone, d.achTotal, d.passTier, d.cow, d.cowStage, d.verdict),
  }
  for i, l in ipairs(lines) do lines[i] = ns.Fit(l) end
  return lines
end

function ns:PostWrapped()
  local ch = self:GroupChannel()
  if not ch then return false, "Join a group to show off your Moo Wrapped." end
  local sent = 0
  for i, line in ipairs(self:WrappedLines()) do
    if i == 1 then
      if self:SendNow(ch, line) then sent = sent + 1 end
    elseif self:Queue(ch, line, 3, 30) then
      sent = sent + 1
    end
  end
  if sent == 0 then return false, self:ChannelLabel(ch) .. " is HARD MUTED." end
  self:Bump("wrappedPosts")
  return true
end
