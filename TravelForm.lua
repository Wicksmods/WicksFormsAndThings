-- Wick's Forms and Things
-- TravelForm.lua: form decision logic and macro builder (the former Wick's
-- Travel Form Core). Saved variables, events and the slash command moved to
-- Core.lua on WickCore; this file keeps the part that decides which form.

local ADDON, ns = ...
local D = WickCore.Dialect

ns.MIN_SIZE, ns.MAX_SIZE = 32, 96

-- =====================================================================
-- Druid forms (enUS spell names — used directly in macro text)
-- =====================================================================
ns.FORMS = {
    AQUATIC = "Aquatic Form",
    TRAVEL  = "Travel Form",
    CAT     = "Cat Form",
    FLIGHT  = "Flight Form",
    SWIFT   = "Swift Flight Form",
}

local FORM_SPELL_ID = {
    [ns.FORMS.AQUATIC] = 1066,
    [ns.FORMS.TRAVEL]  = 783,
    [ns.FORMS.CAT]     = 768,
    [ns.FORMS.FLIGHT]  = 33943,
    [ns.FORMS.SWIFT]   = 40120,
}

function ns.formIcon(name)
    return D.GetSpellTexture(FORM_SPELL_ID[name] or 0)
end

-- =====================================================================
-- IsFlyableArea() reports incorrectly for Azeroth zones in TBC, so we
-- maintain our own whitelist. enUS-only for now.
-- =====================================================================
local FLYABLE_ZONES = {
    ["Hellfire Peninsula"]     = true,
    ["Zangarmarsh"]            = true,
    ["Terokkar Forest"]        = true,
    ["Nagrand"]                = true,
    ["Blade's Edge Mountains"] = true,
    ["Netherstorm"]            = true,
    ["Shadowmoon Valley"]      = true,
    ["Isle of Quel'Danas"]     = true,
}

-- Shattrath is flagged indoors by WoW but flying is allowed there.
-- These zones need the flight clause without the [outdoors] conditional.
local FLYABLE_INDOOR_ZONES = {
    ["Shattrath City"] = true,
}

function ns.isFlyableZone()
    local zone = GetRealZoneText()
    return zone and (FLYABLE_ZONES[zone] == true or FLYABLE_INDOOR_ZONES[zone] == true)
end

function ns.isFlyableIndoorZone()
    local zone = GetRealZoneText()
    return zone and FLYABLE_INDOOR_ZONES[zone] == true
end

-- =====================================================================
-- Cached best flight form. Refreshed on SPELLS_CHANGED so we don't scan
-- the spellbook every press.
-- =====================================================================
local cachedFlightForm = nil

local function scanFlightForm()
    -- Forever has no flying and no flight forms; this returns nil there and
    -- the macro never gains a flight clause.
    if D.IsSpellKnown(FORM_SPELL_ID[ns.FORMS.SWIFT]) then return ns.FORMS.SWIFT end
    if D.IsSpellKnown(FORM_SPELL_ID[ns.FORMS.FLIGHT]) then return ns.FORMS.FLIGHT end
    if GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName then
        local best = nil
        for tab = 1, GetNumSpellTabs() do
            local _, _, offset, num = GetSpellTabInfo(tab)
            for i = offset + 1, offset + num do
                local n = GetSpellBookItemName(i, BOOKTYPE_SPELL or "spell")
                if n == ns.FORMS.SWIFT then return ns.FORMS.SWIFT end
                if n == ns.FORMS.FLIGHT then best = ns.FORMS.FLIGHT end
            end
        end
        return best
    end
    return nil
end

function ns.bestFlightForm()
    return cachedFlightForm
end

-- =====================================================================
-- Predict which form a press will resolve to (used for the icon preview
-- and tooltip — the actual cast resolution is done by the macro itself).
-- =====================================================================
function ns.predictForm()
    if IsSwimming() then return ns.FORMS.AQUATIC end
    local fly = ns.bestFlightForm()
    if fly and ns.isFlyableIndoorZone() and not InCombatLockdown() then
        return fly
    end
    if IsOutdoors() then
        if fly and ns.isFlyableZone() and not InCombatLockdown() then
            return fly
        end
        return ns.FORMS.TRAVEL
    end
    return ns.FORMS.CAT
end

