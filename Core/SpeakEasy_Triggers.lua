-- Game events: loading, combat end for queued macro renames, and the triggers
-- that play a scene by themselves.
local ADDON, L = ...

L.Triggers = {}

-- Runtime only: /speakeasy debug prints why each trigger does or does not fire.
L.Triggers.debug = false

-- input: a message format and its values
-- output: nothing
-- Prints a debug message when trigger debugging is on.
local function Debug(message, ...)
    if L.Triggers.debug then
        L.Util.Print(L.Text.DEBUG_PREFIX .. message:format(...))
    end
end

-- input: true to turn trigger debugging on
-- output: nothing
-- Turns trigger debugging on or off and says which.
function L.Triggers.SetDebug(on)
    L.Triggers.debug = on and true or false
    L.Util.Print(on and L.Text.DEBUG_ON or L.Text.DEBUG_OFF)
end

-- Per trigger runtime state, keyed by the trigger table.
local lastFired = setmetatable({}, { __mode = "k" })
local wasBelow = setmetatable({}, { __mode = "k" })
local lastAny = -math.huge

local loaded = false
local wasMounted, wasResting

-- input: a trigger and the event context
-- output: true when this occurrence of the event applies to the trigger
-- Checks a trigger's options against the event.
local function Matches(trigger, context)
    -- Low health fires once per drop below the threshold, not on every tick under it.
    if trigger.event == "LOW_HEALTH" then
        local below = context.health < trigger.options.threshold
        local fire = below and not wasBelow[trigger]
        wasBelow[trigger] = below
        return fire
    end

    if trigger.event == "SPELL_CAST" then
        local wanted = trigger.options.spell
        return wanted ~= nil and context.spellName ~= nil and wanted:lower() == context.spellName:lower()
    end

    return true
end

