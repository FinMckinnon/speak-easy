-- Chat output, table helpers, the error guard, and client API wrappers.
local ADDON, L = ...

L.Util = {}
L.Compat = {}

local unpack = unpack or table.unpack

local COLOUR_INFO = "1E90FF"
local COLOUR_ERROR = "DC143C"

-- The same error is printed at most once in this many seconds.
local ERROR_REPEAT = 10

-- Emote indexes have gaps, so the scan runs past the last known one.
local MAX_EMOTE_SCAN = 1000

-- input: a message string and an optional tone of "error"
-- output: nothing
-- Prints a coloured SpeakEasy message to your own chat frame.
function L.Util.Print(message, tone)
    local colour = tone == "error" and COLOUR_ERROR or COLOUR_INFO
    DEFAULT_CHAT_FRAME:AddMessage("|cff" .. colour .. L.Text.CHAT_NAME .. ":|r " .. tostring(message))
end

-- input: any value
-- output: an independent copy of it, or the value itself when not a table
-- Copies a table and every table inside it.
function L.Util.DeepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, inner in pairs(value) do
        copy[key] = L.Util.DeepCopy(inner)
    end

    return copy
end

-- input: a string and a byte limit
-- output: the string cut to the limit without splitting a character
-- Shortens UTF-8 text, dropping a character the cut would leave half written.
function L.Util.Cut(text, limit)
    if #text <= limit then
        return text
    end

    local cut = text:sub(1, limit)
    local lead = cut:find("[\192-\255][\128-\191]*$")
    if lead then
        local first = cut:byte(lead)
        local size = first >= 240 and 4 or first >= 224 and 3 or 2
        if #cut - lead + 1 < size then
            cut = cut:sub(1, lead - 1)
        end
    end

    return cut
end

-- input: user text
-- output: the text with every | doubled
-- Shows text as typed, since a lone | starts an escape code in a font string.
function L.Util.Escape(text)
    return (tostring(text or ""):gsub("|", "||"))
end

local lastErrors = {}

-- input: an error
-- output: the error as a string
-- Prints an error to chat, once per ERROR_REPEAT seconds for the same text.
local function Report(err)
    local message = tostring(err)
    local now = GetTime()

    if not lastErrors[message] or now - lastErrors[message] >= ERROR_REPEAT then
        lastErrors[message] = now
        L.Util.Print(L.Text.MSG_ERROR .. " " .. message, "error")
    end

    return message
end

-- input: a function
-- output: a function that runs it, printing any error to chat instead of raising it
-- Guards a client entry point so an error becomes one chat message.
function L.Util.Safe(fn)
    -- Every entry point the client calls (events, slash commands, clicks, key
    -- bindings, widget callbacks) goes through this, so a bad saved line or a
    -- changed client API costs one chat message rather than a Lua error.
    return function(...)
        local args, count = { ... }, select("#", ...)
        local ok, result = xpcall(function()
            return fn(unpack(args, 1, count))
        end, Report)

        if ok then
            return result
        end
    end
end

-- input: any value
-- output: true when the client hides it from addons
-- Checks whether a value is one the client keeps secret.
function L.Compat.IsSecret(value)
    -- Retail 12 hands addons some combat values (health, for one) as secret
    -- values: they can be shown on screen, but comparing or doing sums with them
    -- raises an error. Anything we calculate with is checked here first.
    return issecretvalue ~= nil and issecretvalue(value) == true
end

-- Trigger events and variables this client cannot support, when it keeps
-- secret values. Feature checked rather than keyed on the game version, so a
-- patch that adds or lifts a restriction needs no new release.
-- ponytail: assumes secret values mean secret health; probe UnitHealth if
-- Blizzard ever splits the two.
local SECRET_CLIENT_LIMITS = { LOW_HEALTH = true, healthPercent = true }
local NO_LIMITS = {}

-- input: nothing
-- output: a set of event names and variable keys this client cannot support
-- Picks the limits that apply to this client.
function L.Compat.Unavailable()
    if issecretvalue ~= nil then
        return SECRET_CLIENT_LIMITS
    end

    return NO_LIMITS
end

-- input: message text and a chat type
-- output: nothing
-- Sends a chat message through whichever API the client has.
function L.Compat.SendChat(text, channel)
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    send(text, channel)
end

-- input: an emote token such as "WAVE"
-- output: nothing
-- Performs a built in emote.
function L.Compat.DoEmote(token)
    local perform = DoEmote or (C_ChatInfo and C_ChatInfo.PerformEmote)
    perform(token)
end

