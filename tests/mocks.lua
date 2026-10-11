-- Mock WoW client: game APIs and state, enough to run SpeakEasy outside the
-- game. tests/frames.lua adds frames, and tests/real.lua loads the real AceGUI.
-- Tests change the M fields (units, zone, combat, instance...) to set the scene.
local M = {
    failures = 0, allFrames = {}, chat = {}, sent = {}, emotes = {}, macros = {}, popups = {},
    now = 1000, hour = 14,
    units = { player = { name = "Aria", class = "Paladin", race = "Human", health = 100, max = 100, isPlayer = true } },
    zone = "Elwynn Forest", subZone = "Goldshire",
    spells = { [133] = "Fireball" },
}

function M.check(cond, msg)
    if cond then print("  ok   " .. msg) else M.failures = M.failures + 1; print("  FAIL " .. msg) end
end

unpack = unpack or table.unpack

-- Mock regions and frames ---------------------------------------------------
local function noop() end
-- Unknown methods (capitalised) are no-ops; unknown fields stay nil.
local FALLBACK = { __index = function(_, k) if type(k) == "string" and k:match("^%u") then return noop end end }
local function Region(kind, parent)
    local r = { kind = kind or "Frame", shown = true, points = {}, parent = parent, events = {} }
    function r:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function r:GetPoint() local p = self.points[1] or {}; return p[1], p[2], p[3], p[4], p[5] end
    function r:ClearAllPoints() self.points = {} end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:SetShown(v) self.shown = v and true or false end
    function r:IsShown() return self.shown end
    function r:GetObjectType() return self.kind end
    function r:GetParent() return self.parent end
    function r:SetParent(p) self.parent = p end
    function r:SetText(t) self.text = t end
    function r:GetText() return self.text end
    function r:Insert(t) self.text = (self.text or "") .. t; if self.obj then self.obj.text = self.text end end
    function r:SetTexture(t) self.texture = t end
    function r:SetHeight(h) self.h = h end
    function r:SetWidth(w) self.w = w end
    function r:GetHeight() return self.h or 0 end
    function r:GetWidth() return self.w or 0 end
    function r:SetSize(w, h) self.w, self.h = w, h end
    function r:GetFrameLevel() return 1 end
    function r:CreateTexture() return Region("Texture", self) end
    function r:CreateFontString() return Region("FontString", self) end
    function r:RegisterEvent(e) self.events[e] = true end
    function r:RegisterUnitEvent(e) self.events[e] = true end
    function r:SetScript(name, fn) self.scripts = self.scripts or {}; self.scripts[name] = fn end
    function r:GetChildren() return unpack(self.children or {}) end
    return setmetatable(r, FALLBACK)
end
M.Region = Region

