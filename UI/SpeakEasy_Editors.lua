---@diagnostic disable: undefined-field
-- The line editor and the trigger editor dialogs.
local ADDON, L = ...

L.Editors = {}

local AceGUI = L.AceGUI
local Safe = L.Util.Safe

local RED = L.Style.COLOURS.danger
local QUIET = L.Style.COLOURS.secondary

local lineWindow, triggerWindow, iconWindow

-- The trigger editor's height, taller for a spell trigger's list of spells.
local TRIGGER_EDITOR_HEIGHT = 340
local SPELL_EDITOR_HEIGHT = 480
local SPELL_LIST_HEIGHT = 120

-- input: nothing
-- output: nothing
-- Closes both editors, for when the main window closes.
function L.Editors.CloseAll()
    if iconWindow then
        iconWindow:Hide()
    end

    if lineWindow then
        lineWindow:Hide()
    end

    if triggerWindow then
        triggerWindow:Hide()
    end
end

-- input: a scene and a line index, or nil for a new line
-- output: the editor window
-- Opens the line editor: text with a live counter and preview, an emote
-- picker with search, and the Insert variable menu. Enter saves, Escape cancels.
function L.Editors.Line(scene, index)
    if lineWindow then
        lineWindow:Hide()
    end

    local original = scene.lines[index]
    local draft = {
        text = original and original.text or "",
        emote = original and original.emote,
        enabled = not original or original.enabled,
    }

    local title = original and L.Text.TITLE_EDIT_LINE or L.Text.TITLE_NEW_LINE
    local window = L.UI.Window(title:format(scene.name), 540, 372, "SpeakEasyLineEditor", nil, function()
        lineWindow = nil
    end)
    lineWindow = window

    local box = AceGUI:Create("MultiLineEditBox")
    box:SetLabel(L.Text.LABEL_LINE)
    box:SetNumLines(4)
    box:SetFullWidth(true)
    box:DisableButton(true)
    box:SetText(draft.text)
    window:AddChild(L.UI.Quiet(box))

    local counter = L.UI.Label(window, "", 0.2)
    local warning = L.UI.Label(window, "", 0.78, RED)
    L.UI.Gap(window, L.Style.GAP)
    local preview = L.UI.Label(window, "", nil, "body")
    L.UI.Gap(window, L.Style.GAP * 2)

    local save

    -- input: nothing
    -- output: true when the draft is longer than a chat line allows
    -- Checks the draft against the line length limit.
    local function Over()
        return #draft.text > L.Db.MAX_LINE
    end

    -- input: nothing
    -- output: true when the line fits and says or does something
    -- Checks whether the draft is fit to save.
    local function CanSave()
        return not Over() and (strtrim(draft.text) ~= "" or draft.emote ~= nil)
    end

    -- input: nothing
    -- output: nothing
    -- Refreshes the counter, the warning, the preview and the Save button.
    local function Update()
        counter:SetText(L.Text.COUNTER:format(#draft.text, L.Db.MAX_LINE))
        local colour = Over() and RED or QUIET
        counter:SetColor(colour[1], colour[2], colour[3])

        local unknown = L.Play.UnknownVariables(draft.text)
        warning:SetText(#unknown > 0 and L.Text.WARN_UNKNOWN:format(table.concat(unknown, ", ")) or "")

        local resolved = L.Play.Resolve(L.Util.Escape(draft.text), {}, true)
        local heights = counter.frame.height + warning.frame.height + preview.frame.height
        preview:SetText(L.Text.LABEL_PREVIEW .. " " .. (resolved ~= "" and resolved or L.Text.PREVIEW_EMPTY))

        -- A label changes height with its text (the preview wraps as the line
        -- grows), and AceGUI does not move what is below it; lay out again.
        if counter.frame.height + warning.frame.height + preview.frame.height ~= heights then
            window:DoLayout()
        end

        if save then
            save:SetDisabled(not CanSave())
        end
    end

    -- input: nothing
    -- output: nothing
    -- Saves the draft line and closes the editor, when it is fit to save.
    local function Save()
        if not CanSave() then
            return
        end

        L.Db.SaveLine(scene, index, draft)
        window:Hide()
        L.Window.Refresh()
    end

    box:SetCallback("OnTextChanged", Safe(function(_, _, text)
        -- Chat lines are one line, so Enter saves rather than adding a break.
        if text:find("[\r\n]") then
            draft.text = text:gsub("[\r\n]", "")
            box:SetText(draft.text)
            Update()
            Save()
            return
        end

        draft.text = text
        Update()
    end))

    local variables, order = {}, {}
    local unavailable = L.Compat.Unavailable()
    for _, variable in ipairs(L.Play.VARIABLES) do
        -- Left out of the menu where unsupported; a line that already has it gets a blank.
        if not unavailable[variable.key] then
            local token = "{" .. variable.key .. "}"
            local example = L.Play.Resolve(token, { spellName = L.Text.EXAMPLE_SPELL, itemName = L.Text.EXAMPLE_ITEM })
            variables[variable.key] = L.Text.VARIABLE_ITEM:format(token, L.Text["VAR_" .. variable.key],
                example ~= "" and L.Util.Escape(example) or L.Text.EXAMPLE_BLANK)
            order[#order + 1] = variable.key
        end
    end

    local insert
    insert = L.UI.Select(window, L.Text.LABEL_INSERT, nil, variables, order, nil, function(key)
        box.editBox:Insert("{" .. key .. "}")
        insert:SetValue(nil)
        draft.text = box:GetText()
        Update()
        box:SetFocus()
    end)

    L.UI.EmoteSelect(window, L.Text.LABEL_EMOTE, draft.emote, nil, function(token)
        draft.emote = token
        Update()
    end)

    L.UI.Label(window, " ", nil)
    L.UI.Button(window, L.Text.BUTTON_TEST, 0.2, function()
        L.Play.Test(scene, draft.text, draft.emote)
    end)
    L.UI.Spacer(window, 0.39)
    L.UI.Button(window, L.Text.BUTTON_CANCEL, 0.19, function()
        window:Hide()
    end)
    save = L.UI.Button(window, L.Text.BUTTON_SAVE, 0.19, Save, "primary")

    Update()
    box:SetFocus()

    return window
end

-- The picker's grid: columns and rows of icons on one page.
local ICON_COLUMNS, ICON_ROWS = 9, 6
local ICON_SIZE = 36
local LOADING_SIZE = 72
-- How fast the loading glow turns, in radians a second.
local LOADING_SPIN = 4
local ICON_GAP = 6

local grid

-- input: nothing
-- output: the icon grid frame, built once and reused for every page
-- Builds the icon grid out of plain buttons the first time it is needed.
local function IconGrid()
    -- Plain buttons rather than AceGUI widgets: turning a page only swaps their
    -- textures, with no widgets made and no layout run, so pages are instant.
    if grid then
        return grid
    end

    grid = CreateFrame("Frame", "SpeakEasyIconGrid", UIParent)
    grid:SetSize(ICON_COLUMNS * (ICON_SIZE + ICON_GAP) - ICON_GAP, ICON_ROWS * (ICON_SIZE + ICON_GAP) - ICON_GAP)
    grid:EnableMouseWheel(true)
    grid.buttons = {}

    for index = 1, ICON_COLUMNS * ICON_ROWS do
        local button = CreateFrame("Button", nil, grid)
        button:SetSize(ICON_SIZE, ICON_SIZE)
        local column, row = (index - 1) % ICON_COLUMNS, math.floor((index - 1) / ICON_COLUMNS)
        button:SetPoint("TOPLEFT", column * (ICON_SIZE + ICON_GAP), -row * (ICON_SIZE + ICON_GAP))
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetAllPoints()
        button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        button:SetScript("OnClick", Safe(function(self)
            if grid.onChoose and self.value then
                grid.onChoose(self.value)
            end
        end))
        button:SetScript("OnEnter", Safe(function(self)
            if not self.value then
                return
            end

            local name, also = L.Compat.IconName(self.value)
            local quiet = L.Style.COLOURS.secondary
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L.Util.Escape(self.name or name), 1, 1, 1)
            if also then
                GameTooltip:AddLine(L.Text.ICON_ALSO:format(L.Util.Escape(also)), quiet[1], quiet[2], quiet[3], true)
            end

            GameTooltip:AddLine(L.Text.ICON_ID:format(tostring(self.value)), quiet[1], quiet[2], quiet[3])
            GameTooltip:Show()
        end))
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        grid.buttons[index] = button
    end

    -- A cover over the grid while spell names are still being read: the
    -- wheel's own ring with its glow turning, and how far along it is.
    local loading = CreateFrame("Frame", nil, grid, BackdropTemplateMixin and "BackdropTemplate" or nil)
    loading:SetAllPoints()
    loading:SetFrameLevel(grid:GetFrameLevel() + 5)
    loading:EnableMouse(true)
    L.Style.Surface(loading, { 0.075, 0.075, 0.09, 0.92 }, { 0, 0, 0, 0 })
    loading.ring = loading:CreateTexture(nil, "ARTWORK")
    loading.ring:SetTexture(L.Wheel.RING_TEXTURE)
    loading.ring:SetSize(LOADING_SIZE, LOADING_SIZE)
    loading.ring:SetPoint("CENTER", 0, 14)
    loading.glow = loading:CreateTexture(nil, "OVERLAY")
    loading.glow:SetTexture(L.Wheel.GLOW_TEXTURE)
    loading.glow:SetBlendMode("ADD")
    loading.glow:SetAllPoints(loading.ring)
    loading.text = loading:CreateFontString(nil, "OVERLAY")
    loading.text:SetFontObject(L.Style.Body)
    loading.text:SetPoint("TOP", loading.ring, "BOTTOM", 0, -10)
    loading:SetScript("OnUpdate", function(self, elapsed)
        self.angle = ((self.angle or 0) - elapsed * LOADING_SPIN) % (2 * math.pi)
        self.glow:SetRotation(self.angle)
    end)
    loading:Hide()
    grid.loading = loading

    -- The next page's icons, drawn invisibly so the game loads them before
    -- the page is turned and they appear at once.
    grid.preload = {}
    for index = 1, #grid.buttons do
        local texture = grid:CreateTexture(nil, "BACKGROUND")
        texture:SetSize(1, 1)
        texture:SetPoint("TOPLEFT")
        texture:SetAlpha(0)
        grid.preload[index] = texture
    end

    grid:SetScript("OnMouseWheel", Safe(function(_, delta)
        if grid.onScroll then
            grid.onScroll(-delta)
        end
    end))

    return grid
end

-- input: a scene
-- output: the picker window
-- Opens a page of the game's icons; clicking one gives the scene that icon,
-- which its bar button picks up too.
function L.Editors.Icon(scene)
    -- A typed icon id or name works as well. Scroll over the icons, or use the
    -- buttons, to turn the page.
    if iconWindow then
        iconWindow:Hide()
    end

    local icons = L.Compat.MacroIcons()
    if #icons == 0 then
        L.Util.Print(L.Text.MSG_NO_ICONS, "error")
        return nil
    end

    local frame = IconGrid()
    local window = L.UI.Window(L.Text.TITLE_ICON:format(L.Util.Escape(scene.name)), 440, 440,
        "SpeakEasyIconPicker", nil, function()
            iconWindow = nil
            L.Compat.ReadIconNames(nil)
            frame.loading:Hide()
            frame:Hide()
            frame:ClearAllPoints()
            frame:SetParent(UIParent)
            frame.onChoose, frame.onScroll = nil, nil
        end)
    iconWindow = window

    local page = 1
    local label, reading, lastSearch
    -- What the grid shows: icons, with names where a search found them.
    local list, names = icons, {}

    -- input: nothing
    -- output: nothing
    -- Shows the current page of the list on the grid, with its page label.
    local function Show()
        local pages = math.max(1, math.ceil(#list / #frame.buttons))
        page = math.max(1, math.min(page, pages))
        local first = (page - 1) * #frame.buttons
        for index, button in ipairs(frame.buttons) do
            local value = list[first + index]
            button.value, button.name = value, names[first + index]
            button.icon:SetTexture(value)
            button:SetShown(value ~= nil)
            frame.preload[index]:SetTexture(list[first + #frame.buttons + index])
        end

        -- A search before every name is read shows the loading cover.
        local searching = lastSearch ~= nil and lastSearch ~= ""
        frame.loading:SetShown(reading ~= nil and searching)
        frame.loading.text:SetText(reading or "")
        label:SetText(#list == 0 and not reading and L.Text.ICON_NONE or L.Text.ICON_PAGE:format(page, pages))
    end

    -- input: the search text, and true to stay on the current page
    -- output: nothing
    -- Lists an exact spell or item (or a shift-clicked one) first, then every
    -- icon whose name holds the text, or an id typed as a number.
    local function Search(text, keepPage)
        text = strtrim(text or "")
        lastSearch = text
        list, names = icons, {}
        if text ~= "" then
            list = {}
            local found, name = L.Compat.IconFor(text)
            if tonumber(text) then
                found, name = tonumber(text), nil
            end

            if found then
                list[1], names[1] = found, name
            end

            local _, _, query = L.Compat.ParseLink(text)
            for _, icon in ipairs(L.Compat.SearchIcons(query)) do
                if icon ~= found then
                    list[#list + 1] = icon
                end
            end
        end

        if not keepPage then
            page = 1
        end

        Show()
    end

    -- input: an icon file id
    -- output: nothing
    -- Gives the scene that icon and closes the picker.
    frame.onChoose = function(icon)
        scene.icon = icon
        L.Macro.Sync(scene)
        window:Hide()
        L.Window.Refresh()
    end

    -- input: the number of pages to turn, negative for back
    -- output: nothing
    -- Turns the page and shows it.
    frame.onScroll = function(delta)
        page = page + delta
        Show()
    end

    local search = L.UI.Input(window, L.Text.LABEL_ICON_SEARCH, "", nil, function(text)
        -- A number is an icon's file id: use it straight away.
        local id = tonumber(text)
        if id then
            frame.onChoose(id)
        end
    end)
    search:SetCallback("OnTextChanged", Safe(function(_, _, text)
        Search(text)
    end))

    -- A space of the grid's size in the layout; the grid sits on top of it.
    local holder = L.UI.Group(window)
    holder:SetAutoAdjustHeight(false)
    holder:SetHeight(frame:GetHeight() + ICON_GAP)
    frame:SetParent(holder.frame)
    frame:ClearAllPoints()
    frame:SetPoint("TOP", holder.frame, "TOP", 0, -2)
    frame:SetFrameLevel(holder.frame:GetFrameLevel() + 2)
    frame:Show()

    L.UI.Button(window, L.Text.BUTTON_PREVIOUS, 0.25, function()
        frame.onScroll(-1)
    end)
    label = L.UI.Label(window, "", 0.48, "caption")
    label:SetJustifyH("CENTER")
    L.UI.Button(window, L.Text.BUTTON_NEXT, 0.25, function()
        frame.onScroll(1)
    end)

    Show()
    -- Names come from reading the spell list; refresh a search as they
    -- arrive. Started last, as it reports at once when already done.
    L.Compat.ReadIconNames(function(progress, done)
        if iconWindow ~= window then
            return
        end

        -- While names are read only the loading text changes; the search runs
        -- once they are all in, rather than on every frame.
        if not done then
            reading = L.Text.ICON_READING:format(math.floor(progress * 100))
            frame.loading.text:SetText(reading)
            return
        end

        reading = nil
        Search(lastSearch or "", true)
    end)

    return window
end

-- input: a trigger, and true to leave out its option
-- output: the trigger's event with its option, as text, marked when this
--         client cannot fire it
-- Describes a trigger's event for lists and menus.
function L.Editors.EventText(trigger, nameOnly)
    local text = L.Text["EVENT_" .. trigger.event] or trigger.event
    if L.Compat.Unavailable()[trigger.event] then
        return text .. " " .. L.Text.NOT_ON_CLIENT
    elseif nameOnly then
        return text
    elseif trigger.event == "LOW_HEALTH" then
        return text .. " " .. L.Text.EVENT_BELOW:format(trigger.options.threshold)
    elseif trigger.event == "SPELL_CAST" then
        local spells = trigger.options.spells or {}
        local first = spells[1]
        if not first then
            return text
        end

        local name = first.item and L.Text.EVENT_ITEM_SHORT:format(L.Util.Escape(first.item))
            or L.Text.EVENT_SPELL_SHORT:format(L.Util.Escape(first.spell))
        if #spells > 1 then
            name = name .. " " .. L.Text.EVENT_MORE:format(#spells - 1)
        end

        return name
    end

    return text
end

-- input: a trigger index, or nil for a new trigger
-- output: the editor window
-- Opens the trigger editor: event and its option, scene, chance and cooldown.
function L.Editors.Trigger(index)
    if triggerWindow then
        triggerWindow:Hide()
    end

    local stored = L.Db.Set().triggers[index]
    local draft = L.Util.DeepCopy(stored or L.Db.NewTrigger())

    local window = L.UI.Window(stored and L.Text.TITLE_EDIT_TRIGGER or L.Text.TITLE_NEW_TRIGGER,
        420, TRIGGER_EDITOR_HEIGHT, "SpeakEasyTriggerEditor", nil, function()
            triggerWindow = nil
        end)
    triggerWindow = window

    local events, eventOrder = {}, {}
    local unavailable = L.Compat.Unavailable()
    for _, event in ipairs(L.Db.EVENTS) do
        -- An unsupported event stays listed only for a trigger that already uses it.
        if not unavailable[event] or event == draft.event then
            events[event] = L.Editors.EventText({ event = event, options = {} }, true)
            eventOrder[#eventOrder + 1] = event
        end
    end

    local scenes, sceneOrder = {}, {}
    for _, scene in ipairs(L.Db.Set().scenes) do
        scenes[scene.id] = L.Util.Escape(scene.name)
        sceneOrder[#sceneOrder + 1] = scene.id
    end

    local Build

    -- input: nothing
    -- output: nothing
    -- Saves the draft trigger and closes the editor, unless a spell or scene is missing.
    local function Save()
        if draft.event == "SPELL_CAST" and #(draft.options.spells or {}) == 0 then
            L.Util.Print(L.Text.ERR_NO_SPELL, "error")
            return
        end

        if not scenes[draft.sceneId] then
            L.Util.Print(L.Text.ERR_NO_SCENE, "error")
            return
        end

        L.Db.SaveTrigger(index, draft)
        window:Hide()
        L.Window.Refresh()
    end

    -- input: true to put the cursor back in the spell box
    -- output: nothing
    -- Rebuilds the editor's controls, since each event has its own option.
    Build = function(focusSpell)
        window:ReleaseChildren()
        -- The spell list needs room; other events need less.
        window:SetHeight(draft.event == "SPELL_CAST" and SPELL_EDITOR_HEIGHT or TRIGGER_EDITOR_HEIGHT)

        L.UI.Select(window, L.Text.LABEL_EVENT, draft.event, events, eventOrder, nil, function(event)
            draft.event = event
            Build()
        end)

        if draft.event == "LOW_HEALTH" then
            L.UI.Range(window, L.Text.LABEL_THRESHOLD, 5, 95, 1, draft.options.threshold, nil, function(value)
                draft.options.threshold = value
            end)
        elseif draft.event == "SPELL_CAST" then
            draft.options.spells = draft.options.spells or {}
            local spells = draft.options.spells

            -- input: text typed or a shift-clicked spell or item link
            -- output: nothing
            -- Adds the spell, or the spell an item casts, to the list, once.
            local function Add(text)
                local spell, item = L.Compat.SpellOrItem(text)
                if spell == "" then
                    return
                end

                for _, entry in ipairs(spells) do
                    if entry.spell:lower() == spell:lower() and entry.item == item then
                        return
                    end
                end

                if #spells < L.Db.MAX_TRIGGER_SPELLS then
                    spells[#spells + 1] = { spell = spell, item = item }
                end

                -- Rebuilt on the next frame, not inside the box's own callback.
                C_Timer.After(0, Safe(function()
                    if triggerWindow == window then
                        Build(true)
                    end
                end))
            end

            local input = L.UI.Input(window, L.Text.LABEL_SPELL, "", nil, Add)
            input:DisableButton(true)
            input:SetCallback("OnTextChanged", Safe(function(_, _, text)
                if text:find("|H", 1, true) then
                    Add(text)
                end
            end))

            local list = L.UI.ScrollList(window, SPELL_LIST_HEIGHT)
            for index, entry in ipairs(spells) do
                local row = L.UI.Row(list, L.Util.Escape(entry.item or entry.spell), function()
                end)
                row:SetSecondary(entry.item and L.Text.SPELL_VIA:format(L.Util.Escape(entry.spell)) or "")
                row:SetActions({ { "remove", L.Text.BUTTON_REMOVE, "danger" } })
                row:SetCallback("OnAction", Safe(function()
                    table.remove(spells, index)
                    C_Timer.After(0, Safe(function()
                        if triggerWindow == window then
                            Build()
                        end
                    end))
                end))
            end

            if #spells == 0 then
                L.UI.Label(list, L.Text.HINT_NO_SPELLS, nil)
            end

            if focusSpell then
                input:SetFocus()
            end
        end

        L.UI.Select(window, L.Text.LABEL_SCENE, draft.sceneId, scenes, sceneOrder, nil, function(id)
            draft.sceneId = id
        end)
        L.UI.Range(window, L.Text.LABEL_CHANCE, 1, 100, 1, draft.chance, nil, function(value)
            draft.chance = value
        end)
        L.UI.Range(window, L.Text.LABEL_TRIGGER_COOLDOWN, 0, 600, 5, draft.cooldown, nil, function(value)
            draft.cooldown = value
        end)

        L.UI.Label(window, " ", nil)
        L.UI.Spacer(window, 0.47)
        L.UI.Button(window, L.Text.BUTTON_CANCEL, 0.25, function()
            window:Hide()
        end)
        L.UI.Button(window, L.Text.BUTTON_SAVE, 0.25, Save, "primary")
    end

    Build()

    return window
end
