-- MooHelper: the Moo button, combo popups, kodo rain, toasts and the options panel

local _, ns = ...

local KODO = "Interface\\Icons\\Ability_Mount_Kodo_01"
local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

---------------------------------------------------------------------------
-- The Moo button
---------------------------------------------------------------------------

local button

local function SaveButtonPosition()
  local point, _, relPoint, x, y = button:GetPoint()
  ns.db.buttonPos = { point = point, relPoint = relPoint, x = x, y = y }
end

local function CreateButton()
  button = CreateFrame("Button", "MooHelperButton", UIParent, BACKDROP_TEMPLATE)
  button:SetSize(72, 72)
  button:SetFrameStrata("MEDIUM")
  button:SetMovable(true)
  button:SetClampedToScreen(true)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  local pos = ns.db.buttonPos
  if pos then
    button:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
  else
    button:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
  end
  if button.SetBackdrop then
    button:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14 })
    button:SetBackdropBorderColor(1, 0.82, 0.2, 1)
  end

  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetPoint("TOPLEFT", 4, -4)
  button.icon:SetPoint("BOTTOMRIGHT", -4, 4)
  button.icon:SetTexture(KODO)
  button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  button.label:SetPoint("BOTTOM", 0, -18)
  button.label:SetText("MOO")

  button:SetScript("OnClick", function(_, mouse)
    if mouse == "RightButton" then
      ns:ToggleOptions()
    elseif IsShiftKeyDown() then
      ns:MooAtTarget()
    else
      ns:Moo()
    end
    button.bounce = 0
  end)
  button:SetScript("OnDragStart", function(self) self:StartMoving() end)
  button:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() SaveButtonPosition() end)
  button:SetScript("OnUpdate", function(self, elapsed)
    if not self.bounce then return end
    self.bounce = self.bounce + elapsed
    local t = self.bounce / 0.25
    if t >= 1 then
      self.bounce = nil
      self:SetScale(ns.db.buttonScale)
    else
      self:SetScale(ns.db.buttonScale * (1 + 0.25 * math.sin(t * math.pi)))
    end
  end)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("MOO")
    GameTooltip:AddLine("Click: moo in every selected channel", 1, 1, 1)
    GameTooltip:AddLine("Shift-click: /moo at your target", 1, 1, 1)
    GameTooltip:AddLine("Right-click: options   Drag: move", 1, 1, 1)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function ns:UpdateButton()
  if not button then return end
  button:SetScale(self.db.buttonScale)
  -- the Golden Moo Button upgrade from the Moo Shop
  if self.HasUpgrade and self:HasUpgrade("golden") then
    button.icon:SetVertexColor(1, 0.85, 0.2)
    if button.SetBackdropBorderColor then button:SetBackdropBorderColor(1, 0.9, 0.1, 1) end
    button.label:SetText("|cffffd700MOO|r")
  else
    button.icon:SetVertexColor(1, 1, 1)
  end
  if self.db.hideButton then button:Hide() else button:Show() end
end

---------------------------------------------------------------------------
-- Combo popup
---------------------------------------------------------------------------

local comboFrame
local COMBO_COLORS = { { 1, 1, 1 }, { 1, 0.82, 0 }, { 1, 0.5, 0 }, { 1, 0.15, 0.15 }, { 0.8, 0.3, 1 } }

local function CreateCombo()
  comboFrame = CreateFrame("Frame", nil, UIParent)
  comboFrame:SetSize(600, 80)
  comboFrame:SetPoint("TOP", 0, -110)
  comboFrame:SetFrameStrata("HIGH")
  comboFrame:EnableMouse(false)
  comboFrame.text = comboFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  comboFrame.text:SetPoint("CENTER")
  comboFrame:Hide()
  comboFrame:SetScript("OnUpdate", function(self, elapsed)
    self.t = self.t + elapsed
    local pop = math.min(self.t / 0.12, 1)
    self:SetScale(self.base * (1.6 - 0.6 * pop))
    if self.t > 1.2 then
      local a = 1 - (self.t - 1.2) / 0.5
      if a <= 0 then self:Hide() else self:SetAlpha(a) end
    end
  end)
end

