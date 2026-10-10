-- Scene buttons: a macro whose body is only "/speakeasy <id>", made when you drag it.
local ADDON, L = ...

L.Macro = {}

local MAX_NAME = 16

-- Renames asked for in combat, made once combat ends.
local pending = {}

-- input: a scene
-- output: the macro body that plays it
-- Builds the "/speakeasy <id>" body for a scene's macro.
local function BodyFor(scene)
    return "/speakeasy " .. scene.id
end

-- input: a macro name or nil
-- output: the index of one of our macros with that name, or nil
-- Finds one of our macros by name.
local function Find(name)
    -- Only a macro whose body starts with /speakeasy counts, so a macro of yours that
    -- happens to share the scene's name is never overwritten.
    if not name then
        return nil
    end

    local index = GetMacroIndexByName(name)
    if index and index > 0 then
        local body = GetMacroBody(index)
        -- Buttons made before the rename ran "/sl", and are rewritten by Sync.
        if body and (body:match("^/speakeasy ") or body:match("^/sl ")) then
            return index
        end
    end
end

-- input: a name, an icon and a body
-- output: the new macro's index, or nil when every slot is full
-- Uses an account slot, or a character slot once those are full.
local function Create(name, icon, body)
    local account, character = GetNumMacros()
    local perCharacter = account >= (MAX_ACCOUNT_MACROS or 120)
    if perCharacter and character >= (MAX_CHARACTER_MACROS or 18) then
        return nil
    end

    local ok, index = pcall(CreateMacro, name, icon, body, perCharacter)
    if ok and index and index > 0 then
        return index
    end
end

-- input: a scene
-- output: true when the macro is on the cursor
-- Creates or updates the scene's macro and picks it up to drop on a bar.
function L.Macro.Pickup(scene)
    if InCombatLockdown() then
        L.Util.Print(L.Text.MSG_MACRO_COMBAT, "error")
        return false
    end

    local name = L.Util.Cut(scene.name, MAX_NAME)
    local icon = scene.icon
    local index = Find(scene.macroName) or Find(name)

    if index then
        index = EditMacro(index, name, icon, BodyFor(scene)) or index
    else
        index = Create(name, icon, BodyFor(scene))
        if not index then
            L.Util.Print(L.Text.MSG_MACRO_FULL:format(BodyFor(scene)), "error")
            return false
        end
    end

    scene.macroName = name
    PickupMacro(index)

    return true
end

-- input: a scene
-- output: nothing
-- Renames the scene's macro to match the scene, waiting for combat to end.
function L.Macro.Sync(scene)
    -- The body names the id, which never changes, so bar buttons work meanwhile.
    if not scene.macroName then
        return
    end

    if InCombatLockdown() then
        pending[scene] = true
        return
    end

    local index = Find(scene.macroName)
    if not index then
        scene.macroName = nil
        return
    end

    local name = L.Util.Cut(scene.name, MAX_NAME)
    EditMacro(index, name, scene.icon, BodyFor(scene))
    scene.macroName = name
end

-- input: nothing
-- output: nothing
-- Makes the renames that waited for combat to end.
function L.Macro.Flush()
    for scene in pairs(pending) do
        pending[scene] = nil
        L.Macro.Sync(scene)
    end
end

-- input: nothing
-- output: nothing
-- Brings every scene's existing button up to date, such as old "/sl" ones.
function L.Macro.UpdateAll()
    for _, set in ipairs({ SpeakEasyDB, SpeakEasyCharDB }) do
        for _, scene in ipairs(set.scenes or {}) do
            L.Macro.Sync(scene)
        end
    end
end
