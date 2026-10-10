-- Picking the next line (shuffle bag), filling in variables, sending it, and /speakeasy.
local ADDON, L = ...

L.Play = {}

-- "No lines" and "disabled" notices repeat at most this often per scene.
local NOTICE_GAP = 10

-- Runtime only, rebuilt after /reload: bags[sceneId] = { remaining = { lineIndex, ... }, last = lineIndex }
local bags = {}
local lastPlayed = {}
local lastNotice = {}

-- input: nothing
-- output: morning, afternoon, evening or night from the game clock
-- Names the part of the day the game clock is in.
local function TimeOfDay()
    local hour = GetGameTime()
    if hour >= 5 and hour < 12 then
        return L.Text.TIME_MORNING
    elseif hour >= 12 and hour < 17 then
        return L.Text.TIME_AFTERNOON
    elseif hour >= 17 and hour < 21 then
        return L.Text.TIME_EVENING
    end

    return L.Text.TIME_NIGHT
end

-- input: a unit API such as UnitName
-- output: its first result for your target, or nil without a target
-- Asks a unit API about the current target.
local function Target(get)
    if UnitExists("target") then
        return (get("target"))
    end
end

-- The variables a line can hold. The Insert variable menu lists them in this
-- order. Each get receives the play context and returns the text to put in
-- the line, or nil to leave it blank.
L.Play.VARIABLES = {
    { key = "targetName", get = function()
        return Target(UnitName) or L.Db.Settings().targetFallback
    end },
    { key = "targetClass", get = function()
        return Target(UnitClass)
    end },
    { key = "targetRace", get = function()
        return Target(UnitRace)
    end },
    { key = "playerName", get = function()
        return (UnitName("player"))
    end },
    { key = "playerClass", get = function()
        return (UnitClass("player"))
    end },
    { key = "playerRace", get = function()
        return (UnitRace("player"))
    end },
    { key = "zone", get = function()
        return GetZoneText()
    end },
    { key = "subZone", get = function()
        local sub = GetSubZoneText()
        if sub and sub ~= "" then
            return sub
        end

        return GetZoneText()
    end },
    { key = "guild", get = function()
        return (GetGuildInfo("player"))
    end },
    { key = "timeOfDay", get = TimeOfDay },
    { key = "healthPercent", get = function()
        local percent = L.Compat.HealthPercent()
        return percent and (percent .. "%")
    end },
    { key = "spellName", get = function(context)
        return context.spellName
    end },
    { key = "itemName", get = function(context)
        return context.itemName
    end },
}

local VARIABLE_BY_KEY = {}
for _, variable in ipairs(L.Play.VARIABLES) do
    VARIABLE_BY_KEY[variable.key] = variable
end

-- input: line text, a context table (spellName for spell triggers), and
--        whether to colour unknown variables red for the editor
-- output: the text with every known variable filled in, trimmed
-- Fills in every known variable; unknown variables stay as typed.
function L.Play.Resolve(text, context, mark)
    -- A variable whose API fails is left blank, so one changed client API
    -- cannot stop the rest of the line.
    local resolved = text:gsub("{(%w+)}", function(key)
        local variable = VARIABLE_BY_KEY[key]
        if not variable then
            return mark and ("|cffff4040{" .. key .. "}|r") or nil
        end

        local ok, value = pcall(variable.get, context or {})
        if not ok or value == nil or L.Compat.IsSecret(value) then
            return ""
        end

        return tostring(value)
    end)

    return strtrim(resolved)
end