-- input: typed text, or a shift-clicked spell or item link
-- output: the link's kind ("spell" or "item") and id, or nil for plain text,
--         and the name shown in it, or the trimmed text
-- Splits a link into its kind, id and shown name.
function L.Compat.ParseLink(text)
    text = strtrim(tostring(text or ""))
    local kind, id = text:match("|H(%a+):(%d+)")
    return kind, tonumber(id), text:match("|h%[(.-)%]|h") or text
end

-- input: text typed or shift-clicked into a spell box: a spell or item link,
--        or a name
-- output: the spell name to watch for, and the item's name when it came from an item
-- Using an item casts a spell (eating casts "Food"), so an item becomes the
-- spell it casts.
function L.Compat.SpellOrItem(text)
    -- A plain name is kept as typed unless it names an item the client knows.
    local kind, id, shown = L.Compat.ParseLink(text)

    local getItemSpell = (C_Item and C_Item.GetItemSpell) or GetItemSpell
    if kind == "spell" then
        return L.Compat.SpellName(id) or shown, nil
    elseif kind == "item" or not kind then
        local spell = getItemSpell and getItemSpell(id or shown)
        if spell then
            return spell, shown
        end
    end

    return shown, nil
end

-- input: a spell or item name or id, or a shift-clicked spell or item link
-- output: its icon and its name, or nil when the client knows neither
-- Finds the icon for a spell or item.
function L.Compat.IconFor(text)
    -- Retail's icon list has ids but no names, so searching by name goes
    -- through spells and items instead.
    local kind, id, name = L.Compat.ParseLink(text)
    if name == "" then
        return nil
    end

    local spellTexture = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture
    local itemIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon

    -- input: an icon API, or nil when the client lacks it, and its argument
    -- output: the icon, or nil when the API is missing or fails
    -- Calls an icon API without letting it raise an error.
    local function Try(fn, value)
        if not fn then
            return nil
        end

        local ok, icon = pcall(fn, value)

        return ok and icon or nil
    end

    local icon
    if kind == "spell" then
        icon = Try(spellTexture, id)
    elseif kind == "item" then
        icon = Try(itemIcon, id)
    else
        icon = Try(spellTexture, name) or Try(itemIcon, name)
    end

    if icon then
        return icon, name
    end
end