-- input: an event name from L.Db.EVENTS and a context table
-- output: nothing
-- Plays the first matching trigger that passes its cooldown and chance roll,
-- at most one line per globalTriggerGap seconds across every trigger.
function L.Triggers.Fire(kind, context)
    context = context or {}
    local settings = L.Db.Settings()
    local now = GetTime()

    -- Matched for every trigger first, so low health state stays current even
    -- while muted or inside the global gap.
    local candidates = {}
    for _, trigger in ipairs(L.Db.Set().triggers) do
        if trigger.event == kind and Matches(trigger, context) and trigger.enabled then
            candidates[#candidates + 1] = trigger
        end
    end

    -- Spells are reported even with no trigger, to show they were seen.
    if #candidates > 0 or kind == "SPELL_CAST" then
        Debug(L.Text.DEBUG_EVENT, L.Text["EVENT_" .. kind] or kind, L.Util.Escape(context.spellName or ""), #candidates)
    end

    if #candidates == 0 then
        return
    end

    if settings.triggersMuted then
        Debug(L.Text.DEBUG_MUTED)
        return
    end

    if now - lastAny < settings.globalTriggerGap then
        Debug(L.Text.DEBUG_GAP, math.ceil(settings.globalTriggerGap - (now - lastAny)))
        return
    end

    for _, trigger in ipairs(candidates) do
        local name = L.Editors.EventText(trigger)
        local wait = lastFired[trigger] and trigger.cooldown - (now - lastFired[trigger]) or 0
        local roll = math.random(100)
        local scene = L.Db.FindScene(trigger.sceneId)
        if wait > 0 then
            Debug(L.Text.DEBUG_COOLDOWN, name, math.ceil(wait))
        elseif roll > trigger.chance then
            Debug(L.Text.DEBUG_CHANCE, name, roll, trigger.chance)
        elseif not scene then
            Debug(L.Text.DEBUG_NO_SCENE, name)
        else
            -- The cast only names the spell; the trigger knows which item it was.
            context.itemName = trigger.options.item
            local played, why = L.Play.Scene(scene, context, true)
            if played then
                Debug(why == "primed" and L.Text.DEBUG_PRIMED or L.Text.DEBUG_SENT, name)
                lastFired[trigger] = now
                lastAny = now
                return
            end

            Debug(L.Text.DEBUG_SCENE, name, L.Util.Escape(scene.name), L.Text["DEBUG_WHY_" .. why] or why)
        end
    end
end

-- input: true to mute every trigger
-- output: nothing
-- Mutes or unmutes every trigger and refreshes the window.
function L.Triggers.SetMuted(muted)
    L.Db.Settings().triggersMuted = muted and true or false
    L.Util.Print(muted and L.Text.MSG_MUTED or L.Text.MSG_UNMUTED)
    L.Window.Refresh()
end

-- input: an event name from L.Db.EVENTS
-- output: an event handler that fires it with no context
-- Builds a handler for events that need no checks of their own.
local function Fire(kind)
    return function()
        L.Triggers.Fire(kind)
    end
end

-- input: the unit whose health changed
-- output: nothing
-- Fires low health triggers with your current health.
local function Health(unit)
    if unit == "player" then
        local percent = L.Compat.HealthPercent()
        if percent then
            L.Triggers.Fire("LOW_HEALTH", { health = percent })
        end
    end
end

-- input: nothing
-- output: nothing
-- Fires mount triggers when you go from on foot to mounted.
local function Mount()
    local mounted = IsMounted() and true or false
    if mounted and not wasMounted then
        L.Triggers.Fire("MOUNT")
    end

    wasMounted = mounted
end

-- input: the name of the addon that loaded
-- output: nothing
-- Loads the saved variables once this addon has loaded.
local function HandleAddonLoaded(name)
    if name == ADDON then
        L.Db.Load()
        loaded = true
    end
end

-- input: nothing
-- output: nothing
-- Records the starting mount and rest state, then sets up the minimap button, key listener and scene buttons.
local function HandlePlayerLogin()
    wasMounted = IsMounted() and true or false
    wasResting = IsResting() and true or false
    L.Window.CreateMinimapButton()
    L.Prime.ListenForKeys()
    L.Macro.UpdateAll()
end

-- input: nothing
-- output: nothing
-- Makes the queued macro renames and fires leave combat triggers.
local function HandleRegenEnabled()
    L.Macro.Flush()
    -- After a /reload in combat, the key listener waits until now.
    L.Prime.ListenForKeys()
    L.Triggers.Fire("LEAVE_COMBAT")
end

-- input: the casting unit, the cast id and the spell id
-- output: nothing
-- Fires spell cast triggers for your own casts.
local function HandleSpellcastSucceeded(unit, _, spellID)
    if unit == "player" and spellID then
        L.Triggers.Fire("SPELL_CAST", { spellName = L.Compat.SpellName(spellID) })
    end
end

-- input: the unit whose auras changed
-- output: nothing
-- Checks for a mount when your own auras change.
local function HandleUnitAura(unit)
    if unit == "player" then
        Mount()
    end
end

-- input: nothing
-- output: nothing
-- Fires rest area triggers when you enter a rest area.
local function HandleUpdateResting()
    local resting = IsResting() and true or false
    if resting and not wasResting then
        L.Triggers.Fire("REST_AREA")
    end

    wasResting = resting
end

-- input: nothing
-- output: nothing
-- Fires target triggers when you target a living non player character.
local function HandleTargetChanged()
    if UnitExists("target") and not UnitIsPlayer("target") and not UnitIsDead("target") then
        L.Triggers.Fire("TARGET_NPC")
    end
end

local handlers = {
    ADDON_LOADED = HandleAddonLoaded,
    PLAYER_LOGIN = HandlePlayerLogin,
    PLAYER_REGEN_DISABLED = Fire("ENTER_COMBAT"),
    PLAYER_REGEN_ENABLED = HandleRegenEnabled,
    UNIT_HEALTH = Health,
    UNIT_HEALTH_FREQUENT = Health,
    PLAYER_DEAD = Fire("DEATH"),
    UNIT_SPELLCAST_SUCCEEDED = HandleSpellcastSucceeded,
    PLAYER_MOUNT_DISPLAY_CHANGED = Mount,
    UNIT_AURA = HandleUnitAura,
    PLAYER_UPDATE_RESTING = HandleUpdateResting,
    PLAYER_TARGET_CHANGED = HandleTargetChanged,
}

-- Unit events only for the player, where the client supports filtering them.
local PLAYER_EVENTS = { UNIT_HEALTH = true, UNIT_HEALTH_FREQUENT = true, UNIT_SPELLCAST_SUCCEEDED = true, UNIT_AURA = true }

local frame = CreateFrame("Frame")
for event in pairs(handlers) do
    -- Not every event exists on every client; registering a missing one errors.
    if PLAYER_EVENTS[event] and frame.RegisterUnitEvent then
        pcall(frame.RegisterUnitEvent, frame, event, "player")
    else
        pcall(frame.RegisterEvent, frame, event)
    end
end

frame:SetScript("OnEvent", L.Util.Safe(function(_, event, ...)
    if loaded or event == "ADDON_LOADED" then
        handlers[event](...)
    end
end))