-- input: line text
-- output: a list of the unknown variables in it, as typed
-- Finds the variables in a line that the addon does not know.
function L.Play.UnknownVariables(text)
    local unknown = {}
    for key in text:gmatch("{(%w+)}") do
        if not VARIABLE_BY_KEY[key] then
            unknown[#unknown + 1] = "{" .. key .. "}"
        end
    end

    return unknown
end

-- input: a scene
-- output: how many of its lines are enabled
-- Counts a scene's enabled lines.
function L.Play.EnabledCount(scene)
    local count = 0
    for _, line in ipairs(scene.lines) do
        if line.enabled then
            count = count + 1
        end
    end

    return count
end

-- input: a scene id
-- output: nothing
-- Empties a scene's bag, keeping the last line so it still cannot repeat next.
function L.Play.ResetBag(sceneId)
    if bags[sceneId] then
        bags[sceneId].remaining = {}
    end
end

-- input: nothing
-- output: nothing
-- Forgets every bag, for a switch between account and character sets.
function L.Play.ResetAll()
    wipe(bags)
end

-- input: a bag and its scene
-- output: nothing
-- Fills the bag with every enabled line in a random order, never starting
-- with the line played last.
local function Refill(bag, scene)
    local remaining = {}
    for index, line in ipairs(scene.lines) do
        if line.enabled then
            remaining[#remaining + 1] = index
        end
    end

    for index = #remaining, 2, -1 do
        local swap = math.random(index)
        remaining[index], remaining[swap] = remaining[swap], remaining[index]
    end

    if #remaining > 1 and remaining[1] == bag.last then
        local swap = math.random(2, #remaining)
        remaining[1], remaining[swap] = remaining[swap], remaining[1]
    end

    bag.remaining = remaining
end

-- input: a scene and a context table
-- output: the resolved text and emote of the next line, or nil when there is none
-- Takes lines from the bag, skipping any that resolve to nothing.
function L.Play.Next(scene, context)
    -- The bag is refilled at most once per call, so a scene of empty lines
    -- cannot loop.
    local bag = bags[scene.id]
    if not bag then
        bag = { remaining = {} }
        bags[scene.id] = bag
    end

    local refilled = false
    while true do
        if #bag.remaining == 0 then
            if refilled then
                return nil
            end

            Refill(bag, scene)
            refilled = true
            if #bag.remaining == 0 then
                return nil
            end
        end

        local index = table.remove(bag.remaining, 1)
        local line = scene.lines[index]
        if line then
            local text = L.Play.Resolve(line.text, context)
            local emote = line.emote or scene.defaultEmote
            if text ~= "" or emote then
                bag.last = index
                return text, emote
            end
        end
    end
end

-- input: a scene's channel setting
-- output: the chat type to send on
-- Turns Auto into the group channel when grouped, else Say.
function L.Play.Channel(channel)
    if channel ~= "AUTO" then
        return channel
    end

    if LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    elseif IsInRaid() then
        return "RAID"
    elseif IsInGroup() then
        return "PARTY"
    end

    return "SAY"
end

-- input: resolved text, an emote token or nil, and a chat type
-- output: nothing
-- Sends at most one chat message and one emote.
function L.Play.Send(text, emote, channel)
    -- Emote before the line, so the body language leads the words.
    -- ponytail: one fixed order; add a setting if players ask for "after".
    if emote then
        L.Compat.DoEmote(emote)
    end

    if text ~= "" then
        -- The server rejects a message holding a stray escape code.
        text = text:gsub("|", "")
        if #text > L.Db.MAX_LINE then
            text = L.Util.Cut(text, L.Db.MAX_LINE)
            L.Util.Print(L.Text.MSG_TRIMMED)
        end

        L.Compat.SendChat(text, channel)
    end
end

-- input: a scene and a message format taking the scene name
-- output: nothing
-- Prints a notice about a scene, at most once every NOTICE_GAP seconds.
local function Notice(scene, message)
    local now = GetTime()
    if not lastNotice[scene.id] or now - lastNotice[scene.id] >= NOTICE_GAP then
        lastNotice[scene.id] = now
        L.Util.Print(message:format(scene.name))
    end
end

-- input: a scene, a context table, and whether a trigger rather than a key press asked
-- output: true when a line was sent or primed, and why: "sent", "primed",
--         "off", "cooldown" or "nolines"
-- Plays the scene's next line.
function L.Play.Scene(scene, context, fromTrigger)
    -- Outside instances, a trigger cannot send Say or Yell without a key
    -- press, so it primes the line for the Speak key.
    if not scene.enabled then
        if not fromTrigger then
            Notice(scene, L.Text.MSG_SCENE_DISABLED)
        end

        return false, "off"
    end

    local now = GetTime()
    if lastPlayed[scene.id] and now - lastPlayed[scene.id] < scene.cooldown then
        return false, "cooldown"
    end

    local text, emote = L.Play.Next(scene, context)
    if not text then
        if not fromTrigger then
            Notice(scene, L.Text.MSG_NO_LINES)
        end

        return false, "nolines"
    end

    lastPlayed[scene.id] = now
    local channel = L.Play.Channel(scene.channel)

    if fromTrigger and text ~= "" and (channel == "SAY" or channel == "YELL") and not IsInInstance() then
        L.Prime.Set(text, emote, channel)
        return true, "primed"
    end

    L.Play.Send(text, emote, channel)

    return true, "sent"
end

-- input: a scene, line text, and the line's emote or nil
-- output: nothing
-- Prints how a line would come out, to your own chat only.
function L.Play.Test(scene, text, emote)
    local resolved = L.Play.Resolve(text or "", {})
    emote = emote or scene.defaultEmote

    if resolved == "" and not emote then
        L.Util.Print(L.Text.MSG_TEST_EMPTY)
        return
    end

    local channel = L.Play.Channel(scene.channel)
    L.Util.Print(L.Text.MSG_TEST:format(L.Text["CHANNEL_" .. channel] or channel,
        L.Util.Escape(resolved), L.Compat.EmoteName(emote)))
end

-- input: the text after /speakeasy
-- output: nothing
-- /speakeasy opens the window, /speakeasy mute toggles triggers, /speakeasy speak sends a primed
-- line, and /speakeasy <scene> plays a scene by id or name.
local function SlashCommand(message)
    message = strtrim(message or "")
    local lower = message:lower()

    if message == "" then
        L.Window.Toggle()
    elseif lower == "mute" then
        L.Triggers.SetMuted(not L.Db.Settings().triggersMuted)
    elseif lower == "speak" then
        L.Prime.Speak()
    elseif lower == "debug" then
        L.Triggers.SetDebug(not L.Triggers.debug)
    else
        local scene = L.Db.FindScene(message)
        if scene then
            L.Play.Scene(scene, {})
        else
            L.Util.Print(L.Text.MSG_NO_SCENE:format(message), "error")
        end
    end
end

SLASH_SPEAKEASY1 = "/speakeasy"
SlashCmdList["SPEAKEASY"] = L.Util.Safe(SlashCommand)