-- Icon names, worked out from spells. The icon list has file ids but no
-- names, while every spell has a name and an icon, so reading the client's
-- spell list gives most icons a readable name to show and search. Built a few
-- milliseconds per frame, the first time the icon picker opens.
-- ponytail: icons no spell uses stay nameless; ship a listfile if that matters.
L.Compat.SPELL_SCAN_MAX = (WOW_PROJECT_ID and WOW_PROJECT_MAINLINE and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
    and 1500000 or 600000
local SCAN_BUDGET_MS = 4
local NAMES_PER_ICON = 4

local iconNames = {}   -- icon -> "Name\nOther name", up to NAMES_PER_ICON
local iconSearch = {}  -- icon -> the same, lower case, for searching
local scanNext, scanFrame
local scanDone = false

-- input: nothing
-- output: nothing
-- Reads the next stretch of spell ids, stopping once its time is used up.
local function ScanStep()
    local stop = debugprofilestop() + SCAN_BUDGET_MS
    local getName = C_Spell and C_Spell.GetSpellName
    local getIcon = C_Spell and C_Spell.GetSpellTexture
    local max = L.Compat.SPELL_SCAN_MAX
    local id = scanNext

    while id <= max do
        local name, icon
        if getName then
            name = getName(id)
            if name then
                icon = getIcon(id)
            end
        else
            local _
            name, _, icon = GetSpellInfo(id)
        end

        if name and icon and name ~= "" and not L.Compat.IsSecret(name) then
            local names = iconNames[icon]
            if not names then
                iconNames[icon], iconSearch[icon] = name, name:lower()
            elseif not ("\n" .. names .. "\n"):find("\n" .. name .. "\n", 1, true)
                and select(2, names:gsub("\n", "")) < NAMES_PER_ICON - 1 then
                iconNames[icon] = names .. "\n" .. name
                iconSearch[icon] = iconSearch[icon] .. "\n" .. name:lower()
            end
        end

        id = id + 1
        if id % 1000 == 0 and debugprofilestop() > stop then
            break
        end
    end

    scanNext = id
    if id > max then
        scanDone = true
        scanFrame:SetScript("OnUpdate", nil)
    end

    if scanFrame.onProgress then
        scanFrame.onProgress(math.min(1, id / max), scanDone)
    end
end

-- input: a function given progress from 0 to 1 and whether reading is done,
--        or nil to stop being told
-- output: nothing
-- Starts reading spell names, once a session, and reports as it goes.
function L.Compat.ReadIconNames(onProgress)
    if not scanFrame then
        scanFrame = CreateFrame("Frame")
        scanNext = 1
        scanFrame:SetScript("OnUpdate", L.Util.Safe(ScanStep))
    end

    scanFrame.onProgress = onProgress
    if scanDone and onProgress then
        onProgress(1, true)
    end
end

-- input: text to look for
-- output: every named icon whose name holds the text, sorted by name
-- Searches the icon names read so far.
function L.Compat.SearchIcons(text)
    local query, found = text:lower(), {}
    for icon, names in pairs(iconSearch) do
        if names:find(query, 1, true) then
            found[#found + 1] = icon
        end
    end

    table.sort(found, function(a, b)
        return iconSearch[a] < iconSearch[b]
    end)

    return found
end

-- input: an icon, as a file id or a texture path
-- output: its readable name, and any other names it goes by, or a fallback
-- Names an icon for display.
function L.Compat.IconName(icon)
    local names = iconNames[icon]
    if names then
        local first, rest = names:match("^([^\n]*)\n?(.*)$")
        return first, rest ~= "" and rest:gsub("\n", ", ") or nil
    end

    if type(icon) == "string" then
        return (icon:match("([^\\]+)$") or icon)
    end

    return L.Text.ICON_UNNAMED
end

local iconList

-- input: nothing
-- output: every icon the macro editor offers, as file ids or texture paths
-- Read once from the client's own macro icon lists.
function L.Compat.MacroIcons()
    if iconList then
        return iconList
    end

    local found = {}
    if GetMacroIcons then
        GetMacroIcons(found)
    end

    if GetMacroItemIcons then
        GetMacroItemIcons(found)
    end

    iconList = {}
    for _, icon in ipairs(found) do
        if type(icon) == "string" and not icon:find("\\", 1, true) then
            icon = "Interface\\Icons\\" .. icon
        end

        iconList[#iconList + 1] = icon
    end

    return iconList
end

-- input: text
-- output: nothing
-- Opens the chat box holding the text so it can be copied, or prints it.
function L.Compat.OpenChat(text)
    local open = (ChatFrameUtil and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
    if open then
        open(text)
    else
        L.Util.Print(text)
    end
end

-- input: a spell id
-- output: the spell's name, or nil
-- Reads a spell name through whichever API the client has.
function L.Compat.SpellName(spellID)
    if L.Compat.IsSecret(spellID) then
        return nil
    end

    local name
    if C_Spell and C_Spell.GetSpellName then
        name = C_Spell.GetSpellName(spellID)
    elseif GetSpellInfo then
        name = (GetSpellInfo(spellID))
    end

    if L.Compat.IsSecret(name) then
        return nil
    end

    return name
end

-- input: nothing
-- output: your health as a whole percentage, or nil when unknown or secret
-- Reads your current health. On clients that keep it secret, {healthPercent}
-- is blank and low health triggers never fire.
function L.Compat.HealthPercent()
    local health, maximum = UnitHealth("player"), UnitHealthMax("player")
    if L.Compat.IsSecret(health) or L.Compat.IsSecret(maximum) then
        return nil
    end

    if not health or not maximum or maximum <= 0 then
        return nil
    end

    return math.floor(health / maximum * 100 + 0.5)
end

local emoteNames, emoteOrder

-- input: nothing
-- output: a table of emote token to display name, and the tokens sorted by name
-- Builds the emote list once from the client's EMOTEn_TOKEN globals.
function L.Compat.Emotes()
    if emoteNames then
        return emoteNames, emoteOrder
    end

    emoteNames, emoteOrder = {}, {}
    for index = 1, MAX_EMOTE_SCAN do
        local token = _G["EMOTE" .. index .. "_TOKEN"]
        if type(token) == "string" and not emoteNames[token] then
            local command = _G["EMOTE" .. index .. "_CMD1"]
            local name = type(command) == "string" and command:gsub("^/", "") or token:lower()
            emoteNames[token] = name:gsub("^%l", string.upper)
            emoteOrder[#emoteOrder + 1] = token
        end
    end

    table.sort(emoteOrder, function(a, b)
        return emoteNames[a] < emoteNames[b]
    end)

    return emoteNames, emoteOrder
end

-- input: an emote token or nil
-- output: the emote's display name, or the "none" text
-- Names an emote, falling back to its token when this client lacks it.
function L.Compat.EmoteName(token)
    if not token then
        return L.Text.NONE
    end

    return L.Compat.Emotes()[token] or token
end
