-- The scene wheel: hold its key to open a ring of 8 slots around the cursor,
-- point at one and release the key to play it. A slot holds a scene or a
-- single emote. Scrolling the mouse wheel while holding flips between pages.
--
-- Plain frames rather than AceGUI: AceGUI only lays widgets out in rows and
-- lists, and recycles its frames between addons. The ring and glow textures
-- are drawn by tools/make_textures.py.
local ADDON, L = ...

L.Wheel = {}

local SLOTS = L.Db.WHEEL_SLOTS
local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
L.Wheel.RING_TEXTURE = MEDIA .. "wheel_ring"
L.Wheel.GLOW_TEXTURE = MEDIA .. "wheel_glow"

-- The textures are 256 pixels with the ring between radius 56 and 126.
-- Sizes are at wheel size 1; the size setting scales the whole frame.
local SIZE = 300
local TEXTURE_SCALE = SIZE / 256
local RADIUS = 91 * TEXTURE_SCALE
-- Releasing inside the ring's hole cancels, as does releasing far outside it.
local DEAD_ZONE = 56 * TEXTURE_SCALE
local OUTER_EDGE = SIZE
local ICON_SIZE = 38
local ARROW_SIZE = 32
local COG_SIZE = 22
local SLOT_ANGLE = 2 * math.pi / SLOTS
local EMOTE_ICON = "Interface\\Icons\\Ability_Warrior_BattleShout"
local PREVIEW_SECONDS = 4

local atan2 = math.atan2 or math.atan

BINDING_NAME_SPEAKEASY_WHEEL = L.Text.BINDING_WHEEL

local frame
local slices = {}
local current = {}
local page = 1
local originX, originY
local picked
local previewing = false