function ns:ShowCombo(n)
  if not self.db.effects.combo or not comboFrame then return end
  local text
  if n <= 1 then text = "MOO!"
  elseif n < 5 then text = ("MOO x%d"):format(n)
  elseif n < 10 then text = ("MOO COMBO x%d!"):format(n)
  elseif n < 25 then text = ("MEGA MOO COMBO x%d!!"):format(n)
  else text = ("UNSTOPPABLE STAMPEDE x%d!!!"):format(n) end
  local c = COMBO_COLORS[math.min(1 + math.floor(n / 5), #COMBO_COLORS)]
  comboFrame.text:SetText(text)
  comboFrame.text:SetTextColor(c[1], c[2], c[3])
  comboFrame.base = math.min(1 + n * 0.04, 2.2)
  comboFrame.t = 0
  comboFrame:SetAlpha(1)
  comboFrame:Show()
end

---------------------------------------------------------------------------
-- Kodo rain
---------------------------------------------------------------------------

local rainFrame
local drops, pool = {}, {}

local function CreateRain()
  rainFrame = CreateFrame("Frame", nil, UIParent)
  rainFrame:SetAllPoints(UIParent)
  rainFrame:SetFrameStrata("HIGH")
  rainFrame:EnableMouse(false)
  rainFrame:SetScript("OnUpdate", function(_, elapsed)
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    for i = #drops, 1, -1 do
      local d = drops[i]
      d.x = d.x + d.vx * elapsed
      d.y = d.y + d.vy * elapsed
      d.angle = d.angle + d.spin * elapsed
      d.tex:ClearAllPoints()
      d.tex:SetPoint("CENTER", UIParent, "BOTTOMLEFT", d.x, d.y)
      if d.tex.SetRotation then d.tex:SetRotation(d.angle) end
      if d.y < -60 or d.y > h + 200 or d.x > w + 100 then
        d.tex:Hide()
        table.insert(pool, d.tex)
        table.remove(drops, i)
      end
    end
    if #drops == 0 then rainFrame:Hide() end
  end)
  rainFrame:Hide()
end

function ns:CowRain(count)
  if not rainFrame or not self.db.effects.cowRain then return end
  local w, h = UIParent:GetWidth(), UIParent:GetHeight()
  for _ = 1, math.min(count or 10, 40 - #drops) do
    local tex = table.remove(pool) or rainFrame:CreateTexture(nil, "OVERLAY")
    tex:SetTexture(KODO)
    local size = math.random(28, 64)
    tex:SetSize(size, size)
    tex:Show()
    drops[#drops + 1] = {
      tex = tex, x = math.random() * w, y = h + math.random(20, 180),
      vx = 0, vy = -math.random(220, 520), angle = math.random() * 6.28, spin = (math.random() - 0.5) * 6,
    }
  end
  rainFrame:Show()
end

-- A herd of kodos thundering across the bottom of the screen
function ns:Stampede(count)
  if not rainFrame or not self.db.effects.stampede then return end
  local h = UIParent:GetHeight()
  for _ = 1, math.min(count or 12, 40 - #drops) do
    local tex = table.remove(pool) or rainFrame:CreateTexture(nil, "OVERLAY")
    tex:SetTexture(KODO)
    local size = math.random(40, 80)
    tex:SetSize(size, size)
    tex:Show()
    drops[#drops + 1] = {
      tex = tex, x = -math.random(60, 600), y = math.random(60, math.floor(h * 0.35)),
      vx = math.random(380, 700), vy = 0, angle = 0, spin = 0,
    }
  end
  rainFrame:Show()
end

---------------------------------------------------------------------------
-- Moo-vision: a quick cow-print flash over the whole screen
---------------------------------------------------------------------------

local vision
local function CreateVision()
  vision = CreateFrame("Frame", nil, UIParent)
  vision:SetAllPoints(UIParent)
  vision:SetFrameStrata("FULLSCREEN")
  vision:EnableMouse(false)
  vision.base = vision:CreateTexture(nil, "BACKGROUND")
  vision.base:SetAllPoints()
  vision.base:SetColorTexture(1, 1, 1, 0.18)
  vision.spots = {}
  for i = 1, 14 do
    local spot = vision:CreateTexture(nil, "ARTWORK")
    spot:SetColorTexture(0.05, 0.05, 0.05, 0.45)
    vision.spots[i] = spot
  end
  vision:Hide()
  vision:SetScript("OnUpdate", function(self, elapsed)
    self.t = self.t + elapsed
    local a = 1 - self.t / 1.4
    if a <= 0 then self:Hide() else self:SetAlpha(a) end
  end)
end

function ns:MooVision()
  if not vision or not self.db.effects.mooVision then return end
  local w, h = UIParent:GetWidth(), UIParent:GetHeight()
  for _, spot in ipairs(vision.spots) do
    spot:ClearAllPoints()
    spot:SetSize(math.random(80, 260), math.random(60, 200))
    spot:SetPoint("CENTER", UIParent, "BOTTOMLEFT", math.random() * w, math.random() * h)
  end
  vision.t = 0
  vision:SetAlpha(1)
  vision:Show()
end

---------------------------------------------------------------------------
-- Toasts (queued, so several in a row don't overwrite each other)
---------------------------------------------------------------------------

local toast
local toastQueue = {}

local function ShowNextToast()
  local item = table.remove(toastQueue, 1)
  if not item then return end
  toast.icon:SetTexture(item.icon or KODO)
  toast.title:SetText(item.title)
  toast.text:SetText(item.text)
  toast.points:SetText(item.points and item.points > 0 and tostring(item.points) or "")
  toast.t = 0
  toast:SetAlpha(1)
  toast:Show()
  if ns.CowRain then ns:CowRain(item.rain or 12) end
end

local function CreateToast()
  toast = CreateFrame("Button", "MooHelperToast", UIParent, BACKDROP_TEMPLATE)
  toast:SetSize(360, 70)
  toast:SetPoint("TOP", 0, -190)
  toast:SetFrameStrata("DIALOG")
  if toast.SetBackdrop then
    toast:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
      insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    toast:SetBackdropColor(0.16, 0.1, 0.04, 0.96)
    toast:SetBackdropBorderColor(1, 0.82, 0.2, 1)
  end
  -- cow-print strip along the top edge
  for i = 1, 6 do
    local spot = toast:CreateTexture(nil, "BORDER")
    spot:SetColorTexture(0.95, 0.93, 0.86, 0.9)
    spot:SetSize(18 + (i % 3) * 10, 5)
    spot:SetPoint("TOPLEFT", 12 + (i - 1) * 56, -4)
  end
  toast.icon = toast:CreateTexture(nil, "ARTWORK")
  toast.icon:SetSize(46, 46)
  toast.icon:SetPoint("LEFT", 12, -2)
  toast.title = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  toast.title:SetPoint("TOPLEFT", toast.icon, "TOPRIGHT", 10, -2)
  toast.text = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  toast.text:SetPoint("TOPLEFT", toast.title, "BOTTOMLEFT", 0, -4)
  toast.text:SetWidth(230)
  toast.text:SetJustifyH("LEFT")
  toast.points = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
  toast.points:SetPoint("RIGHT", -16, 0)
  toast:Hide()
  toast:SetScript("OnClick", function(self)
    self:Hide()
    if ns.OpenBarn and self.openTab then ns:OpenBarn(self.openTab) end
    ShowNextToast()
  end)
  toast:SetScript("OnUpdate", function(self, elapsed)
    self.t = self.t + elapsed
    if self.t > 3.5 then
      local a = 1 - (self.t - 3.5) / 0.6
      if a <= 0 then self:Hide() ShowNextToast() else self:SetAlpha(a) end
    end
  end)
end

function ns:Toast(title, text, icon, points)
  if not toast then return end
  table.insert(toastQueue, { title = title, text = text, icon = icon, points = points })
  if #toastQueue > 6 then table.remove(toastQueue, 1) end
  if not toast:IsShown() then ShowNextToast() end
end

-- the achievement engine calls this when you earn one
function ns:AchievementToast(a)
  if not toast then return end
  toast.openTab = "ach"
  self:Toast("MOO-CHIEVEMENT EARNED", a.name, a.icon, a.points)
end

---------------------------------------------------------------------------
-- Entry points
---------------------------------------------------------------------------

function ns:ToggleOptions() if self.ToggleBarn then self:ToggleBarn() end end
function MooHelper_OnAddonCompartmentClick() ns:ToggleBarn() end

function ns:CreateVisuals()
  CreateButton()
  CreateCombo()
  CreateRain()
  CreateVision()
  CreateToast()
  if self.CreateBarn then self:CreateBarn() end
  self:UpdateButton()
end
