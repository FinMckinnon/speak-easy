-- Lays every window out with the real AceGUI library on a geometry aware mock
-- client, then checks for widgets that overlap, spill out of their container
-- or the window, and text too wide for its widget. Writes a picture of each
-- view to tests/out/layout.html for a look by eye.
-- Run from the addon folder: node tests/run.js tests/layout.lua .
local M, F, L = dofile("tests/real.lua")
local check = M.check

-- Worst case data: long names and lines, several triggers and pages.
local combat = L.Db.FindScene("combat")
L.Db.SaveLine(combat, nil, { text = "By the Light, I will not let {targetName} walk away from this fight while I still stand in {zone}!", emote = "CHARGE" })
L.Db.SaveLine(combat, nil, { text = "", emote = "ROAR" })
L.Db.SetLineEnabled(combat, 2, false)
L.Db.AddScene("An Unusually Long Scene Name")
L.Db.SaveTrigger(nil, { event = "SPELL_CAST", sceneId = "combat", chance = 30, cooldown = 60, enabled = true, options = { spell = "Flash of Light" } })
L.Db.SaveTrigger(nil, { event = "LOW_HEALTH", sceneId = "tavern", chance = 100, cooldown = 600, enabled = false, options = { threshold = 30 } })
L.Db.SetWheelPageCount(3)
L.Db.SetWheelSlot(1, 2, "emote:DANCE")

-- Checks -----------------------------------------------------------------------
local issues = {}
local views = {}
local TOLERANCE = 1

local function Overlap(a, b)
    local w = math.min(a[3], b[3]) - math.max(a[1], b[1])
    local h = math.min(a[4], b[4]) - math.max(a[2], b[2])
    return w > TOLERANCE and h > TOLERANCE
end