-- input: a slot's stored value
-- output: what the slot plays, as { name, icon, scene or emote }, or nil when empty
-- Turns a stored slot value into the scene or emote it plays.
local function Entry(value)
    if not value or value == "" then
        return nil
    end

    local prefix = L.Db.EMOTE_SLOT
    if value:sub(1, #prefix) == prefix then
        local token = value:sub(#prefix + 1)
        return { name = L.Compat.EmoteName(token), icon = EMOTE_ICON, emote = token }
    end

    local scene = L.Db.FindScene(value)
    if scene then
        return { name = scene.name, icon = scene.icon, scene = scene }
    end
end

-- input: a page number
-- output: a table of slot number to entry, holes where the slot is empty
-- Reads every slot on one wheel page.
function L.Wheel.Slots(pageIndex)
    local values = L.Db.WheelPages()[pageIndex] or {}
    local slots = {}
    for slot = 1, SLOTS do
        slots[slot] = Entry(values[slot])
    end

    return slots
end

-- input: a wheel entry
-- output: true when choosing it would do something
-- Tells whether an entry is an emote or an enabled scene with lines to play.
local function Playable(entry)
    if entry.emote then
        return true
    end

    return entry.scene.enabled and L.Play.EnabledCount(entry.scene) > 0
end

-- input: the cursor's offset from the centre, in wheel size 1 pixels
-- output: the slot the cursor points at, or nil for the centre or outside
-- Finds the slot under the cursor, with slot 1 at the top and the rest clockwise.
function L.Wheel.Pick(dx, dy)
    -- The whole segment counts, not just the icon, so a quick flick in a
    -- direction is enough.
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance < DEAD_ZONE or distance > OUTER_EDGE then
        return nil
    end

    local clockwiseFromTop = (math.pi / 2 - atan2(dy, dx)) % (2 * math.pi)

    return math.floor(clockwiseFromTop / SLOT_ANGLE + 0.5) % SLOTS + 1
end

-- input: nothing
-- output: the cursor's position in the wheel's own coordinates
-- Reads the cursor and scales it to the wheel's size.
local function Cursor()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale() * L.Db.Settings().wheelScale
    return x / scale, y / scale
end

-- input: nothing
-- output: nothing
-- Lights the segment under the cursor and names its entry in the centre.
local function Track()
    local x, y = Cursor()
    picked = L.Wheel.Pick(x - originX, y - originY)
    -- Over a page arrow or the cog, nothing is picked, so letting go there cancels.
    if frame.previous:IsMouseOver() or frame.next:IsMouseOver() or frame.cog:IsMouseOver() then
        picked = nil
    end

    local entry = picked and current[picked]

    frame.glow:SetShown(entry ~= nil)
    if entry then
        frame.glow:SetRotation(-(picked - 1) * SLOT_ANGLE)
    end

    for slot, slice in pairs(slices) do
        slice:SetScale(slot == picked and entry and 1.15 or 1)
    end

    frame.centre:SetText(entry and L.Util.Escape(entry.name) or L.Text.WHEEL_CANCEL)
end

-- input: a slot number
-- output: the slice frame for that slot, built on first use
-- Builds or returns the icon and label for one slot.
local function Slice(slot)
    if slices[slot] then
        return slices[slot]
    end

    local slice = CreateFrame("Frame", nil, frame)
    slice:SetSize(ICON_SIZE, ICON_SIZE)
    local angle = math.pi / 2 - (slot - 1) * SLOT_ANGLE
    slice:SetPoint("CENTER", frame, "CENTER", math.cos(angle) * RADIUS, math.sin(angle) * RADIUS + 6)

    slice.icon = slice:CreateTexture(nil, "ARTWORK")
    slice.icon:SetAllPoints()
    slice.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    slice.label = slice:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    slice.label:SetPoint("TOP", slice, "BOTTOM", 0, -1)
    slice.label:SetWidth(76)
    slice.label:SetWordWrap(false)

    slices[slot] = slice

    return slice
end

-- input: nothing
-- output: nothing
-- Creates the wheel frame with its ring, glow, centre text, page arrows and cog.
local function Build()
    frame = CreateFrame("Frame", "SpeakEasyWheel", UIParent)
    frame:SetSize(SIZE, SIZE)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouseWheel(true)
    frame:Hide()

    frame.ring = frame:CreateTexture(nil, "BACKGROUND")
    frame.ring:SetTexture(L.Wheel.RING_TEXTURE)
    frame.ring:SetAllPoints()

    frame.glow = frame:CreateTexture(nil, "BORDER")
    frame.glow:SetTexture(L.Wheel.GLOW_TEXTURE)
    frame.glow:SetAllPoints()
    frame.glow:SetBlendMode("ADD")

    frame.centre = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.centre:SetPoint("CENTER", 0, 6)
    frame.centre:SetWidth(DEAD_ZONE * 1.8)

    frame.page = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.page:SetPoint("TOP", frame.centre, "BOTTOM", 0, -4)

    -- input: -1 or +1 for the direction, the anchor point, and an x offset
    -- output: the arrow button
    -- Builds a page arrow beside the ring.
    local function Arrow(direction, point, x)
        -- Shown only when there is a page that way. Click them while holding
        -- the wheel key.
        local arrow = CreateFrame("Button", nil, frame)
        arrow:SetSize(ARROW_SIZE, ARROW_SIZE)
        arrow:SetPoint(point, frame, point, x, 0)
        local name = direction < 0 and "PrevPage" or "NextPage"
        arrow:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. name .. "-Up")
        arrow:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. name .. "-Down")
        arrow:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        arrow:SetScript("OnClick", L.Util.Safe(function()
            L.Wheel.TurnPage(direction)
        end))

        return arrow
    end

    frame.previous = Arrow(-1, "LEFT", -ARROW_SIZE)
    frame.next = Arrow(1, "RIGHT", ARROW_SIZE)

    -- A cog under the ring opens the wheel's settings.
    frame.cog = CreateFrame("Button", nil, frame)
    frame.cog:SetSize(COG_SIZE, COG_SIZE)
    frame.cog:SetPoint("TOP", frame, "BOTTOM", 0, -4)
    frame.cog:SetNormalTexture("Interface\\Icons\\INV_Misc_Gear_01")
    frame.cog:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    frame.cog:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L.Text.TOOLTIP_WHEEL_SETTINGS, 1, 1, 1)
        GameTooltip:Show()
    end)
    frame.cog:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    frame.cog:SetScript("OnClick", L.Util.Safe(function()
        previewing = false
        frame:Hide()
        L.Window.Open("wheel")
    end))

    frame:SetScript("OnUpdate", L.Util.Safe(Track))
    frame:SetScript("OnMouseWheel", L.Util.Safe(function(_, delta)
        L.Wheel.TurnPage(-delta)
    end))
