-- A geometry aware stand-in for the WoW frame API, so the real AceGUI library
-- can lay windows out outside the game. Anchors resolve to rectangles,
-- size changes fire OnSizeChanged, Tick() runs OnUpdate like a game frame,
-- and font strings estimate their size from the font's point size.
-- Load after tests/mocks.lua; it replaces CreateFrame, UIParent and the fonts.
local F = { regions = {}, names = {}, errors = {}, frames = {}, staleRects = true }

local SCREEN_W, SCREEN_H = 1920, 1080
-- Average glyph width as a share of the point size, for Friz Quadrata.
local GLYPH = 0.56

local function noop() end
local FALLBACK = { __index = function(_, k) if type(k) == "string" and k:match("^%u") then return noop end end }

-- Fonts ----------------------------------------------------------------------
local function Font(size)
    local font = { size = size, flags = "" }
    function font:GetFont() return "Fonts\\FRIZQT__.TTF", self.size, self.flags end
    function font:SetFont(_, s, flags) self.size = s or self.size; self.flags = flags or "" end
    function font:CopyFontObject(other) self.size = other.size end
    function font:SetTextColor(r, g, b, a) self.color = { r, g, b, a or 1 } end
    function font:GetTextColor() local c = self.color or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] end
    function font:SetJustifyH() end
    function font:SetShadowColor() end
    function font:SetShadowOffset() end
    function font:SetSpacing() end
    return setmetatable(font, FALLBACK)
end
for name, size in pairs({
    GameFontNormal = 12, GameFontHighlight = 12, GameFontDisable = 12, GameFontNormalSmall = 10,
    GameFontHighlightSmall = 10, GameFontDisableSmall = 10, GameFontNormalLarge = 16,
    GameFontHighlightLarge = 16, ChatFontNormal = 14, GameFontNormalHuge = 20,
}) do
    _G[name] = Font(size)
    -- Blizzard's colours: Normal is gold, Highlight white, Disable grey.
    _G[name].color = name:find("Normal") and { 1, 0.82, 0, 1 } or name:find("Disable") and { 0.5, 0.5, 0.5, 1 } or { 1, 1, 1, 1 }
end
CreateFont = function(name) local f = Font(12); if name then _G[name] = f end return f end

-- Geometry -------------------------------------------------------------------
local H_PART = { LEFT = "l", RIGHT = "r", CENTER = "c", TOP = "c", BOTTOM = "c",
    TOPLEFT = "l", TOPRIGHT = "r", BOTTOMLEFT = "l", BOTTOMRIGHT = "r" }
local V_PART = { TOP = "t", BOTTOM = "b", CENTER = "c", LEFT = "c", RIGHT = "c",
    TOPLEFT = "t", TOPRIGHT = "t", BOTTOMLEFT = "b", BOTTOMRIGHT = "b" }

local generation = 0
local Rect

-- input: a region and an axis, "h" or "v"
-- output: the low and high edge on that axis, or nil when unanchored
local function Axis(r, axis)
    local partOf = axis == "h" and H_PART or V_PART
    local lowKey, highKey = axis == "h" and "l" or "b", axis == "h" and "r" or "t"
    local size = axis == "h" and r:GetExplicitWidth() or r:GetExplicitHeight()
    local edges = {}

    for _, p in ipairs(r.points) do
        local rel = p.rel
        if rel == nil then rel = r.parent or F.UIParent end
        local relRect = Rect(rel)
        if relRect then
            local relLow, relHigh = relRect[axis == "h" and 1 or 2], relRect[axis == "h" and 3 or 4]
            local relPart = partOf[p.relPoint] or "c"
            local at = relPart == lowKey and relLow or relPart == highKey and relHigh or (relLow + relHigh) / 2
            at = at + (axis == "h" and p.x or p.y)
            -- When two anchors set the same edge, the first one set wins.
            local part = partOf[p.point] or "c"
            if edges[part] == nil then edges[part] = at end
        end
    end

    local low, high, centre = edges[lowKey], edges[highKey], edges.c
    if low and high then return low, high end
    size = size or 0
    if low then return low, low + size end
    if high then return high - size, high end
    if centre then return centre - size / 2, centre + size / 2 end
    return nil
end

