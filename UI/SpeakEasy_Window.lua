---@diagnostic disable: undefined-field
-- The main window: a sidebar of scenes beside the selected scene's details,
-- the wheel, triggers and settings tabs, the scene button you drag to a bar,
-- and the minimap button.
local ADDON, L = ...

L.Window = {}

local AceGUI = L.AceGUI
local Safe = L.Util.Safe

local WIDTH, HEIGHT = 860, 580
local FOOTER_HEIGHT = 40
-- Pixels the Scenes tab spends around its two lists, found by laying the tab
-- out in tests/layout.lua: the sidebar's heading, padding and button row; and
-- the scene header, the Delivery card, and the Lines card's heading and
-- toolbar; plus, for both, the footer under them.
local SCENE_LIST_CHROME = 102 + FOOTER_HEIGHT
local LINE_LIST_CHROME = 262 + FOOTER_HEIGHT
local MINIMAP_ICON = "Interface\\Icons\\INV_Misc_Note_01"
-- The actions every line and trigger row offers.
local ROW_ACTIONS = { { "edit", L.Text.BUTTON_EDIT }, { "delete", L.Text.BUTTON_DELETE, "danger" } }

local window, tabs, dragLabel, dragButton, minimapButton
local state = { scene = 1, tab = "wheel" }

