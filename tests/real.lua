-- Loads SpeakEasy with the real AceGUI library on the geometry aware mock
-- client: game APIs from tests/mocks.lua, frames from tests/frames.lua.
-- Returns the mock (M), the frame engine (F) and the addon table (L).
local M = dofile("tests/mocks.lua")
local F = dofile("tests/frames.lua")
M.allFrames = F.frames

-- The frame engine replaces the cursor; tests move it through M.cursor.
GetCursorPosition = function() return M.cursor[1], M.cursor[2] end

-- LibStub and AceGUI, in the order the .toc and AceGUI's xml give.
LibStub = nil
local function Load(path) assert(loadfile(ADDON_DIR .. "/" .. path))() end
Load("Libs/LibStub/LibStub.lua")
for file in READ_FILE(ADDON_DIR .. "/Libs/AceGUI-3.0/AceGUI-3.0.xml"):gmatch('file="([^"]+)"') do
    Load("Libs/AceGUI-3.0/" .. file:gsub("\\", "/"))
end

local L = M.LoadAddon()
F.Settle()

-- input: a widget
-- output: the text it shows: its label, or its own text for buttons and rows
function M.TextOf(w)
    if type(w.text) == "table" and w.text.text then return w.text.text end
    if type(w.label) == "table" and w.label.text then return w.label.text end
    return nil
end

-- input: text
-- output: a test for M.Find matching widgets that show exactly that text
function M.Shows(text)
    return function(w) return M.TextOf(w) == text end
end

-- input: a widget type
-- output: a test for M.Find matching widgets of that type
function M.OfType(kind)
    return function(w) return w.type == kind end
end

return M, F, L
