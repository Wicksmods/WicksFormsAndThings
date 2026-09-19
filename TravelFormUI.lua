-- Wick's Forms and Things
-- TravelFormUI.lua — secure click button + contextual form icon (the former Wick's Travel Form UI)
-- Brand spec: locked palette, 10px L-bracket corners, 1px muted-purple border.
--
-- The secure button is created at file-parse-time (mirroring WicksQuestKey)
-- so it exists before any event handler can reference it. Position and
-- lock state are applied later from saved variables once they're loaded.

local _, ns = ...
local UI = {}
ns.UI = UI

-- =====================================================================
-- Wick brand palette (locked)
-- Fel #4FC778 · Void #0D0A14 · Border #383058 · Off-White #D4C8A1
-- =====================================================================
local C_BG     = { 0.051, 0.039, 0.078, 0.97 }
local C_BORDER = { 0.220, 0.188, 0.345, 1 }
local C_GREEN  = { 0.310, 0.780, 0.471, 1 }
local C_HOVER  = { 0.310, 0.780, 0.471, 0.10 }
local C_MOVE   = { 0.640, 0.210, 0.930, 0.20 }

local BRACKET, ARM = 10, 2

local function newTex(parent, layer, c)
    local t = parent:CreateTexture(nil, layer)
    t:SetColorTexture(unpack(c))
    return t
end

local function addBorder(f)
    local ts = {}
    local t = newTex(f, "BORDER", C_BORDER); t:SetPoint("TOPLEFT");    t:SetPoint("TOPRIGHT");    t:SetHeight(1); ts[#ts+1] = t
    local b = newTex(f, "BORDER", C_BORDER); b:SetPoint("BOTTOMLEFT"); b:SetPoint("BOTTOMRIGHT"); b:SetHeight(1); ts[#ts+1] = b
    local l = newTex(f, "BORDER", C_BORDER); l:SetPoint("TOPLEFT");    l:SetPoint("BOTTOMLEFT");  l:SetWidth(1);  ts[#ts+1] = l
    local r = newTex(f, "BORDER", C_BORDER); r:SetPoint("TOPRIGHT");   r:SetPoint("BOTTOMRIGHT"); r:SetWidth(1);  ts[#ts+1] = r
    return ts
end

local function addCornerAccents(f)
    local ts = {}
    for _, anchor in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
        local h = newTex(f, "OVERLAY", C_GREEN); h:SetPoint(anchor); h:SetSize(BRACKET, ARM); ts[#ts+1] = h
        local v = newTex(f, "OVERLAY", C_GREEN); v:SetPoint(anchor); v:SetSize(ARM, BRACKET); ts[#ts+1] = v
    end
    return ts
end

local function shortBind(key)
    if not key or key == "" then return "" end
    return (key:upper()
        :gsub("ALT%-", "a")
        :gsub("CTRL%-", "c")
        :gsub("SHIFT%-", "s")
        :gsub("NUMPAD", "n")
        :gsub("BUTTON1", "M1")
        :gsub("BUTTON2", "M2")
        :gsub("BUTTON3", "M3")
        :gsub("MOUSEWHEELUP", "MwU")
        :gsub("MOUSEWHEELDOWN", "MwD"))
end

local TF_BINDING = "CLICK WicksTravelFormButton:LeftButton"
local locked = true

-- =====================================================================
-- Button creation (top-level — runs at file load)
-- =====================================================================
-- Architecture: a non-secure `host` Frame owns position, scale, and drag.
-- The secure `btn` (SecureActionButton) fills the host. Blizzard's secure-init
-- pipeline reverts SetSize/SetScale on secure frames during the load sequence;
-- by isolating those properties on the host we avoid that revert entirely.
-- This mirrors how WicksTotemsAndThings persists its bar scale.
local REFERENCE_SIZE = 48
local host = CreateFrame("Frame", "WicksTravelFormHost", UIParent)
host:SetSize(REFERENCE_SIZE, REFERENCE_SIZE)
host:SetFrameStrata("MEDIUM")
host:SetClampedToScreen(true)
host:SetMovable(true)
host:SetPoint("CENTER", UIParent, "CENTER", 0, -120)

local btn = CreateFrame("Button", "WicksTravelFormButton", host, "SecureActionButtonTemplate")
btn:SetAllPoints(host)
-- Mirror the WicksQuestKey pattern: type1=macro, both macrotext attrs
-- set, AnyUp+AnyDown registration. The SAB's internal macro processor
-- handles the cast so the keybind fires the same code path as a click.
btn:SetAttribute("type1", "macro")
btn:RegisterForClicks("AnyUp", "AnyDown")

local bg = newTex(btn, "BACKGROUND", C_BG); bg:SetAllPoints(btn)
local borderTex  = addBorder(btn)
local cornerTex  = addCornerAccents(btn)
btn.chromeTex = { bg }
for _, t in ipairs(borderTex) do btn.chromeTex[#btn.chromeTex+1] = t end
for _, t in ipairs(cornerTex) do btn.chromeTex[#btn.chromeTex+1] = t end

local icon = btn:CreateTexture(nil, "ARTWORK")
icon:SetPoint("TOPLEFT", 4, -4)
icon:SetPoint("BOTTOMRIGHT", -4, 4)
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
btn.icon = icon

local bindLabel = btn:CreateFontString(nil, "OVERLAY")
bindLabel:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
bindLabel:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -3, -3)
bindLabel:SetTextColor(1, 1, 1, 1)
btn.bindLabel = bindLabel

local hover = newTex(btn, "HIGHLIGHT", C_HOVER); hover:SetAllPoints(btn)

local moveTint = newTex(btn, "OVERLAY", C_MOVE); moveTint:SetAllPoints(btn); moveTint:Hide()

-- Drag is wired to the host (which owns position). The button is registered
-- for drag and forwards StartMoving/StopMoving to host so the visual is
-- consistent (you grab the button, the whole thing moves).
btn:RegisterForDrag("LeftButton")
btn:SetScript("OnDragStart", function() if not locked then host:StartMoving() end end)
btn:SetScript("OnDragStop",  function()
    host:StopMovingOrSizing()
    if WicksTravelFormDB then
        local point, _, relativePoint, x, y = host:GetPoint(1)
        WicksTravelFormDB.point, WicksTravelFormDB.relativePoint = point, relativePoint
        WicksTravelFormDB.x, WicksTravelFormDB.y = x, y
    end
end)

btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Wick's Forms and Things", 0.31, 0.78, 0.47)
    local action
    if ns.isInManagedForm then
        if ns.isInManagedForm() then
            action = "Cancel form"
        else
            local predicted = ns.predictForm()
            -- Nothing to predict until the first form is learned.
            action = predicted and ("Will cast: " .. predicted)
                or "No forms learned yet. Cat Form is the first one."
        end
    end
    GameTooltip:AddLine(action or "Initializing...", 0.83, 0.78, 0.63)
    GameTooltip:AddLine(" ")
    if locked then
        GameTooltip:AddLine("Right-click to unlock for drag and resize.", 0.42, 0.35, 0.54)
    else
        GameTooltip:AddLine("Drag to move · scroll to resize · right-click to lock.", 0.42, 0.35, 0.54)
    end
    GameTooltip:Show()
end)
btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Mouse wheel resize while unlocked. Step 4px, clamped 32–96.
btn:EnableMouseWheel(true)
btn:SetScript("OnMouseWheel", function(self, delta)
    if locked then return end
    local cur = (WicksTravelFormDB and WicksTravelFormDB.size) or 48
    local step = (delta > 0) and 4 or -4
    local s = cur + step
    if s < (ns.MIN_SIZE or 32) then s = ns.MIN_SIZE or 32 end
    if s > (ns.MAX_SIZE or 96) then s = ns.MAX_SIZE or 96 end
    if s == cur then return end
    if WicksTravelFormDB then WicksTravelFormDB.size = s end
    UI:ApplySize()
    ApplyBarLayout()
end)

-- HookScript so Blizzard's secure OnClick still runs and fires the
-- macrotext for left-click. Right-click toggles lock.
btn:HookScript("OnClick", function(self, button, down)
    if button == "RightButton" and down and not InCombatLockdown() then
        UI:SetLocked(not locked)
    end
end)

-- Button is visible by default. Non-druid characters get it hidden by
-- Core.lua's class check. This way the button appears even if Activate
-- never runs cleanly — failure mode is "button visible, macro stale"
-- rather than "button missing entirely".

-- =====================================================================
-- Resource bar
-- Two fixed-height segments stacked below the button host.
-- Primary slot (top): rage in Bear, energy in Cat, mana otherwise.
-- Mana slot (bottom): always mana, hidden when primary IS mana.
-- Both bars dim when the form makes them passive.
-- =====================================================================
local BAR_H_DEFAULT      = 5
local BAR_GAP_DEFAULT    = 2
local BAR_MARGIN_DEFAULT = 2

local function barH()       return (WicksTravelFormDB and WicksTravelFormDB.barSegH)      or BAR_H_DEFAULT      end
local function barGap()     return (WicksTravelFormDB and WicksTravelFormDB.barGap)       or BAR_GAP_DEFAULT    end
local function barMargin()  return (WicksTravelFormDB and WicksTravelFormDB.barMargin)    or BAR_MARGIN_DEFAULT end
local function fbarH()      return (WicksTravelFormDB and WicksTravelFormDB.barFloatSegH) or BAR_H_DEFAULT      end
local function fbarGap()    return (WicksTravelFormDB and WicksTravelFormDB.barFloatGap)  or BAR_GAP_DEFAULT    end

local C_RAGE   = { 1.00, 0.49, 0.10, 1 }
local C_ENERGY = { 1.00, 0.82, 0.10, 1 }
local C_MANA   = { 0.31, 0.52, 0.90, 1 }
local C_DIM_BG = { 0.10, 0.10, 0.12, 0.6 }

-- Power type constants (UnitPowerType returns these)
local POWER_MANA   = 0
local POWER_RAGE   = 1
local POWER_ENERGY = 3

-- =====================================================================
-- Shared draw logic — operates on whichever bar frame is passed in.
-- Each bar frame has .priTrack, .priFill, .manaTrack, .manaFill children.
-- =====================================================================
local WHITE = "Interface\\Buttons\\WHITE8X8"
local function makeBar(f)
    local sb = CreateFrame("StatusBar", nil, f)
    sb:SetStatusBarTexture(WHITE)
    sb:SetMinMaxValues(0, 1)
    sb:SetValue(0)
    local bg = sb:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(unpack(C_DIM_BG))
    return sb
end
local function MakeBarChildren(f)
    -- StatusBars, not textures: SetMinMaxValues and SetValue accept secret
    -- values, which is what the player's power is on Forever.
    f.priTrack  = makeBar(f)
    f.manaTrack = makeBar(f)
    f.priFill   = f.priTrack
    f.manaFill  = f.manaTrack
end

-- pad: inset tracks inside the frame on all sides (used by float bar for bracket clearance)
local function LayoutBarChildren(f, w, h, g, pad)
    pad = pad or 0

    f.priTrack:ClearAllPoints()
    f.priTrack:SetPoint("TOPLEFT",  f, "TOPLEFT",   pad, -pad)
    f.priTrack:SetPoint("TOPRIGHT", f, "TOPRIGHT", -pad, -pad)
    f.priTrack:SetHeight(h)

    f.manaTrack:ClearAllPoints()
    f.manaTrack:SetPoint("TOPLEFT",  f, "TOPLEFT",   pad, -(pad + h + g))
    f.manaTrack:SetPoint("TOPRIGHT", f, "TOPRIGHT", -pad, -(pad + h + g))
    f.manaTrack:SetHeight(h)

end

local function setBar(sb, cur, max, color, alpha)
    -- Pass values straight through; never compare or divide them.
    pcall(sb.SetMinMaxValues, sb, 0, max)
    pcall(sb.SetValue, sb, cur)
    sb:SetStatusBarColor(color[1], color[2], color[3], alpha or 1)
end

local function DrawBar(f)
    local powerType = UnitPowerType("player")
    local mana, manaMax = UnitPower("player", POWER_MANA), UnitPowerMax("player", POWER_MANA)

    if powerType == POWER_RAGE then
        setBar(f.priTrack, UnitPower("player", POWER_RAGE), UnitPowerMax("player", POWER_RAGE), C_RAGE, 1)
        setBar(f.manaTrack, mana, manaMax, C_MANA, 0.45)
        f.manaTrack:Show()
    elseif powerType == POWER_ENERGY then
        setBar(f.priTrack, UnitPower("player", POWER_ENERGY), UnitPowerMax("player", POWER_ENERGY), C_ENERGY, 1)
        setBar(f.manaTrack, mana, manaMax, C_MANA, 0.45)
        f.manaTrack:Show()
    else
        local formIndex = GetShapeshiftForm()
        local isMoonkin = false
        if formIndex and formIndex > 0 then
            local formName = GetShapeshiftFormInfo(formIndex)
            isMoonkin = (formName == "Moonkin Form")
        end
        setBar(f.priTrack, mana, manaMax, C_MANA, isMoonkin and 1 or 0.55)
        f.manaTrack:Hide()
    end
end

-- =====================================================================
-- Attached bar — anchored below the button host, width = button size.
-- =====================================================================
local barHost = CreateFrame("Frame", "WicksTravelFormBarHost", UIParent)
barHost:SetFrameStrata("MEDIUM")
barHost:SetClampedToScreen(true)
barHost:Hide()
MakeBarChildren(barHost)

local function ApplyBarLayout()
    if WicksTravelFormDB and WicksTravelFormDB.barEnabled == false then
        barHost:Hide()
        return
    end
    local s = (WicksTravelFormDB and WicksTravelFormDB.size) or 48
    local h = barH()
    local g = barGap()
    local m = barMargin()
    barHost:SetSize(s, h * 2 + g)
    barHost:ClearAllPoints()
    barHost:SetPoint("TOP", host, "BOTTOM", 0, -m)
    LayoutBarChildren(barHost, s, h, g)
    barHost:Show()
    DrawBar(barHost)
end
ns.ApplyBarLayout = ApplyBarLayout

-- =====================================================================
-- Floating bar — independent draggable frame.
-- =====================================================================
local FLOAT_W_DEFAULT = 120

local floatBar = CreateFrame("Frame", "WicksTravelFormFloatBar", UIParent)
floatBar:SetFrameStrata("MEDIUM")
floatBar:SetClampedToScreen(true)
floatBar:SetMovable(true)
floatBar:Hide()
MakeBarChildren(floatBar)

-- Wick border + corner accents on the float bar
addBorder(floatBar)
addCornerAccents(floatBar)

floatBar:EnableMouse(true)
floatBar:RegisterForDrag("LeftButton")
floatBar:SetScript("OnDragStart", function(self)
    if not locked then self:StartMoving() end
end)
floatBar:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if WicksTravelFormDB then
        local _, _, _, x, y = self:GetPoint(1)
        WicksTravelFormDB.barFloatX = x
        WicksTravelFormDB.barFloatY = y
    end
end)

local function ApplyFloatBarLayout()
    if not (WicksTravelFormDB and WicksTravelFormDB.barFloat) then
        floatBar:Hide()
        return
    end
    local w = (WicksTravelFormDB and WicksTravelFormDB.barFloatW) or FLOAT_W_DEFAULT
    local h = fbarH()
    local g = fbarGap()
    local pad = ARM  -- bracket arm thickness = inset amount
    -- frame is larger than the fill area by 2*pad on each axis
    floatBar:SetSize(w + pad * 2, h * 2 + g + pad * 2)
    floatBar:ClearAllPoints()
    local x = (WicksTravelFormDB and WicksTravelFormDB.barFloatX) or 0
    local y = (WicksTravelFormDB and WicksTravelFormDB.barFloatY) or 100
    floatBar:SetPoint("CENTER", UIParent, "CENTER", x, y)
    LayoutBarChildren(floatBar, w, h, g, pad)
    -- store inner width so DrawBar scales fills correctly
    floatBar._innerW = w
    floatBar:Show()
    DrawBar(floatBar)
end
ns.ApplyFloatBarLayout = ApplyFloatBarLayout

-- Throttled OnUpdate drives both bars.
local elapsed = 0
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < 0.05 then return end
    elapsed = 0
    if barHost:IsShown()  then DrawBar(barHost)  end
    if floatBar:IsShown() then DrawBar(floatBar) end
end)

local function UpdateResourceBar()
    if barHost:IsShown()  then DrawBar(barHost)  end
    if floatBar:IsShown() then DrawBar(floatBar) end
end
ns.UpdateResourceBar = UpdateResourceBar

-- =====================================================================
-- Methods
-- =====================================================================
function UI:ApplyPosition()
    if not WicksTravelFormDB then return end
    local db = WicksTravelFormDB
    host:ClearAllPoints()
    host:SetPoint(db.point or "CENTER", UIParent, db.relativePoint or "CENTER",
                  db.x or 0, db.y or -120)
end

function UI:ApplySize()
    local s = (WicksTravelFormDB and WicksTravelFormDB.size) or REFERENCE_SIZE
    local lo, hi = ns.MIN_SIZE or 32, ns.MAX_SIZE or 96
    if s < lo then s = lo end
    if s > hi then s = hi end
    host:SetSize(s, s)
end

function UI:UpdateBindLabel()
    btn.bindLabel:SetText(shortBind(GetBindingKey(TF_BINDING)))
    if WicksTravelFormDB and WicksTravelFormDB.showBind == false then
        btn.bindLabel:Hide()
    else
        btn.bindLabel:Show()
    end
end

function UI:ApplyChrome()
    local show = not (WicksTravelFormDB and WicksTravelFormDB.showChrome == false)
    for _, t in ipairs(btn.chromeTex) do
        if show then t:Show() else t:Hide() end
    end
    btn.icon:ClearAllPoints()
    if show then
        btn.icon:SetPoint("TOPLEFT", 4, -4)
        btn.icon:SetPoint("BOTTOMRIGHT", -4, 4)
        btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    else
        btn.icon:SetAllPoints(btn)
        btn.icon:SetTexCoord(0, 1, 0, 1)
    end
end

function UI:Refresh()
    -- Macrotext can only be set out of combat. The macro itself contains
    -- runtime conditionals so the in-combat behavior is still correct
    -- with whatever was set at the last out-of-combat refresh.
    if not InCombatLockdown() then
        local m = ns.buildMacro()
        btn:SetAttribute("macrotext", m)
        btn:SetAttribute("macrotext1", m)
    end
    local predicted = ns.predictForm()
    btn.icon:SetTexture(ns.formIcon(predicted))
    btn.icon:SetDesaturated(predicted == nil)
    btn.icon:SetAlpha(predicted and 1 or 0.4)
    -- A druid below level eight has no form to shift into, so the button
    -- has nothing to do and stays out of the way until one is learned.
    -- SPELLS_CHANGED brings it back. A protected frame cannot be shown or
    -- hidden in combat, so that is left for the next refresh.
    if not InCombatLockdown() then
        local wanted = predicted ~= nil
        if wanted ~= host:IsShown() then
            host:SetShown(wanted)
            if wanted then btn:Show() end
            ApplyBarLayout()
            ApplyFloatBarLayout()
        end
    end
    self:UpdateBindLabel()
end

function UI:SetLocked(state)
    if InCombatLockdown() then
        print("|cff4FC778Wick's Forms and Things|r: cannot change lock during combat.")
        return
    end
    locked = state
    if WicksTravelFormDB then WicksTravelFormDB.locked = state end
    if locked then moveTint:Hide() else moveTint:Show() end
end

-- Called by Core.lua at PLAYER_LOGIN once we know we're a druid.
function UI:Activate()
    locked = not (WicksTravelFormDB and WicksTravelFormDB.locked == false)
    if locked then moveTint:Hide() else moveTint:Show() end
    self:ApplyPosition()
    self:ApplySize()
    self:ApplyChrome()
    ApplyBarLayout()
    ApplyFloatBarLayout()
    host:Show()
    btn:Show()
    self:Refresh()   -- may hide it again when no form is known yet
end

-- Called when we know the player isn't a druid — hide everything.
function UI:Deactivate()
    host:Hide()
    barHost:Hide()
    floatBar:Hide()
end

-- Build is kept as an alias for /wstf show — same effect as Activate
-- but doesn't depend on having gone through PLAYER_LOGIN cleanly.
function UI:Build()
    self:Activate()
end
