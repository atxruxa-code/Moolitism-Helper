-- MooHelper: Yo Moo-ma jokes
-- Friends say "your mom", "yo mama" or "mom joke" in party or guild chat (or you type
-- /moo mom [name]) and the cow fires back. Cow-themed and friendly: roasts, not insults.

local _, ns = ...

local random = math.random

ns.MOM_JOKES = {
  "%s, yo moo-ma is so big, she has her own zip code in Mulgore.",
  "%s, yo moo-ma is so old, she mooed at the Titans.",
  "%s, yo moo-ma is so slow, the kodos lapped her twice.",
  "%s, yo moo-ma is so loud, Thunder Bluff filed a noise complaint.",
  "%s, yo moo-ma is so lazy, she gets her grass delivered.",
  "%s, yo moo-ma is so dramatic, she stands in the fire for attention.",
  "%s, yo moo-ma is so cheap, she rolls Need on grey items.",
  "%s, yo moo-ma is so lost, she took the Deeprun Tram to Mulgore.",
  "%s, yo moo-ma is so short, she grazes on moss.",
  "%s, yo moo-ma is so slow at loading, she still has the old character models.",
  "%s, yo moo-ma is so bad at raiding, she wiped on the training dummy.",
  "%s, yo moo-ma is so clumsy, she tipped herself over.",
  "%s, yo moo-ma is so hungry, she ate the whole Barrens. Now it's the Barrens-er.",
  "%s, yo moo-ma is so stubborn, her hearthstone gave up.",
  "%s, yo moo-ma is so wise, she knows where the Hogger spawns. Respect.",
  "%s, yo moo-ma is so sweet, she gives chocolate milk.",
  "%s, yo moo-ma is so AFK, the herd thought she was a statue.",
  "%s, yo moo-ma is so famous, every Tauren just says moo in her honour.",
}

function ns:MomJoke(target)
  target = target and target ~= "" and ns.Clean(target):sub(1, 24) or "Hey"
  ns:Bump("momJokes")
  return ns.MOM_JOKES[random(#ns.MOM_JOKES)]:format(target)
end

-- friends can ask for one; it runs once per chat even with several copies of the addon
local HasAny = ns.TextHasAny
local insertAt = #ns.INTENTS + 1
for i, intent in ipairs(ns.INTENTS) do
  if intent.id == "ask" then insertAt = i break end
end
table.insert(ns.INTENTS, insertAt, { id = "mom",
  match = function(n) return HasAny(n, { "your mom", "ur mom", "yo mama", "yo momma", "your mama", "mom joke", "yo moo ma", "your moo ma" }) end,
  run = function(name) return ns:MomJoke(name) end })
