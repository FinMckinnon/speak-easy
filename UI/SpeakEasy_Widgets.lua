---@diagnostic disable: undefined-field, invisible
-- AceGUI ships without type annotations, and widget.frame is its documented
-- route to the underlying frame.
--
-- AceGUI widget factories and popups. Every callback runs through L.Util.Safe.
local ADDON, L = ...

L.UI = {}

local AceGUI = LibStub("AceGUI-3.0")
L.AceGUI = AceGUI

local Safe = L.Util.Safe

local NO_EMOTE = "__none"

-- input: a widget and a width
-- output: nothing
-- Pixels when over 1, a share of the row when 1 or less, the full row when nil.
local function Size(widget, width)
    if not width then
        widget:SetFullWidth(true)
    elseif width <= 1 then
        widget:SetRelativeWidth(width)
    else
        widget:SetWidth(width)
    end
end

-- input: a stock AceGUI input widget
-- output: the widget
-- Gives its label the quiet caption colour instead of Blizzard gold.
local function Quiet(widget)
    -- AceGUI puts the gold back when the widget is reused, so this cannot leak.
    local colour = L.Style.COLOURS.secondary
    if widget.label then
        widget.label:SetTextColor(colour[1], colour[2], colour[3])
    end

    return widget
end
L.UI.Quiet = Quiet

local escapeNames = {}

-- input: a frame
-- output: true when it sits inside one of the addon's open windows
-- Walks up the frame's parents looking for one of the addon's windows.
local function InOurWindow(frame)
    while frame do
        for name in pairs(escapeNames) do
            if _G[name] == frame then
                return true
            end
        end

        frame = frame:GetParent()
    end

    return false
end

-- Clicking anywhere outside an open dropdown closes it, as menus do elsewhere
-- in the game. AceGUI alone only closes it when another AceGUI control is
-- clicked. Only our own dropdowns are closed, never other addons'.
local closer = CreateFrame("Frame")
pcall(closer.RegisterEvent, closer, "GLOBAL_MOUSE_DOWN")
closer:SetScript("OnEvent", Safe(function()
    local focused = AceGUI.FocusedWidget
    if not focused or not focused.open or not InOurWindow(focused.frame) then
        return
    end

    local pullout = focused.pullout and focused.pullout.frame
    if focused.frame:IsMouseOver() or (pullout and pullout:IsMouseOver()) then
        return
    end

    AceGUI:ClearFocus()
end))

-- input: a title, a default width and height, a global name for Escape to
--        close it by, a status table for position and size or nil, and a close callback
-- output: the window widget
-- Creates one of the addon's windows, which Escape closes.
function L.UI.Window(title, width, height, name, status, onClose)
    local window = AceGUI:Create("SpeakEasyWindow")
    window:SetTitle(title)
    window:SetLayout("Flow")

    status = status or {}
    status.width = math.max(status.width or width, width)
    status.height = math.max(status.height or height, height)
    window:SetStatusTable(status)

    local raw = window.frame
    if raw.SetResizeBounds then
        raw:SetResizeBounds(width, height)
    end

    -- The name is cleared on close: AceGUI reuses the frame later.
    _G[name] = raw
    if not escapeNames[name] then
        escapeNames[name] = true
        table.insert(UISpecialFrames, name)
    end

    window:SetCallback("OnClose", Safe(function(widget)
        _G[name] = nil
        onClose(widget)
        AceGUI:Release(widget)
    end))

    return window
end

-- input: an AceGUI container
-- output: the height of its content area in pixels
-- Reads the content area's height, falling back to 0 before it is drawn.
function L.UI.ContentHeight(container)
    local content = container.content
    return content.height or content:GetHeight() or 0
end

-- input: a parent and a width
-- output: the group
-- Adds a plain group whose children flow in rows.
function L.UI.Group(parent, width)
    local group = AceGUI:Create("SimpleGroup")
    group:SetLayout("Flow")
    Size(group, width)
    parent:AddChild(group)

    return group
end

-- input: a parent, a title, an optional caption and a width
-- output: the section card
-- Groups related controls on a soft card under a heading.
function L.UI.Section(parent, title, caption, width)
    local section = AceGUI:Create("SpeakEasySection")
    section:SetLayout("Flow")
    Size(section, width)
    section:SetTitle(title)
    section:SetDescription(caption)
    parent:AddChild(section)

    return section
end

-- input: a parent using the "Fill" layout
-- output: the AceGUI ScrollFrame
-- Switches the parent to a "List" layout and fills it with a scroll list.
function L.UI.Scroll(parent)
    -- Lists never sit in a "Fill" layout: Fill sizes its child from the frame's
    -- current size, which the game only works out once a frame is drawn, so a
    -- reused frame reports an old size or 0 and a list came out 0px wide or tall
    -- (lines counted but not shown). Sizes are handed over directly instead, and
    -- a second layout runs on the next frame, once every size is known.
    parent:SetLayout("List")
    return L.UI.ScrollList(parent, L.UI.ContentHeight(parent))
end

local relayoutToken = setmetatable({}, { __mode = "k" })