-- input: nothing
-- output: the selected scene, or nil when there are none
-- Clamps the remembered selection to the scene list and returns that scene.
function L.Window.SelectedScene()
    local scenes = L.Db.Set().scenes
    state.scene = math.max(1, math.min(state.scene or 1, #scenes))
    return scenes[state.scene]
end

local SelectedScene = L.Window.SelectedScene

-- input: nothing
-- output: nothing
-- Redraws the open tab and the footer. Safe to call with the window closed.
function L.Window.Refresh()
    if tabs then
        tabs:SelectTab(state.tab)
    end
end

local Refresh = L.Window.Refresh

-- input: the tab's container and the pixels taken by everything around the list
-- output: the list height that fills the rest of the tab
-- Works out how tall a list can be, keeping a small minimum.
-- ponytail: worked out on each redraw, so a resize applies on the next click.
local function ListHeight(container, chrome)
    return math.max(78, L.UI.ContentHeight(container) - chrome)
end

-- input: a list of row widgets and the index to select
-- output: nothing
-- Moves the selection without rebuilding the tab, so it is instant and a
-- double click lands on the same row it started on.
local function Select(rows, index)
    for i, row in ipairs(rows) do
        row:SetSelected(i == index)
    end
end

-- input: nothing
-- output: nothing
-- Points the footer and the drag button at the selected scene. Both belong
-- to scenes, so they only show on the Scenes tab.
local function UpdateFooter()
    local scene = SelectedScene()
    local onScenes = state.tab == "scenes"
    if dragLabel then
        dragLabel:SetText(scene and L.Text.DRAG_HINT:format(L.Util.Escape(scene.name)) or "")
    end

    if dragButton then
        dragButton.icon:SetTexture(scene and scene.icon)
        dragButton:SetShown(scene ~= nil and window ~= nil and onScenes)
    end
end

-- input: a count of lines
-- output: "3 lines", "1 line" or "No lines"
-- Describes how many lines a scene has.
local function LineCount(count)
    if count == 0 then
        return L.Text.LINE_COUNT_NONE
    end

    return (count == 1 and L.Text.LINE_COUNT_ONE or L.Text.LINE_COUNT):format(count)
end

-- input: the sidebar card and the tab container
-- output: nothing
-- Fills the scene list and the buttons under it.
local function BuildSidebar(sidebar, container)
    local scenes = L.Db.Set().scenes
    local list = L.UI.ScrollList(sidebar, ListHeight(container, SCENE_LIST_CHROME))

    for index, scene in ipairs(scenes) do
        local enabled = L.Play.EnabledCount(scene)
        local row = L.UI.Row(list, L.Util.Escape(scene.name), function()
            state.scene, state.line = index, nil
            Refresh()
        end)
        row:SetSecondary(scene.enabled and LineCount(enabled) or L.Text.SCENE_OFF)
        row:SetMuted(not scene.enabled or enabled == 0)
        row:SetSelected(index == state.scene)
    end

    if #scenes == 0 then
        L.UI.Label(list, L.Text.HINT_NO_SCENES, nil)
    end

    L.UI.Button(sidebar, L.Text.BUTTON_NEW_SCENE, nil, function()
        L.UI.Prompt(L.Text.PROMPT_NEW_SCENE, "", function(name)
            local added, result = L.Db.AddScene(name)
            if not added then
                L.Util.Print(result, "error")
                return
            end

            state.scene, state.line = result, nil
            Refresh()
        end)
    end, "primary")
end

-- input: a line
-- output: the line's text for the list, escaped
-- Shows a line's text, or names its emote when the line has no text.
local function LineText(line)
    if strtrim(line.text) == "" then
        return L.Text.EMOTE_ONLY:format(L.Compat.EmoteName(line.emote))
    end

    return L.Util.Escape(line.text)
end

-- input: the detail column, the selected scene and the tab container
-- output: nothing
-- Fills the detail column with the scene's name and actions, how it is said, and its lines.
local function BuildDetail(detail, scene, container)
    -- Header: the scene's icon (click to change it), its name, then what can
    -- be done to the scene itself.
    local icon = AceGUI:Create("Icon")
    icon:SetImage(scene.icon)
    icon:SetImageSize(26, 26)
    icon:SetWidth(34)
    icon:SetHeight(30)
    icon:SetCallback("OnClick", Safe(function()
        L.Editors.Icon(scene)
    end))
    icon:SetCallback("OnEnter", Safe(function(widget)
        GameTooltip:SetOwner(widget.frame, "ANCHOR_TOP")
        GameTooltip:SetText(L.Text.TOOLTIP_ICON, 1, 1, 1)
        GameTooltip:Show()
    end))
    icon:SetCallback("OnLeave", function()
        GameTooltip:Hide()
    end)
    detail:AddChild(icon)
    L.UI.Label(detail, L.Util.Escape(scene.name), 0.46, "title")
    L.UI.Button(detail, L.Text.BUTTON_RENAME, 0.15, function()
        L.UI.Prompt(L.Text.PROMPT_RENAME_SCENE, scene.name, function(name)
            local renamed, err = L.Db.RenameScene(scene, name)
            if not renamed then
                L.Util.Print(err, "error")
            end

            Refresh()
        end)
    end)
    L.UI.Button(detail, L.Text.BUTTON_COPY, 0.16, function()
        local _, index = L.Db.DuplicateScene(scene)
        state.scene, state.line = index, nil
        Refresh()
    end)
    L.UI.Button(detail, L.Text.BUTTON_DELETE, 0.15, function()
        local index = state.scene
        L.UI.Confirm(L.Text.CONFIRM_DELETE_SCENE, L.Util.Escape(scene.name), function()
            L.Db.DeleteScene(index)
            state.line = nil
            Refresh()
        end)
    end, "danger")

    local delivery = L.UI.Section(detail, L.Text.HEADING_DELIVERY)
    local channels = {}
    for _, channel in ipairs(L.Db.CHANNELS) do
        channels[channel] = L.Text["CHANNEL_" .. channel]
    end

    L.UI.Select(delivery, L.Text.LABEL_CHANNEL, scene.channel, channels, L.Db.CHANNELS, 0.3, function(channel)
        scene.channel = channel
    end)
    L.UI.EmoteSelect(delivery, L.Text.LABEL_DEFAULT_EMOTE, scene.defaultEmote, 0.3, function(token)
        scene.defaultEmote = token
        L.Play.ResetBag(scene.id)
    end)
    L.UI.Input(delivery, L.Text.LABEL_COOLDOWN, tostring(scene.cooldown), 0.18, function(text)
        local seconds = tonumber(text)
        if seconds then
            scene.cooldown = math.min(3600, math.max(0, seconds))
        end

        Refresh()
    end)
    L.UI.Toggle(delivery, L.Text.LABEL_ENABLED, scene.enabled, 0.2, function(enabled)
        scene.enabled = enabled
        Refresh()
    end)

    local enabled = L.Play.EnabledCount(scene)
    local caption = L.Text.LINES_SUMMARY:format(enabled, #scene.lines)
    if #scene.lines == 0 then
        caption = L.Text.HINT_NO_LINES
    elseif enabled == 0 then
        caption = L.Text.HINT_ALL_DISABLED
    elseif enabled == 1 then
        caption = L.Text.HINT_ONE_LINE
    end

    local lines = L.UI.Section(detail, L.Text.HEADING_LINES, caption)

    L.UI.Button(lines, L.Text.BUTTON_NEW_LINE, 0.2, function()
        L.Editors.Line(scene, nil)
    end, "primary")

    local list = L.UI.ScrollList(lines, ListHeight(container, LINE_LIST_CHROME))
    local rows = {}
    for index, line in ipairs(scene.lines) do
        local row = L.UI.Row(list, LineText(line), function()
            state.line = index
            Select(rows, index)
        end)
        row:SetSecondary(line.emote and L.Compat.EmoteName(line.emote) or "")
        row:SetToggle(line.enabled)
        row:SetMuted(not line.enabled)
        row:SetSelected(index == state.line)
        row:SetCallback("OnDoubleClick", Safe(function()
            L.Editors.Line(scene, index)
        end))
        row:SetCallback("OnToggle", Safe(function(_, _, on)
            L.Db.SetLineEnabled(scene, index, on)
            Refresh()
        end))
        row:SetActions(ROW_ACTIONS)
        row:SetCallback("OnAction", Safe(function(_, _, action)
            if action == "edit" then
                L.Editors.Line(scene, index)
            else
                L.Db.DeleteLine(scene, index)
                state.line = nil
                Refresh()
            end
        end))
        rows[index] = row
    end
end

-- input: the tab container
-- output: nothing
-- Lays out the scene sidebar, the selected scene's detail and the footer.
local function BuildScenesTab(container)
    container:SetLayout("Flow")
    -- Both columns take the tab's full height, so their tops line up.
    -- Less the footer and the few pixels AceGUI's Flow layout puts above a row.
    local height = L.UI.ContentHeight(container) - FOOTER_HEIGHT - 4
    local sidebar = L.UI.Section(container, L.Text.HEADING_SCENES, nil, 0.28)
    sidebar:SetAutoAdjustHeight(false)
    sidebar:SetHeight(height)
    BuildSidebar(sidebar, container)

    L.UI.Spacer(container, 0.02)

    local detail = L.UI.Group(container, 0.69)
    detail:SetAutoAdjustHeight(false)
    detail:SetHeight(height)
    local scene = SelectedScene()
    if scene then
        BuildDetail(detail, scene, container)
    else
        L.UI.Label(detail, L.Text.HINT_NO_SCENES, nil)
    end

    -- Footer: try a line, and the scene's button to drag to a bar (our own
    -- frame, placed at the window's corner).
    local footer = L.UI.Group(container)
    L.UI.Button(footer, L.Text.BUTTON_TEST_LINE, 110, function()
        local scene = SelectedScene()
        if not scene then
            return
        end

        local line = scene.lines[state.line]
        if not line then
            for _, candidate in ipairs(scene.lines) do
                if candidate.enabled then
                    line = candidate
                    break
                end
            end
        end

        if line then
            L.Play.Test(scene, line.text, line.emote)
        else
            L.Util.Print(L.Text.MSG_NO_LINES:format(scene.name))
        end
    end)
    L.UI.Label(footer, "   " .. L.Text.HINT_TEST, 0.38)
    dragLabel = L.UI.Label(footer, "", 0.4)
    dragLabel:SetJustifyH("RIGHT")
end

-- Slots laid out as a compass in a 3 by 3 grid, 0 being the centre cell.
local COMPASS = { 8, 1, 2, 7, 0, 3, 6, 5, 4 }

-- input: nothing
-- output: a list of slot choices and their order: empty, every scene, every emote
-- Gathers everything a wheel slot can hold.
local function SlotChoices()
    local list, order = { [""] = L.Text.EMPTY_SLOT }, { "" }
    for _, scene in ipairs(L.Db.Set().scenes) do
        list[scene.id] = L.Util.Escape(scene.name)
        order[#order + 1] = scene.id
    end

    local names, tokens = L.Compat.Emotes()
    for _, token in ipairs(tokens) do
        local value = L.Db.EMOTE_SLOT .. token
        list[value] = L.Text.EMOTE_CHOICE:format(names[token])
        order[#order + 1] = value
    end

    return list, order
end

-- input: a container and a page number
-- output: nothing
-- Fills one page: a slot picker for each compass point around a ring picture.
local function BuildWheelPage(container, pageIndex)
    container:SetLayout("Flow")
    local page = L.Db.WheelPages()[pageIndex]
    if not page then
        return
    end

    local list, order = SlotChoices()

    -- input: nothing
    -- output: the slot choices and their order
    -- Hands the shared choices to each slot picker when it opens.
    local function Choices()
        return list, order
    end

    for _, slot in ipairs(COMPASS) do
        if slot == 0 then
            local ring = AceGUI:Create("SpeakEasyRing")
            ring:SetImage(L.Wheel.RING_TEXTURE)
            ring:SetRelativeWidth(0.33)
            container:AddChild(ring)
        else
            -- A slot naming a deleted scene shows as empty.
            local value = list[page[slot]] and page[slot] or ""
            L.UI.Picker(container, L.Text["SLOT_" .. slot], value, Choices, 0.33, function(choice)
                L.Db.SetWheelSlot(pageIndex, slot, choice ~= "" and choice or nil)
            end)
        end
    end
end

-- input: the tab container
-- output: nothing
-- Shows the wheel's key, page count and size, then a segment per page of slots.
local function BuildWheelTab(container)
    container:SetLayout("Fill")
    local scroll = L.UI.Scroll(container)
    local settings = L.Db.Settings()
    local pages = L.Db.WheelPages()

    local wheel = L.UI.Section(scroll, L.Text.HEADING_WHEEL, L.Text.HINT_WHEEL)
    -- Narrow key and Preview, with gaps, so the two sliders have room.
    L.UI.BindingPicker(wheel, L.Text.BINDING_WHEEL, "SPEAKEASY_WHEEL", 0.2)
    L.UI.Spacer(wheel, 0.04)
    L.UI.Range(wheel, L.Text.LABEL_WHEEL_PAGES, 1, L.Db.MAX_WHEEL_PAGES, 1, #pages, 0.27, function(count)
        L.Db.SetWheelPageCount(count)
        state.wheelPage = math.min(state.wheelPage or 1, count)
        Refresh()
    end, true)
    L.UI.Spacer(wheel, 0.04)
    L.UI.Range(wheel, L.Text.LABEL_WHEEL_SIZE, 0.5, 2, 0.05, settings.wheelScale, 0.27, function(scale)
        settings.wheelScale = scale
    end)
    L.UI.Spacer(wheel, 0.04)
    L.UI.Button(wheel, L.Text.BUTTON_PREVIEW_WHEEL, 0.13, function()
        L.Wheel.Preview()
    end)
    L.UI.Toggle(wheel, L.Text.LABEL_WHEEL_REMEMBER, settings.wheelRememberPage, nil, function(on)
        settings.wheelRememberPage = on
    end)

    local slots = L.UI.Section(scroll, L.Text.HEADING_SLOTS, L.Text.CAPTION_SLOTS)
    local pageTabs = AceGUI:Create("SpeakEasyTabs")
    pageTabs:SetFullWidth(true)
    pageTabs:SetLayout("Flow")
    local tabList = {}
    for index in ipairs(pages) do
        tabList[index] = { text = L.Text.PAGE_NAME:format(index), value = index }
    end

    pageTabs:SetTabs(tabList)
    pageTabs:SetCallback("OnGroupSelected", Safe(function(group, _, index)
        state.wheelPage = index
        group:ReleaseChildren()
        BuildWheelPage(group, index)
    end))
    slots:AddChild(pageTabs)
    pageTabs:SelectTab(math.min(state.wheelPage or 1, #pages))
end

-- input: a trigger
-- output: its scene, chance and cooldown as one quiet line
-- Summarises a trigger for its row in the list.
local function TriggerDetail(trigger)
    local scene = L.Db.FindScene(trigger.sceneId)
    return L.Text.TRIGGER_DETAIL:format(scene and L.Util.Escape(scene.name) or L.Text.MISSING_SCENE,
        trigger.chance .. "%", L.Text.SECONDS:format(trigger.cooldown))
end

-- input: the tab container
-- output: nothing
-- Fills the tab with the triggers list and its toolbar.
local function BuildTriggersTab(container)
    container:SetLayout("Fill")
    local scroll = L.UI.Scroll(container)
    local triggers = L.Db.Set().triggers

    local box = L.UI.Section(scroll, L.Text.HEADING_TRIGGERS, L.Text.HINT_TRIGGERS)
    L.UI.Button(box, L.Text.BUTTON_NEW_TRIGGER, 0.2, function()
        L.Editors.Trigger(nil)
    end, "primary")
    L.UI.Label(box, " ", nil)

    local rows = {}
    for index, trigger in ipairs(triggers) do
        local row = L.UI.Row(box, L.Editors.EventText(trigger), function()
            state.trigger = index
            Select(rows, index)
        end)
        row:SetSecondary(TriggerDetail(trigger))
        row:SetToggle(trigger.enabled)
        row:SetMuted(not trigger.enabled)
        row:SetSelected(index == state.trigger)
        row:SetCallback("OnDoubleClick", Safe(function()
            L.Editors.Trigger(index)
        end))
        row:SetCallback("OnToggle", Safe(function(_, _, on)
            trigger.enabled = on
            Refresh()
        end))
        row:SetActions(ROW_ACTIONS)
        row:SetCallback("OnAction", Safe(function(_, _, action)
            if action == "edit" then
                L.Editors.Trigger(index)
            else
                L.Db.DeleteTrigger(index)
                state.trigger = nil
                Refresh()
            end
        end))
        rows[index] = row
    end

    if #triggers == 0 then
        L.UI.Label(box, L.Text.HINT_NO_TRIGGERS, nil)
    end

    -- How Say and Yell lines from triggers go out, beside the triggers
    -- themselves: outside instances they wait for a key press.
    local settings = L.Db.Settings()
    local lines = L.UI.Section(scroll, L.Text.HEADING_TRIGGER_LINES, L.Text.CAPTION_TRIGGER_LINES)
    L.UI.Toggle(lines, L.Text.LABEL_ANY_KEY, settings.speakOnAnyKey, nil, function(on)
        settings.speakOnAnyKey = on
    end):SetDescription(L.Text.DESC_ANY_KEY)
    L.UI.Range(lines, L.Text.LABEL_PRIME_TIMEOUT, 3, 30, 1, settings.primeTimeout, 0.5, function(value)
        settings.primeTimeout = value
    end)
end

-- input: the tab container
-- output: nothing
-- Fills the tab with hotkeys, then how trigger lines go out, then general options.
local function BuildSettingsTab(container)
    container:SetLayout("Fill")
    local scroll = L.UI.Scroll(container)
    local settings = L.Db.Settings()

    local hotkeys = L.UI.Section(scroll, L.Text.HEADING_HOTKEYS, L.Text.CAPTION_HOTKEYS)
    L.UI.BindingPicker(hotkeys, L.Text.BINDING_WHEEL, "SPEAKEASY_WHEEL", 0.5)
    L.UI.BindingPicker(hotkeys, L.Text.BINDING_SPEAK, "SPEAKEASY_SPEAK", 0.5)

    -- Limits that apply to every trigger, whatever its channel.
    local all = L.UI.Section(scroll, L.Text.HEADING_ALL_TRIGGERS)
    L.UI.Range(all, L.Text.LABEL_GLOBAL_GAP, 0, 60, 1, settings.globalTriggerGap, 0.5, function(value)
        settings.globalTriggerGap = value
    end)
    L.UI.Spacer(all, 0.48)
    L.UI.Toggle(all, L.Text.LABEL_MUTE, settings.triggersMuted, nil, function(muted)
        L.Triggers.SetMuted(muted)
    end)

    local general = L.UI.Section(scroll, L.Text.HEADING_GENERAL, nil)
    L.UI.Input(general, L.Text.LABEL_TARGET_FALLBACK, settings.targetFallback, 0.5, function(text)
        settings.targetFallback = strtrim(text)
    end)
    L.UI.Toggle(general, L.Text.LABEL_CHARACTER_SET, L.Db.UsesCharacterSet(), nil, function(on)
        L.Db.SetCharacterSet(on)
        state.scene, state.line = 1, nil
        Refresh()
    end)
end

-- input: nothing
-- output: the drag button
-- Builds the scene button once.
local function DragButton()
    -- It is our own frame rather than an AceGUI widget, because AceGUI
    -- recycles frames and drag scripts would leak.
    if dragButton then
        return dragButton
    end

    local button = CreateFrame("Button", "SpeakEasyDragButton", UIParent)
    button:SetSize(32, 32)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:RegisterForDrag("LeftButton")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- input: nothing
    -- output: nothing
    -- Puts the selected scene's macro on the cursor.
    local function Pickup()
        local scene = SelectedScene()
        if scene then
            L.Macro.Pickup(scene)
        end
    end

    button:SetScript("OnDragStart", Safe(Pickup))
    button:SetScript("OnClick", Safe(function(_, mouseButton)
        local scene = SelectedScene()
        if mouseButton == "RightButton" and scene then
            L.Compat.OpenChat("/speakeasy " .. scene.id)
        else
            Pickup()
        end
    end))
    button:SetScript("OnEnter", Safe(function(self)
        local scene = SelectedScene()
        if not scene then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L.Util.Escape(scene.name))
        GameTooltip:AddLine(L.Text.TOOLTIP_DRAG, 1, 1, 1, true)
        GameTooltip:AddLine(L.Text.TOOLTIP_COPY:format(scene.id), 1, 1, 1, true)
        GameTooltip:Show()
    end))
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    dragButton = button

    return button
end

-- input: a tab to show ("scenes", "wheel", "triggers", "settings"), or nil
--        for the last one used
-- output: nothing
-- Opens the window, or brings it to that tab when it is already open.
function L.Window.Open(tab)
    state.tab = tab or state.tab
    if window then
        Refresh()
        return
    end

    -- Read spell names for the icon picker's search now, in the background,
    -- so they are usually all in by the time the picker is opened.
    L.Compat.StartReadingIconNames()

    window = L.UI.Window(L.Text.ADDON_NAME, WIDTH, HEIGHT, "SpeakEasyWindow", L.Db.Settings().window, function()
        window, tabs, dragLabel = nil, nil, nil
        if dragButton then
            dragButton:Hide()
            dragButton:ClearAllPoints()
            dragButton:SetParent(UIParent)
        end

        L.Editors.CloseAll()
    end)

    tabs = AceGUI:Create("SpeakEasyTabs")
    tabs:SetFullWidth(true)
    tabs:SetAutoAdjustHeight(false)
    tabs:SetTabs({
        { text = L.Text.TAB_WHEEL, value = "wheel" },
        { text = L.Text.TAB_SCENES, value = "scenes" },
        { text = L.Text.TAB_TRIGGERS, value = "triggers" },
        { text = L.Text.TAB_SETTINGS, value = "settings" },
    })
    tabs:SetCallback("OnGroupSelected", Safe(function(container, _, tab)
        state.tab = tab
        dragLabel = nil
        container:ReleaseChildren()
        container:PauseLayout()
        if tab == "triggers" then
            BuildTriggersTab(container)
        elseif tab == "settings" then
            BuildSettingsTab(container)
        elseif tab == "wheel" then
            BuildWheelTab(container)
        else
            BuildScenesTab(container)
        end

        container:ResumeLayout()
        container:DoLayout()
        UpdateFooter()
    end))
    -- Less the few pixels AceGUI's Flow layout puts above a row.
    tabs:SetHeight(L.UI.ContentHeight(window) - 4)
    window:AddChild(tabs)

    local button = DragButton()
    button:SetParent(window.frame)
    button:ClearAllPoints()
    button:SetPoint("BOTTOMRIGHT", window.frame, "BOTTOMRIGHT", -L.Style.PAD - 4, L.Style.PAD - 2)
    button:SetFrameLevel(window.frame:GetFrameLevel() + 10)

    tabs:SelectTab(state.tab)
end

-- input: nothing
-- output: nothing
-- Closes the window when it is open, otherwise opens it.
function L.Window.Toggle()
    if window then
        window:Hide()
    else
        L.Window.Open()
    end
end

-- input: nothing
-- output: true while the window is open
-- Tells whether the window is showing.
function L.Window.IsOpen()
    return window ~= nil
end

-- input: the minimap button
-- output: nothing
-- Places the button on the minimap's edge at the saved angle.
local function PlaceMinimapButton(button)
    local angle = math.rad(L.Db.Settings().minimapAngle)
    local radius = Minimap:GetWidth() / 2 + 10
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

-- input: nothing
-- output: nothing
-- Builds the minimap button: left click opens the window, right click mutes
-- triggers, drag moves it around the edge.
function L.Window.CreateMinimapButton()
    if minimapButton or not Minimap then
        return
    end

    local button = CreateFrame("Button", "SpeakEasyMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture(MINIMAP_ICON)
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", 7, -5)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    local atan2 = math.atan2 or math.atan

    -- input: the minimap button
    -- output: nothing
    -- Saves the angle from the minimap's centre to the cursor and moves the button there.
    local function Follow(self)
        local centreX, centreY = Minimap:GetCenter()
        local cursorX, cursorY = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        L.Db.Settings().minimapAngle = math.deg(atan2(cursorY / scale - centreY, cursorX / scale - centreX))
        PlaceMinimapButton(self)
    end

    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", Safe(Follow))
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    button:SetScript("OnClick", Safe(function(_, mouseButton)
        if mouseButton == "RightButton" then
            L.Triggers.SetMuted(not L.Db.Settings().triggersMuted)
        else
            L.Window.Toggle()
        end
    end))
    button:SetScript("OnEnter", Safe(function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L.Text.ADDON_NAME)
        GameTooltip:AddLine(L.Text.TOOLTIP_MINIMAP_LEFT, 1, 1, 1)
        GameTooltip:AddLine(L.Db.Settings().triggersMuted and L.Text.TOOLTIP_MINIMAP_UNMUTE
            or L.Text.TOOLTIP_MINIMAP_MUTE, 1, 1, 1)
        GameTooltip:Show()
    end))
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    PlaceMinimapButton(button)
    minimapButton = button
end
