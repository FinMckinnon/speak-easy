-- Main window, line editor, trigger editor, the scene button and the wheel,
-- driven through the real AceGUI widgets on the mock client.
-- Run from the addon folder: node tests/run.js tests/ui.lua .
local M, F, L = dofile("tests/real.lua")
local check, Find, OfType, Shows, TextOf = M.check, M.Find, M.OfType, M.Shows, M.TextOf

local function Labelled(text)
    return function(w) return type(w.label) == "table" and w.label.text == text end
end
local function Entries(dropdown) return #dropdown.pullout.items end

print("Window")
SlashCmdList.SPEAKEASY("")
F.Settle()
check(L.Window.IsOpen(), "/speakeasy opens the window")
local window = SpeakEasyWindow.obj
check(window.type == "SpeakEasyWindow" and UISpecialFrames[1] == "SpeakEasyWindow", "our window, closed by Escape")
check(SpeakEasyMinimapButton ~= nil, "minimap button made at login")

local tabs = window.children[1]
check(tabs.type == "SpeakEasyTabs" and #tabs.tabList == 4 and tabs.tabList[1].value == "wheel" and tabs.tabList[2].value == "scenes",
    "Emote Wheel first, then Scenes, Triggers and Settings")
check(tabs.selected == "wheel" and window.title.text == "SpeakEasy", "opens on the Emote Wheel under the new name")
check(not SpeakEasyDragButton.shown and #Find(window, Shows(L.Text.BUTTON_TEST_LINE)) == 0, "no drag button or footer away from Scenes")
tabs:SelectTab("scenes")
F.Settle()
check(SpeakEasyDragButton.shown and #Find(tabs, Shows(L.Text.BUTTON_TEST_LINE)) == 1, "the Scenes tab shows the footer and drag button")
local function Detail() return tabs.children[3] end
local rows = Find(tabs, OfType("SpeakEasyRow"))
check(#rows == 4 + 4, "4 scenes and the first scene's 4 lines listed")
check(rows[1].selected and rows[1].secondary.text == "4 lines", "first scene selected, with its line count")

rows[3]:Fire("OnClick")
check(L.Window.SelectedScene().id == "combat", "clicking a scene selects it")
check(#Find(window, Shows("Drag Combat to a bar")) == 1, "footer names the selected scene")
check(#Find(Detail(), Shows("Combat")) == 1, "the scene's name heads the detail")

local lineRows = Find(Detail(), OfType("SpeakEasyRow"))
lineRows[2]:Fire("OnClick")
check(lineRows[2].selected and not lineRows[1].selected, "clicking a line selects it in place")
check(Find(Detail(), OfType("SpeakEasyRow"))[2] == lineRows[2], "selecting a line rebuilds nothing")
lineRows[2]:Fire("OnDoubleClick")
check(_G.SpeakEasyLineEditor ~= nil, "double clicking a line opens the editor")
L.Editors.CloseAll()

lineRows = Find(Detail(), OfType("SpeakEasyRow"))
lineRows[1]:Fire("OnToggle", false)
check(L.Db.FindScene("combat").lines[1].enabled == false, "a line's box turns it off")
lineRows = Find(Detail(), OfType("SpeakEasyRow"))
check(lineRows[1].muted and lineRows[1].toggleValue == false, "an off line shows greyed")
lineRows[1]:Fire("OnToggle", true)

check(#Find(tabs, Shows("Up")) == 0 and #Find(tabs, Shows("Down")) == 0, "no Up or Down buttons")
local lineTotal = #L.Db.FindScene("combat").lines
lineRows = Find(Detail(), OfType("SpeakEasyRow"))
lineRows[2].actionButtons[1].scripts.OnClick(lineRows[2].actionButtons[1])
check(_G.SpeakEasyLineEditor ~= nil, "a line's Edit opens it")
L.Editors.CloseAll()
lineRows[4].actionButtons[2].scripts.OnClick(lineRows[4].actionButtons[2])
check(#L.Db.FindScene("combat").lines == lineTotal - 1, "a line's Delete removes it")
L.Db.SaveLine(L.Db.FindScene("combat"), nil, { text = "Stand and fight!" })
tabs:SelectTab("scenes")

print("Icon")
local icon = Find(Detail(), OfType("Icon"))[1]
icon:Fire("OnClick")
local cells = SpeakEasyIconGrid and SpeakEasyIconGrid.buttons or {}
check(#cells == 54 and cells[1].shown and cells[1].icon.texture == L.Compat.MacroIcons()[1], "clicking the scene's icon opens the icon picker with icons")
check(cells[#L.Compat.MacroIcons() + 1].shown == false, "cells past the last icon are hidden")
local widgetsBefore = #F.regions
SpeakEasyIconGrid.scripts.OnMouseWheel(SpeakEasyIconGrid, -1)
check(#F.regions == widgetsBefore, "turning the page makes no new frames")
local iconSearch = Find(SpeakEasyIconPicker.obj, Labelled(L.Text.LABEL_ICON_SEARCH))[1]
iconSearch:Fire("OnTextChanged", "Fireball")
check(cells[1].value == 135812 and cells[1].name == "Fireball" and not cells[2].shown, "searching a spell's name finds its icon")
cells[1].scripts.OnEnter(cells[1])
check(GameTooltip.text == "Fireball", "hovering an icon shows its name")
iconSearch:Fire("OnTextChanged", "|cff71d5ff|Hspell:133:0|h[Fireball]|h|r")
check(cells[1].value == 135812, "a shift-clicked spell finds its icon")
F.Settle()
iconSearch:Fire("OnTextChanged", "hammer")
check(cells[1].value == 135963 and not cells[2].shown, "searching part of a name finds icons spells with that name use")
cells[1].scripts.OnEnter(cells[1])
check(GameTooltip.text == "Hammer of Justice", "hovering shows the icon's readable name")
local name, also = L.Compat.IconName(135963)
check(name == "Hammer of Justice" and also == "Hammer of Wrath", "other spells with the same icon are listed too")
check(L.Compat.IconName(136243) == L.Text.ICON_UNNAMED, "an icon no spell uses says it has no name")
iconSearch:Fire("OnTextChanged", "zzz")
check(not cells[1].shown and #Find(SpeakEasyIconPicker.obj, Shows(L.Text.ICON_NONE)) == 1, "no match says so instead of a blank grid")
iconSearch:Fire("OnTextChanged", "")
check(cells[1].value == L.Compat.MacroIcons()[1], "clearing the search shows every icon again")
L.Macro.Pickup(L.Db.FindScene("combat"))
local macro = M.macros[#M.macros]
cells[2].scripts.OnClick(cells[2])
check(L.Db.FindScene("combat").icon == L.Compat.MacroIcons()[2] and macro.icon == L.Compat.MacroIcons()[2], "choosing an icon sets the scene's and its macro's icon")
check(_G.SpeakEasyIconPicker == nil, "the picker closes after choosing")
icon = Find(Detail(), OfType("Icon"))[1]
icon:Fire("OnClick")
Find(SpeakEasyIconPicker.obj, Labelled(L.Text.LABEL_ICON_SEARCH))[1]:Fire("OnEnterPressed", "132147")
check(L.Db.FindScene("combat").icon == 132147, "an icon id typed in is used")

for _, tab in ipairs({ "wheel", "triggers", "settings", "scenes" }) do
    local ok, err = pcall(tabs.SelectTab, tabs, tab)
    check(ok, "tab " .. tab .. " builds " .. tostring(err or ""))
end
check(#F.errors == 0, "AceGUI raised no errors " .. table.concat(F.errors, "; "))

print("Line editor")
local combat = L.Db.FindScene("combat")
local editor = L.Editors.Line(combat, nil)
local box = Find(editor, OfType("MultiLineEditBox"))[1]
local labels = Find(editor, OfType("Label"))
local counter, warning, preview = labels[1], labels[2], labels[3]
local save = Find(editor, Shows("Save"))[1]
local function Type(text) box:SetText(text); box:Fire("OnTextChanged", text) end

Type("Hello {zone}")
check(counter.label.text == "12 / 255" and counter.label.textColor[1] < 0.9, "live counter, quiet colour")
check(preview.label.text:find("Hello Elwynn Forest", 1, true) ~= nil, "preview fills in variables")
check(save.disabled == false and save.look == "primary", "save is the primary action and enabled")
Type(string.rep("a", 256))
check(counter.label.textColor[1] > 0.9 and save.disabled == true, "counter red and save blocked over 255")
Type("{bogus} hi")
check(warning.label.text:find("{bogus}", 1, true) and preview.label.text:find("ff4040", 1, true), "unknown variable highlighted")
Type("")
check(save.disabled == true, "empty line with no emote can't be saved")

local insert = Find(editor, Labelled(L.Text.LABEL_INSERT))[1]
check(Entries(insert) == #L.Play.VARIABLES and insert.list.zone:find("Elwynn Forest", 1, true), "variable menu shows live examples")
insert:Fire("OnValueChanged", "targetName")
check(box:GetText() == "{targetName}" and insert.value == nil, "variable inserted at the cursor")

local emote = Find(editor, Labelled(L.Text.LABEL_EMOTE))[1]
emote:Fire("OnEnter")
check(emote.list.DANCE and emote.list.WAVE and emote.list.__none, "emote picker lists every emote and none")
emote:Fire("OnValueChanged", "DANCE")

local lineCount = #combat.lines
Type("Have at you\n")
check(#combat.lines == lineCount + 1 and combat.lines[lineCount + 1].text == "Have at you", "Enter saves the line")
check(combat.lines[lineCount + 1].emote == "DANCE", "chosen emote saved")
check(_G.SpeakEasyLineEditor == nil, "editor closed after saving")

editor = L.Editors.Line(combat, 1)
Find(editor, Shows("Cancel"))[1]:Fire("OnClick")
check(_G.SpeakEasyLineEditor == nil and combat.lines[1].text == "For {zone}!", "Cancel leaves the line alone")

print("Trigger editor")
local triggerCount = #SpeakEasyDB.triggers
local triggerEditor = L.Editors.Trigger(nil)
Find(triggerEditor, Labelled(L.Text.LABEL_EVENT))[1]:Fire("OnValueChanged", "SPELL_CAST")
local spell = Find(triggerEditor, Labelled(L.Text.LABEL_SPELL))[1]
check(spell ~= nil, "spell field shown for the spell event")
Find(triggerEditor, Shows("Save"))[1]:Fire("OnClick")
check(#SpeakEasyDB.triggers == triggerCount, "spell trigger without a spell not saved")
spell:Fire("OnTextChanged", "|cffffffff|Hitem:2287:0|h[Haunch of Meat]|h|r")
check(spell:GetText() == "Haunch of Meat", "a shift-clicked item shows as its name")
check(Find(triggerEditor, function(w) return w.type == "Label" and (w.label.text or ""):find("casts Food", 1, true) end)[1] ~= nil, "the editor explains the item casts Food")
spell:Fire("OnTextChanged", "|cff71d5ff|Hspell:133:0|h[Fireball]|h|r")
check(spell:GetText() == "Fireball", "a shift-clicked spell shows as its name")
Find(triggerEditor, Shows("Save"))[1]:Fire("OnClick")
local saved = SpeakEasyDB.triggers[#SpeakEasyDB.triggers]
check(#SpeakEasyDB.triggers == triggerCount + 1 and saved.options.spell == "Fireball" and saved.chance == 30, "trigger saved with defaults")

print("Triggers tab")
tabs:SelectTab("triggers")
local triggerRows = Find(tabs, OfType("SpeakEasyRow"))
check(#triggerRows == #SpeakEasyDB.triggers and triggerRows[1].secondary.text:find("30%", 1, true), "one row per trigger, detail on the right")
check(#Find(tabs, Shows("Delete")) == 0, "no toolbar Delete; each row has its own")
local function Act(row, index) local b = row.actionButtons[index]; b.scripts.OnClick(b) end
check(triggerRows[2].actionButtons[1].label.text == "Edit" and triggerRows[2].actionButtons[2].label.text == "Delete", "each trigger row offers Edit and Delete")
Act(triggerRows[2], 1)
check(_G.SpeakEasyTriggerEditor ~= nil, "a row's Edit opens that trigger")
L.Editors.CloseAll()
Act(Find(tabs, OfType("SpeakEasyRow"))[2], 2)
check(#SpeakEasyDB.triggers == triggerCount, "a row's Delete removes that trigger")
tabs:SelectTab("scenes")

print("Scenes")
local sceneCount = #SpeakEasyDB.scenes
Find(Detail(), Shows("Delete"))[1]:Fire("OnClick")
check(M.popups[#M.popups].id == "SPEAKEASY_CONFIRM" and M.popups[#M.popups].arg == "Combat", "delete asks first")
StaticPopupDialogs.SPEAKEASY_CONFIRM.OnAccept()
check(#SpeakEasyDB.scenes == sceneCount - 1 and not L.Db.FindScene("combat"), "confirmed delete removes the scene")

Find(tabs, Shows("New scene"))[1]:Fire("OnClick")
local dialogBox = M.Region("EditBox")
local dialog = M.Region("Frame")
dialogBox.parent = dialog
dialog.editBox = dialogBox
dialogBox.text = "Market"
StaticPopupDialogs.SPEAKEASY_PROMPT.OnAccept(dialog)
check(L.Window.SelectedScene().name == "Market", "new scene added and selected")
check(#Find(tabs, function(w) return w.caption and w.caption.text == L.Text.HINT_NO_LINES end) == 1, "an empty scene says how to add a line")

print("Scene button")
local drag = SpeakEasyDragButton
check(drag.shown and drag.parent == window.frame, "drag button sits on the window")
drag.scripts.OnDragStart(drag)
check(M.macros[#M.macros].body == "/speakeasy market", "dragging makes the macro")
drag.scripts.OnClick(drag, "RightButton")
check(M.opened == "/speakeasy market", "right click opens the /speakeasy text to copy")

print("Errors in callbacks")
local realDelete = L.Db.DeleteScene
L.Db.DeleteScene = function() error("delete broke") end
Find(Detail(), Shows("Delete"))[1]:Fire("OnClick")
check(pcall(StaticPopupDialogs.SPEAKEASY_CONFIRM.OnAccept), "an error in a popup callback is contained")
L.Db.DeleteScene = realDelete

print("Scene wheel")
local Pick = L.Wheel.Pick
check(Pick(0, 100) == 1 and Pick(100, 0) == 3 and Pick(0, -100) == 5 and Pick(-100, 0) == 7, "eight slots clockwise from the top")
check(Pick(70, 70) == 2 and Pick(-70, 70) == 8, "diagonals pick the in between slots")
check(Pick(10, 10) == nil and Pick(400, 0) == nil, "the ring's hole and far outside cancel")

local hail = assert(L.Db.AddScene("Hail"))
L.Db.SaveLine(hail, nil, { text = "Hail!" })
local pages = L.Db.WheelPages()
local placed = false
for _, value in ipairs(pages[1]) do if value == "hail" then placed = true end end
check(placed, "a new scene goes in the first empty wheel slot")

check(L.Db.SetWheelPageCount(2) == 2 and #pages == 2 and pages[2][1] == "", "page count adds an empty page")
for slot = 1, 8 do L.Db.SetWheelSlot(1, slot, nil) end
L.Db.SetWheelSlot(1, 1, "hail")
L.Db.SetWheelSlot(1, 3, "emote:DANCE")
L.Db.SetWheelSlot(2, 5, "hail")

local function Hold(x, y) M.cursor = { x, y }; SpeakEasy_Wheel("down") end
local function Point(x, y) M.cursor = { x, y }; SpeakEasyWheel.scripts.OnUpdate(SpeakEasyWheel) end
local function LetGo(x, y) M.now = M.now + 10; M.cursor = { x, y }; SpeakEasy_Wheel("up") end

Hold(500, 500)
check(L.Wheel.IsOpen() and SpeakEasyWheel.points[1].x == 500, "holding the key opens the wheel at the cursor")
Point(500, 600)
check(SpeakEasyWheel.centre.text == "Hail" and SpeakEasyWheel.glow.shown, "pointing at a slot names it and lights it")
local sentAt = #M.sent
LetGo(500, 600)
check(not L.Wheel.IsOpen() and #M.sent == sentAt + 1 and M.sent[#M.sent].text == "Hail!", "letting go plays the scene pointed at")

local emotesAt = #M.emotes
Hold(500, 500); LetGo(600, 500)
check(#M.emotes == emotesAt + 1 and M.emotes[#M.emotes] == "DANCE" and #M.sent == sentAt + 1, "an emote slot plays just the emote")

Hold(500, 500); LetGo(505, 500)
check(#M.sent == sentAt + 1 and #M.emotes == emotesAt + 1, "letting go in the middle cancels")

Hold(500, 500)
SpeakEasyWheel.scripts.OnMouseWheel(SpeakEasyWheel, -1)
check(SpeakEasyWheel.page.text == "Page 2 of 2", "scrolling turns the page")
LetGo(500, 400)
check(#M.sent == sentAt + 2, "a slot on page 2 plays")
Hold(500, 500)
check(SpeakEasyWheel.previous.shown and not SpeakEasyWheel.next.shown, "on the last page only the previous arrow shows")
SpeakEasyWheel.scripts.OnMouseWheel(SpeakEasyWheel, -1)
check(SpeakEasyWheel.page.text == "Page 2 of 2", "scrolling past the last page stays there")
SpeakEasyWheel.previous.scripts.OnClick(SpeakEasyWheel.previous)
check(SpeakEasyWheel.page.text == "Page 1 of 2" and SpeakEasyWheel.next.shown and not SpeakEasyWheel.previous.shown, "previous arrow turns back, arrows follow")
local realOver = SpeakEasyWheel.previous.IsMouseOver
SpeakEasyWheel.previous.IsMouseOver = function() return true end
LetGo(400, 500)
SpeakEasyWheel.previous.IsMouseOver = realOver
check(#M.sent == sentAt + 2 and #M.emotes == emotesAt + 1, "letting go over an arrow cancels")

hail.enabled = false
Hold(500, 500); LetGo(500, 600)
check(#M.sent == sentAt + 2, "a disabled scene on the wheel does nothing")
hail.enabled = true

SpeakEasyDB.settings.wheelScale = 2
Hold(500, 500)
check(SpeakEasyWheel.points[1].x == 250, "wheel size scales the frame, kept under the cursor")
LetGo(500, 700)
check(#M.sent == sentAt + 3, "picking still follows the cursor at size 2")
SpeakEasyDB.settings.wheelScale = 1

SpeakEasyDB.settings.wheelRememberPage = false
Hold(500, 500)
SpeakEasyWheel.scripts.OnMouseWheel(SpeakEasyWheel, -1)
LetGo(505, 500)
Hold(500, 500)
check(SpeakEasyWheel.page.text == "Page 1 of 2", "with remembering off, the wheel opens on page 1")
LetGo(505, 500)
SpeakEasyDB.settings.wheelRememberPage = true
Hold(500, 500)
SpeakEasyWheel.scripts.OnMouseWheel(SpeakEasyWheel, -1)
LetGo(505, 500)
Hold(500, 500)
check(SpeakEasyWheel.page.text == "Page 2 of 2", "with remembering on, it opens on the last page used")
SpeakEasyWheel.cog.scripts.OnClick(SpeakEasyWheel.cog)
check(not L.Wheel.IsOpen() and L.Window.IsOpen(), "the cog closes the wheel and opens the settings")
check(SpeakEasyWindow.obj.children[1].selected == "wheel", "on the Wheel tab")
SpeakEasy_Wheel("up")

L.Wheel.Preview()
F.Tick()
check(not L.Wheel.IsOpen(), "preview closes itself")
check(pcall(SpeakEasy_Wheel, "up"), "letting go with the wheel closed is harmless")

for slot = 1, 8 do L.Db.SetWheelSlot(1, slot, nil); L.Db.SetWheelSlot(2, slot, nil) end
local chatAt = #M.chat
SpeakEasy_Wheel("down")
check(not L.Wheel.IsOpen() and M.chat[chatAt + 1]:find("The wheel is empty", 1, true), "empty wheel explains itself")

print("Wheel tab")
tabs:SelectTab("wheel")
local pageSlider = Find(tabs, function(w) return w.type == "Slider" and w.label.text == L.Text.LABEL_WHEEL_PAGES end)[1]
pageSlider:Fire("OnValueChanged", 3)
check(#L.Db.WheelPages() == 2, "dragging the page slider rebuilds nothing")
pageSlider:Fire("OnMouseUp", 3)
check(#L.Db.WheelPages() == 3, "page slider sets the page count")
local pageTabs = Find(tabs, function(w) return w.type == "SpeakEasyTabs" and w ~= tabs end)[1]
check(#pageTabs.tabList == 3, "one segment per page")
local top = Find(pageTabs, Labelled("Top"))[1]
local itemCount = 0
for _, picker in ipairs(Find(pageTabs, OfType("Dropdown"))) do itemCount = itemCount + Entries(picker) end
check(itemCount == 8, "slot pickers hold one entry each until used: " .. itemCount)
top:Fire("OnEnter")
check(top.list["emote:WAVE"] == "Emote: wave" or top.list["emote:WAVE"] == "Emote: Wave", "hovering fills the choices, emotes included")
check(top.list.hail ~= nil and top.list[""] == L.Text.EMPTY_SLOT, "slot choices include scenes and empty")
top:Fire("OnValueChanged", "emote:WAVE")
top:Fire("OnClosed")
check(L.Db.WheelPages()[1][1] == "emote:WAVE", "choosing a slot saves it")
check(Entries(top) == 1 and top.value == "emote:WAVE", "closing lets the long list go, keeping the choice")
top.button.scripts.OnClick(top.button)
check(top.open, "clicking a dropdown opens it")
M.Fire("GLOBAL_MOUSE_DOWN", "LeftButton")
check(not top.open, "clicking anywhere else closes it without choosing")
check(L.Db.WheelPages()[1][1] == "emote:WAVE", "and the choice is unchanged")
pageTabs:SelectTab(3)
Find(pageTabs, Labelled("Bottom left"))[1]:Fire("OnValueChanged", "hail")
check(L.Db.WheelPages()[3][6] == "hail", "slots on later pages save to that page")
local sizeSlider = Find(tabs, function(w) return w.type == "Slider" and w.label.text == L.Text.LABEL_WHEEL_SIZE end)[1]
sizeSlider:Fire("OnValueChanged", 1.5)
check(SpeakEasyDB.settings.wheelScale == 1.5, "size slider saves the wheel size")
SpeakEasyDB.settings.wheelScale = 1
pageSlider = Find(tabs, function(w) return w.type == "Slider" and w.label.text == L.Text.LABEL_WHEEL_PAGES end)[1]
pageSlider:Fire("OnMouseUp", 1)
check(#L.Db.WheelPages() == 1, "lowering the page count drops pages from the end")
tabs:SelectTab("scenes")

print("Key pickers")
tabs:SelectTab("settings")
local keyPicker = Find(tabs, function(w) return w.type == "Keybinding" and w.label.text == L.Text.BINDING_WHEEL end)[1]
keyPicker:Fire("OnKeyChanged", "F")
check(M.bindings.F == "SPEAKEASY_WHEEL" and M.bindingsSaved == 1, "wheel key set and saved")
keyPicker:Fire("OnKeyChanged", "G")
check(M.bindings.G == "SPEAKEASY_WHEEL" and M.bindings.F == nil, "new key replaces the old one")
M.combat = true
keyPicker:Fire("OnKeyChanged", "H")
check(M.bindings.H == nil, "keys not changed in combat")
M.combat = nil
tabs:SelectTab("scenes")

print("Game version limits")
issecretvalue = nil
local fullEditor = L.Editors.Trigger(nil)
local fullEvents = Find(fullEditor, Labelled(L.Text.LABEL_EVENT))[1]
check(fullEvents.list.LOW_HEALTH ~= nil, "low health offered where health is readable")
fullEditor:Hide()

M.Secret()
local limited = L.Editors.Trigger(nil)
local limitedEvents = Find(limited, Labelled(L.Text.LABEL_EVENT))[1]
check(limitedEvents.list.LOW_HEALTH == nil and Entries(limitedEvents) == #L.Db.EVENTS - 1, "low health hidden where health is secret")
limited:Hide()
local limitedLine = L.Editors.Line(L.Db.Set().scenes[1], nil)
local limitedVars = Find(limitedLine, Labelled(L.Text.LABEL_INSERT))[1]
check(limitedVars.list.healthPercent == nil and limitedVars.list.zone ~= nil, "{healthPercent} left out of the variable menu")
limitedLine:Hide()
check(L.Editors.EventText({ event = "LOW_HEALTH", options = { threshold = 30 } }):find("not on this game version", 1, true), "an existing low health trigger is marked")
issecretvalue = nil

print("Closing")
Find(Detail(), OfType("Icon"))[1]:Fire("OnClick")
check(_G.SpeakEasyIconPicker ~= nil, "icon picker open before closing")
window.closeButton.scripts.OnClick(window.closeButton)
check(not L.Window.IsOpen() and _G.SpeakEasyWindow == nil, "window closed and name cleared")
check(_G.SpeakEasyIconPicker == nil, "closing the window closes the icon picker too")
check(drag.parent == UIParent and not drag.shown, "drag button handed back to UIParent")
check(#F.errors == 0, "AceGUI raised no errors " .. table.concat(F.errors, "; "))

print(M.failures == 0 and "ALL PASSED" or (M.failures .. " FAILED"))