-- input: a container
-- output: nothing
-- Lays the container out again on the next frame, unless AceGUI has handed
-- it to someone else by then.
function L.UI.RelayoutSoon(container)
    local token = {}
    relayoutToken[container] = token
    C_Timer.After(0, Safe(function()
        if relayoutToken[container] == token and container.frame:IsShown() then
            container:DoLayout()
        end
    end))
end

-- input: a parent, a height and a width
-- output: a ScrollFrame inside a box of that height
-- Adds a scroll list of a fixed height, laid out again on the next frame.
function L.UI.ScrollList(parent, height, width)
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("List")
    Size(scroll, width)
    scroll:SetHeight(height)
    parent:AddChild(scroll)
    L.UI.RelayoutSoon(scroll)

    return scroll
end

local TEXT_STYLES = { title = "Title", heading = "Heading", body = "Body", caption = "Caption" }

-- input: a parent, text, a width, and a style: "title", "heading", "body" or
--        "caption" (the default), or a { r, g, b } colour on caption text
-- output: the AceGUI Label
-- Adds a line of text in one of the addon's text styles.
function L.UI.Label(parent, text, width, style)
    local widget = AceGUI:Create("Label")
    widget:SetText(text)
    Size(widget, width)
    local font = L.Style[TEXT_STYLES[type(style) == "string" and style or "caption"]]
    widget:SetFontObject(font)
    local colour = type(style) == "table" and style or { font:GetTextColor() }
    widget:SetColor(colour[1], colour[2], colour[3])
    parent:AddChild(widget)

    return widget
end

-- input: a parent, the main text, and a click callback
-- output: the list row
-- Adds a full width list row; set secondary text, a toggle or selection on it.
function L.UI.Row(parent, text, onClick)
    local widget = AceGUI:Create("SpeakEasyRow")
    widget:SetText(text)
    widget:SetCallback("OnClick", Safe(onClick))
    parent:AddChild(widget)

    return widget
end

-- input: a parent, the button text, a width, a click callback, and a look:
--        "primary", "secondary" (the default) or "danger"
-- output: the button
-- Adds one of the addon's buttons in the given look.
function L.UI.Button(parent, text, width, onClick, look)
    local widget = AceGUI:Create("SpeakEasyButton")
    widget:SetText(text)
    widget:SetLook(look or "secondary")
    Size(widget, width)
    widget:SetCallback("OnClick", Safe(onClick))
    parent:AddChild(widget)

    return widget
end

-- input: a parent and a width
-- output: nothing
-- Adds empty space in a Flow row, to push what follows to the right.
function L.UI.Spacer(parent, width)
    L.UI.Label(parent, " ", width)
end

-- input: a parent and a height in pixels
-- output: nothing
-- Adds a full width band of empty space between rows.
function L.UI.Gap(parent, height)
    local gap = AceGUI:Create("SimpleGroup")
    gap:SetFullWidth(true)
    gap:SetAutoAdjustHeight(false)
    gap:SetHeight(height)
    parent:AddChild(gap)
end

-- input: a parent, a label, a value, a width, and a change callback
-- output: the AceGUI CheckBox
-- Adds a checkbox that reports its new state as true or false.
function L.UI.Toggle(parent, label, value, width, onChange)
    local widget = AceGUI:Create("CheckBox")
    widget:SetLabel(label)
    widget:SetValue(value and true or false)
    Size(widget, width)
    widget:SetCallback("OnValueChanged", Safe(function(_, _, newValue)
        onChange(newValue and true or false)
    end))
    parent:AddChild(widget)

    return widget
end

-- input: a parent, a label, a value, a key to text table, the keys in order, a width, and a change callback
-- output: the AceGUI Dropdown
-- Adds a dropdown that reports the chosen key.
function L.UI.Select(parent, label, value, list, order, width, onChange)
    local widget = AceGUI:Create("Dropdown")
    widget:SetLabel(label)
    widget:SetList(list, order)
    widget:SetValue(value)
    Size(widget, width)
    widget:SetCallback("OnValueChanged", Safe(function(_, _, newValue)
        onChange(newValue)
    end))
    parent:AddChild(widget)

    return Quiet(widget)
end

-- input: a parent, a label, the starting text, a width, and a callback for Enter or Okay
-- output: the AceGUI EditBox
-- Adds a text box that reports its text when committed.
function L.UI.Input(parent, label, text, width, onCommit)
    local widget = AceGUI:Create("EditBox")
    widget:SetLabel(label)
    widget:SetText(text or "")
    Size(widget, width)
    widget:SetCallback("OnEnterPressed", Safe(function(_, _, newText)
        onCommit(newText)
    end))
    parent:AddChild(widget)

    return Quiet(widget)
end