-- input: two rectangles and whether to check top and bottom too
-- output: true when the first is inside the second, else false and which sides stick out
local function Inside(inner, outer, vertical)
    local sides = {}
    local function Side(name, amount) if amount > TOLERANCE then sides[#sides + 1] = ("%s %.0fpx"):format(name, amount) end end
    Side("left", outer[1] - inner[1])
    Side("right", inner[3] - outer[3])
    if vertical then
        Side("bottom", outer[2] - inner[2])
        Side("top", inner[4] - outer[4])
    end
    return #sides == 0, table.concat(sides, ", ")
end

local function Describe(w)
    local text = w.label and w.label.text or w.text and type(w.text) == "table" and w.text.text or w.titletext and w.titletext.text or ""
    text = tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return w.type .. (text ~= "" and (" '" .. text:sub(1, 30) .. "'") or "")
end

local function Issue(view, message)
    issues[#issues + 1] = view .. ": " .. message
end

-- input: a font string region, the width it has, and what it belongs to
-- output: nothing
-- Flags single line text wider than its space.
local function TextFits(view, fontString, width, owner, what)
    if fontString and fontString.text and fontString.text ~= "" and fontString:IsVisible() then
        local needed = fontString:GetStringWidth()
        if needed > width + TOLERANCE then
            Issue(view, ("%s: %s needs %.0fpx, has %.0fpx"):format(owner, what, needed, width))
        end
    end
end

-- input: the view name, a widget, the window rectangle, and the scroll viewport above it, if any
-- output: nothing
local function Walk(view, widget, windowRect, viewport)
    local frameRect = F.Rect(widget.frame)
    local name = Describe(widget)

    -- A row too narrow to read is as good as missing.
    if widget.type == "SpeakEasyRow" and widget.frame:GetWidth() < 120 then
        Issue(view, ("row '%s' is only %.0fpx wide"):format(M.TextOf(widget) or "", widget.frame:GetWidth()))
    end

    if widget.type == "Button" then
        TextFits(view, widget.text, widget.frame:GetWidth() - 8, name, "text")
    elseif widget.type == "CheckBox" then
        TextFits(view, widget.text, widget.frame:GetWidth() - 26, name, "label")
    elseif widget.type == "Dropdown" then
        TextFits(view, widget.label, widget.frame:GetWidth(), name, "label")
        TextFits(view, widget.text, widget.frame:GetWidth() - 40, name, "chosen text")
    elseif widget.type == "Slider" or widget.type == "EditBox" or widget.type == "Keybinding" then
        TextFits(view, widget.label, widget.frame:GetWidth(), name, "label")
    end

    if not widget.children then return end

    local content = F.Rect(widget.content or widget.frame)
    local isScroll = widget.type == "ScrollFrame"
    if isScroll and #widget.children > 0 then
        local viewport = F.Rect(widget.scrollframe)
        if not viewport or viewport[4] - viewport[2] < 20 then
            Issue(view, ("a list of %d rows has no room to show them (%.0fpx tall)"):format(
                #widget.children, viewport and viewport[4] - viewport[2] or 0))
        end
    end
    local childViewport = isScroll and F.Rect(widget.scrollframe) or viewport
    local shown = {}

    for _, child in ipairs(widget.children) do
        if child.frame:IsVisible() then
            local rect = F.Rect(child.frame)
            local childName = Describe(child)
            if not rect then
                Issue(view, childName .. " has no position")
            else
                shown[#shown + 1] = { child, rect }
                local fits, sides = Inside(rect, content or rect, not isScroll)
                if not fits then
                    Issue(view, ("%s spills out of %s (%s)"):format(childName, name, sides))
                end
                -- Below a scroll viewport is fine (it scrolls); sideways never is.
                local hidden = childViewport and (rect[4] < childViewport[2] or rect[2] > childViewport[4])
                local inWindow, windowSides = Inside(rect, windowRect, childViewport == nil)
                if not hidden and not inWindow then
                    Issue(view, ("%s is outside the window (%s)"):format(childName, windowSides))
                end
            end
            Walk(view, child, windowRect, childViewport)
        end
    end

    for i = 1, #shown do
        for j = i + 1, #shown do
            local a, b = shown[i], shown[j]
            if Overlap(a[2], b[2]) then
                Issue(view, ("%s overlaps %s in %s"):format(Describe(a[1]), Describe(b[1]), name))
            end
            -- AceGUI's Flow layout centres a row's widgets on each other, so a
            -- short group beside a tall one floats halfway down.
            local sameRow = math.min(a[2][4], b[2][4]) - math.max(a[2][2], b[2][2]) > TOLERANCE
            if a[1].children and b[1].children and sameRow and math.abs(a[2][4] - b[2][4]) > 2 then
                Issue(view, ("%s and %s sit side by side but their tops are %.0fpx apart"):format(
                    Describe(a[1]), Describe(b[1]), math.abs(a[2][4] - b[2][4])))
            end
        end
    end
end

-- input: a region
-- output: true when it is one of our own frames rather than part of AceGUI
local function IsRawFrame(region)
    return region.kind ~= "Texture" and region.kind ~= "FontString" and (region.name or ""):match("^SpeakEasy") ~= nil
end

-- Snapshot -------------------------------------------------------------------
local html = {}
local function Esc(s) return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")) end

local COLOURS = { Button = "#c04040", Dropdown = "#4060c0", CheckBox = "#408040", Slider = "#a040a0",
    EditBox = "#a07020", Label = "#999", MultiLineEditBox = "#a07020", Keybinding = "#c06060", Icon = "#808000" }

local function Rgba(c, alphaScale)
    if not c then return "transparent" end
    return ("rgba(%.0f,%.0f,%.0f,%.3f)"):format(c[1] * 255, c[2] * 255, c[3] * 255, (c[4] or 1) * (alphaScale or 1))
end

-- Stand-ins for Blizzard's own input art, which the snapshot cannot load:
-- where each stock widget draws its field, as offsets from its frame.
local FIELDS = {
    Dropdown = function(r) return { r[1] + 2, r[2] + 2, r[3] - 2, r[2] + 26 }, "field" end,
    EditBox = function(r) return { r[1] + 2, r[2] + 1, r[3] - 2, r[2] + 23 }, "field" end,
    Keybinding = function(r) return { r[1] + 2, r[2] + 2, r[3] - 2, r[2] + 26 }, "key" end,
    MultiLineEditBox = function(r) return { r[1], r[2] + 2, r[3], r[4] - 18 }, "field" end,
    Slider = function(r) return { r[1] + 2, r[4] - 26, r[3] - 2, r[4] - 20 }, "track" end,
    CheckBox = function(r) local y = (r[2] + r[4]) / 2; return { r[1] + 2, y - 9, r[1] + 20, y + 9 }, "check" end,
}

local function Draw(view, windowRect)
    local out = {}
    -- Positions are relative to the innermost clipping box drawn so far.
    local origin = windowRect
    local function Place(rect)
        return ("left:%.0fpx;top:%.0fpx;width:%.0fpx;height:%.0fpx"):format(rect[1] - origin[1],
            origin[4] - rect[4], math.max(0, rect[3] - rect[1]), math.max(0, rect[4] - rect[2]))
    end
    local function Region(region)
        if not region:IsVisible() then return end
        local rect = F.Rect(region)
        if rect then
            local widget = region.obj
            if region.backdrop then
                out[#out + 1] = ('<div class="p" style="%s;background:%s;border:1px solid %s"></div>')
                    :format(Place(rect), Rgba(region.bg), Rgba(region.edge))
            end
            if region.kind == "Texture" and region.color then
                out[#out + 1] = ('<div class="p" style="%s;background:%s"></div>'):format(Place(rect), Rgba(region.color))
            elseif region.kind == "Texture" and region.texture and tostring(region.texture):find("Check") and region.parent.kind ~= "CheckButton" then
                out[#out + 1] = ('<div class="p chk" style="%s">&#10003;</div>'):format(Place(rect))
            end
            if widget and widget.frame == region and FIELDS[widget.type] then
                local field, kind = FIELDS[widget.type](rect)
                out[#out + 1] = ('<div class="p %s" style="%s">%s</div>'):format(kind, Place(field),
                    kind == "check" and ((widget.checked or widget.value) and "&#10003;" or "") or "")
            end
            if widget and widget.frame == region then
                out[#out + 1] = ('<div class="dbg" style="%s;border-color:%s" title="%s"></div>')
                    :format(Place(rect), COLOURS[widget.type] or "#2e8b57", Esc(Describe(widget)))
            end
            if region.kind == "FontString" and region.text and region.text ~= "" then
                local text = tostring(region.text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("||", "|")
                local align = ({ LEFT = "flex-start", RIGHT = "flex-end" })[region.justifyH or "CENTER"] or "center"
                local twoPoints = #region.points >= 2 or region.w
                out[#out + 1] = ('<div class="t%s" style="%s;font-size:%.0fpx;color:%s;justify-content:%s">%s</div>')
                    :format(region.noWrap and " nw" or "", twoPoints and Place(rect)
                        or ("left:%.0fpx;top:%.0fpx"):format(rect[1] - origin[1], origin[4] - rect[4]),
                        region.size or 12, Rgba(region.textColor or { 1, 0.82, 0 }), align, Esc(text))
            end
        end
        -- A scroll frame shows only what is inside it, as in the game.
        local clip = region.kind == "ScrollFrame" and rect
        local outer = origin
        if clip then
            out[#out + 1] = ('<div class="p" style="%s;overflow:hidden">'):format(Place(clip))
            origin = clip
        end
        for _, child in ipairs(region.children) do Region(child) end
        if clip then
            out[#out + 1] = "</div>"
            origin = outer
        end
    end
    return out, Region
end

-- input: a view name and the AceGUI window widget
-- output: nothing
local function View(name, window)
    F.Settle()
    local windowRect = F.Rect(window.frame)
    local before = #issues
    Walk(name, window, windowRect, nil)

    -- Our own frames on the window, such as the drag button, against every widget.
    for _, region in ipairs(window.frame.children) do
        if IsRawFrame(region) and region:IsVisible() then
            local rect = F.Rect(region)
            local fits, sides = Inside(rect or windowRect, windowRect, true)
            if not fits then
                Issue(name, ("%s is outside the window (%s)"):format(region.name, sides))
            end
            local function Against(widget)
                for _, child in ipairs(widget.children or {}) do
                    if child.frame:IsVisible() then
                        local childRect = F.Rect(child.frame)
                        if rect and childRect and not child.children and Overlap(rect, childRect) then
                            Issue(name, region.name .. " overlaps " .. Describe(child))
                        end
                        Against(child)
                    end
                end
            end
            Against(window)
        end
    end

    check(#issues == before, name .. " lays out cleanly")
    local out, Region = Draw(name, windowRect)
    Region(window.frame)
    views[#views + 1] = ('<h2>%s</h2><ul>%s</ul><div class="w" style="width:%.0fpx;height:%.0fpx">%s</div>')
        :format(Esc(name), (function()
            local list = {}
            for i = before + 1, #issues do list[#list + 1] = "<li>" .. Esc(issues[i]) .. "</li>" end
            return table.concat(list)
        end)(), windowRect[3] - windowRect[1], windowRect[4] - windowRect[2], table.concat(out))
end

-- Views ----------------------------------------------------------------------
print("Layout")
SlashCmdList.SPEAKEASY("")
local window = SpeakEasyWindow.obj
local tabs = window.children[1]
local state = L.Window

tabs:SelectTab("scenes")
View("Scenes tab", window)
tabs:SelectTab("wheel")
View("Wheel tab", window)
tabs:SelectTab("triggers")
View("Triggers tab", window)
tabs:SelectTab("settings")
View("Settings tab", window)
check(not SpeakEasyDragButton.shown, "no drag button away from the Scenes tab")
-- Back to scenes after the other tabs, so AceGUI hands out reused widgets,
-- and on another scene, as a player clicking around would.
tabs:SelectTab("scenes")
F.Settle()
for _, row in ipairs(M.Find(tabs, M.OfType("SpeakEasyRow"))) do
    if M.TextOf(row) == "Combat" then row:Fire("OnClick") break end
end
View("Scenes tab, after the other tabs", window)
tabs:SelectTab("triggers")
F.Settle()
tabs:SelectTab("scenes")
View("Scenes tab, revisited", window)

-- Clicking between scenes, as reported: lines there, then gone after a switch.
local function ClickScene(name)
    for _, row in ipairs(M.Find(tabs, M.OfType("SpeakEasyRow"))) do
        if M.TextOf(row) == name then row:Fire("OnClick") return end
    end
end
for round = 1, 3 do
    ClickScene("Greeting"); F.Settle()
    ClickScene("Tavern"); F.Settle()
    ClickScene("Combat")
end
View("Scenes tab, after clicking between scenes", window)

local lineEditor = L.Editors.Line(combat, nil)
View("Line editor, new line", lineEditor)
local editBox = M.Find(lineEditor, M.OfType("MultiLineEditBox"))[1]
local long = "By the Light, {targetName}, I will not let you walk away from this fight while I still stand in {zone}!"
editBox:SetText(long)
editBox:Fire("OnTextChanged", long)
View("Line editor, after typing a long line", lineEditor)
lineEditor:Hide()

lineEditor = L.Editors.Line(combat, 5)
View("Line editor", lineEditor)
lineEditor:Hide()

local triggerEditor = L.Editors.Trigger(2)
View("Trigger editor (spell)", triggerEditor)
triggerEditor:Hide()
triggerEditor = L.Editors.Trigger(3)
View("Trigger editor (low health)", triggerEditor)
triggerEditor:Hide()

check(#F.errors == 0, "AceGUI raised no errors " .. table.concat(F.errors, "; "))

for _, issue in ipairs(issues) do print("    " .. issue) end

local page = [[<!doctype html><meta charset="utf-8"><title>SpeakEasy layout</title>
<style>body{background:#3a4048;color:#ddd;font:13px sans-serif;margin:16px}
.w{position:relative;margin-bottom:28px;font-family:"Friz Quadrata TT","Palatino Linotype",serif}
.p,.dbg,.t{position:absolute;box-sizing:border-box}
.t{display:flex;align-items:center;line-height:1.15;white-space:normal}.t.nw{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.field{background:#0b0b0d;border:1px solid #5a5a60;border-radius:2px}.key{background:#2a1c10;border:1px solid #8a6a30;border-radius:3px}
.track{background:#111;border:1px solid #555;border-radius:3px}.check{background:#111;border:1px solid #777;color:#ffd200;text-align:center;font-size:14px;line-height:16px}
.chk{color:#ffd200;font-size:12px;text-align:center;line-height:14px}
.dbg{display:none;border:1px dashed}body.debug .dbg{display:block}
li{color:#ff9090}h2{margin:12px 0 6px;font-weight:600}</style>
<label><input type="checkbox" onchange="document.body.classList.toggle('debug',this.checked)"> show widget outlines</label>]] .. table.concat(views)
WRITE_FILE(ADDON_DIR .. "/tests/out/layout.html", page)

print(M.failures == 0 and "ALL PASSED" or (M.failures .. " FAILED"))