local MANAGED_SPELL_IDS = {
    [1066]  = true,  -- Aquatic Form
    [783]   = true,  -- Travel Form
    [33943] = true,  -- Flight Form
    [40120] = true,  -- Swift Flight Form
    [768]   = true,  -- Cat Form
}

local FORM_SPELL_TO_NAME = {
    [1066]  = ns.FORMS.AQUATIC,
    [783]   = ns.FORMS.TRAVEL,
    [33943] = ns.FORMS.FLIGHT,
    [40120] = ns.FORMS.SWIFT,
    [768]   = ns.FORMS.CAT,
}

-- Returns the spell name of the current managed form, or nil if not in one.
function ns.currentManagedForm()
    local formIndex = GetShapeshiftForm()
    if formIndex == 0 then return nil end
    local _, _, _, spellId = GetShapeshiftFormInfo(formIndex)
    return FORM_SPELL_TO_NAME[spellId]
end

function ns.isInManagedForm()
    return ns.currentManagedForm() ~= nil
end

function ns.isFlying()
    local formIndex = GetShapeshiftForm()
    if formIndex == 0 then return false end
    local _, _, _, spellId = GetShapeshiftFormInfo(formIndex)
    return spellId == 33943 or spellId == 40120
end

-- =====================================================================
-- Build the macrotext. The macro itself runs the swim / outdoors /
-- combat conditional checks at click time — those are cheap and always
-- correct. Lua only decides whether to inject the flight clause based
-- on zone + spellbook (rare events), so we don't need any polling.
-- =====================================================================
function ns.buildMacro()
    -- Only /cancelform when the predicted cast would be the same form we're already
    -- in (powershift prevention). Cross-form transitions (e.g. Cat -> Flight) work
    -- with a direct /cast — TBC transitions the form in a single GCD.
    local current = ns.currentManagedForm()
    if current and current == ns.predictForm() then
        return "/cancelform"
    end
    local clauses = { "[swimming] " .. ns.FORMS.AQUATIC }
    local fly = ns.bestFlightForm()
    if fly then
        if ns.isFlyableIndoorZone() then
            -- Shattrath and similar: flyable but IsOutdoors() returns false.
            table.insert(clauses, ("[nocombat] %s"):format(fly))
        elseif ns.isFlyableZone() then
            table.insert(clauses, ("[nocombat,outdoors] %s"):format(fly))
        end
    end
    table.insert(clauses, "[outdoors] " .. ns.FORMS.TRAVEL)
    table.insert(clauses, ns.FORMS.CAT)
    return "/cast " .. table.concat(clauses, "; ")
end

-- =====================================================================
-- Activation: Core.lua calls ns.Activate() on enable for druids.
-- =====================================================================
local activated = false
function ns.Activate()
    if activated then return end
    activated = true
    ns.RegisterEvents({
        "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED",
        "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
        "UPDATE_SHAPESHIFT_FORM", "SPELLS_CHANGED", "UPDATE_BINDINGS",
        "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "PLAYER_ENTERING_WORLD",
    })
    cachedFlightForm = scanFlightForm()
    if ns.UI and ns.UI.Activate then ns.UI:Activate() end
end

local function refresh() if ns.UI and ns.UI.Refresh then ns.UI:Refresh() end end

ns:On("PLAYER_ENTERING_WORLD", refresh)
ns:On("SPELLS_CHANGED",        function() cachedFlightForm = scanFlightForm(); refresh() end)
ns:On("ZONE_CHANGED_NEW_AREA", refresh)
ns:On("ZONE_CHANGED_INDOORS",  refresh)
ns:On("ZONE_CHANGED",          refresh)
ns:On("PLAYER_REGEN_DISABLED", refresh)
ns:On("PLAYER_REGEN_ENABLED",  refresh)
ns:On("UPDATE_SHAPESHIFT_FORM", function()
    refresh()
    if ns.ApplyBarLayout      then ns.ApplyBarLayout()      end
    if ns.ApplyFloatBarLayout then ns.ApplyFloatBarLayout() end
end)
ns:On("UPDATE_BINDINGS",       function() if ns.UI and ns.UI.UpdateBindLabel then ns.UI:UpdateBindLabel() end end)
ns:On("UNIT_POWER_UPDATE",     function(unit) if unit == "player" and ns.UpdateResourceBar then ns.UpdateResourceBar() end end)
ns:On("UNIT_MAXPOWER",         function(unit) if unit == "player" and ns.UpdateResourceBar then ns.UpdateResourceBar() end end)