-- input: a parent, a label, min, max, step, a value, a width, a change
--        callback, and true to report only once the slider is let go
-- output: the AceGUI Slider
-- Adds a slider that reports its value as it moves, or once it is let go.
function L.UI.Range(parent, label, low, high, step, value, width, onChange, onRelease)
    local widget = AceGUI:Create("Slider")
    widget:SetLabel(label)
    widget:SetSliderValues(low, high, step)
    widget:SetValue(value)
    Size(widget, width)
    -- OnMouseUp also fires when a value is typed into the slider's box.
    widget:SetCallback(onRelease and "OnMouseUp" or "OnValueChanged", Safe(function(_, _, newValue)
        onChange(newValue)
    end))
    parent:AddChild(widget)

    return Quiet(widget)
end

-- input: a parent, a label, a binding name from Bindings.xml, and a width
-- output: the AceGUI Keybinding
-- Sets the key for one of our bindings, replacing whatever key it had.
function L.UI.BindingPicker(parent, label, action, width)
    local widget = AceGUI:Create("Keybinding")
    widget:SetLabel(label)
    widget:SetKey(GetBindingKey(action) or "")
    Size(widget, width)
    widget:SetCallback("OnKeyChanged", Safe(function(self, _, key)
        if InCombatLockdown() then
            L.Util.Print(L.Text.MSG_BIND_COMBAT, "error")
            self:SetKey(GetBindingKey(action) or "")
            return
        end

        for _, old in ipairs({ GetBindingKey(action) }) do
            SetBinding(old)
        end

        if key and key ~= "" then
            SetBinding(key, action)
        end

        SaveBindings(GetCurrentBindingSet())
    end))
    parent:AddChild(widget)

    return Quiet(widget)
end

-- input: a parent, a label, the chosen key, a function returning the full
--        list and its order, a width, and a change callback
-- output: the picker
-- Adds a searchable picker: click it, type to filter, pick a row.
function L.UI.Picker(parent, label, value, source, width, onChange)
    local widget = AceGUI:Create("SpeakEasyPicker")
    widget:SetLabel(label)
    widget:SetSource(source)
    local list = source()
    widget:SetValue(value, list[value])
    Size(widget, width)
    widget:SetCallback("OnValueChanged", Safe(function(_, _, key)
        onChange(key)
    end))
    parent:AddChild(widget)

    return widget
end

-- input: nothing
-- output: "none" plus every emote, and their order
-- Builds the emote picker's list, with "none" first.
local function EmoteChoices()
    local names, tokens = L.Compat.Emotes()
    local list, order = { [NO_EMOTE] = L.Text.NONE }, { NO_EMOTE }
    for _, token in ipairs(tokens) do
        list[token] = names[token]
        order[#order + 1] = token
    end

    return list, order
end

-- input: a parent, a label, the chosen token or nil, a width, and a change
--        callback given a token or nil
-- output: the dropdown
-- Adds an emote picker listing "none" and every emote.
function L.UI.EmoteSelect(parent, label, value, width, onChange)
    return L.UI.Picker(parent, label, value or NO_EMOTE, EmoteChoices, width, function(token)
        onChange(token ~= NO_EMOTE and token or nil)
    end)
end

-- input: text with one %s, the value for it, and a callback for Yes
-- output: nothing
-- Asks a yes or cancel question before going ahead.
function L.UI.Confirm(text, argument, onAccept)
    StaticPopupDialogs.SPEAKEASY_CONFIRM = {
        text = text,
        button1 = L.Text.BUTTON_YES,
        button2 = L.Text.BUTTON_CANCEL,
        OnAccept = Safe(onAccept),
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("SPEAKEASY_CONFIRM", argument)
end

-- input: a prompt, the starting text, and a callback given the entered text
-- output: nothing
-- Asks for a line of text, such as a scene name.
function L.UI.Prompt(text, initial, onAccept)
    -- input: a StaticPopup dialog
    -- output: the dialog's edit box
    -- Finds the edit box under whichever name this client gives it.
    local function Box(dialog)
        return (dialog.GetEditBox and dialog:GetEditBox()) or dialog.editBox or dialog.EditBox
    end

    -- input: a StaticPopup dialog
    -- output: nothing
    -- Hands the entered text to the callback.
    local accept = Safe(function(dialog)
        onAccept(Box(dialog):GetText())
    end)

    StaticPopupDialogs.SPEAKEASY_PROMPT = {
        text = text,
        button1 = L.Text.BUTTON_OK,
        button2 = L.Text.BUTTON_CANCEL,
        hasEditBox = true,
        maxLetters = L.Db.MAX_NAME,
        -- input: the dialog
        -- output: nothing
        -- Fills the box with the starting text and selects it.
        OnShow = Safe(function(dialog)
            local box = Box(dialog)
            box:SetText(initial or "")
            box:SetFocus()
            box:HighlightText()
        end),
        OnAccept = accept,
        -- input: the dialog's edit box
        -- output: nothing
        -- Accepts the text and closes the dialog.
        EditBoxOnEnterPressed = function(box)
            local dialog = box:GetParent()
            accept(dialog)
            dialog:Hide()
        end,
        -- input: the dialog's edit box
        -- output: nothing
        -- Closes the dialog without accepting.
        EditBoxOnEscapePressed = function(box)
            box:GetParent():Hide()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("SPEAKEASY_PROMPT")
end
