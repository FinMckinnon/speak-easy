---@diagnostic disable: undefined-field
-- The look: palette, type scale, and the addon's own AceGUI widget types for
-- the window, segmented tabs, section cards, buttons and list rows.
--
-- Own widget types rather than restyling AceGUI's: AceGUI pools widgets per
-- type and shares the pool with other addons, so changing the stock
-- widgets' frames would leak this look into them. These types are ours alone.
local ADDON, L = ...

local AceGUI = LibStub("AceGUI-3.0")

L.Style = {}

-- Palette: one accent; everything else is neutral, so the accent always means
-- "this one" (selected, primary action).
local COLOURS = {
    window = { 0.075, 0.075, 0.09, 0.97 },
    windowEdge = { 1, 1, 1, 0.09 },
    card = { 1, 1, 1, 0.035 },
    cardEdge = { 1, 1, 1, 0.07 },
    text = { 0.93, 0.93, 0.95 },
    secondary = { 0.62, 0.62, 0.68 },
    muted = { 0.45, 0.45, 0.5 },
    accent = { 0.98, 0.76, 0.32 },
    onAccent = { 0.12, 0.1, 0.06 },
    danger = { 0.95, 0.42, 0.42 },
    fill = { 1, 1, 1, 0.07 },
    fillHover = { 1, 1, 1, 0.12 },
    fillPressed = { 1, 1, 1, 0.18 },
    rowHover = { 1, 1, 1, 0.045 },
    rowSelected = { 0.98, 0.76, 0.32, 0.16 },
}
L.Style.COLOURS = COLOURS

-- Spacing on an 8 point grid.
local PAD = 16
local GAP = 8
local TITLE_BAR = 44
local SEGMENT_BAR = 28
local BUTTON_HEIGHT = 26
local ROW_HEIGHT = 26
L.Style.PAD, L.Style.GAP = PAD, GAP

local FLAT = "Interface\\Buttons\\WHITE8X8"

-- Type scale: hierarchy from size, weight and colour together: title,
-- heading, body, caption.

-- input: a font name, a base font object, a size and a colour
-- output: the new font object
-- Builds a named font from the base font's face and flags at the given size and colour.
local function Font(name, base, size, colour)
    local font = CreateFont(name)
    local path, _, flags = base:GetFont()
    font:SetFont(path, size, flags)
    font:SetTextColor(colour[1], colour[2], colour[3])

    return font
end
L.Style.Title = Font("SpeakEasyFontTitle", GameFontHighlight, 15, COLOURS.text)
L.Style.Heading = Font("SpeakEasyFontHeading", GameFontHighlight, 13, COLOURS.text)
L.Style.Body = Font("SpeakEasyFontBody", GameFontHighlight, 12, COLOURS.text)
L.Style.Caption = Font("SpeakEasyFontCaption", GameFontHighlightSmall, 11, COLOURS.secondary)

-- input: a frame, a fill colour and an edge colour
-- output: nothing
-- Gives a frame a flat fill and a one pixel edge.
local function Surface(frame, fill, edge)
    frame:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
    frame:SetBackdropColor(fill[1], fill[2], fill[3], fill[4])
    frame:SetBackdropBorderColor(edge[1], edge[2], edge[3], edge[4])
end

-- input: a texture and a colour
-- output: nothing
-- Fills a texture with a flat colour, opaque unless the colour has an alpha.
local function Paint(texture, colour)
    texture:SetColorTexture(colour[1], colour[2], colour[3], colour[4] or 1)
end

local BACKDROP = BackdropTemplateMixin and "BackdropTemplate" or nil

