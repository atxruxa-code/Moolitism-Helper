-- MooHelper: the Moo Market
-- Three stocks you trade with milk. Prices move every minute (a random walk that drifts
-- back toward a fair price) and react to what happens: a Moo-nsoon is great for hay,
-- a stampede is terrible for kodo logistics, a Golden Moo lifts milk futures.

local _, ns = ...

local random = math.random

ns.STOCKS = {
  { key = "MILK", name = "Milk Futures", base = 100, vol = 0.04, desc = "Steady. Like a cow." },
  { key = "HAY", name = "Hay Co.", base = 40, vol = 0.07, desc = "Weather-sensitive. Loves a Moo-nsoon." },
  { key = "KODO", name = "Kodo Logistics", base = 250, vol = 0.12, desc = "High risk. Stampedes happen." },
}
ns.STOCK_BY_KEY = {}
for _, s in ipairs(ns.STOCKS) do ns.STOCK_BY_KEY[s.key] = s end
local HISTORY = 60
local TICK = 60 -- seconds per price move

local function M() return ns.db.market end

function ns:MarketInit()
  self.db.market = self.db.market or { prices = {}, history = {}, shares = {}, cost = {}, realized = 0, trades = 0 }
  local m = M()
  for _, s in ipairs(ns.STOCKS) do
    m.prices[s.key] = m.prices[s.key] or s.base
    m.history[s.key] = m.history[s.key] or { m.prices[s.key] }
    m.shares[s.key] = m.shares[s.key] or 0
    m.cost[s.key] = m.cost[s.key] or 0
  end
  -- prices kept moving while you were away (up to 10 hours of minutes)
  if m.lastTick then
    local missed = math.min(math.floor((time() - m.lastTick) / TICK), 600)
    for _ = 1, missed do self:MarketStep() end
  end
  m.lastTick = time()
end

local function Gauss()
  local u1, u2 = math.max(random(), 1e-9), random()
  return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

local function SetPrice(key, price)
  local m = M()
  price = math.max(1, math.floor(price * 100 + 0.5) / 100)
  m.prices[key] = price
  local h = m.history[key]
  h[#h + 1] = price
  while #h > HISTORY do table.remove(h, 1) end
end

function ns:MarketStep()
  for _, s in ipairs(ns.STOCKS) do
    local p = M().prices[s.key]
    local drift = 0.03 * math.log(s.base / p) -- pulled back toward the fair price
    SetPrice(s.key, p * math.exp(drift + Gauss() * s.vol))
  end
end

-- news moves prices right away
function ns:MarketShock(key, factor, headline)
  if not M() then return end
  SetPrice(key, M().prices[key] * factor)
  if headline then self:Print("|cff80c0ffMoo Market:|r " .. headline) end
  if self.RefreshBarn then self:RefreshBarn() end
end

function ns:StockPrice(key) return M().prices[key] end

function ns:Portfolio()
  local value = 0
  for _, s in ipairs(ns.STOCKS) do value = value + M().shares[s.key] * M().prices[s.key] end
  return value
end

local function AfterTrade()
  local m = M()
  m.trades = m.trades + 1
  ns:Bump("trades")
  ns:StatMax("portfolioBest", math.floor(ns:Portfolio()))
  if m.realized > 0 then ns:StatMax("marketProfitBest", math.floor(m.realized)) end
  if ns.RefreshBarn then ns:RefreshBarn() end
end

-- qty: a number, or "max"
function ns:BuyStock(key, qty)
  local s = ns.STOCK_BY_KEY[key]
  if not s then return false, "No such stock. Try MILK, HAY or KODO." end
  local price = M().prices[key]
  if qty == "max" then qty = math.floor(self:Milk() / price) end
  qty = math.floor(tonumber(qty) or 0)
  if qty < 1 then return false, ("You can't afford a share of %s (%.2f milk)."):format(s.name, price) end
  local cost = math.ceil(price * qty)
  if not self:SpendMilk(cost) then return false, ("%d shares of %s cost %s milk."):format(qty, s.name, ns.FormatNumber(cost)) end
  M().shares[key] = M().shares[key] + qty
  M().cost[key] = M().cost[key] + cost
  AfterTrade()
  return true, ("Bought %d %s for %s milk."):format(qty, s.name, ns.FormatNumber(cost))
end

function ns:SellStock(key, qty)
  local s = ns.STOCK_BY_KEY[key]
  if not s then return false, "No such stock. Try MILK, HAY or KODO." end
  local m = M()
  local held = m.shares[key]
  if qty == "all" or qty == "max" then qty = held end
  qty = math.floor(tonumber(qty) or 0)
  if qty < 1 or held < 1 then return false, ("You don't own any %s."):format(s.name) end
  qty = math.min(qty, held)
  local proceeds = math.floor(m.prices[key] * qty)
  local basis = m.cost[key] * qty / held
  m.cost[key] = m.cost[key] - basis
  m.shares[key] = held - qty
  m.realized = m.realized + (proceeds - basis)
  -- milk from selling isn't "earned" milk: it skips AddMilk, so it doesn't count toward
  -- lifetime milk and isn't doubled by a Moo-nsoon
  self.db.farm.milk = self.db.farm.milk + proceeds
  AfterTrade()
  local pl = proceeds - basis
  return true, ("Sold %d %s for %s milk (%s%s on those shares)."):format(qty, s.name, ns.FormatNumber(proceeds),
    pl >= 0 and "+" or "-", ns.FormatNumber(math.abs(pl)))
end

-- a stock's unrealized profit or loss
function ns:StockPL(key)
  local m = M()
  return m.shares[key] * m.prices[key] - m.cost[key]
end

-- news from the barnyard
table.insert(ns.bumpListeners, function(key)
  if not M() then return end
  if key == "moonsoons" then ns:MarketShock("HAY", 1.15, "Moo-nsoon! Hay Co. shares jump 15%.") end
  if key == "stampedeHours" then ns:MarketShock("KODO", 0.8, "Stampede Hour! Kodo Logistics drops 20%.") end
  if key == "goldenMoos" then ns:MarketShock("MILK", 1.1, "A Golden Moo was spotted. Milk Futures up 10%.") end
end)

local acc = 0
table.insert(ns.tickFns, function()
  if not M() then return end
  acc = acc + 1
  if acc >= TICK then
    acc = 0
    ns:MarketStep()
    M().lastTick = time()
    if ns.RefreshBarn then ns:RefreshBarn() end
  end
end)

ns:On("PLAYER_LOGIN", function() ns:MarketInit() end)
