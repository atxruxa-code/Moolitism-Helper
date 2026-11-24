-- MooHelper: The Barn, the main window
-- Tabs down the left; each page is built once and refreshed while it's showing.

local _, ns = ...

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil
local KODO = "Interface\\Icons\\Ability_Mount_Kodo_01"
local BAR = "Interface\\TargetingFrame\\UI-StatusBar"
local W, H = 920, 620
local CONTENT_W, CONTENT_H = 728, 526

-- palette
local WOOD = { 0.17, 0.10, 0.06 }
local PLANK = { 0.24, 0.15, 0.09 }
local CREAM = { 0.96, 0.92, 0.82 }
local GOLD = { 1, 0.82, 0.2 }
local RED = { 0.95, 0.25, 0.2 }
local GREEN = { 0.3, 0.85, 0.35 }

local barn, contentArea
local pages, tabs, current = {}, {}, nil

---------------------------------------------------------------------------
-- Widget helpers
---------------------------------------------------------------------------

local function Backdrop(f, bg, border, edge)
  if not f.SetBackdrop then return end
  f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = edge or 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 } })
  f:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 0.95)
  f:SetBackdropBorderColor((border or GOLD)[1], (border or GOLD)[2], (border or GOLD)[3], 1)
end

local function Label(parent, text, font, x, y, width)
  local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
  fs:SetPoint("TOPLEFT", x or 0, y or 0)
  fs:SetJustifyH("LEFT")
  if width then fs:SetWidth(width) end
  fs:SetText(text or "")
  return fs
end

local function Btn(parent, text, w, h, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w or 120, h or 24)
  b:SetText(text)
  b:SetScript("OnClick", function(self, ...) onClick(self, ...) end)
  return b
end

local function Say(ok, message)
  if message then ns:Print(message) end
  if ns.RefreshBarn then ns:RefreshBarn() end
end

local function Check(parent, x, y, label, get, set)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(22, 22)
  cb:SetPoint("TOPLEFT", x, y)
  cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  cb.text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
  cb.text:SetText(label)
  cb.get = get
  cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
  return cb
end

local function Bar(parent, w, h, color)
  local bar = CreateFrame("StatusBar", nil, parent)
  bar:SetSize(w, h)
  bar:SetStatusBarTexture(BAR)
  bar:SetStatusBarColor(color[1], color[2], color[3])
  bar:SetMinMaxValues(0, 1)
  bar.bg = bar:CreateTexture(nil, "BACKGROUND")
  bar.bg:SetAllPoints()
  bar.bg:SetColorTexture(0, 0, 0, 0.55)
  bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  bar.text:SetPoint("CENTER")
  return bar
end

local function SetBar(bar, value, max, text)
  bar:SetMinMaxValues(0, math.max(max, 1))
  bar:SetValue(math.min(value, max))
  bar.text:SetText(text or "")
end

local function Section(parent, title, x, y, w)
  local fs = Label(parent, title, "GameFontNormal", x, y)
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.35)
  line:SetSize(w or 220, 1)
  line:SetPoint("TOPLEFT", x, y - 16)
  return fs
end

local function Fmt(n) return ns.FormatNumber and ns.FormatNumber(n or 0) or tostring(math.floor(n or 0)) end