-- Window: a flat dark panel with the title at the top left and a quiet close
-- button; drag the title bar to move it and the grip at the bottom right to
-- resize it. Position and size live in the status table, as with AceGUI's Frame.
do
    local Type, Version = "SpeakEasyWindow", 1

    -- input: a window widget
    -- output: nothing
    -- Saves the window's size and position into its status table, if it has one.
    local function SaveStatus(self)
        local status = self.status
        if not status then
            return
        end

        local frame = self.frame
        status.width, status.height = frame:GetWidth(), frame:GetHeight()
        status.top, status.left = frame:GetTop(), frame:GetLeft()
    end

    local methods = {
        -- input: nothing
        -- output: nothing
        -- Resets the window to a blank, shown dialog when AceGUI hands it out.
        OnAcquire = function(self)
            self.frame:SetFrameStrata("DIALOG")
            self:SetTitle("")
            self:Show()
        end,

        -- input: nothing
        -- output: nothing
        -- Drops the status table when the window goes back to the pool.
        OnRelease = function(self)
            self.status = nil
        end,

        -- input: nothing
        -- output: nothing
        -- Shows the window.
        Show = function(self)
            self.frame:Show()
        end,

        -- input: nothing
        -- output: nothing
        -- Hides the window.
        Hide = function(self)
            self.frame:Hide()
        end,

        -- input: the title text
        -- output: nothing
        -- Sets the title shown at the top left.
        SetTitle = function(self, text)
            self.title:SetText(text or "")
        end,

        -- input: a status table
        -- output: nothing
        -- Restores the window's size and position from the status table and keeps it for saving.
        SetStatusTable = function(self, status)
            self.status = status
            local frame = self.frame
            frame:SetSize(status.width or 700, status.height or 500)
            frame:ClearAllPoints()
            if status.top and status.left then
                frame:SetPoint("TOP", UIParent, "BOTTOM", 0, status.top)
                frame:SetPoint("LEFT", UIParent, "LEFT", status.left, 0)
            else
                frame:SetPoint("CENTER")
            end

            self:OnWidthSet(frame:GetWidth())
            self:OnHeightSet(frame:GetHeight())
        end,

        -- input: the window width
        -- output: nothing
        -- Sizes the content area to the width less the side padding.
        OnWidthSet = function(self, width)
            self.content.width = width - 2 * PAD
            self.content:SetWidth(self.content.width)
        end,

        -- input: the window height
        -- output: nothing
        -- Sizes the content area to the height less the title bar and padding.
        OnHeightSet = function(self, height)
            self.content.height = height - TITLE_BAR - PAD
            self.content:SetHeight(self.content.height)
        end,
    }

    -- input: nothing
    -- output: the new window widget
    -- Builds the window's frames and wires up moving, resizing and closing.
    local function Constructor()
        local frame = CreateFrame("Frame", nil, UIParent, BACKDROP)
        frame:Hide()
        frame:SetMovable(true)
        frame:SetResizable(true)
        frame:SetClampedToScreen(true)
        frame:SetToplevel(true)
        frame:EnableMouse(true)
        Surface(frame, COLOURS.window, COLOURS.windowEdge)

        local bar = CreateFrame("Frame", nil, frame)
        bar:SetPoint("TOPLEFT")
        bar:SetPoint("TOPRIGHT")
        bar:SetHeight(TITLE_BAR)
        bar:EnableMouse(true)

        local title = frame:CreateFontString(nil, "OVERLAY")
        title:SetFontObject(L.Style.Title)
        title:SetPoint("LEFT", bar, "LEFT", PAD, 0)

        -- A child of the title bar, so it sits above the bar that drags the
        -- window; as the bar's sibling, the bar could take its clicks.
        local close = CreateFrame("Button", nil, bar)
        close:SetSize(24, 24)
        close:SetPoint("RIGHT", bar, "RIGHT", -10, 0)
        local cross = close:CreateFontString(nil, "OVERLAY")
        cross:SetFontObject(L.Style.Heading)
        cross:SetText("X")
        cross:SetTextColor(COLOURS.secondary[1], COLOURS.secondary[2], COLOURS.secondary[3])
        cross:SetPoint("CENTER")
        close:SetScript("OnEnter", function()
            cross:SetTextColor(COLOURS.text[1], COLOURS.text[2], COLOURS.text[3])
        end)
        close:SetScript("OnLeave", function()
            cross:SetTextColor(COLOURS.secondary[1], COLOURS.secondary[2], COLOURS.secondary[3])
        end)
        close:SetScript("OnClick", function()
            frame:Hide()
        end)

        local grip = CreateFrame("Button", nil, frame)
        grip:SetSize(16, 16)
        grip:SetPoint("BOTTOMRIGHT", -2, 2)
        grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
        grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

        local content = CreateFrame("Frame", nil, frame)
        content:SetPoint("TOPLEFT", PAD, -TITLE_BAR)
        content:SetPoint("BOTTOMRIGHT", -PAD, PAD)

        local widget = { frame = frame, content = content, title = title, grip = grip, closeButton = close, type = Type }
        for name, fn in pairs(methods) do
            widget[name] = fn
        end

        bar:SetScript("OnMouseDown", function()
            frame:StartMoving()
        end)
        bar:SetScript("OnMouseUp", function()
            frame:StopMovingOrSizing()
            SaveStatus(widget)
        end)
        grip:SetScript("OnMouseDown", function()
            frame:StartSizing("BOTTOMRIGHT")
        end)
        grip:SetScript("OnMouseUp", function()
            frame:StopMovingOrSizing()
            SaveStatus(widget)
            widget:OnWidthSet(frame:GetWidth())
            widget:OnHeightSet(frame:GetHeight())
            widget:DoLayout()
        end)
        frame:SetScript("OnHide", function()
            widget:Fire("OnClose")
        end)
        -- A click on the window's empty space closes any open dropdown.
        frame:SetScript("OnMouseDown", function()
            AceGUI:ClearFocus()
        end)

        return AceGUI:RegisterAsContainer(widget)
    end

    AceGUI:RegisterWidgetType(Type, Constructor, Version)
