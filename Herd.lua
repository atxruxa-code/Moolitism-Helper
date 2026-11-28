-- MooHelper: The Herd
-- Friends join your herd just by playing along in chat: mooing back, answering interviews,
-- winning games. They earn Herd Points and get promoted, in party chat, for everyone to see.

local _, ns = ...

local Usable = ns.Usable

ns.HERD_RANKS = {
  { 0, "Stray" }, { 10, "Herd Member" }, { 30, "Grazer" }, { 75, "Herd Lieutenant" },
  { 150, "Herd Captain" }, { 300, "Bovine Commander" }, { 600, "Moo Legend" },
}

local function RankFor(points)
  local idx = 1
  for i, r in ipairs(ns.HERD_RANKS) do if points >= r[1] then idx = i end end
  return idx
end
ns.HerdRankFor = RankFor

function ns:HerdMember(name)
  if not self.db or type(name) ~= "string" or name == "" then return nil end
  name = ns.ShortName(name)
  local herd = self.db.herd
  local m = herd[name]
  if not m then
    m = { points = 0, rank = 1, mooBacks = 0, answers = 0, wins = 0, joined = time() }
    herd[name] = m
    if self.Ach and self.Ach.char then
      local n = 0
      for _ in pairs(herd) do n = n + 1 end
      self.Ach:SetMax("playersSeen", n)
    end
  end
  m.last = time()
  return m, name
end

-- reason is a short stat name: "mooBacks", "answers", "wins" (or nil)
function ns:HerdAward(name, points, reason)
  if not self.db or name == UnitName("player") then return end
  local m, short = self:HerdMember(name)
  if not m then return end
  m.points = m.points + (points or 1)
  if reason then m[reason] = (m[reason] or 0) + 1 end
  local idx = RankFor(m.points)
  if idx > m.rank then
    m.rank = idx
    local rank = ns.HERD_RANKS[idx]
    self:Bump("promotions")
    if idx == #ns.HERD_RANKS then self:Bump("herdLegend") end
    if self.db.triggers.herdPromotions and not self.db.panic then
      local ch = self:GroupChannel()
      if ch then
        self:Queue(ch, ("HERD PROMOTION: %s is now a %s (%d herd points). The herd salutes you. MOO!")
          :format(short, rank[2], m.points), 2)
      end
    end
    if self.Toast then self:Toast("HERD PROMOTION", short .. ": " .. rank[2]) end
  end
  self:StatChanged()
end

function ns:HerdRankName(name)
  local m = self.db.herd[ns.ShortName(name or "")]
  if not m then return "Stray", 0 end
  return ns.HERD_RANKS[RankFor(m.points)][2], m.points
end

function ns:HerdTop(n)
  local list = {}
  for name, m in pairs(self.db.herd) do list[#list + 1] = { name = name, points = m.points } end
  table.sort(list, function(a, b) return a.points > b.points or (a.points == b.points and a.name < b.name) end)
  local out = {}
  for i = 1, math.min(n or #list, #list) do out[i] = list[i] end
  return out
end

ns:On("PLAYER_LOGIN", function()
  ns.db.herd = ns.db.herd or {}
end)

-- Anyone who moos in group chat is part of the herd (and earns a point, at most once a minute)
local lastMooPoint = {}
for _, event in ipairs({ "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_GUILD" }) do
  ns:On(event, function(msg, sender)
    if not Usable(msg) or not Usable(sender) or type(msg) ~= "string" then return end
    if ns:IsOwnOutput(msg, sender) or not ns.SaysMoo(msg) then return end
    local name = ns.ShortName(sender)
    if name == UnitName("player") then return end
    ns:GateChat(sender, msg, function()
      local now = ns.Now()
      if now - (lastMooPoint[name] or -1000) < 60 then return end
      lastMooPoint[name] = now
      ns:HerdAward(name, 1, "mooBacks")
    end)
  end)
end