CreateFrame = function(kind, name, parent)
    local f = Region(kind or "Frame", parent)
    M.allFrames[#M.allFrames + 1] = f
    if name then _G[name] = f end
    return f
end
UIParent = Region("Frame")
Minimap = Region("Frame"); Minimap.w = 140
function Minimap:GetCenter() return 100, 100 end
function Minimap:GetEffectiveScale() return 1 end
M.cursor = { 150, 100 }
GetCursorPosition = function() return M.cursor[1], M.cursor[2] end
function UIParent:GetEffectiveScale() return 1 end
BackdropTemplateMixin = {}
GameTooltip = Region("GameTooltip")
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) M.chat[#M.chat + 1] = m; print("  chat: " .. m) end }
SlashCmdList = {}
UISpecialFrames = {}
StaticPopupDialogs = {}
StaticPopup_Show = function(id, arg) M.popups[#M.popups + 1] = { id = id, arg = arg } end
ChatFrame_OpenChat = function(text) M.opened = text end
M.bindings = {}
GetBindingKey = function(action)
    for key, bound in pairs(M.bindings) do if bound == action then return key end end
end
SetBinding = function(key, action) M.bindings[key] = action end
SaveBindings = function(set) M.bindingsSaved = set end
GetCurrentBindingSet = function() return 1 end
C_Timer = { After = function(_, fn) fn() end }
GetTime = function() return M.now end
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

-- Units, places and state ----------------------------------------------------
local function Unit(u) return M.units[u] end
UnitExists = function(u) return Unit(u) ~= nil end
UnitName = function(u) local d = Unit(u); return d and d.name end
UnitClass = function(u) local d = Unit(u); return d and d.class end
UnitRace = function(u) local d = Unit(u); return d and d.race end
UnitIsPlayer = function(u) local d = Unit(u); return d and d.isPlayer end
UnitIsDead = function() return false end
-- A secret value errors on any sum or comparison, as on Retail 12.
local SECRET_MT = { __div = function() error("attempt to perform arithmetic on a secret number value") end,
    __lt = function() error("attempt to compare a secret number value") end, __le = function() error("secret") end }
-- issecretvalue only exists once a test asks for a secret, like a client before Retail 12.
function M.Secret()
    issecretvalue = function(v) return getmetatable(v) == SECRET_MT end
    return setmetatable({}, SECRET_MT)
end
UnitHealth = function(u) return Unit(u).health end
UnitHealthMax = function(u) return Unit(u).max end
GetZoneText = function() return M.zone end
GetSubZoneText = function() return M.subZone end
GetGuildInfo = function() return M.guild end
GetGameTime = function() return M.hour, 0 end
LE_PARTY_CATEGORY_INSTANCE = 2
IsInInstance = function() return M.instance end
IsInGroup = function(category) if category then return M.instanceGroup end return M.group or M.raid end
IsInRaid = function() return M.raid end
IsMounted = function() return M.mounted end
IsResting = function() return M.resting end
InCombatLockdown = function() return M.combat end
M.spells[433] = "Food"
M.spells[430] = "Drink"
M.spells[853] = "Hammer of Justice"
M.spells[24275] = "Hammer of Wrath"
M.spells[2812] = "Denounce"
M.spellIcons = { Fireball = 135812, [133] = 135812, [853] = 135963, [24275] = 135963, [2812] = 135903 }
WOW_PROJECT_ID, WOW_PROJECT_MAINLINE = 1, 1
debugprofilestop = function() return 0 end
C_Spell = { GetSpellName = function(id) return M.spells[id] end, GetSpellTexture = function(spell) return M.spellIcons[spell] end }
M.itemSpells = { [2287] = "Food", ["Haunch of Meat"] = "Food" }
C_Item = { GetItemSpell = function(item) return M.itemSpells[item] end }
-- Using items: from the action bar, the bags and /use.
M.actions = { [5] = { "item", 2287 } }
M.bags = { [0] = { [1] = "|cffffffff|Hitem:2288::::|h[Conjured Water]|h|r" } }
M.itemNames = { [2287] = "Haunch of Meat", [2288] = "Conjured Water" }
GetActionInfo = function(slot) local a = M.actions[slot]; if a then return a[1], a[2] end end
UseAction = function() end
UseItemByName = function() end
C_Container = { UseContainerItem = function() end, GetContainerItemLink = function(bag, slot) return M.bags[bag] and M.bags[bag][slot] end }
C_Item.GetItemNameByID = function(id) return M.itemNames[id] end
GetMacroIcons = function(t) for _, id in ipairs({ 134400, 132147, 136243, 135432 }) do t[#t + 1] = id end end
GetMacroItemIcons = function(t) t[#t + 1] = "INV_Misc_Food_15" end

SendChatMessage = function(text, channel)
    if M.sendError then error(M.sendError) end
    M.sent[#M.sent + 1] = { text = text, channel = channel }
end
DoEmote = function(token) M.emotes[#M.emotes + 1] = token end

-- Emote globals, with a gap at 6 like the real list.
for index, token in pairs({ "WAVE", "BOW", "CHEER", "ROAR", "CHARGE", [7] = "DANCE" }) do
    _G["EMOTE" .. index .. "_TOKEN"] = token
    _G["EMOTE" .. index .. "_CMD1"] = "/" .. token:lower()
end

-- Macros ---------------------------------------------------------------------
MAX_ACCOUNT_MACROS, MAX_CHARACTER_MACROS = 120, 18
GetNumMacros = function()
    local account, character = 0, 0
    for _, m in ipairs(M.macros) do
        if m.perCharacter then character = character + 1 else account = account + 1 end
    end
    return account, character
end
CreateMacro = function(name, icon, body, perCharacter)
    M.macros[#M.macros + 1] = { name = name, icon = icon, body = body, perCharacter = perCharacter and true or false }
    return #M.macros
end
EditMacro = function(index, name, icon, body)
    local m = M.macros[index]
    m.name, m.icon, m.body = name, icon, body
    return index
end
GetMacroIndexByName = function(name)
    for index, m in ipairs(M.macros) do if m.name == name then return index end end
    return 0
end
GetMacroBody = function(index) return M.macros[index] and M.macros[index].body end
PickupMacro = function(index) M.picked = index end

-- input: a widget, a test function, and a list to fill
-- output: every widget in the tree the test accepts
function M.Find(w, pred, out)
    out = out or {}
    if pred(w) then out[#out + 1] = w end
    for _, c in ipairs(w.children or {}) do M.Find(c, pred, out) end
    return out
end

-- input: an event name and its arguments
-- output: nothing
-- Delivers an event to every frame that registered it.
function M.Fire(event, ...)
    for _, f in ipairs(M.allFrames) do
        if f.events[event] and f.scripts and f.scripts.OnEvent then
            f.scripts.OnEvent(f, event, ...)
        end
    end
end

-- input: nothing
-- output: the addon's private table
-- Loads every file the .toc lists, except the libraries, then logs in.
function M.LoadAddon()
    local L = {}
    for line in TOC:gmatch("[^\r\n]+") do
        if line:match("%.lua$") and not line:match("^Libs") then
            local chunk = assert(loadfile(ADDON_DIR .. "/" .. line:gsub("\\", "/")))
            chunk("SpeakEasy", L)
        end
    end
    M.Fire("ADDON_LOADED", "SpeakEasy")
    M.Fire("PLAYER_LOGIN")
    return L
end

return M