end

-- Segmented tabs: a row of segments over the content, like a segmented
-- control. Same calls as AceGUI's TabGroup: SetTabs, SelectTab and the
-- OnGroupSelected callback.
do
    local Type, Version = "SpeakEasyTabs", 1

    -- input: a segment and whether it is selected
    -- output: nothing
    -- Colours a segment's label and fill to match its selected state.
    local function Look(segment, selected)
        segment.selected = selected
        local colour = selected and COLOURS.text or COLOURS.secondary
        segment.label:SetTextColor(colour[1], colour[2], colour[3])
        Paint(segment.fill, selected and COLOURS.fillPressed or { 0, 0, 0, 0 })
    end

    local methods = {
        -- input: nothing
        -- output: nothing
        -- Clears the tabs and turns auto height back on when AceGUI hands it out.
        OnAcquire = function(self)
            self:SetTabs({})
            self.noAutoHeight = false
        end,

        -- input: a list of { value, text } tabs
        -- output: nothing
        -- Lays out one segment per tab, building segments on first use and hiding spares.
        SetTabs = function(self, tabs)
            self.tabList = tabs
            local x = 0
            for index, tab in ipairs(tabs) do
                local segment = self.segments[index]
                if not segment then
                    segment = CreateFrame("Button", nil, self.bar)
                    segment:SetHeight(SEGMENT_BAR - 4)
                    segment.fill = segment:CreateTexture(nil, "BACKGROUND")
                    segment.fill:SetAllPoints()
                    segment.label = segment:CreateFontString(nil, "OVERLAY")
                    segment.label:SetFontObject(L.Style.Body)
                    segment.label:SetPoint("CENTER")
                    segment:SetScript("OnEnter", function(s)
                        if not s.selected then
                            Paint(s.fill, COLOURS.rowHover)
                        end
                    end)
                    segment:SetScript("OnLeave", function(s)
                        if not s.selected then
                            Paint(s.fill, { 0, 0, 0, 0 })
                        end
                    end)
                    segment:SetScript("OnClick", function(s)
                        self:SelectTab(s.value)
                    end)
                    self.segments[index] = segment
                end

                segment.value = tab.value
                segment.label:SetText(tab.text)
                segment:SetWidth(segment.label:GetStringWidth() + 2 * PAD)
                segment:ClearAllPoints()
                segment:SetPoint("LEFT", self.bar, "LEFT", 2 + x, 0)
                x = x + segment:GetWidth() + 2
                Look(segment, false)
                segment:Show()
            end

            for index = #tabs + 1, #self.segments do
                self.segments[index]:Hide()
            end

            self.bar:SetWidth(x + 2)
        end,

        -- input: the value of the tab to select
        -- output: nothing
        -- Marks the matching segment as selected and fires OnGroupSelected.
        SelectTab = function(self, value)
            for _, segment in ipairs(self.segments) do
                Look(segment, segment:IsShown() and segment.value == value)
            end

            self.selected = value
            self:Fire("OnGroupSelected", value)
        end,

        -- input: whether to grow with the content
        -- output: nothing
        -- Turns auto height on or off.
        SetAutoAdjustHeight = function(self, on)
            self.noAutoHeight = not on
        end,

        -- input: the content width (unused) and height
        -- output: nothing
        -- Grows the tabs to fit the laid out content, unless auto height is off.
        LayoutFinished = function(self, _, height)
            if self.noAutoHeight then
                return
            end

            self:SetHeight((height or 0) + SEGMENT_BAR + PAD)
        end,

        -- input: the tabs width
        -- output: nothing
        -- Sizes the content area to the full width.
        OnWidthSet = function(self, width)
            self.content.width = width
            self.content:SetWidth(width)
        end,

        -- input: the tabs height
        -- output: nothing
        -- Sizes the content area to the height less the segment bar and padding.
        OnHeightSet = function(self, height)
            self.content.height = height - SEGMENT_BAR - PAD
            self.content:SetHeight(self.content.height)
        end,
    }

    -- input: nothing
    -- output: the new tabs widget
    -- Builds the segment bar and the content area under it.
    local function Constructor()
        local frame = CreateFrame("Frame", nil, UIParent)
        local bar = CreateFrame("Frame", nil, frame, BACKDROP)
        bar:SetPoint("TOPLEFT")
        bar:SetHeight(SEGMENT_BAR)
        Surface(bar, COLOURS.fill, { 0, 0, 0, 0 })

        local content = CreateFrame("Frame", nil, frame)
        content:SetPoint("TOPLEFT", 0, -(SEGMENT_BAR + PAD))
        content:SetPoint("BOTTOMRIGHT")

        local widget = { frame = frame, content = content, bar = bar, segments = {}, type = Type }
        for name, fn in pairs(methods) do
            widget[name] = fn
        end

        return AceGUI:RegisterAsContainer(widget)
    end

    AceGUI:RegisterWidgetType(Type, Constructor, Version)