-- A scrolling list with pooled rows: list:SetData(items) calls fill(row, item, index)
local listCount = 0
local function ScrollList(parent, x, y, w, h, rowH, create, fill)
  listCount = listCount + 1
  local scroll = CreateFrame("ScrollFrame", "MooHelperBarnList" .. listCount, parent, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", x, y)
  scroll:SetSize(w - 24, h)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(w - 24, 1)
  scroll:SetScrollChild(content)
  local list = { rows = {}, scroll = scroll, content = content }
  function list:SetData(items)
    for i, item in ipairs(items) do
      local row = self.rows[i]
      if not row then
        row = create(content, w - 30, rowH)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * (rowH + 3))
        self.rows[i] = row
      end
      fill(row, item, i)
      row:Show()
    end
    for i = #items + 1, #self.rows do self.rows[i]:Hide() end
    content:SetHeight(math.max(1, #items * (rowH + 3)))
  end
  return list
end

local function RowFrame(parent, w, h)
  local r = CreateFrame("Frame", nil, parent, BACKDROP_TEMPLATE)
  r:SetSize(w, h)
  Backdrop(r, { 0.1, 0.06, 0.03, 0.85 }, { 0.45, 0.32, 0.18 }, 10)
  return r
end

---------------------------------------------------------------------------
-- Page: Moo HQ (the big button, launch pad, translator)
---------------------------------------------------------------------------

local launchCount = 1

pages.moo = { title = "Moo HQ", icon = KODO, build = function(p)
  local big = CreateFrame("Button", nil, p, BACKDROP_TEMPLATE)
  big:SetSize(150, 150)
  big:SetPoint("TOPLEFT", 6, -6)
  Backdrop(big, { 0.1, 0.06, 0.03 }, GOLD, 16)
  big.icon = big:CreateTexture(nil, "ARTWORK")
  big.icon:SetPoint("TOPLEFT", 8, -8)
  big.icon:SetPoint("BOTTOMRIGHT", -8, 8)
  big.icon:SetTexture(KODO)
  big.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  local word = big:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  word:SetPoint("BOTTOM", 0, 10)
  word:SetText("MOO")
  big:SetScript("OnClick", function() ns:Moo() ns:RefreshBarn() end)
  p.stats = Label(p, "", "GameFontHighlight", 176, -10, 540)

  Section(p, "Launch pad: fire moos into one channel", 176, -100, 540)
  Label(p, "How many:", "GameFontHighlightSmall", 176, -126)
  p.countButtons = {}
  for i, n in ipairs({ 1, 3, 5, 10, 20 }) do
    local b = Btn(p, "x" .. n, 48, 22, function() launchCount = n ns:RefreshBarn() end)
    b:SetPoint("TOPLEFT", 240 + (i - 1) * 52, -120)
    b.n = n
    p.countButtons[i] = b
  end
  p.launchButtons = {}

  Section(p, "Moo translator", 6, -336, 710)
  p.input = CreateFrame("EditBox", "MooHelperBarnTranslate", p, "InputBoxTemplate")
  p.input:SetSize(420, 22)
  p.input:SetPoint("TOPLEFT", 12, -360)
  p.input:SetAutoFocus(false)
  p.input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  p.input:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  p.input:SetScript("OnTextChanged", function() if pages.moo.refresh then pages.moo.refresh(p) end end)
  p.dialect = "classic"
  p.dialectButtons = {}
  for i, d in ipairs(ns.DIALECTS) do
    local b = Btn(p, d.name, 100, 20, function() p.dialect = d.key ns:RefreshBarn() end)
    b:SetPoint("TOPLEFT", 6 + (i - 1) * 102, -388)
    b.key = d.key
    p.dialectButtons[i] = b
  end
  p.preview = Label(p, "", "GameFontHighlightSmall", 12, -416, 700)
  local sends = {
    { "Say it", "SAY" }, { "Party / group", "GROUP" }, { "Guild", "GUILD" }, { "Yell it", "YELL" },
    { "Cipher to Say", "CIPHER:SAY" }, { "Cipher to group", "CIPHER:GROUP" },
  }
  for i, s in ipairs(sends) do
    local b = Btn(p, s[1], 112, 22, function()
      local text = p.input:GetText() or ""
      if text == "" then ns:Print("Type something to translate first.") return end
      local target = s[2]
      local cipher = target:sub(1, 7) == "CIPHER:"
      if cipher then target = target:sub(8) end
      if target == "GROUP" then target = ns:GroupChannel() end
      if not target then ns:Print("You're not in a group.") return end
      local line
      if cipher then line = ns.CipherEncode(text) else line = ns:Speak(p.dialect, text) end
      if line and ns:SendNow(target, line) then
        if cipher then ns:Bump("cipherEncoded") end
        p.input:SetText("")
      elseif ns:IsMuted(target) then
        ns:Print(ns:ChannelLabel(target) .. " is HARD MUTED.")
      end
    end)
    b:SetPoint("TOPLEFT", 6 + (i - 1) * 118, -444)
  end
  Label(p, "Tip: a cipher line looks like plain moos to everyone else. MooHelper shows you the hidden message.",
    "GameFontDisableSmall", 8, -476, 700)
end, refresh = function(p)
  local s = ns.db.stats
  local done, total, points = 0, 0, 0
  if ns.Ach and ns.Ach.char then done, total, points = ns.Ach:GetSummary() end
  p.stats:SetText(("|cffffd100%s|r lifetime moos   Rank: |cffffd100%s|r   Best combo: %d   Current combo: %d\nMilk: |cffffffff%s|r (%.1f/s)   Moo-chievements: %d/%d (%d points)%s")
    :format(Fmt(s.total), ns:RankName(), s.bestCombo, ns.combo or 0, Fmt(ns:Milk()), ns:MilkPerSecond(), done, total, points,
      ns.inMoonsoon and "   |cff80c0ffMOO-NSOON: double milk!|r" or ""))
  for _, b in ipairs(p.countButtons) do
    if b.n == launchCount then b:LockHighlight() else b:UnlockHighlight() end
  end
  -- one launch button per channel (numbered channels change as you join/leave them)
  local channels = {}
  for _, c in ipairs(ns.FIXED_CHANNELS) do channels[#channels + 1] = c end
  for _, c in ipairs(ns:JoinedChannels()) do channels[#channels + 1] = c end
  for i, c in ipairs(channels) do
    local b = p.launchButtons[i]
    if not b then
      b = Btn(p, "", 172, 24, function(self)
        local ok, why = ns:Launch(self.key, launchCount)
        Say(ok, why)
      end)
      p.launchButtons[i] = b
    end
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", 6 + ((i - 1) % 4) * 178, -150 - math.floor((i - 1) / 4) * 28)
    b.key = c.key
    local muted = ns:IsMuted(c.key)
    local available = ns:ChannelAvailable(c.key)
    if muted then
      b:SetText("|cffff4040" .. c.label .. ": MUTED|r")
      b:Disable()
    elseif not available then
      b:SetText("|cff808080" .. c.label .. "|r")
      b:Disable()
    else
      b:SetText("Moo " .. c.label .. (launchCount > 1 and (" x" .. launchCount) or ""))
      b:Enable()
    end
    b:Show()
  end
  for i = #channels + 1, #p.launchButtons do p.launchButtons[i]:Hide() end
  for _, b in ipairs(p.dialectButtons) do
    if b.key == p.dialect then b:LockHighlight() else b:UnlockHighlight() end
  end
  local text = p.input:GetText() or ""
  p.preview:SetText(text ~= "" and ("Preview: |cffffffff" .. ns.DialectTranslate(p.dialect, text) .. "|r") or
    "Type above, pick a dialect, then send it.")
end, live = true }

---------------------------------------------------------------------------
-- Page: Channels (Moo button targets and HARD MUTE)
---------------------------------------------------------------------------

pages.channels = { title = "Channels", icon = "INV_Letter_01", build = function(p)
  Label(p, "|cffffd100HARD MUTE|r blocks every MooHelper message to a channel: the button, launches, games, " ..
    "interviews, the clock, welcomes, achievement announcements, whisper replies. Nothing can get through. " ..
    "\"Moo button\" only decides where the button and /moo send.", "GameFontHighlightSmall", 6, -6, 710)
  Label(p, "Channel", "GameFontNormal", 12, -62)
  Label(p, "Moo button", "GameFontNormal", 220, -62)
  Label(p, "Hard mute", "GameFontNormal", 380, -62)
  Label(p, "Status", "GameFontNormal", 560, -62)
  p.rows = {}
  p.blocked = Label(p, "", "GameFontDisableSmall", 12, -500, 700)
end, refresh = function(p)
  local channels = {}
  for _, c in ipairs(ns.FIXED_CHANNELS) do channels[#channels + 1] = c end
  channels[#channels + 1] = { key = "WHISPER", label = "Whispers (replies, welcomes)", noButton = true }
  for _, c in ipairs(ns:JoinedChannels()) do channels[#channels + 1] = c end
  for i, c in ipairs(channels) do
    local row = p.rows[i]
    if not row then
      row = CreateFrame("Frame", nil, p)
      row:SetSize(710, 28)
      row.bg = row:CreateTexture(nil, "BACKGROUND")
      row.bg:SetAllPoints()
      row.name = Label(row, "", "GameFontHighlight", 8, -6)
      row.send = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
      row.send:SetSize(24, 24)
      row.send:SetPoint("TOPLEFT", 230, -2)
      row.mute = Btn(row, "", 150, 22, function(self)
        ns:SetMuted(self.key, not ns:IsMuted(self.key))
        ns:RefreshBarn()
      end)
      row.mute:SetPoint("TOPLEFT", 368, -3)
      row.status = Label(row, "", "GameFontHighlightSmall", 550, -8)
      p.rows[i] = row
    end
    row:SetPoint("TOPLEFT", 4, -82 - (i - 1) * 30)
    local muted = ns:IsMuted(c.key)
    row.bg:SetColorTexture(muted and 0.35 or 0.1, muted and 0.05 or 0.06, muted and 0.04 or 0.03, 0.7)
    row.name:SetText(c.label)
    local key = c.key
    if c.noButton then
      row.send:Hide()
    else
      row.send:Show()
      row.send:SetChecked(ns.db.channels[key] == true)
      row.send:SetScript("OnClick", function(self) ns.db.channels[key] = self:GetChecked() and true or nil end)
    end
    row.mute.key = key
    row.mute:SetText(muted and "|cffff4040HARD MUTED|r" or "|cff80ff80open|r")
    local status
    if c.protected then status = "click or key press only"
    elseif c.key == "EMOTE" then status = "button and commands only"
    else status = "button, commands and automatic" end
    if not ns:ChannelAvailable(key) and key ~= "WHISPER" then status = "|cff808080not available right now|r" end
    row.status:SetText(status)
    row:Show()
  end
  for i = #channels + 1, #p.rows do p.rows[i]:Hide() end
  p.blocked:SetText(("Messages stopped by hard mutes this session: %d"):format(ns.blockedByMute or 0))
end, live = true }

---------------------------------------------------------------------------
-- Page: Triggers (everything automatic)
---------------------------------------------------------------------------

local TRIGGER_GROUPS = {
  { "When things happen", {
    { "death", "You die (group)" }, { "partyDeath", "A friend dies (group)" }, { "levelUp", "Level-ups (group + guild)" },
    { "epicLoot", "Epic loot (group)" }, { "bossKill", "Boss kills (group)" }, { "readyCheck", "Ready checks (group)" },
    { "countdown", "MOO-UNTDOWN (group)" }, { "hearth", "Hearthstone (group)" }, { "rollComment", "Roll commentary (group)" },
    { "mountMoo", "Mounting up (group)" }, { "jumpMoo", "Every 25th jump (group)" }, { "shame", "Moo-litism (group)" },
  } },
  { "Talking with friends", {
    { "interactions", "Answer when talked to (group/whisper)" }, { "interviews", "Moo Interviews (group)" },
    { "mooCheck", "Surprise moo checks (group)" }, { "mooBack", "Moo back (group/guild)" },
    { "autoReply", "Whisper conversations (whisper)" }, { "taurenTarget", "/moo at Taurens (emote)" },
    { "herdPromotions", "Herd promotions (group)" }, { "bessieTalk", "Bessie speaks up (group)" },
    { "guildGames", "Games and chat in guild (guild)" },
  } },
  { "Ambient and guild", {
    { "alarm", "Moo Alarm (group)" }, { "mooClock", "Moo Clock (group)" }, { "clockGuild", "Moo Clock in guild (guild)" },
    { "afkStalk", "AFK stalker (group)" }, { "guildWelcome", "Login welcomes (guild/whisper)" },
    { "rankUp", "Rank-ups (group + guild)" }, { "forecast", "Daily forecast (guild)" }, { "mooFM", "Moo FM radio (group)" },
    { "events", "Moo-nsoons etc. (group)" }, { "goldenMoo", "Golden Moos (your screen)" },
    { "@achAnnounce", "Achievements (group)" }, { "@achAnnounceGuild", "Achievements (guild)" },
  } },
}

local NUMBERS = {
  { "alarmMinutes", "Moo Alarm every %d min", 1, 120 }, { "interviewMinutes", "Interviews every %d min", 1, 120 },
  { "mooCheckMinutes", "Moo checks every %d min", 1, 120 }, { "publicCooldown", "Public cooldown %ds", 1, 120 },
}

pages.triggers = { title = "Triggers", icon = "Spell_Holy_MindVision", build = function(p)
  p.checks = {}
  for col, group in ipairs(TRIGGER_GROUPS) do
    local x = 6 + (col - 1) * 242
    Section(p, group[1], x, -4, 230)
    for i, t in ipairs(group[2]) do
      local key, label = t[1], t[2]
      local get, set
      if key:sub(1, 1) == "@" then
        local field = key:sub(2)
        get = function() return ns.db[field] end
        set = function(v) ns.db[field] = v end
      else
        get = function() return ns.db.triggers[key] end
        set = function(v) ns.db.triggers[key] = v end
      end
      p.checks[#p.checks + 1] = Check(p, x, -26 - (i - 1) * 22, label, get, set)
    end
  end
  Section(p, "How often", 6, -320, 710)
  for i, n in ipairs(NUMBERS) do
    local x = 6 + ((i - 1) % 2) * 360
    local y = -346 - math.floor((i - 1) / 2) * 30
    local label = Label(p, "", "GameFontHighlight", x + 60, y - 4)
    local minus = Btn(p, "-", 24, 22, function() ns.db[n[1]] = math.max(n[3], ns.db[n[1]] - 1) ns:RefreshBarn() end)
    minus:SetPoint("TOPLEFT", x, y)
    local plus = Btn(p, "+", 24, 22, function() ns.db[n[1]] = math.min(n[4], ns.db[n[1]] + 1) ns:RefreshBarn() end)
    plus:SetPoint("TOPLEFT", x + 28, y)
    p["num" .. i] = { label = label, def = n }
  end
  local panic = Btn(p, "", 300, 30, function()
    ns.db.panic = not ns.db.panic
    if ns.db.panic then ns:Bump("panicUsed") end
    ns:RefreshBarn()
  end)
  panic:SetPoint("TOPLEFT", 6, -430)
  p.panic = panic
  Label(p, "The panic button stops everything automatic. Your button, /moo and launches still work. " ..
    "Hard mutes (Channels tab) always apply.", "GameFontDisableSmall", 320, -436, 390)
end, refresh = function(p)
  for _, cb in ipairs(p.checks) do cb:SetChecked(cb.get() and true or false) end
  for i = 1, #NUMBERS do
    local e = p["num" .. i]
    e.label:SetText(e.def[2]:format(ns.db[e.def[1]]))
  end
  p.panic:SetText(ns.db.panic and "|cff80ff80UNLEASH THE MOOS|r" or "|cffff4040STOP ALL AUTOMATIC MOOS|r")
end }

---------------------------------------------------------------------------
-- Page: Games
---------------------------------------------------------------------------

pages.games = { title = "Party Games", icon = "INV_Misc_Dice_02", build = function(p)
  p.status = Label(p, "", "GameFontHighlightSmall", 6, -4, 470)
  Label(p, "Play in:", "GameFontNormalSmall", 490, -4)
  p.scopeButtons = {}
  for i, s in ipairs({ { "group", "Party / raid" }, { "guild", "Guild chat" } }) do
    local b = Btn(p, s[2], 92, 18, function() ns.db.gameScope = s[1] ns:RefreshBarn() end)
    b:SetPoint("TOPLEFT", 540 + (i - 1) * 94, -1)
    b.scope = s[1]
    p.scopeButtons[i] = b
  end
  for i, g in ipairs(ns.GAME_LIST) do
    local card = CreateFrame("Frame", nil, p, BACKDROP_TEMPLATE)
    card:SetSize(232, 92)
    card:SetPoint("TOPLEFT", 4 + ((i - 1) % 3) * 240, -22 - math.floor((i - 1) / 3) * 98)
    Backdrop(card, { 0.12, 0.07, 0.04, 0.9 }, { 0.6, 0.45, 0.25 }, 12)
    local icon = card:CreateTexture(nil, "ARTWORK")
    icon:SetSize(34, 34)
    icon:SetPoint("TOPLEFT", 8, -8)
    icon:SetTexture("Interface\\Icons\\" .. (g.icon or "INV_Misc_Dice_01"))
    Label(card, g.name, "GameFontNormal", 48, -8)
    Label(card, g.desc, "GameFontHighlightSmall", 48, -26, 176)
    Label(card, ('Friends say: "%s"'):format(g.say), "GameFontDisableSmall", 8, -50, 216)
    local start = Btn(card, "Start", 70, 20, function()
      local ok, why = g.start()
      Say(ok, not ok and why or nil)
    end)
    start:SetPoint("BOTTOMRIGHT", -8, 8)
    local played = Label(card, "", "GameFontDisableSmall", 8, -70)
    card.played, card.key = played, g.key
    p["card" .. i] = card
  end
end, refresh = function(p)
  local running = {}
  for key, label in pairs({ battle = "MOO-OFF", trivia = "Trivia", vote = "Vote", mooCheck = "Moo Check", draw = "Quick Draw",
    hangman = "Moo-gman", scramble = "Scramble", mathq = "Moo Math", tales = "Moo Tales" }) do
    if ns[key] then running[#running + 1] = label end
  end
  for _, b in ipairs(p.scopeButtons) do
    if b.scope == (ns.db.gameScope or "group") then b:LockHighlight() else b:UnlockHighlight() end
  end
  local guild = ns.db.gameScope == "guild"
  local available = ns:ScopeChannel(ns.db.gameScope or "group")
  p.status:SetText(#running > 0 and ("|cff80ff80Running now in " .. ns:ChatName() .. " chat:|r " .. table.concat(running, ", ")) or
    (available and ("Start buttons play in " .. (guild and "guild" or "party") .. " chat. Friends can also start games by saying them in party or guild chat.")
      or (guild and "|cffff8040Join a guild to play in guild chat.|r" or "|cffff8040Join a group to play in party chat.|r")))
  for i = 1, #ns.GAME_LIST do
    local card = p["card" .. i]
    card.played:SetText(("Hosted %d times"):format(ns:GetStat("played:" .. card.key)))
  end
end, live = true }

---------------------------------------------------------------------------
-- Page: Herd
---------------------------------------------------------------------------

pages.herd = { title = "The Herd", icon = "Spell_Holy_PrayerOfFortitude", build = function(p)
  Label(p, "Friends join your herd by playing along in chat: mooing, answering interviews, winning games. " ..
    "Nobody needs to install anything.", "GameFontHighlightSmall", 6, -4, 560)
  local post = Btn(p, "Post the top 5", 130, 22, function()
    local ch = ns:GroupChannel()
    if not ch then ns:Print("Join a group to post it.") return end
    local parts = {}
    for i, e in ipairs(ns:HerdTop(5)) do parts[#parts + 1] = ("%d. %s (%s, %d)"):format(i, e.name, ns:HerdRankName(e.name), e.points) end
    ns:SendNow(ch, "THE HERD: " .. (#parts > 0 and table.concat(parts, "  ") or "empty. Moo?"))
  end)
  post:SetPoint("TOPRIGHT", -8, -2)
  local COLS = { { "#", 8 }, { "Name", 36 }, { "Herd rank", 210 }, { "Points", 420 }, { "Moos", 500 },
    { "Answers", 570 }, { "Wins", 650 } }
  for _, c in ipairs(COLS) do Label(p, c[1], "GameFontNormal", c[2] + 4, -40) end
  p.list = ScrollList(p, 4, -60, 720, 450, 26, function(parent, w, h)
    local r = RowFrame(parent, w, h)
    r.cols = {}
    for i, c in ipairs(COLS) do r.cols[i] = Label(r, "", i == 3 and "GameFontNormal" or "GameFontHighlight", c[2], -6) end
    return r
  end, function(r, e, i)
    local m = ns.db.herd[e.name]
    local values = { i, e.name, (ns:HerdRankName(e.name)), m.points, m.mooBacks or 0, m.answers or 0, m.wins or 0 }
    for c, v in ipairs(values) do r.cols[c]:SetText(tostring(v)) end
  end)
  p.empty = Label(p, "|cff9d9d9dNobody in your herd yet. Get your party to say moo.|r", "GameFontHighlight", 10, -80)
end, refresh = function(p)
  local top = ns:HerdTop()
  p.list:SetData(top)
  if #top == 0 then p.empty:Show() else p.empty:Hide() end
end }

---------------------------------------------------------------------------
-- Page: Bessie
---------------------------------------------------------------------------

pages.bessie = { title = "Bessie", icon = "INV_Misc_Food_19", build = function(p)
  local frame = CreateFrame("Frame", nil, p, BACKDROP_TEMPLATE)
  frame:SetSize(150, 150)
  frame:SetPoint("TOPLEFT", 10, -10)
  Backdrop(frame, { 0.1, 0.06, 0.03 }, GOLD, 16)
  p.portrait = frame:CreateTexture(nil, "ARTWORK")
  p.portrait:SetPoint("TOPLEFT", 8, -8)
  p.portrait:SetPoint("BOTTOMRIGHT", -8, 8)
  p.portrait:SetTexture(KODO)
  p.portrait:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  p.name = Label(p, "", "GameFontNormalHuge", 180, -12)
  p.stage = Label(p, "", "GameFontHighlight", 180, -46)
  p.xp = Bar(p, 420, 16, GOLD)
  p.xp:SetPoint("TOPLEFT", 180, -70)
  local rows = { { "hunger", "Fullness", { 0.85, 0.6, 0.2 } }, { "happiness", "Happiness", { 0.9, 0.4, 0.6 } },
    { "energy", "Energy", { 0.35, 0.7, 1 } } }
  p.bars = {}
  for i, r in ipairs(rows) do
    Label(p, r[2], "GameFontHighlightSmall", 180, -102 - (i - 1) * 26)
    local bar = Bar(p, 300, 16, r[3])
    bar:SetPoint("TOPLEFT", 260, -100 - (i - 1) * 26)
    p.bars[r[1]] = bar
  end
  p.mood = Label(p, "", "GameFontHighlight", 10, -180, 700)
  local actions = {
    { "Feed", function() return ns:BessieFeed() end }, { "Pet", function() return ns:BessiePet() end },
    { "Brush", function() return ns:BessieBrush() end }, { "Show her off", function() return ns:BessieShowOff() end },
  }
  p.actionButtons = {}
  for i, a in ipairs(actions) do
    local b = Btn(p, a[1], 130, 28, function() Say(a[2]()) end)
    b:SetPoint("TOPLEFT", 10 + (i - 1) * 140, -214)
    p.actionButtons[i] = b
  end
  Section(p, "Rename", 10, -264, 300)
  p.rename = CreateFrame("EditBox", "MooHelperBarnRename", p, "InputBoxTemplate")
  p.rename:SetSize(200, 22)
  p.rename:SetPoint("TOPLEFT", 16, -290)
  p.rename:SetAutoFocus(false)
  p.rename:SetMaxLetters(20)
  p.rename:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  local rn = Btn(p, "Rename", 90, 22, function()
    Say(ns:BessieRename(p.rename:GetText() or ""))
    p.rename:SetText("")
    p.rename:ClearFocus()
  end)
  rn:SetPoint("TOPLEFT", 226, -290)
  Label(p, "Bessie grows as you moo, gets hungry and bored over time, and speaks up in group chat now and then. " ..
    "Feeding costs milk from the Farm. She's happiest after boss kills and sad when you die.",
    "GameFontDisableSmall", 10, -330, 700)
end, refresh = function(p)
  local b = ns.db.bessie
  local stages = ns.BESSIE_STAGES
  local mood, moodText = ns:BessieMood()
  p.name:SetText(b.name)
  p.stage:SetText(("the %s  (%s xp)"):format(ns:BessieStageName(), Fmt(b.xp)))
  local nextStage = stages[b.stage + 1]
  if nextStage then
    local from = stages[b.stage].xp
    SetBar(p.xp, b.xp - from, nextStage.xp - from, ("%s / %s xp to %s"):format(Fmt(b.xp - from), Fmt(nextStage.xp - from), nextStage.name))
  else
    SetBar(p.xp, 1, 1, "Fully grown. A legend.")
  end
  for key, bar in pairs(p.bars) do SetBar(bar, b[key], 100, ("%d%%"):format(b[key])) end
  p.mood:SetText(("%s %s"):format(b.name, moodText))
  local tint = { starving = { 0.9, 0.6, 0.5 }, sad = { 0.6, 0.6, 0.9 }, sleepy = { 0.7, 0.7, 0.7 },
    ecstatic = { 1, 0.95, 0.6 }, content = { 1, 1, 1 } }
  local c = tint[mood] or tint.content
  p.portrait:SetVertexColor(c[1], c[2], c[3])
  local cost = ns:HasUpgrade("diet") and 5 or 10
  p.actionButtons[1]:SetText(("Feed (%d milk)"):format(cost))
end, live = true }

---------------------------------------------------------------------------
-- Page: Farm (milk, generators, upgrades, daily quests)
---------------------------------------------------------------------------

pages.farm = { title = "The Farm", icon = "INV_Drink_Milk_01", build = function(p)
  p.milk = Label(p, "", "GameFontNormalHuge", 6, -6)
  p.rate = Label(p, "", "GameFontHighlight", 6, -40)
  local golden = Btn(p, "Summon a Golden Moo (1,000)", 210, 22, function() SlashCmdList.MOOHELPER("golden") ns:RefreshBarn() end)
  golden:SetPoint("TOPRIGHT", -8, -8)
  Section(p, "Generators (produce milk every second)", 6, -64, 440)
  p.gens = ScrollList(p, 0, -86, 462, 430, 38, function(parent, w, h)
    local r = RowFrame(parent, w, h)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(28, 28)
    r.icon:SetPoint("LEFT", 6, 0)
    r.name = Label(r, "", "GameFontNormal", 40, -4)
    r.info = Label(r, "", "GameFontHighlightSmall", 40, -20, 260)
    r.buy = Btn(r, "", 120, 22, function(self) Say(ns:BuyGenerator(self.key)) end)
    r.buy:SetPoint("RIGHT", -6, 0)
    return r
  end, function(r, g)
    local owned = ns.db.farm.owned[g.key] or 0
    local cost = ns:GeneratorCost(g.key)
    r.icon:SetTexture("Interface\\Icons\\" .. g.icon)
    r.name:SetText(("%s  |cffffffffx%d|r"):format(g.name, owned))
    r.info:SetText(("%s milk/s each. %s"):format(g.mps, g.desc))
    r.buy.key = g.key
    r.buy:SetText(Fmt(cost))
    if ns:Milk() >= cost then r.buy:Enable() else r.buy:Disable() end
  end)
  Section(p, "Upgrades", 476, -64, 240)
  p.upgrades = ScrollList(p, 470, -86, 258, 240, 40, function(parent, w, h)
    local r = RowFrame(parent, w, h)
    r.name = Label(r, "", "GameFontNormalSmall", 6, -4, 150)
    r.desc = Label(r, "", "GameFontDisableSmall", 6, -18, 150)
    r.buy = Btn(r, "", 76, 20, function(self) Say(ns:BuyUpgrade(self.key)) end)
    r.buy:SetPoint("RIGHT", -4, 0)
    return r
  end, function(r, u)
    r.name:SetText(u.name)
    r.desc:SetText(u.desc)
    r.buy.key = u.key
    if ns:HasUpgrade(u.key) then
      r.buy:SetText("|cff80ff80Owned|r")
      r.buy:Disable()
    else
      r.buy:SetText(Fmt(u.cost))
      if ns:Milk() >= u.cost then r.buy:Enable() else r.buy:Disable() end
    end
  end)
  Section(p, "Daily Moo Quests", 476, -340, 240)
  p.quests = {}
  for i = 1, 3 do
    local text = Label(p, "", "GameFontHighlightSmall", 476, -364 - (i - 1) * 44, 240)
    local bar = Bar(p, 236, 12, GREEN)
    bar:SetPoint("TOPLEFT", 476, -380 - (i - 1) * 44)
    p.quests[i] = { text = text, bar = bar }
  end
  p.streak = Label(p, "", "GameFontDisableSmall", 476, -500, 240)
end, refresh = function(p)
  p.milk:SetText(("|cffffffff%s|r milk"):format(Fmt(ns:Milk())))
  p.rate:SetText(("%.1f milk per second%s   Lifetime: %s"):format(ns:MilkPerSecond(),
    ns.inMoonsoon and " (x2 Moo-nsoon!)" or "", Fmt(ns.db.farm.lifetime)))
  p.gens:SetData(ns.GENERATORS)
  p.upgrades:SetData(ns.UPGRADES)
  local list = ns:QuestsForToday()
  for i, q in ipairs(p.quests) do
    local entry = list[i]
    if entry then
      local cur, goal, def = ns:QuestProgress(entry)
      q.text:SetText(("%s%s (+%d milk)"):format(entry.done and "|cff80ff80[done]|r " or "", def and def.text or "?", def and def.reward or 0))
      SetBar(q.bar, cur, goal, ("%d / %d"):format(cur, goal))
    end
  end
  local qs = ns.db.farm.quests
  p.streak:SetText(("Streak: %d day%s (finish all three daily for +500 milk)"):format(qs.streak or 0, (qs.streak or 0) == 1 and "" or "s"))
end, live = true }

---------------------------------------------------------------------------
-- Page: Moo-chievements (the ported achievement browser)
---------------------------------------------------------------------------

local achCat, achSearch = "recent", ""

local function AchList()
  local A = ns.Ach
  local items = {}
  local function visible(a) return not a.hidden or A.char.completed[a.id] end
  if achSearch ~= "" then
    for _, a in ipairs(A.list) do
      if visible(a) and (a.name:lower():find(achSearch, 1, true) or (a.desc or ""):lower():find(achSearch, 1, true)) then
        items[#items + 1] = a
      end
    end
  elseif achCat == "recent" then
    for _, a in ipairs(A.list) do if A.char.completed[a.id] then items[#items + 1] = a end end
    table.sort(items, function(x, y) return A.char.completed[x.id] > A.char.completed[y.id] end)
    for i = #items, 31, -1 do items[i] = nil end
  elseif achCat == "nearly" then
    local function ratio(a)
      local cur, max = A:GetProgress(a)
      return (cur and max and max > 0) and cur / max or 0
    end
    for _, a in ipairs(A.list) do
      if visible(a) and not A.char.completed[a.id] and ratio(a) > 0 then items[#items + 1] = a end
    end
    table.sort(items, function(x, y) return ratio(x) > ratio(y) end)
    for i = #items, 31, -1 do items[i] = nil end
  else
    for _, a in ipairs(A.list) do
      if (achCat == "all" or a.category == achCat) and visible(a) then items[#items + 1] = a end
    end
  end
  return items
end

pages.ach = { title = "Moo-chievements", icon = "INV_Misc_Trophy_01", build = function(p)
  p.search = CreateFrame("EditBox", "MooHelperBarnAchSearch", p, "InputBoxTemplate")
  p.search:SetSize(156, 20)
  p.search:SetPoint("TOPLEFT", 8, -6)
  p.search:SetAutoFocus(false)
  p.search:SetScript("OnEscapePressed", function(self) self:SetText("") self:ClearFocus() end)
  p.search:SetScript("OnTextChanged", function(self)
    achSearch = (self:GetText() or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    pages.ach.refresh(p)
  end)
  p.summary = Bar(p, 548, 18, GOLD)
  p.summary:SetPoint("TOPLEFT", 178, -6)
  p.catButtons = {}
  p.list = ScrollList(p, 172, -32, 560, 490, 46, function(parent, w, h)
    local r = RowFrame(parent, w, h)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(36, 36)
    r.icon:SetPoint("LEFT", 5, 0)
    r.name = Label(r, "", "GameFontNormal", 48, -5, 380)
    r.desc = Label(r, "", "GameFontHighlightSmall", 48, -22, 380)
    r.points = r:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    r.points:SetPoint("RIGHT", -12, 6)
    r.date = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.date:SetPoint("RIGHT", -10, -12)
    r.bar = Bar(r, 200, 10, GREEN)
    r.bar:SetPoint("BOTTOMLEFT", 48, 5)
    return r
  end, function(r, a)
    local A = ns.Ach
    local earned = A.char.completed[a.id]
    r.icon:SetTexture(a.icon)
    r.icon:SetDesaturated(not earned)
    r.name:SetText(earned and ("|cffffd100" .. a.name .. "|r") or ("|cffa0a0a0" .. a.name .. "|r"))
    r.desc:SetText(a.desc .. (a.hint and ("  |cff808080" .. a.hint .. "|r") or ""))
    r.points:SetText(a.points > 0 and tostring(a.points) or "")
    r.date:SetText(earned and date("%Y-%m-%d", earned) or "")
    local cur, max = A:GetProgress(a)
    if not earned and cur and max and max > 1 then
      SetBar(r.bar, cur, max, a.format == "money" and ("%dg / %dg"):format(math.floor(cur / 10000), math.floor(max / 10000))
        or ("%s / %s"):format(Fmt(cur), Fmt(max)))
      r.bar:Show()
    else
      r.bar:Hide()
    end
  end)
end, refresh = function(p)
  local A = ns.Ach
  if not A or not A.char then return end
  local done, total, points = A:GetSummary()
  SetBar(p.summary, done, total, ("%d / %d moo-chievements   %d points"):format(done, total, points))
  local cats = { { key = "recent", name = "Recently Earned" }, { key = "nearly", name = "Nearly There" }, { key = "all", name = "All" } }
  for _, key in ipairs(A.categoryOrder) do cats[#cats + 1] = { key = key, name = A.categories[key].name } end
  for i, c in ipairs(cats) do
    local b = p.catButtons[i]
    if not b then
      b = CreateFrame("Button", nil, p)
      b:SetSize(164, 20)
      b:SetPoint("TOPLEFT", 4, -32 - (i - 1) * 21)
      b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
      b.sel = b:CreateTexture(nil, "BACKGROUND")
      b.sel:SetAllPoints()
      b.sel:SetColorTexture(1, 0.82, 0, 0.2)
      b.text = Label(b, "", "GameFontNormalSmall", 6, -4, 120)
      b.count = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      b.count:SetPoint("RIGHT", -4, 0)
      b:SetScript("OnClick", function(self)
        achCat = self.key
        p.search:SetText("")
        p.list.scroll:SetVerticalScroll(0)
        pages.ach.refresh(p)
      end)
      p.catButtons[i] = b
    end
    b.key = c.key
    b.text:SetText(c.name)
    if A.categories[c.key] then
      local d, t = A:GetSummary(c.key)
      b.count:SetText(d .. "/" .. t)
    else
      b.count:SetText("")
    end
    b.sel:SetShown(achSearch == "" and achCat == c.key)
  end
  p.list:SetData(AchList())
end }

---------------------------------------------------------------------------
-- Page: Settings
---------------------------------------------------------------------------

pages.settings = { title = "Settings", icon = "INV_Misc_Gear_01", build = function(p)
  Section(p, "Effects", 6, -4, 230)
  p.checks = {}
  local effects = { { "combo", "Combo popup" }, { "cowRain", "Kodo rain" }, { "stampede", "Kodo stampedes" },
    { "mooVision", "Moo-vision flashes" }, { "hearMoo", "Hear Moo (others' chat in moo, your screen)" } }
  for i, e in ipairs(effects) do
    local key = e[1]
    p.checks[#p.checks + 1] = Check(p, 6, -26 - (i - 1) * 22, e[2],
      function() return ns.db.effects[key] end, function(v) ns.db.effects[key] = v end)
  end
  Section(p, "Hear Moo dialect", 6, -150, 710)
  p.hearButtons = {}
  for i, d in ipairs(ns.DIALECTS) do
    local b = Btn(p, d.name, 100, 20, function() ns.db.hearDialect = d.key ns:RefreshBarn() end)
    b:SetPoint("TOPLEFT", 6 + (i - 1) * 102, -172)
    b.key = d.key
    p.hearButtons[i] = b
  end
  Section(p, "Moo style (the button)", 6, -206, 710)
  p.styleButtons = {}
  for i, s in ipairs({ { "escalate", "Escalating" }, { "classic", "Classic" }, { "chaos", "Chaos" } }) do
    local b = Btn(p, s[2], 110, 22, function() ns.db.style = s[1] ns:RefreshBarn() end)
    b:SetPoint("TOPLEFT", 6 + (i - 1) * 114, -228)
    b.style = s[1]
    p.styleButtons[i] = b
  end
  Section(p, "The Moo button", 6, -266, 710)
  local toggle = Btn(p, "Show / hide", 110, 22, function() SlashCmdList.MOOHELPER("button") ns:RefreshBarn() end)
  toggle:SetPoint("TOPLEFT", 6, -288)
  local smaller = Btn(p, "Smaller", 80, 22, function()
    ns.db.buttonScale = math.max(0.5, ns.db.buttonScale - 0.1) ns:UpdateButton() ns:RefreshBarn()
  end)
  smaller:SetPoint("TOPLEFT", 122, -288)
  local bigger = Btn(p, "Bigger", 80, 22, function()
    ns.db.buttonScale = math.min(2.5, ns.db.buttonScale + 0.1) ns:UpdateButton() ns:RefreshBarn()
  end)
  bigger:SetPoint("TOPLEFT", 206, -288)
  local center = Btn(p, "Reset position", 120, 22, function()
    ns.db.buttonPos = nil
    if MooHelperButton then
      MooHelperButton:ClearAllPoints()
      MooHelperButton:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
    end
  end)
  center:SetPoint("TOPLEFT", 290, -288)
  p.scale = Label(p, "", "GameFontHighlightSmall", 420, -292)
  Label(p, "Keybinds: Options > Keybindings > AddOns > MooHelper (\"Moo!\" and \"/moo at your target\").\n" ..
    "Every command: type /moo help.", "GameFontDisableSmall", 6, -330, 700)
end, refresh = function(p)
  for _, cb in ipairs(p.checks) do cb:SetChecked(cb.get() and true or false) end
  for _, b in ipairs(p.hearButtons) do
    if b.key == (ns.db.hearDialect or "classic") then b:LockHighlight() else b:UnlockHighlight() end
  end
  for _, b in ipairs(p.styleButtons) do
    if b.style == ns.db.style then b:LockHighlight() else b:UnlockHighlight() end
  end
  p.scale:SetText(("Size: %d%%   %s"):format(math.floor(ns.db.buttonScale * 100 + 0.5), ns.db.hideButton and "(hidden)" or ""))
end }

local PAGE_ORDER = { "moo", "channels", "triggers", "games", "herd", "bessie", "farm", "ach", "settings" }

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------

local function ShowPage(key)
  if not pages[key] then key = "moo" end
  current = key
  for k, page in pairs(pages) do
    if page.frame then page.frame:SetShown(k == key) end
  end
  local page = pages[key]
  if not page.frame then
    page.frame = CreateFrame("Frame", nil, contentArea)
    page.frame:SetAllPoints(contentArea)
    page.build(page.frame)
  end
  page.frame:Show()
  for _, t in ipairs(tabs) do
    t.sel:SetShown(t.key == key)
    t.text:SetTextColor(t.key == key and 1 or CREAM[1], t.key == key and 0.82 or CREAM[2], t.key == key and 0.2 or CREAM[3])
  end
  barn.subtitle:SetText(page.title)
  if page.refresh then page.refresh(page.frame) end
end

function ns:RefreshBarn()
  if not barn or not barn:IsShown() or not current then return end
  local page = pages[current]
  if page.frame and page.refresh then
    local ok, err = pcall(page.refresh, page.frame)
    if not ok then table.insert(ns.errors, "barn " .. current .. ": " .. tostring(err)) end
  end
end

function ns:CreateBarn()
  barn = CreateFrame("Frame", "MooHelperBarn", UIParent, BACKDROP_TEMPLATE)
  barn:SetSize(W, H)
  barn:SetPoint("CENTER")
  barn:SetFrameStrata("HIGH")
  barn:SetMovable(true)
  barn:SetClampedToScreen(true)
  barn:EnableMouse(true)
  barn:RegisterForDrag("LeftButton")
  barn:SetScript("OnDragStart", barn.StartMoving)
  barn:SetScript("OnDragStop", barn.StopMovingOrSizing)
  Backdrop(barn, { WOOD[1], WOOD[2], WOOD[3], 0.97 }, GOLD, 18)
  tinsert(UISpecialFrames, "MooHelperBarn")
  barn:Hide()

  -- vertical planks
  for i = 0, 8 do
    local plank = barn:CreateTexture(nil, "BACKGROUND", nil, 1)
    plank:SetColorTexture(PLANK[1], PLANK[2], PLANK[3], i % 2 == 0 and 0.35 or 0.15)
    plank:SetPoint("TOPLEFT", 6 + i * 101, -6)
    plank:SetSize(100, H - 12)
  end
  -- cow-print header band
  local band = barn:CreateTexture(nil, "BORDER")
  band:SetColorTexture(CREAM[1], CREAM[2], CREAM[3], 0.95)
  band:SetPoint("TOPLEFT", 8, -8)
  band:SetPoint("TOPRIGHT", -8, -8)
  band:SetHeight(58)
  local spots = { { 30, 18, 40, 22 }, { 110, 30, 28, 18 }, { 190, 12, 52, 20 }, { 330, 26, 34, 24 }, { 470, 10, 46, 18 },
    { 560, 30, 30, 16 }, { 650, 14, 58, 24 }, { 760, 28, 36, 20 }, { 850, 12, 40, 26 } }
  for _, s in ipairs(spots) do
    local spot = barn:CreateTexture(nil, "BORDER", nil, 1)
    spot:SetColorTexture(0.08, 0.06, 0.05, 0.9)
    spot:SetSize(s[3], s[4])
    spot:SetPoint("TOPLEFT", s[1], -(8 + s[2]))
  end
  local plate = CreateFrame("Frame", nil, barn, BACKDROP_TEMPLATE)
  plate:SetSize(330, 46)
  plate:SetPoint("TOPLEFT", 16, -14)
  Backdrop(plate, { 0.22, 0.08, 0.05, 0.96 }, GOLD, 14)
  local title = plate:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  title:SetPoint("LEFT", 12, 0)
  title:SetText("THE BARN")
  barn.subtitle = plate:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  barn.subtitle:SetPoint("LEFT", title, "RIGHT", 12, -2)
  local close = CreateFrame("Button", nil, barn, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -10, -18)

  -- tabs
  for i, key in ipairs(PAGE_ORDER) do
    local page = pages[key]
    local t = CreateFrame("Button", nil, barn, BACKDROP_TEMPLATE)
    t:SetSize(150, 44)
    t:SetPoint("TOPLEFT", 12, -78 - (i - 1) * 48)
    Backdrop(t, { 0.3, 0.18, 0.1, 0.95 }, { 0.55, 0.4, 0.22 }, 12)
    t.key = key
    t.sel = t:CreateTexture(nil, "ARTWORK")
    t.sel:SetPoint("TOPLEFT", 3, -3)
    t.sel:SetPoint("BOTTOMRIGHT", -3, 3)
    t.sel:SetColorTexture(1, 0.82, 0.2, 0.18)
    t.icon = t:CreateTexture(nil, "OVERLAY")
    t.icon:SetSize(28, 28)
    t.icon:SetPoint("LEFT", 8, 0)
    t.icon:SetTexture(page.icon:find("\\") and page.icon or ("Interface\\Icons\\" .. page.icon))
    t.text = t:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t.text:SetPoint("LEFT", t.icon, "RIGHT", 8, 0)
    t.text:SetText(page.title)
    t:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    t:SetScript("OnClick", function() ShowPage(key) end)
    tabs[i] = t
  end

  contentArea = CreateFrame("Frame", nil, barn, BACKDROP_TEMPLATE)
  contentArea:SetSize(CONTENT_W + 16, CONTENT_H + 12)
  contentArea:SetPoint("TOPLEFT", 172, -72)
  Backdrop(contentArea, { 0.08, 0.05, 0.03, 0.9 }, { 0.5, 0.36, 0.2 }, 12)

  barn:SetScript("OnShow", function() ShowPage(current or "moo") end)
  local acc = 0
  barn:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 1 then return end
    acc = 0
    if current and pages[current].live then ns:RefreshBarn() end
  end)

  -- the achievement engine refreshes the browser when something is earned
  if ns.Ach then
    ns.Ach.RefreshUI = function() if current == "ach" then ns:RefreshBarn() end end
  end
end

function ns:ToggleBarn()
  if not barn then return end
  if barn:IsShown() then barn:Hide() else barn:Show() end
end

function ns:OpenBarn(key)
  if not barn then return end
  barn:Show()
  ShowPage(key)
end
