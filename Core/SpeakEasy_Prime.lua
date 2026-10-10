-- Primed lines: a Say or Yell line a trigger chose outside an instance waits
-- in a small prompt until the Speak key (a hardware event) sends it.
local ADDON, L = ...

L.Prime = {}

BINDING_HEADER_SPEAKEASY = L.Text.ADDON_NAME
BINDING_NAME_SPEAKEASY_SPEAK = L.Text.BINDING_SPEAK

-- Keys that never send a primed line: closing things, opening chat, modifiers.
local IGNORED_KEYS = {
    ESCAPE = true, ENTER = true,
    LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
}

local pending
local prompt
local listener

-- input: nothing
-- output: nothing
-- Writes the prompt's position into the settings.
local function SavePosition()
    local point, _, _, x, y = prompt:GetPoint()
    local saved = L.Db.Settings().prompt
    saved.point, saved.x, saved.y = point, x, y
end

-- input: nothing
-- output: nothing
-- Shows the seconds left and the key to press, clearing the line once it expires.
local function Tick()
    if not pending then
        return
    end

    local left = pending.expires - GetTime()
    if left <= 0 then
        L.Prime.Clear()
        return
    end

    local key = GetBindingKey("SPEAKEASY_SPEAK") or L.Text.PROMPT_NO_KEY
    prompt.title:SetText(L.Text.PROMPT_TITLE:format(key, math.ceil(left)))
end

-- input: nothing
-- output: nothing
-- Builds the movable prompt. Left click speaks, right click dismisses.
local function Build()
    prompt = CreateFrame("Button", "SpeakEasyPrompt", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    prompt:SetSize(340, 56)
    prompt:SetFrameStrata("HIGH")
    prompt:SetClampedToScreen(true)
    prompt:SetMovable(true)
    prompt:EnableMouse(true)
    prompt:RegisterForDrag("LeftButton")
    prompt:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    if prompt.SetBackdrop then
        prompt:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        prompt:SetBackdropColor(0, 0, 0, 0.85)
    end

    prompt.title = prompt:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    prompt.title:SetPoint("TOPLEFT", 10, -8)

    prompt.text = prompt:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    prompt.text:SetPoint("TOPLEFT", 10, -24)
    prompt.text:SetPoint("RIGHT", -10, 0)
    prompt.text:SetJustifyH("LEFT")

    local saved = L.Db.Settings().prompt
    prompt:SetPoint(saved.point or "CENTER", UIParent, saved.point or "CENTER", saved.x or 0, saved.y or 180)

    prompt:SetScript("OnDragStart", prompt.StartMoving)
    prompt:SetScript("OnDragStop", L.Util.Safe(function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end))
    prompt:SetScript("OnClick", L.Util.Safe(function(_, button)
        if button == "RightButton" then
            L.Prime.Clear()
        else
            L.Prime.Speak()
        end
    end))
    prompt:SetScript("OnUpdate", L.Util.Safe(Tick))
end

-- input: resolved text, an emote token or nil, and SAY or YELL
-- output: nothing
-- Holds a line for the Speak key, replacing any line already waiting.
function L.Prime.Set(text, emote, channel)
    pending = {
        text = text,
        emote = emote,
        channel = channel,
        expires = GetTime() + L.Db.Settings().primeTimeout,
    }

    -- Sent silently with the next key press; the prompt is only for manual mode.
    if L.Db.Settings().speakOnAnyKey then
        return
    end

    if not prompt then
        Build()
    end

    prompt.text:SetText(L.Util.Escape(text))
    Tick()
    prompt:Show()
end

-- input: nothing
-- output: the waiting line's text, or nil
-- Returns the line waiting for the Speak key.
function L.Prime.Pending()
    return pending and pending.text
end

-- input: nothing
-- output: nothing
-- Drops the waiting line and hides the prompt.
function L.Prime.Clear()
    pending = nil
    if prompt then
        prompt:Hide()
    end
end

-- input: nothing
-- output: true when a waiting line was sent
-- Sends the waiting line. Must run from a key press or click.
function L.Prime.Speak()
    if not pending or GetTime() >= pending.expires then
        L.Prime.Clear()
        return false
    end

    local line = pending
    L.Prime.Clear()
    L.Play.Send(line.text, line.emote, line.channel)

    return true
end

-- input: nothing
-- output: nothing
-- Watches every key press so a primed line can go out with the next one,
-- such as your next ability in combat.
function L.Prime.ListenForKeys()
    -- A key press is the hardware event the game asks for, and the key still
    -- reaches its own binding as normal. Keyboard settings cannot change in
    -- combat, so this is set up once outside it and only checks the setting on
    -- each press.
    if listener or InCombatLockdown() then
        return
    end

    listener = CreateFrame("Frame", "SpeakEasyKeyListener", UIParent)
    listener:EnableKeyboard(true)
    listener:SetPropagateKeyboardInput(true)
    listener:SetScript("OnKeyDown", L.Util.Safe(function(_, key)
        if pending and not IGNORED_KEYS[key] and L.Db.Settings().speakOnAnyKey then
            L.Prime.Speak()
        end
    end))
end

-- Called by the Speak key binding in Bindings.xml.
SpeakEasy_Speak = L.Util.Safe(L.Prime.Speak)