end

-- Section card: a softly filled card with a heading and an optional caption,
-- grouping the controls that belong together. Replaces AceGUI's gold
-- bordered InlineGroup.
do
    local Type, Version = "SpeakEasySection", 1
    local INNER = 12

    -- input: a section widget
    -- output: the height taken by the heading and caption
    -- Places the content under the heading and caption, whatever they hold.
    local function HeaderHeight(self)
        local height = INNER
        if self.heading:GetText() ~= "" then
            height = height + self.heading:GetStringHeight() + 4
        end

        if self.caption:GetText() ~= "" then
            height = height + self.caption:GetStringHeight() + 4
        end

        return height + (height > INNER and 6 or 0)
    end

    -- input: a section widget
    -- output: nothing
    -- Anchors the content area under the header, inside the card's padding.
    local function Arrange(self)
        self.header = HeaderHeight(self)
        self.content:ClearAllPoints()
        self.content:SetPoint("TOPLEFT", INNER, -self.header)
        self.content:SetPoint("BOTTOMRIGHT", -INNER, INNER + GAP)
    end

    local methods = {
        -- input: nothing
        -- output: nothing
        -- Resets the section to a blank card of the default size when AceGUI hands it out.
        OnAcquire = function(self)
            self:SetTitle("")
            self:SetDescription("")
            self.noAutoHeight = false
            self:SetWidth(300)
            self:SetHeight(100)
        end,

        -- input: the heading text
        -- output: nothing
        -- Sets the heading and moves the content to fit under it.
        SetTitle = function(self, text)
            self.heading:SetText(text or "")
            Arrange(self)
        end,

        -- input: the caption text
        -- output: nothing
        -- Sets the caption and moves the content to fit under it.
        SetDescription = function(self, text)
            self.caption:SetText(text or "")
            Arrange(self)
        end,

        -- input: whether to grow with the content
        -- output: nothing
        -- Turns auto height on or off.
        SetAutoAdjustHeight = function(self, on)
            self.noAutoHeight = not on
        end,

        -- input: the content width (unused) and height
        -- output: nothing
        -- Grows the card to fit the laid out content, unless auto height is off.
        LayoutFinished = function(self, _, height)
            if self.noAutoHeight then
                return
            end

            self:SetHeight((height or 0) + self.header + INNER + GAP)
        end,

        -- input: the section width
        -- output: nothing
        -- Wraps the caption to the new width and resizes the content area.
        OnWidthSet = function(self, width)
            self.caption:SetWidth(width - 2 * INNER)
            Arrange(self)
            self.content.width = width - 2 * INNER
            self.content:SetWidth(self.content.width)
        end,

        -- input: the section height
        -- output: nothing
        -- Sizes the content area to the height less the header and padding.
        OnHeightSet = function(self, height)
            self.content.height = height - self.header - INNER - GAP
            self.content:SetHeight(self.content.height)
        end,
    }

    -- input: nothing
    -- output: the new section widget
    -- Builds the card, heading, caption and content area.
    local function Constructor()
        local frame = CreateFrame("Frame", nil, UIParent)
        -- The card leaves a gap under itself, so stacked sections breathe.
        local card = CreateFrame("Frame", nil, frame, BACKDROP)
        card:SetPoint("TOPLEFT")
        card:SetPoint("BOTTOMRIGHT", 0, GAP)
        Surface(card, COLOURS.card, COLOURS.cardEdge)
        local heading = frame:CreateFontString(nil, "OVERLAY")
        heading:SetFontObject(L.Style.Heading)
        heading:SetPoint("TOPLEFT", INNER, -INNER)
        heading:SetJustifyH("LEFT")

        local caption = frame:CreateFontString(nil, "OVERLAY")
        caption:SetFontObject(L.Style.Caption)
        caption:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
        caption:SetJustifyH("LEFT")

        local content = CreateFrame("Frame", nil, frame)
        local widget = { frame = frame, card = card, content = content, heading = heading, caption = caption,
            type = Type, header = INNER }
        for name, fn in pairs(methods) do
            widget[name] = fn
        end

        return AceGUI:RegisterAsContainer(widget)
    end

    AceGUI:RegisterWidgetType(Type, Constructor, Version)