end

-- input: nothing
-- output: nothing
-- Fills the ring with the current page's entries.
local function ShowPage()
    local pages = #L.Db.WheelPages()
    page = math.max(1, math.min(page, pages))
    current = L.Wheel.Slots(page)

    for slot = 1, SLOTS do
        local slice = Slice(slot)
        local entry = current[slot]
        if entry then
            slice.icon:SetTexture(entry.icon)
            slice.label:SetText(L.Util.Escape(entry.name))
            local playable = Playable(entry)
            slice.icon:SetDesaturated(not playable)
            slice:SetAlpha(playable and 1 or 0.45)
            slice:Show()
        else
            slice:Hide()
        end
    end

    frame.page:SetText(pages > 1 and L.Text.WHEEL_PAGE:format(page, pages) or "")
    frame.previous:SetShown(page > 1)
    frame.next:SetShown(page < pages)
    Track()
end

-- input: +1 for the next page, -1 for the previous
-- output: the page now shown
-- Turns the wheel's page, stopping at the first and last page like the arrows.
function L.Wheel.TurnPage(delta)
    local pages = #L.Db.WheelPages()
    page = math.max(1, math.min(pages, page + delta))
    if L.Wheel.IsOpen() then
        ShowPage()
    end

    return page
end

-- input: nothing
-- output: true when every page is empty
-- Checks whether any wheel page holds an entry.
local function AllEmpty()
    for index in ipairs(L.Db.WheelPages()) do
        if next(L.Wheel.Slots(index)) then
            return false
        end
    end

    return true
end

-- input: x and y in the wheel's own coordinates
-- output: nothing
-- Shows the wheel centred on a point, building it on first use.
local function ShowAt(x, y)
    if not frame then
        Build()
    end

    originX, originY = x, y
    frame:SetScale(L.Db.Settings().wheelScale)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", originX, originY)
    frame:Show()
    ShowPage()
end

-- input: nothing
-- output: nothing
-- Opens the wheel centred on the cursor, on the page used last.
function L.Wheel.Open()
    if AllEmpty() then
        L.Util.Print(L.Text.MSG_WHEEL_EMPTY)
        return
    end

    previewing = false
    if not L.Db.Settings().wheelRememberPage then
        page = 1
    end

    ShowAt(Cursor())
end

-- input: nothing
-- output: nothing
-- Shows the wheel in the middle of the screen for a few seconds, for judging its size.
function L.Wheel.Preview()
    -- Nothing plays from a preview.
    local scale = L.Db.Settings().wheelScale
    previewing = true
    ShowAt(UIParent:GetWidth() / 2 / scale, UIParent:GetHeight() / 2 / scale)
    C_Timer.After(PREVIEW_SECONDS, function()
        if previewing and frame then
            previewing = false
            frame:Hide()
        end
    end)
end

-- input: nothing
-- output: true while the wheel is on screen
-- Tells whether the wheel is showing.
function L.Wheel.IsOpen()
    return frame ~= nil and frame:IsShown()
end

-- input: nothing
-- output: the entry played, or nil
-- Closes the wheel and plays the slot pointed at.
function L.Wheel.Release()
    -- Runs on the key release, which is a hardware event, so Say and Yell go
    -- out like a bar button press.
    if not L.Wheel.IsOpen() or previewing then
        return nil
    end

    Track()
    frame:Hide()

    local entry = picked and current[picked]
    if not entry or not Playable(entry) then
        return nil
    end

    if entry.emote then
        L.Compat.DoEmote(entry.emote)
    else
        L.Play.Scene(entry.scene, {})
    end

    return entry
end

-- Called by the Scene wheel key binding in Bindings.xml with "down" or "up".
SpeakEasy_Wheel = L.Util.Safe(function(keystate)
    if keystate == "up" then
        L.Wheel.Release()
    else
        L.Wheel.Open()
    end
end)
