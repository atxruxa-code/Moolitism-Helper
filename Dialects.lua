-- MooHelper: moo dialects and the Moo Cipher
--
-- Dialects turn any sentence into a flavour of moo, keeping links and raid markers intact.
-- The Moo Cipher hides a short secret message inside an innocent-looking line of moos;
-- MooHelper decodes it on your screen (and on any friend's screen who also has MooHelper).

local _, ns = ...

local random = math.random

-- Shared machinery: protect links/textures/markers, transform each word, restore.
local function Transform(text, wordFn)
  if type(text) ~= "string" then return text end
  local saved = {}
  local function protect(chunk)
    saved[#saved + 1] = chunk
    return "\001" .. #saved .. "\002"
  end
  text = text:gsub("|c[^|]*|H.-|h.-|h|r", protect)
  text = text:gsub("|H.-|h.-|h", protect)
  text = text:gsub("|T.-|t", protect)
  text = text:gsub("|A.-|a", protect)
  local index = 0
  text = text:gsub("%S+", function(word)
    if word:find("[\001\002{]") then return word end
    local pre, core, post = word:match("^([^%w\128-\255]*)(.-)([^%w\128-\255]*)$")
    if not core or core == "" or not core:find("[%a\128-\255]") then return word end
    index = index + 1
    local n = #(core:gsub("[\128-\191]", ""))
    local upper = n > 1 and core:find("[A-Z]") and not core:find("[a-z]")
    local cap = core:sub(1, 1):find("[A-Z]") ~= nil
    return pre .. wordFn(n, upper, cap, index) .. post
  end)
  return (text:gsub("\001(%d+)\002", function(i) return saved[tonumber(i)] end))
end

local function Case(word, upper, cap)
  if upper then return word:upper() end
  if cap then return word:sub(1, 1):upper() .. word:sub(2) end
  return word
end

ns.DIALECTS = {
  { key = "classic", name = "Classic Moo", sample = "Moooo, mooooo!",
    word = function(n, up, cap) return Case(n <= 1 and "m" or ("m" .. string.rep("o", n - 1)), up, cap) end },
  { key = "ancient", name = "Ancient Bovine", sample = "Muur'ka muuuur",
    word = function(n, up, cap, i)
      local w = n <= 2 and "mu" or ("m" .. string.rep("u", n - 2) .. "r")
      if i % 3 == 0 then w = w .. "'ka" end
      return Case(w, up, cap)
    end },
  { key = "calf", name = "Calf Speak", sample = "mew moo-moo mew",
    word = function(n, up, cap) return Case(n <= 3 and "mew" or "moo-moo", up, cap) end },
  { key = "opera", name = "Moo Opera", sample = "MOOOO-OOO-OOOO!",
    word = function(n) return "MOO" .. string.rep("O", math.min(n, 6)) .. "-OO" .. string.rep("O", n % 3) end },
  { key = "whisper", name = "Whispered Moo", sample = "m o o . . .",
    word = function(n) return n <= 3 and "moo..." or "m o o..." end },
  { key = "pirate", name = "Pirate Moo", sample = "Arr moo, MOO-ARR!",
    word = function(n, up, cap, i)
      local w = (i % 4 == 0) and "moo-arr" or (n > 5 and "mooarr" or "moo")
      return Case(w, up, cap)
    end },
  { key = "bard", name = "Olde Bovine", sample = "Mooeth thou moo",
    word = function(n, up, cap, i)
      local w = n > 5 and "mooeth" or (i % 5 == 0 and "thou" or "moo")
      return Case(w, up, cap)
    end },
}
ns.DIALECT_BY_KEY = {}
for _, d in ipairs(ns.DIALECTS) do ns.DIALECT_BY_KEY[d.key] = d end

function ns.DialectTranslate(key, text)
  local d = ns.DIALECT_BY_KEY[key] or ns.DIALECT_BY_KEY.classic
  local out = Transform(text, d.word)
  if key == "opera" then out = out .. " ~" end
  if key == "pirate" and random() < 0.5 then out = out .. " ARR." end
  return out
end

-- Translate and count it (for achievements and quests)
function ns:Speak(key, text)
  local out = ns.DialectTranslate(key, text)
  self:Bump("dialect:" .. (ns.DIALECT_BY_KEY[key] and key or "classic"))
  return out
end

---------------------------------------------------------------------------
-- The Moo Cipher
---------------------------------------------------------------------------
-- Each character becomes three moos. The four spellings of "moo" carry two bits each,
-- so 3 moos = 6 bits = one of 64 characters. The line starts with "MOO-CIPHER:" so
-- MooHelper knows to decode it.

-- exactly 64 characters (26 + 10 + 7 + 21); capitals past U are sent as lowercase
local ALPHABET = "abcdefghijklmnopqrstuvwxyz0123456789 .,!?'-ABCDEFGHIJKLMNOPQRSTU"
assert(#ALPHABET == 64, "Moo Cipher alphabet must have 64 characters")
local WORDS = { "moo", "Moo", "mOo", "moO" }
local WORD_VALUE = { moo = 0, Moo = 1, mOo = 2, moO = 3 }
local MARKER = "MOO-CIPHER:"
ns.CIPHER_MAX = 20

function ns.CipherEncode(text)
  local out = {}
  local used = 0
  for ch in tostring(text):gmatch(".") do
    local i = ALPHABET:find(ch, 1, true) or ALPHABET:find(ch:lower(), 1, true)
    if i and used < ns.CIPHER_MAX then
      local v = i - 1
      local a, b, c = math.floor(v / 16), math.floor(v / 4) % 4, v % 4
      out[#out + 1] = WORDS[a + 1] .. " " .. WORDS[b + 1] .. " " .. WORDS[c + 1]
      used = used + 1
    end
  end
  if #out == 0 then return nil end
  return MARKER .. " " .. table.concat(out, " ")
end

function ns.CipherDecode(line)
  if type(line) ~= "string" then return nil end
  local s, e = line:find(MARKER, 1, true)
  if not s then return nil end
  local words = {}
  for w in line:sub(e + 1):gmatch("%S+") do
    local v = WORD_VALUE[w]
    if not v then break end
    words[#words + 1] = v
  end
  if #words == 0 or #words % 3 ~= 0 then return nil end
  local out = {}
  for i = 1, #words, 3 do
    local v = words[i] * 16 + words[i + 1] * 4 + words[i + 2]
    out[#out + 1] = ALPHABET:sub(v + 1, v + 1)
  end
  return table.concat(out)
end

-- Your screen only: show the hidden message next to any Moo Cipher line you see
local CIPHER_EVENTS = {
  "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID",
  "CHAT_MSG_RAID_LEADER", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_CHANNEL", "CHAT_MSG_WHISPER",
  "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
}
local decodedSeen = {}
function ns.CipherFilter(_, _, msg, ...)
  if type(msg) ~= "string" or not ns.Usable(msg) then return false end
  local secret = ns.CipherDecode(msg)
  if not secret then return false end
  if not decodedSeen[msg] then
    decodedSeen[msg] = true
    if ns.db then ns:Bump("cipherDecoded") end
  end
  return false, msg .. "  |cff9d9d9d[decoded: " .. secret:gsub("|", "") .. "]|r", ...
end

ns:On("PLAYER_LOGIN", function()
  local add = ChatFrame_AddMessageEventFilter or (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter)
  if add then
    for _, e in ipairs(CIPHER_EVENTS) do pcall(add, e, ns.CipherFilter) end
  end
end)