end

-- Button: flat, with three looks: "primary" (the accent, one per view),
-- "secondary" and "danger". It darkens the moment it is pressed, not on release.
do
    local Type, Version = "SpeakEasyButton", 1

    local LOOKS = {
        primary = { fill = COLOURS.accent, hover = { 1, 0.82, 0.42 }, pressed = { 0.86, 0.66, 0.26 }, text = COLOURS.onAccent },
        secondary = { fill = COLOURS.fill, hover = COLOURS.fillHover, pressed = COLOURS.fillPressed, text = COLOURS.text },
        danger = { fill = { 0.95, 0.42, 0.42, 0.12 }, hover = { 0.95, 0.42, 0.42, 0.2 }, pressed = { 0.95, 0.42, 0.42, 0.28 }, text = COLOURS.danger },
    }

    -- input: a button widget and a state ("fill", "hover" or "pressed")
    -- output: nothing
    -- Paints the button's fill in its look's colour for that state.
    local function Show(self, state)
        local look = LOOKS[self.look]
        Paint(self.fill, look[state])
    end

    local methods = {
        -- input: nothing
        -- output: nothing
        -- Resets the button to a blank, enabled secondary button when AceGUI hands it out.
        OnAcquire = function(self)
            self:SetHeight(BUTTON_HEIGHT)
            self:SetWidth(120)
            self:SetLook("secondary")
            self:SetText("")
            self:SetDisabled(false)
        end,

        -- input: the button text
        -- output: nothing
        -- Sets the button's text.
        SetText = function(self, text)
            self.text:SetText(text or "")
        end,

        -- input: a look name ("primary", "secondary" or "danger")
        -- output: nothing
        -- Switches the button to that look, falling back to "secondary" for unknown names.
        SetLook = function(self, look)
            self.look = LOOKS[look] and look or "secondary"
            local colour = LOOKS[self.look].text
            self.text:SetTextColor(colour[1], colour[2], colour[3])
            Show(self, "fill")
        end,

        -- input: whether the button is disabled
        -- output: nothing
        -- Enables or disables the button and fades it when disabled.
        SetDisabled = function(self, disabled)
            self.disabled = disabled
            self.frame:SetEnabled(not disabled)
            self.frame:SetAlpha(disabled and 0.4 or 1)
        end,
    }

    -- input: nothing
    -- output: the new button widget
    -- Builds the button's fill and text and wires up its hover, press and click.
    local function Constructor()
        local frame = CreateFrame("Button", nil, UIParent)
        frame:Hide()
        -- AceGUI's Flow layout puts widgets edge to edge, so the visible
        -- fill sits in from the frame's sides; the click area stays whole.
        local fill = frame:CreateTexture(nil, "BACKGROUND")
        fill:SetPoint("TOPLEFT", GAP / 2 - 1, 0)
        fill:SetPoint("BOTTOMRIGHT", -(GAP / 2 - 1), 0)
        local text = frame:CreateFontString(nil, "OVERLAY")
        text:SetFontObject(L.Style.Body)
        text:SetPoint("LEFT", fill, "LEFT", 6, 0)
        text:SetPoint("RIGHT", fill, "RIGHT", -6, 0)
        text:SetWordWrap(false)

        local widget = { frame = frame, fill = fill, text = text, type = Type }
        for name, fn in pairs(methods) do
            widget[name] = fn
        end

        frame:SetScript("OnEnter", function()
            Show(widget, "hover")
            widget:Fire("OnEnter")
        end)
        frame:SetScript("OnLeave", function()
            Show(widget, "fill")
            widget:Fire("OnLeave")
        end)
        frame:SetScript("OnMouseDown", function()
            if not widget.disabled then
                Show(widget, "pressed")
            end
        end)
        frame:SetScript("OnMouseUp", function()
            Show(widget, frame:IsMouseOver() and "hover" or "fill")
        end)
        frame:SetScript("OnClick", function(_, button)
            AceGUI:ClearFocus()
            PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION or 852)
            widget:Fire("OnClick", button)
        end)

        return AceGUI:RegisterAsWidget(widget)
    end

    AceGUI:RegisterWidgetType(Type, Constructor, Version)
