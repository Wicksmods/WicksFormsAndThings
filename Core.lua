-- Wick's Forms and Things
-- Core.lua: WickCore addon object, saved variables, event dispatch, slash command.
--
-- The druid kit for World of Warcraft: Forever. Wick's Travel Form is the
-- heart of it: one secure keybind that resolves to the right form for where
-- you are. Forever has no flying, so the flight clause never fires there
-- and the same code still serves a TBC druid. Through WickCore the kit adds
-- the talent layer, the pre-pull checklist and racials.

local ADDON, ns = ...

local Core = WickCore
assert(Core, "Wick's Forms and Things requires WickCore. Enable the WickCore addon.")
local D, R = Core.Dialect, Core.Restrict

ns.version = "1.0.0"

local PROFILE_DEFAULTS = {
    point = "CENTER", relativePoint = "CENTER", x = 0, y = -120,
    locked       = true,
    size         = 48,
    showBind     = true,
    showChrome   = true,
    barEnabled   = true,
    barSegH      = 5,
    barGap       = 2,
    barMargin    = 2,
    barFloat     = false,
    barFloatW    = 120,
    barFloatSegH = 5,
    barFloatGap  = 2,
    barFloatX    = 0,
    barFloatY    = 100,
    kitWindow    = {},
}

local A = Core:NewAddon("WicksFormsAndThings", {
    title    = "Wick's Forms and Things",
    version  = ns.version,
    savedVar = "WicksFormsSaved",
    defaults = { profile = PROFILE_DEFAULTS, global = {} },
})
ns.A = A
_G.WICKSTRAVELFORM = ns   -- the Travel Form module addresses ns through this

-- TravelForm.lua and TravelFormUI.lua read this name. It is a runtime alias
-- to the WickCore profile, bound in OnInitialize.
WicksTravelFormDB = WicksTravelFormDB or nil

-- ============================================================
-- Event dispatcher used by the Travel Form module
-- ============================================================
local events = {}
function ns:On(event, fn)
    events[event] = events[event] or {}
    table.insert(events[event], fn)
end

local frame = CreateFrame("Frame", "WicksFormsEvents")
ns.eventFrame = frame
frame:SetScript("OnEvent", function(_, event, ...)
    if events[event] then
        for _, fn in ipairs(events[event]) do
            local ok, err = pcall(fn, ...)
            if not ok then A:Print(("error in %s: %s"):format(event, tostring(err))) end
        end
    end
end)
function ns.RegisterEvents(list)
    for _, ev in ipairs(list) do pcall(frame.RegisterEvent, frame, ev) end
end

local _, playerClass = UnitClass("player")
ns.isDruid = playerClass == "DRUID"

-- ============================================================
-- Lifecycle
-- ============================================================
function A:OnInitialize()
    WicksTravelFormDB = self.db.profile
    ns.db = self.db
    self.db:On("OnProfileChanged", function()
        WicksTravelFormDB = self.db.profile
        if ns.UI and ns.UI.Activate and ns.isDruid then ns.UI:Activate() end
    end)

    Core.Cooldowns:New(self, { key = "cooldownBar" })

    Core.Kit:New(self, {
        racials = true,
        checklist = {
            { label = "Mark of the Wild", aura = { "Mark of the Wild", "Gift of the Wild" }, cast = "Mark of the Wild" },
            { label = "Thorns",           aura = "Thorns", cast = "Thorns" },
            { label = "Omen of Clarity",  aura = "Omen of Clarity", cast = "Omen of Clarity", known = 16864 },
            { label = "Rebirth ready",    check = function()
                local cd = D.GetSpellCooldown("Rebirth")
                if not cd then return nil end
                if R:IsSecret(cd.duration) then return nil end
                return (cd.duration or 0) == 0
            end },
        },
    })
end

function A:OnEnable()
    if not ns.isDruid then
        self:Print("loaded (non-druid: viewer mode).")
        if ns.UI and ns.UI.Deactivate then ns.UI:Deactivate() end
    else
        self:Print("loaded. /wft for options, /wft kit for talents and checklist.")
        if ns.Activate then ns.Activate() end
    end

    self:RegisterLauncher({
        onClick = function(_, button)
            if button == "RightButton" then self.kit:Toggle()
            else self:OpenOptions() end
        end,
        tooltip = function(tt)
            tt:AddLine(Core.Chrome:TitleMarkup("Wick's Forms and Things"))
            tt:AddLine("Left-click: options   Right-click: talents and checklist", 0.5, 0.5, 0.5)
        end,
    })

    if self.cooldowns then self.cooldowns:Init() end

    self:RegisterOptions(function(page, addon)
        local O = Core.Options
        local db = WicksTravelFormDB
        local y = O:Heading(page, "Travel form button", 0)
        y = O:Check(page, "Lock position", function() return db.locked ~= false end,
            function(v) if ns.UI then ns.UI:SetLocked(v) end end, y)
        y = O:Check(page, "Show keybind label", function() return db.showBind ~= false end,
            function(v) db.showBind = v; if ns.UI then ns.UI:UpdateBindLabel() end end, y)
        y = O:Check(page, "Show button chrome", function() return db.showChrome ~= false end,
            function(v) db.showChrome = v; if ns.UI then ns.UI:ApplyChrome() end end, y)
        y = O:Check(page, "Attached resource bar", function() return db.barEnabled ~= false end,
            function(v) db.barEnabled = v; if ns.ApplyBarLayout then ns.ApplyBarLayout() end end, y)
        y = O:Check(page, "Floating resource bar", function() return db.barFloat == true end,
            function(v) db.barFloat = v; if ns.ApplyFloatBarLayout then ns.ApplyFloatBarLayout() end end, y)
        y = O:Note(page, "Size and bar geometry: /wft size <32-96>, /wft bar. Right-click the button to unlock and drag.", y)
        y = O:Button(page, "Open kit", function() addon.kit:Toggle() end, y, 100)
        if addon.cooldowns then y = addon.cooldowns:OptionRow(page, y - 6) end
        y = O:ProfileSection(page, addon, y - 8)
    end)