-- input: a region
-- output: { left, bottom, right, top } in screen pixels, or nil when unanchored
Rect = function(r)
    if r == F.UIParent then return { 0, 0, SCREEN_W, SCREEN_H } end
    if r.rectGen == generation then return r.rect end
    if r.resolving then return nil end
    r.resolving = true
    local l, rr = Axis(r, "h")
    local b, t = Axis(r, "v")
    r.resolving = false
    r.rectGen = generation
    r.rect = (l and b) and { l, b, rr, t } or nil
    return r.rect
end
F.Rect = Rect

local function Changed()
    generation = generation + 1
end

-- input: text that may hold colour codes and textures
-- output: the text as it would be drawn, for measuring
local function Visible(text)
    return (tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "WW"):gsub("||", "|"))
end

-- Regions --------------------------------------------------------------------
local Region

-- Methods that hand back a region, created on first use.
local function Child(key, kind)
    return function(self)
        self[key] = self[key] or Region(kind, self)
        return self[key]
    end
end

local function Setter(key, kind)
    return function(self, value)
        if type(value) == "table" then self[key] = value; return end
        local t = self[key] or Region(kind or "Texture", self)
        t.texture = value
        t:SetAllPoints(self)
        self[key] = t
    end
end

Region = function(kind, parent, name)
    local r = { kind = kind or "Frame", shown = true, points = {}, parent = parent, children = {},
        events = {}, scripts = {}, name = name, level = 1, alpha = 1 }
    if parent and parent.children then parent.children[#parent.children + 1] = r end
    F.regions[#F.regions + 1] = r
    if name then _G[name] = r; F.names[name] = r end

    -- Anchors and size
    function r:SetPoint(point, rel, relPoint, x, y)
        if type(rel) == "number" then rel, relPoint, x, y = nil, nil, rel, relPoint end
        if type(rel) == "string" then rel = _G[rel] end
        if type(relPoint) == "number" then relPoint, x, y = nil, relPoint, x end
        for i = #self.points, 1, -1 do if self.points[i].point == point then table.remove(self.points, i) end end
        self.points[#self.points + 1] = { point = point, rel = rel, relPoint = relPoint or point, x = x or 0, y = y or 0 }
        self.fresh = true
        Changed()
    end
    function r:SetAllPoints(rel)
        rel = rel or self.parent
        self.points = {}
        self:SetPoint("TOPLEFT", rel, "TOPLEFT", 0, 0)
        self:SetPoint("BOTTOMRIGHT", rel, "BOTTOMRIGHT", 0, 0)
    end
    function r:ClearAllPoints() self.points = {}; Changed() end
    function r:GetNumPoints() return #self.points end
    function r:GetPoint(i)
        local p = self.points[i or 1]
        if p then return p.point, p.rel, p.relPoint, p.x, p.y end
    end
    function r:SetWidth(w) self.w = w; Changed() end
    function r:SetHeight(h) self.h = h; Changed() end
    function r:SetSize(w, h) self.w, self.h = w, h; Changed() end
    function r:GetExplicitWidth()
        if self.w then return self.w end
        if self.kind == "FontString" then return self:GetStringWidth() end
    end
    function r:GetExplicitHeight()
        if self.h then return self.h end
        if self.kind == "FontString" then return self:GetStringHeight() end
    end
    -- Like the client, a size that depends on anchors is only worked out
    -- when a game frame is drawn. Until then, a frame whose anchors (or whose
    -- anchor frames' anchors) changed this frame reports the size it had when
    -- last drawn. A frame AceGUI reuses from its pool therefore reports its
    -- old size, exactly as in the game.
    local function Moved(self, seen)
        if self.fresh then return true end
        seen = seen or {}
        if seen[self] then return false end
        seen[self] = true
        for _, p in ipairs(self.points) do
            local rel = p.rel or self.parent
            if rel and rel ~= F.UIParent and rel.points and Moved(rel, seen) then return true end
        end
        return false
    end
    local function Anchored(self, a, b)
        local found = {}
        for _, p in ipairs(self.points) do found[p.point] = true end
        for _, x in ipairs(a) do
            if found[x] then for _, y in ipairs(b) do if found[y] then return true end end end
        end
        return false
    end
    local LEFTS, RIGHTS = { "LEFT", "TOPLEFT", "BOTTOMLEFT" }, { "RIGHT", "TOPRIGHT", "BOTTOMRIGHT" }
    local TOPS, BOTTOMS = { "TOP", "TOPLEFT", "TOPRIGHT" }, { "BOTTOM", "BOTTOMLEFT", "BOTTOMRIGHT" }
    function r:GetWidth()
        if F.staleRects and Anchored(self, LEFTS, RIGHTS) and Moved(self) then
            return self.drawnW or 0
        end
        local rect = Rect(self)
        if rect then return rect[3] - rect[1] end
        return self:GetExplicitWidth() or 0
    end
    function r:GetHeight()
        if F.staleRects and Anchored(self, TOPS, BOTTOMS) and Moved(self) then
            return self.drawnH or 0
        end
        local rect = Rect(self)
        if rect then return rect[4] - rect[2] end
        return self:GetExplicitHeight() or 0
    end
    function r:GetSize() return self:GetWidth(), self:GetHeight() end
    function r:GetLeft() local rect = Rect(self); return rect and rect[1] end
    function r:GetBottom() local rect = Rect(self); return rect and rect[2] end
    function r:GetRight() local rect = Rect(self); return rect and rect[3] end
    function r:GetTop() local rect = Rect(self); return rect and rect[4] end
    function r:GetCenter()
        local rect = Rect(self)
        if rect then return (rect[1] + rect[3]) / 2, (rect[2] + rect[4]) / 2 end
    end
    function r:GetRect()
        local rect = Rect(self)
        if rect then return rect[1], rect[2], rect[3] - rect[1], rect[4] - rect[2] end
    end
    function r:GetScale() return 1 end
    function r:GetEffectiveScale() return 1 end

    -- Visibility and hierarchy
    function r:Show() if not self.shown then self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end end
    function r:Hide() if self.shown then self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end end
    function r:SetShown(v) if v then self:Show() else self:Hide() end end
    function r:IsShown() return self.shown end
    function r:IsVisible()
        if not self.shown then return false end
        if self.parent and self.parent ~= F.UIParent and self.parent.IsVisible then return self.parent:IsVisible() end
        return true
    end
    function r:GetParent() return self.parent end
    function r:SetParent(p)
        if self.parent and self.parent.children then
            for i, c in ipairs(self.parent.children) do if c == self then table.remove(self.parent.children, i) break end end
        end
        if type(p) == "string" then p = _G[p] end
        self.parent = p
        if p and p.children then p.children[#p.children + 1] = self end
        Changed()
    end
    function r:GetChildren()
        local list = {}
        for _, c in ipairs(self.children) do if c.kind ~= "Texture" and c.kind ~= "FontString" then list[#list + 1] = c end end
        return table.unpack(list)
    end
    function r:GetRegions()
        local list = {}
        for _, c in ipairs(self.children) do if c.kind == "Texture" or c.kind == "FontString" then list[#list + 1] = c end end
        return table.unpack(list)
    end
    function r:GetName() return self.name end
    function r:GetObjectType() return self.kind end
    function r:IsObjectType(t) return self.kind == t end
    function r:GetFrameLevel() return self.level end
    function r:SetFrameLevel(l) self.level = l end
    function r:GetFrameStrata() return self.strata or "MEDIUM" end
    function r:SetFrameStrata(s) self.strata = s end
    function r:SetAlpha(a) self.alpha = a end
    function r:GetAlpha() return self.alpha end
    function r:IsMouseOver() return false end
    function r:IsMouseEnabled() return self.mouse end
    function r:EnableMouse(v) self.mouse = v end
    function r:IsEnabled() return not self.disabled end
    function r:Enable() self.disabled = false end
    function r:Disable() self.disabled = true end
    function r:SetEnabled(v) self.disabled = not v end

    -- Scripts and events
    function r:SetScript(event, fn) self.scripts[event] = fn end
    function r:GetScript(event) return self.scripts[event] end
    function r:HookScript(event, fn)
        local old = self.scripts[event]
        self.scripts[event] = function(...) if old then old(...) end fn(...) end
    end
    function r:HasScript() return true end
    function r:RegisterEvent(e) self.events[e] = true end
    function r:RegisterUnitEvent(e) self.events[e] = true end
    function r:UnregisterEvent(e) self.events[e] = nil end
    function r:UnregisterAllEvents() self.events = {} end

    -- Child regions
    function r:CreateTexture(n, layer)
        local t = Region("Texture", self, n)
        t.layer = layer
        return t
    end
    function r:CreateFontString(n, layer, font)
        local fs = Region("FontString", self, n)
        fs.layer = layer
        if type(font) == "string" then font = _G[font] end
        fs.size = font and font.size or 12
        fs.textColor = font and font.color
        return fs
    end
    function r:CreateMaskTexture(n) return Region("Texture", self, n) end

    -- Text
    function r:SetText(t)
        if self.kind == "Button" or self.kind == "CheckButton" then
            self:GetFontString().text = t
        else
            self.text = t
        end
        Changed()
    end
    function r:GetText()
        if self.kind == "Button" or self.kind == "CheckButton" then return self:GetFontString().text end
        return self.text
    end
    function r:SetFormattedText(fmt, ...) self:SetText(fmt:format(...)) end
    function r:SetFontObject(font)
        if type(font) == "string" then font = _G[font] end
        self.size = font and font.size or self.size
        if font and font.color then self.textColor = font.color end
        Changed()
    end
    function r:GetFontObject() return Font(self.size or 12) end
    function r:SetFont(_, size) self.size = size or self.size; Changed(); return true end
    function r:GetFont() return "Fonts\\FRIZQT__.TTF", self.size or 12, "" end
    function r:GetStringWidth()
        return #Visible(self.text) * (self.size or 12) * GLYPH
    end
    function r:GetUnboundedStringWidth() return self:GetStringWidth() end
    function r:GetStringHeight()
        local lineHeight = (self.size or 12) + 2
        if (self.text or "") == "" then return 0 end
        local width = self.w
        if not width and #self.points >= 2 then
            local rect = Rect(self)
            width = rect and rect[3] - rect[1]
        end
        local lines = 1
        if width and width > 0 and not self.noWrap then
            lines = math.max(1, math.ceil(self:GetStringWidth() / width))
        end
        return lines * lineHeight
    end
    function r:SetWordWrap(v) self.noWrap = not v end
    function r:SetNonSpaceWrap() end
    function r:GetNumLines() return math.max(1, math.floor(self:GetStringHeight() / ((self.size or 12) + 2))) end
    function r:IsTruncated() return false end
    r.GetFontString = Child("fontString", "FontString")
    function r:SetFontString(fs) self.fontString = fs end
    function r:SetNormalFontObject(font) self:GetFontString():SetFontObject(font) end
    function r:SetHighlightFontObject() end
    function r:SetDisabledFontObject() end

    -- Button textures
    r.SetNormalTexture = Setter("normalTexture")
    r.SetPushedTexture = Setter("pushedTexture")
    r.SetHighlightTexture = Setter("highlightTexture")
    r.SetDisabledTexture = Setter("disabledTexture")
    r.SetCheckedTexture = Setter("checkedTexture")
    r.SetDisabledCheckedTexture = Setter("disabledCheckedTexture")
    r.SetThumbTexture = Setter("thumbTexture")
    r.GetNormalTexture = Child("normalTexture", "Texture")
    r.GetPushedTexture = Child("pushedTexture", "Texture")
    r.GetHighlightTexture = Child("highlightTexture", "Texture")
    r.GetDisabledTexture = Child("disabledTexture", "Texture")
    r.GetCheckedTexture = Child("checkedTexture", "Texture")
    r.GetThumbTexture = Child("thumbTexture", "Texture")
    function r:SetTexture(t) self.texture = t; self.color = nil end
    function r:SetColorTexture(red, g, b, a) self.color = { red, g, b, a or 1 }; self.texture = nil end
    function r:SetVertexColor(red, g, b, a)
        self.vertex = { red, g, b, a or 1 }
        -- On a font string, vertex colour tints the text.
        if self.kind == "FontString" then self.textColor = self.vertex end
    end
    function r:SetBackdrop(b) self.backdrop = b end
    function r:SetBackdropColor(red, g, b, a) self.bg = { red, g, b, a or 1 } end
    function r:SetBackdropBorderColor(red, g, b, a) self.edge = { red, g, b, a or 1 } end
    function r:SetTextColor(red, g, b, a) self.textColor = { red, g, b, a or 1 } end
    function r:SetJustifyH(j) self.justifyH = j end
    function r:GetTexture() return self.texture end

    -- Check buttons, sliders, edit boxes, scroll frames
    function r:SetChecked(v) self.checked = v and true or false end
    function r:GetChecked() return self.checked end
    function r:SetMinMaxValues(lo, hi) self.min, self.max = lo, hi end
    function r:GetMinMaxValues() return self.min or 0, self.max or 0 end
    function r:SetValue(v)
        self.value = v
        if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v) end
    end
    function r:GetValue() return self.value or 0 end
    function r:GetValueStep() return self.step or 1 end
    function r:SetValueStep(s) self.step = s end
    function r:GetNumber() return tonumber(self.text) or 0 end
    function r:Insert(t) self.text = (self.text or "") .. t end
    function r:HasFocus() return false end
    function r:GetCursorPosition() return #(self.text or "") end
    function r:GetMaxLetters() return 0 end
    function r:GetNumLetters() return #(self.text or "") end
    function r:IsMultiLine() return self.multiLine end
    function r:SetMultiLine(v) self.multiLine = v end
    function r:SetScrollChild(child) self.scrollChild = child; Changed() end
    function r:GetScrollChild() return self.scrollChild end
    function r:GetVerticalScroll() return 0 end
    function r:GetHorizontalScroll() return 0 end
    function r:GetVerticalScrollRange()
        local child = self.scrollChild
        if not child then return 0 end
        return math.max(0, child:GetHeight() - self:GetHeight())
    end
    function r:GetHorizontalScrollRange() return 0 end

    return setmetatable(r, FALLBACK)
end

-- Templates: named children the client would create, by suffix.
local TEMPLATE_CHILDREN = {
    UIDropDownMenuTemplate = { Left = "Texture", Middle = "Texture", Right = "Texture", Button = "Button",
        Text = "FontString", Icon = "Texture" },
    InputBoxTemplate = { Left = "Texture", Middle = "Texture", Right = "Texture" },
    UIPanelScrollFrameTemplate = { ScrollBar = "Slider", ScrollBarScrollUpButton = "Button",
        ScrollBarScrollDownButton = "Button", ScrollBarThumbTexture = "Texture" },
    UIPanelButtonTemplate = { Left = "Texture", Middle = "Texture", Right = "Texture" },
}

-- input: a frame type, an optional name, parent and template
-- output: the frame
CreateFrame = function(kind, name, parent, template)
    kind = kind and (kind:sub(1, 1):upper() .. kind:sub(2)) or "Frame"
    if kind == "BUTTON" or kind == "Button" then kind = "Button" end
    if type(parent) == "string" then parent = _G[parent] end
    local f = Region(kind, parent or F.UIParent, name)
    F.frames = F.frames or {}
    F.frames[#F.frames + 1] = f

    for t in tostring(template or ""):gmatch("[^,%s]+") do
        local children = TEMPLATE_CHILDREN[t]
        if children and name then
            for suffix, childKind in pairs(children) do
                local child = Region(childKind, f, name .. suffix)
                if childKind == "Slider" then
                    child.w = 16
                    child:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
                    child:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
                end
            end
        end
        if t == "UIDropDownMenuTemplate" and name then
            local left, middle, right = _G[name .. "Left"], _G[name .. "Middle"], _G[name .. "Right"]
            left:SetSize(25, 64); left:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 17)
            middle:SetSize(115, 64); middle:SetPoint("LEFT", left, "RIGHT", 0, 0)
            right:SetSize(25, 64); right:SetPoint("LEFT", middle, "RIGHT", 0, 0)
            _G[name .. "Text"].size = 10
            _G[name .. "Text"].textColor = { 1, 1, 1, 1 }
        end
        if t == "UIPanelButtonTemplate" or t == "UIPanelCloseButton" then
            f:GetFontString().size = 12
            f:GetFontString():SetPoint("CENTER", f, "CENTER", 0, 0)
        end
    end
    if f.OnLoad then f:OnLoad() end
    return f
end

F.UIParent = Region("Frame", nil, "UIParent")
F.UIParent.w, F.UIParent.h = SCREEN_W, SCREEN_H
UIParent = F.UIParent
WorldFrame = F.UIParent
Minimap = Region("Frame", F.UIParent, "Minimap")
Minimap:SetSize(140, 140)
Minimap:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -20)
GameTooltip = CreateFrame("GameTooltip", "GameTooltip", UIParent)
function GameTooltip:SetOwner(o) self.owner = o end
function GameTooltip:IsOwned(o) return self.owner == o end

-- Unknown named regions (for example a template child this mock lacks)
-- become blank textures instead of nil, as long as their frame exists.
setmetatable(_G, { __index = function(t, k)
    if type(k) ~= "string" then return nil end
    for frameName, frame in pairs(F.names) do
        if #k > #frameName and k:sub(1, #frameName) == frameName then
            local r = Region("Texture", frame, k)
            rawset(t, k, r)
            return r
        end
    end
end })

-- Client globals AceGUI uses ------------------------------------------------
strmatch, strfind, strsub, strlen, strupper, strlower = string.match, string.find, string.sub, string.len, string.upper, string.lower
strrep, strbyte, strchar, gsub, format = string.rep, string.byte, string.char, string.gsub, string.format
tinsert, tremove, tconcat, sort = table.insert, table.remove, table.concat, table.sort
table.wipe = wipe
max, min, floor, ceil, abs = math.max, math.min, math.floor, math.ceil, math.abs
strjoin = function(sep, ...) return table.concat({ ... }, sep) end
strsplit = function(sep, text)
    local parts = {}
    for part in (text .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do parts[#parts + 1] = part end
    return table.unpack(parts)
end
PlaySound = noop
SOUNDKIT = setmetatable({}, { __index = function() return 0 end })
IsShiftKeyDown, IsControlKeyDown, IsAltKeyDown = noop, noop, noop
ChatEdit_InsertLink = noop
CLOSE, OKAY, ACCEPT, NOT_BOUND, NONE = "Close", "Okay", "Accept", "Not Bound", "None"
FONT_COLOR_CODE_CLOSE = "|r"
geterrorhandler = function() return function(err) F.errors[#F.errors + 1] = tostring(err); print("  LUA ERROR " .. tostring(err)) end end
securecallfunction = function(fn, ...) return fn(...) end
hooksecurefunc = function(target, name, fn)
    if type(target) == "string" then target, name, fn = _G, target, name end
    local old = target[name]
    target[name] = function(...) local r = { old(...) }; fn(...); return table.unpack(r) end
end
GetCursorPosition = function() return 0, 0 end
GetScreenWidth = function() return SCREEN_W end
GetScreenHeight = function() return SCREEN_H end
GetCurrentKeyBoardFocus = noop
CloseDropDownMenus = noop
CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a, GetRGB = function(c) return c.r, c.g, c.b end } end

local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end, NewTicker = function() return { Cancel = noop } end }

-- input: nothing
-- output: nothing
-- Settles sizes (firing OnSizeChanged until nothing changes), then runs one
-- game frame: due timers, then every visible frame's OnUpdate.
function F.Tick()
    -- Drawing a frame works out every size; remember them as "last drawn".
    for _, r in ipairs(F.regions) do r.fresh = nil end
    -- A hidden frame isn't drawn, so the client keeps no size for it: one
    -- AceGUI hid when releasing it reports 0 until it has been drawn again.
    for _, r in ipairs(F.regions) do
        local rect = r:IsVisible() and Rect(r)
        if rect then
            r.drawnW, r.drawnH = rect[3] - rect[1], rect[4] - rect[2]
        else
            r.drawnW, r.drawnH = nil, nil
        end
    end
    for _ = 1, 30 do
        local changed = false
        for _, r in ipairs(F.regions) do
            if r.scripts.OnSizeChanged then
                local w, h = r:GetWidth(), r:GetHeight()
                if w ~= r.lastW or h ~= r.lastH then
                    r.lastW, r.lastH = w, h
                    changed = true
                    r.scripts.OnSizeChanged(r, w, h)
                end
            end
        end
        if not changed then break end
    end

    local due = timers
    timers = {}
    for _, fn in ipairs(due) do fn() end

    for _, r in ipairs(F.regions) do
        if r.scripts.OnUpdate and r:IsVisible() then r.scripts.OnUpdate(r, 0.016) end
    end
end

-- input: how many frames to run
function F.Settle(frames)
    for _ = 1, frames or 6 do F.Tick() end
end

return F