end

-- List row: one line of a list, with an optional on/off box, the main text
-- (cut with "..." when too long), quieter secondary text, and small actions
-- such as Edit and Delete at the right edge. Selection is a soft accent fill
-- with an accent bar on the left edge.
do
    local Type, Version = "SpeakEasyRow", 1
    local TOGGLE = 14

    -- input: a row widget
    -- output: nothing
    -- Paints the row's fill, accent bar and text for its selected, hover and muted state.
    local function Look(self)
        if self.selected then
            Paint(self.fill, COLOURS.rowSelected)
        elseif self.hover then
            Paint(self.fill, COLOURS.rowHover)
        else
            Paint(self.fill, { 0, 0, 0, 0 })
        end

        self.bar:SetShown(self.selected)
        local colour = self.muted and COLOURS.muted or COLOURS.text
        self.text:SetTextColor(colour[1], colour[2], colour[3])
    end

    -- input: a row widget
    -- output: nothing
    -- Anchors the main and secondary text around the toggle and the actions.
    local function Place(self)
        self.text:ClearAllPoints()
        local left = self.toggle:IsShown() and (8 + TOGGLE + 8) or 10
        self.text:SetPoint("LEFT", left, 0)
        self.secondary:ClearAllPoints()
        self.secondary:SetPoint("RIGHT", -(10 + (self.actionsWidth or 0)), 0)
        if self.secondary:GetText() ~= "" then
            self.text:SetPoint("RIGHT", self.secondary, "LEFT", -GAP, 0)
        else
            self.text:SetPoint("RIGHT", -(10 + (self.actionsWidth or 0)), 0)
        end
    end

    -- input: a row and the action's index
    -- output: the small action button, built on first use
    -- Returns the row's action button at that index, creating it if needed.
    local function Action(self, index)
        if self.actionButtons[index] then
            return self.actionButtons[index]
        end

        local button = CreateFrame("Button", nil, self.frame)
        button:SetHeight(ROW_HEIGHT - 6)
        button.fill = button:CreateTexture(nil, "BACKGROUND")
        button.fill:SetAllPoints()
        button.label = button:CreateFontString(nil, "OVERLAY")
        button.label:SetFontObject(L.Style.Caption)
        button.label:SetPoint("CENTER")
        button:SetScript("OnEnter", function(b)
            Paint(b.fill, COLOURS.fillHover)
        end)
        button:SetScript("OnLeave", function(b)
            Paint(b.fill, COLOURS.fill)
        end)
        button:SetScript("OnClick", function(b)
            self:Fire("OnAction", b.key)
        end)
        self.actionButtons[index] = button

        return button
    end

    local methods = {
        -- input: nothing
        -- output: nothing
        -- Resets the row to a blank, full width, unselected row when AceGUI hands it out.
        OnAcquire = function(self)
            self:SetHeight(ROW_HEIGHT)
            self:SetFullWidth(true)
            self.selected, self.hover, self.muted = false, false, false
            self:SetText("")
            self:SetSecondary("")
            self:SetToggle(nil)
            self:SetActions(nil)
            Look(self)
        end,

        -- input: a list of { key, text, look } actions, or nil for none
        -- output: nothing
        -- Shows the actions at the right edge; clicking one fires OnAction with its key.
        SetActions = function(self, actions)
            -- A "danger" look shows the action's text in red.
            actions = actions or {}
            local x = 6
            for index = #actions, 1, -1 do
                local action = actions[index]
                local button = Action(self, index)
                button.key = action[1]
                button.label:SetText(action[2])
                local colour = action[3] == "danger" and COLOURS.danger or COLOURS.text
                button.label:SetTextColor(colour[1], colour[2], colour[3])
                Paint(button.fill, COLOURS.fill)
                button:SetWidth(button.label:GetStringWidth() + 2 * 10)
                button:ClearAllPoints()
                button:SetPoint("RIGHT", self.frame, "RIGHT", -x, 0)
                button:Show()
                x = x + button:GetWidth() + 4
            end

            for index = #actions + 1, #self.actionButtons do
                self.actionButtons[index]:Hide()
            end

            self.actionsWidth = #actions > 0 and x or 0
            Place(self)
        end,

        -- input: the main text
        -- output: nothing
        -- Sets the row's main text.
        SetText = function(self, text)
            self.text:SetText(text or "")
        end,

        -- input: the secondary text
        -- output: nothing
        -- Sets the quieter text on the right and re-anchors the main text around it.
        SetSecondary = function(self, text)
            self.secondary:SetText(text or "")
            Place(self)
        end,

        -- input: nil, true or false
        -- output: nothing
        -- nil hides the box; true or false shows it ticked or not.
        SetToggle = function(self, value)
            self.toggle:SetShown(value ~= nil)
            self.check:SetShown(value == true)
            self.toggleValue = value
            Place(self)
        end,

        -- input: whether the row is selected
        -- output: nothing
        -- Marks the row as selected or not and repaints it.
        SetSelected = function(self, selected)
            self.selected = selected and true or false
            Look(self)
        end,

        -- input: whether the row is muted
        -- output: nothing
        -- Marks the row as muted or not and repaints its text.
        SetMuted = function(self, muted)
            self.muted = muted and true or false
            Look(self)
        end,

        -- input: the row width
        -- output: nothing
        -- Gives the secondary text just over a quarter of the row's width.
        OnWidthSet = function(self, width)
            self.secondary:SetWidth(math.floor(width * 0.28))
        end,
    }

    -- input: nothing
    -- output: the new row widget
    -- Builds the row's fill, accent bar, toggle and texts and wires up its clicks.
    local function Constructor()
        local frame = CreateFrame("Button", nil, UIParent)
        frame:Hide()
        frame:RegisterForClicks("LeftButtonUp")
        local fill = frame:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints()
        local bar = frame:CreateTexture(nil, "ARTWORK")
        bar:SetPoint("TOPLEFT")
        bar:SetPoint("BOTTOMLEFT")
        bar:SetWidth(2)
        Paint(bar, COLOURS.accent)

        local toggle = CreateFrame("Button", nil, frame, BACKDROP)
        toggle:SetSize(TOGGLE, TOGGLE)
        toggle:SetPoint("LEFT", 8, 0)
        Surface(toggle, { 0, 0, 0, 0.3 }, { 1, 1, 1, 0.35 })
        local check = toggle:CreateTexture(nil, "OVERLAY")
        check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        check:SetPoint("CENTER")
        check:SetSize(TOGGLE + 6, TOGGLE + 6)

        local text = frame:CreateFontString(nil, "OVERLAY")
        text:SetFontObject(L.Style.Body)
        text:SetJustifyH("LEFT")
        text:SetWordWrap(false)

        local secondary = frame:CreateFontString(nil, "OVERLAY")
        secondary:SetFontObject(L.Style.Caption)
        secondary:SetPoint("RIGHT", -10, 0)
        secondary:SetJustifyH("RIGHT")
        secondary:SetWordWrap(false)

        local widget = { frame = frame, fill = fill, bar = bar, toggle = toggle, check = check,
            text = text, secondary = secondary, actionButtons = {}, type = Type }
        for name, fn in pairs(methods) do
            widget[name] = fn
        end

        frame:SetScript("OnEnter", function()
            widget.hover = true
            Look(widget)
        end)
        frame:SetScript("OnLeave", function()
            widget.hover = false
            Look(widget)
        end)
        frame:SetScript("OnClick", function()
            widget:Fire("OnClick")
        end)
        frame:SetScript("OnDoubleClick", function()
            widget:Fire("OnDoubleClick")
        end)
        toggle:SetScript("OnClick", function()
            widget:SetToggle(not widget.toggleValue)
            widget:Fire("OnToggle", widget.toggleValue)
        end)

        return AceGUI:RegisterAsWidget(widget)
    end

    AceGUI:RegisterWidgetType(Type, Constructor, Version)
end