end

-- ============================================================
-- Slash command
-- ============================================================
BINDING_HEADER_WICKSTRAVELFORM = "Wick's Forms and Things"
_G["BINDING_NAME_CLICK WicksTravelFormButton:LeftButton"] = "Smart travel form"

A:RegisterSlash(function(_, msg)
    msg = (msg or ""):lower()
    if msg == "kit" or msg == "talents" or msg == "checklist" then A.kit:Toggle() return end
    if msg == "cd" or msg:match("^cd%s") then return A.cooldowns:Command(msg:match("^%a+%s*(.*)$")) end
    if msg == "options" or msg == "config" then A:OpenOptions() return end
    if not ns.isDruid then A:Print("druids only.") return end
    local db = WicksTravelFormDB
    if msg == "unlock" or msg == "move" then if ns.UI then ns.UI:SetLocked(false) end return end
    if msg == "lock" then if ns.UI then ns.UI:SetLocked(true) end return end
    if msg == "reset" then
        db.point, db.relativePoint, db.x, db.y, db.size = "CENTER", "CENTER", 0, -120, 48
        if ns.UI then ns.UI:ApplyPosition(); ns.UI:ApplySize() end
        if ns.ApplyBarLayout then ns.ApplyBarLayout() end
        return
    end
    if msg:match("^size") then
        local n = tonumber(msg:match("^size%s+(%S+)") or "")
        if not n then A:Print(("current size %d. Use /wft size <%d-%d>."):format(db.size or 48, ns.MIN_SIZE, ns.MAX_SIZE)) return end
        db.size = math.max(ns.MIN_SIZE, math.min(ns.MAX_SIZE, n))
        if ns.UI then ns.UI:ApplySize() end
        if ns.ApplyBarLayout then ns.ApplyBarLayout() end
        return
    end
    if msg == "debug" then
        A:Print(("zone %s  swimming %s  outdoors %s  combat %s"):format(tostring(GetRealZoneText and GetRealZoneText() or "?"),
            tostring(IsSwimming()), tostring(IsOutdoors()), tostring(InCombatLockdown())))
        A:Print("flight form: " .. tostring(ns.bestFlightForm()) .. "   predicted: " .. tostring(ns.predictForm()))
        A:Print("macro: " .. (ns.buildMacro():gsub("\n", " | ")))
        return
    end
    if msg == "show" then if ns.UI then ns.UI:Build() end return end
    if msg:match("^bar") then
        local key, val = msg:match("^bar%s+(%S+)%s*(%S*)")
        local n = tonumber(val)
        local function relayout() if ns.ApplyBarLayout then ns.ApplyBarLayout() end if ns.ApplyFloatBarLayout then ns.ApplyFloatBarLayout() end end
        if key == "toggle" or key == "t" then db.barEnabled = not (db.barEnabled ~= false); relayout(); return end
        if key == "float" or key == "f" then db.barFloat = not db.barFloat; relayout(); return end
        if (key == "width" or key == "w") and n then db.barFloatW = math.max(40, math.min(600, n)); relayout(); return end
        if (key == "height" or key == "h") and n then db.barSegH = math.max(2, math.min(20, n)); relayout(); return end
        if (key == "gap" or key == "g") and n then db.barGap = math.max(0, math.min(10, n)); relayout(); return end
        if (key == "margin" or key == "m") and n then db.barMargin = math.max(0, math.min(20, n)); relayout(); return end
        if (key == "fheight" or key == "fh") and n then db.barFloatSegH = math.max(2, math.min(20, n)); relayout(); return end
        if (key == "fgap" or key == "fg") and n then db.barFloatGap = math.max(0, math.min(10, n)); relayout(); return end
        A:Print("bar toggle | float | width <40-600> | height <2-20> | gap <0-10> | margin <0-20> | fheight | fgap")
        return
    end
    A:Print("commands: kit | options | unlock | lock | reset | size <N> | bar | debug | show")
end, "/wft", "/wforms", "/wstf")
