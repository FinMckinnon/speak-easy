-- Saved data, rotation, variables, sending, triggers, priming, scene buttons
-- and the error guard, against the mock client.
-- Run from the addon folder: node tests/run.js tests/core.lua .
local M, F, L = dofile("tests/real.lua")
local check = M.check

local function Press(key)
    M.now = M.now + 5
    SlashCmdList.SPEAKEASY(key)
end
local function LastSent() return M.sent[#M.sent] or {} end
local function ChatHas(text, from)
    for index = from or 1, #M.chat do
        if M.chat[index]:find(text, 1, true) then return true end
    end
    return false
end
local function NewScene(name, lines, fields)
    local scene = assert(L.Db.AddScene(name))
    for _, line in ipairs(lines) do
        L.Db.SaveLine(scene, nil, type(line) == "table" and line or { text = line })
    end
    for key, value in pairs(fields or {}) do scene[key] = value end
    return scene
end

print("Text")
local files = {}
for line in TOC:gmatch("[^\r\n]+") do
    if line:match("%.lua$") and not line:match("^Libs") then files[#files + 1] = line end
end
local missing = {}
for _, file in ipairs(files) do
    local source = READ_FILE(ADDON_DIR .. "/" .. file:gsub("\\", "/"))
    for key in source:gmatch("L%.Text%.([%w_]+)") do
        if L.Text[key] == nil then missing[#missing + 1] = key end
    end
end
for _, channel in ipairs(L.Db.CHANNELS) do if not L.Text["CHANNEL_" .. channel] then missing[#missing + 1] = channel end end
for _, event in ipairs(L.Db.EVENTS) do if not L.Text["EVENT_" .. event] then missing[#missing + 1] = event end end
for _, variable in ipairs(L.Play.VARIABLES) do if not L.Text["VAR_" .. variable.key] then missing[#missing + 1] = variable.key end end
check(#missing == 0, "every text key used exists " .. table.concat(missing, ", "))

print("Saved data")
check(#SpeakEasyDB.scenes == 4 and SpeakEasyDB.scenes[3].id == "combat", "first install gets the 4 starter scenes")
check(#SpeakEasyDB.triggers == 1 and not SpeakEasyDB.triggers[1].enabled, "starter trigger is off")

SpeakEasyDB = {
    scenes = {
        "junk",
        { name = "Dup", id = "dup", lines = { 5, { text = "ok" }, { text = string.rep("a", 300) }, { text = "  " } } },
        { name = "Dup2", id = "dup", channel = "SHOUT", cooldown = "soon" },
        { id = "mute" },
    },
    triggers = { { event = "NOPE" }, { event = "DEATH", sceneId = "dup", chance = 500 } },
    settings = { primeTimeout = "soon", triggersMuted = true, window = 5 },
}
SpeakEasyCharDB = "bad"
local ok, err = pcall(L.Db.Load)
check(ok, "damaged saved data loads " .. tostring(err or ""))
local scenes = SpeakEasyDB.scenes
check(#scenes == 3, "non table scenes dropped")
check(scenes[1].id == "dup" and scenes[2].id == "dup2", "duplicate ids made unique")
check(scenes[3].id == "mute2", "reserved id avoided: " .. tostring(scenes[3].id))
check(#scenes[1].lines == 2 and #scenes[1].lines[2].text == 255, "bad lines dropped and long text cut to 255")
check(scenes[2].channel == "SAY" and scenes[2].cooldown == 2, "bad channel and cooldown reset")
check(#SpeakEasyDB.triggers == 1 and SpeakEasyDB.triggers[1].chance == 100, "unknown trigger dropped, chance clamped")
local settings = SpeakEasyDB.settings
check(settings.primeTimeout == 8 and settings.triggersMuted == true and type(settings.window) == "table", "settings repaired, valid ones kept")
check(type(SpeakEasyCharDB) == "table" and SpeakEasyCharDB.useOwn == false, "bad character data replaced")

SpeakEasyDB, SpeakEasyCharDB = { scenes = {}, triggers = {} }, nil
L.Db.Load()
check(#SpeakEasyDB.scenes == 0, "an emptied list stays empty, no starter pack")
SpeakEasyDB = nil
L.Db.Load()
check(#SpeakEasyDB.scenes == 4, "starter pack only on a fresh install")
check(SpeakEasyDB.settings.speakOnAnyKey == true, "settings that default on start on")
local starterPage = SpeakEasyDB.wheelPages[1]
check(#SpeakEasyDB.wheelPages == 1 and starterPage[1] == "greeting" and starterPage[4] == "tavern" and starterPage[5] == "", "starter wheel holds the starter scenes")
local manyPages = {}
for index = 1, 12 do manyPages[index] = { "greeting" } end
manyPages[2] = "junk"
SpeakEasyDB.wheelPages = manyPages
L.Db.Load()
check(#SpeakEasyDB.wheelPages == 9 and #SpeakEasyDB.wheelPages[1] == 8 and SpeakEasyDB.wheelPages[1][2] == "", "wheel pages repaired and capped at 9")

print("Scene names")
check(L.Db.AddScene("") == nil and select(2, L.Db.AddScene("combat")) == L.Text.ERR_NAME_TAKEN, "empty and taken names refused")
local copy = L.Db.DuplicateScene(L.Db.FindScene("combat"))
check(copy.name == "Combat copy" and copy.id == "combatcopy" and #copy.lines == 4, "duplicate gets a free name and the lines")
check(L.Db.FindScene("COMBAT").id == "combat", "scenes found by name in any case")

print("Rotation")
NewScene("Rota", { "one", "two", "three" })
local counts, previous, repeats = {}, nil, 0
for _ = 1, 30 do
    Press("rota")
    local text = LastSent().text
    counts[text] = (counts[text] or 0) + 1
    if text == previous then repeats = repeats + 1 end
    previous = text
end
check(repeats == 0, "no line repeats back to back over 30 presses")
check(counts.one == 10 and counts.two == 10 and counts.three == 10, "every line used once per cycle")

NewScene("Pair", { "a", "b" })
local alternates = true
Press("pair")
for _ = 1, 10 do
    local before = LastSent().text
    Press("pair")
    if LastSent().text == before then alternates = false end
end
check(alternates, "two lines strictly alternate")

NewScene("Solo", { "only" })
local sentBefore = #M.sent
Press("solo"); Press("solo"); Press("solo")
check(#M.sent == sentBefore + 3 and LastSent().text == "only", "one line is said every press")

NewScene("Empty", {})
sentBefore = #M.sent
local chatBefore = #M.chat
Press("empty"); Press("empty")
local notices = 0
for index = chatBefore + 1, #M.chat do if M.chat[index]:find("has no lines yet", 1, true) then notices = notices + 1 end end
check(#M.sent == sentBefore and notices == 1, "no lines: nothing sent, one notice per 10 seconds")

local parked = NewScene("Parked", { "x" })
L.Db.SetLineEnabled(parked, 1, false)
sentBefore = #M.sent
Press("parked")
check(#M.sent == sentBefore, "all lines disabled counts as no lines")

NewScene("Bow", { { text = "", emote = "BOW" } })
sentBefore = #M.sent
Press("bow")
check(#M.sent == sentBefore and M.emotes[#M.emotes] == "BOW", "an emote only line plays just the emote")

M.guild = nil
NewScene("Guild", { "{guild}", "hello" })
local onlyHello = true
for _ = 1, 4 do Press("guild"); if LastSent().text ~= "hello" then onlyHello = false end end
check(onlyHello, "a line that resolves empty is skipped")

NewScene("Blank", { "{guild}" })
sentBefore = #M.sent
Press("blank")
check(#M.sent == sentBefore, "every line empty counts as no lines")

local grow = NewScene("Grow", { "a", "b", "c" })
Press("grow")
L.Db.SaveLine(grow, nil, { text = "d" })
local seen = {}
for _ = 1, 4 do Press("grow"); seen[LastSent().text] = true end
check(seen.a and seen.b and seen.c and seen.d, "adding a line starts a fresh cycle")

NewScene("Cool", { "x", "y" }, { cooldown = 2 })
sentBefore = #M.sent
M.now = M.now + 5
SlashCmdList.SPEAKEASY("cool")
SlashCmdList.SPEAKEASY("cool")
check(#M.sent == sentBefore + 1, "presses inside the cooldown are ignored")

NewScene("Off", { "x" }, { enabled = false })
sentBefore, chatBefore = #M.sent, #M.chat
Press("off")
check(#M.sent == sentBefore and ChatHas("is turned off", chatBefore + 1), "disabled scene says nothing and prints a notice")

print("Variables")
local R = L.Play.Resolve
check(R("Hi {targetName}") == "Hi friend", "no target falls back to friend")
M.units.target = { name = "Bob", class = "Mage", race = "Gnome" }
check(R("{targetName} the {targetRace} {targetClass}") == "Bob the Gnome Mage", "target variables")
M.units.target = nil
check(R("{wat} {zone}") == "{wat} Elwynn Forest", "unknown variables stay as typed")
M.subZone = ""
check(R("{subZone}") == "Elwynn Forest", "subzone falls back to zone")
M.subZone = "Goldshire"
check(R("{spellName}", { spellName = "Fireball" }) == "Fireball", "spell name from the trigger")
M.units.player.health = 27
check(R("{healthPercent}") == "27%", "health percent")
M.units.player.health = 100
M.hour = 8
check(R("{timeOfDay}") == "morning", "time of day")
local realClass = UnitClass
UnitClass = function() error("secret value") end
check(R("{playerClass} ok") == "ok", "a failing API blanks only its variable")
UnitClass = realClass
check(L.Play.UnknownVariables("{a} {zone} {b}")[2] == "{b}", "unknown variables listed")
check(R("Mmm, {itemName}.", { itemName = "Haunch of Meat" }) == "Mmm, Haunch of Meat.", "item name from the trigger")

print("Sending")
NewScene("Long", { "{zone}" .. string.rep("x", 245) })
chatBefore = #M.chat
Press("long")
check(#LastSent().text == 255 and ChatHas("cut short", chatBefore + 1), "a line over 255 once filled in is cut with a warning")
NewScene("Pipe", { "a|b" })
Press("pipe")
check(LastSent().text == "ab", "stray | removed before sending")

local auto = NewScene("Auto", { "x" }, { channel = "AUTO" })
M.raid = true; Press("auto")
check(LastSent().channel == "RAID", "auto uses raid in a raid")
M.raid, M.group = nil, true; Press("auto")
check(LastSent().channel == "PARTY", "auto uses party in a party")
M.group = nil; Press("auto")
check(LastSent().channel == "SAY", "auto uses say alone")
auto.channel = "YELL"; Press("auto")
check(LastSent().channel == "YELL", "a key press sends yell directly")

NewScene("Emotes", { { text = "hi", emote = "BOW" }, "yo" }, { defaultEmote = "WAVE" })
local emoteFor = {}
for _ = 1, 2 do Press("emotes"); emoteFor[LastSent().text] = M.emotes[#M.emotes] end
check(emoteFor.hi == "BOW" and emoteFor.yo == "WAVE", "line emote beats the scene default")

chatBefore = #M.chat
Press("nosuchscene")
check(ChatHas("No scene called nosuchscene", chatBefore + 1), "unknown scene reported")
Press("ROTA")
check(#M.sent > 0, "scene played by name in any case")

print("Triggers")
local function Triggers(list)
    wipe(L.Db.Set().triggers)
    for _, trigger in ipairs(list) do
        trigger.chance, trigger.cooldown = trigger.chance or 100, trigger.cooldown or 0
        trigger.options = trigger.options or {}
        L.Db.SaveTrigger(nil, trigger)
    end
    M.now = M.now + 100
end
NewScene("Growl", { "grr" }, { channel = "EMOTE", cooldown = 0 })
NewScene("Shout", { "hey" }, { channel = "SAY", cooldown = 0 })
SpeakEasyDB.settings.triggersMuted = false

Triggers({ { event = "ENTER_COMBAT", sceneId = "growl" } })
sentBefore = #M.sent
M.Fire("PLAYER_REGEN_DISABLED")
check(#M.sent == sentBefore + 1 and LastSent().channel == "EMOTE", "emote channel sent straight from a trigger")
M.now = M.now + 5
M.Fire("PLAYER_REGEN_DISABLED")
check(#M.sent == sentBefore + 1, "global gap holds back a second trigger line")
M.now = M.now + 6
M.Fire("PLAYER_REGEN_DISABLED")
check(#M.sent == sentBefore + 2, "plays again after the gap")

Triggers({ { event = "ENTER_COMBAT", sceneId = "growl", cooldown = 60 } })
sentBefore = #M.sent
M.Fire("PLAYER_REGEN_DISABLED"); M.now = M.now + 30
M.Fire("PLAYER_REGEN_DISABLED")
check(#M.sent == sentBefore + 1, "trigger cooldown holds")

Triggers({ { event = "ENTER_COMBAT", sceneId = "growl", chance = 0 } })
sentBefore = #M.sent
M.Fire("PLAYER_REGEN_DISABLED")
check(#M.sent == sentBefore, "0% chance never fires")

Triggers({ { event = "DEATH", sceneId = "shout" } })
sentBefore = #M.sent
M.Fire("PLAYER_DEAD")
check(#M.sent == sentBefore and L.Prime.Pending() == "hey", "say outside an instance is primed, not sent")
SpeakEasy_Speak()
check(#M.sent == sentBefore + 1 and LastSent().text == "hey" and LastSent().channel == "SAY", "Speak key sends the primed line")

local keyListener = SpeakEasyKeyListener
check(keyListener and keyListener.scripts.OnKeyDown, "key listener set up at login")
M.now = M.now + 100
M.Fire("PLAYER_DEAD")
sentBefore = #M.sent
keyListener.scripts.OnKeyDown(keyListener, "ESCAPE")
keyListener.scripts.OnKeyDown(keyListener, "LSHIFT")
check(#M.sent == sentBefore, "Escape and modifiers don't send")
check(not (SpeakEasyPrompt and SpeakEasyPrompt.shown), "no prompt shown when lines go with the next key")
keyListener.scripts.OnKeyDown(keyListener, "2")
check(#M.sent == sentBefore + 1 and LastSent().text == "hey", "the next key press sends the primed line")
keyListener.scripts.OnKeyDown(keyListener, "2")
check(#M.sent == sentBefore + 1, "only one line per primed line")
SpeakEasyDB.settings.speakOnAnyKey = false
M.now = M.now + 100
M.Fire("PLAYER_DEAD")
keyListener.scripts.OnKeyDown(keyListener, "2")
check(#M.sent == sentBefore + 1 and L.Prime.Pending() == "hey", "with the setting off, only the Speak key sends")
check(SpeakEasyPrompt and SpeakEasyPrompt.shown, "with the setting off, the prompt shows")
L.Prime.Clear()
SpeakEasyDB.settings.speakOnAnyKey = true
check(L.Prime.Pending() == nil, "prompt cleared after speaking")

M.now = M.now + 100
M.Fire("PLAYER_DEAD")
M.now = M.now + 9
sentBefore = #M.sent
SpeakEasy_Speak()
check(#M.sent == sentBefore and L.Prime.Pending() == nil, "a primed line expires after 8 seconds")

M.instance = true
M.now = M.now + 100
M.Fire("PLAYER_DEAD")
check(#M.sent == sentBefore + 1, "say inside an instance is sent straight away")
M.instance = nil

SpeakEasyDB.settings.triggersMuted = true
M.now = M.now + 100
sentBefore = #M.sent
M.Fire("PLAYER_DEAD")
check(#M.sent == sentBefore and L.Prime.Pending() == nil, "muted triggers do nothing")
SlashCmdList.SPEAKEASY("mute")
check(SpeakEasyDB.settings.triggersMuted == false, "/speakeasy mute toggles")

Triggers({ { event = "LOW_HEALTH", sceneId = "growl", options = { threshold = 30 } } })
local function Health(value) M.units.player.health = value; M.now = M.now + 20; M.Fire("UNIT_HEALTH", "player") end
sentBefore = #M.sent
Health(50)
check(#M.sent == sentBefore, "health above threshold does nothing")
Health(20)
check(#M.sent == sentBefore + 1, "dropping below threshold fires")
Health(15)
check(#M.sent == sentBefore + 1, "staying below does not fire again")
Health(60); Health(25)
check(#M.sent == sentBefore + 2, "fires again after recovering and dropping")
M.units.player.health = 100

M.units.player.health = M.Secret()
chatBefore, sentBefore = #M.chat, #M.sent
M.Fire("UNIT_HEALTH", "player")
check(#M.chat == chatBefore and #M.sent == sentBefore, "secret health skipped quietly, no error")
check(L.Play.Resolve("hp {healthPercent}") == "hp", "secret health leaves {healthPercent} blank")
M.units.player.health = 100

Triggers({ { event = "SPELL_CAST", sceneId = "growl", options = { spells = { { spell = "fireball" } } } } })
sentBefore = #M.sent
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 999)
check(#M.sent == sentBefore, "other spells ignored")
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 133)
check(#M.sent == sentBefore + 1, "named spell fires, any case")

Triggers({ { event = "SPELL_CAST", sceneId = "growl", options = { spells = { { spell = "Flash of Light" }, { spell = "Fireball" } } } } })
sentBefore = #M.sent
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 133)
check(#M.sent == sentBefore + 1, "any spell on the trigger's list fires it")

SpeakEasyDB.triggers = { { event = "SPELL_CAST", sceneId = "growl", options = { spell = "Fireball", item = "Wand" } } }
L.Db.Load()
local converted = SpeakEasyDB.triggers[1].options
check(#converted.spells == 1 and converted.spells[1].spell == "Fireball" and converted.spells[1].item == "Wand" and converted.spell == nil,
    "an old single spell trigger becomes a list of one")
chatBefore = #M.chat
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", M.Secret())
check(#M.chat == chatBefore, "secret spell id skipped quietly")

check(select(1, L.Compat.SpellOrItem("|cffffffff|Hitem:2287:0|h[Haunch of Meat]|h|r")) == "Food"
    and select(2, L.Compat.SpellOrItem("|Hitem:2287|h[Haunch of Meat]|h")) == "Haunch of Meat", "an item becomes the spell it casts")
check(L.Compat.SpellOrItem("|Hspell:133:0|h[Fireball]|h") == "Fireball", "a spell link becomes its name")
check(L.Compat.SpellOrItem("Flash of Light") == "Flash of Light", "a typed spell name is kept")

NewScene("Snack", { "Mmm, {itemName}." }, { channel = "EMOTE", cooldown = 0 })
Triggers({ { event = "SPELL_CAST", sceneId = "snack", options = { spells = { { spell = "Food", item = "Haunch of Meat" } } } } })
M.spells[433] = "Food"
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 433)
check(LastSent().text == "Mmm, Haunch of Meat.", "eating the item fires its trigger and fills {itemName}")

print("Trigger debugging")
SlashCmdList.SPEAKEASY("debug")
check(L.Triggers.debug, "/speakeasy debug turns debugging on")
Triggers({ { event = "SPELL_CAST", sceneId = "growl", options = { spells = { { spell = "Fireball" } } }, chance = 0 } })
chatBefore = #M.chat
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 133)
check(ChatHas("1 trigger(s) match", chatBefore + 1) and ChatHas("chance roll", chatBefore + 1), "debug shows a missed chance roll")
Triggers({ { event = "SPELL_CAST", sceneId = "shout", options = { spells = { { spell = "Fireball" } } } } })
chatBefore = #M.chat
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 133)
check(ChatHas("wait for your next key press", chatBefore + 1), "debug explains a Say line is waiting for a key")
L.Prime.Clear()
M.now = M.now + 5
chatBefore = #M.chat
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 133)
check(ChatHas("gap between trigger lines", chatBefore + 1), "debug explains the gap between trigger lines")
SpeakEasyDB.settings.triggersMuted = true
M.now = M.now + 100
chatBefore = #M.chat
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 133)
check(ChatHas("triggers are muted", chatBefore + 1), "debug explains muted triggers")
SpeakEasyDB.settings.triggersMuted = false
SlashCmdList.SPEAKEASY("debug")
check(not L.Triggers.debug, "/speakeasy debug again turns it off")

Triggers({ { event = "EAT_DRINK", sceneId = "growl" } })
sentBefore = #M.sent
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 133)
check(#M.sent == sentBefore, "eat or drink ignores other spells")
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 430)
check(#M.sent == sentBefore + 1, "drinking fires the eat or drink trigger")
M.now = M.now + 100
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 433)
check(#M.sent == sentBefore + 2, "eating fires it too")

NewScene("Meal", { "Mmm, {itemName}." }, { channel = "EMOTE", cooldown = 0 })
Triggers({ { event = "EAT_DRINK", sceneId = "meal" } })
UseAction(5)
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 433)
check(LastSent().text == "Mmm, Haunch of Meat.", "{itemName} is the food used from the action bar")
M.now = M.now + 100
C_Container.UseContainerItem(0, 1)
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 430)
check(LastSent().text == "Mmm, Conjured Water.", "{itemName} is the drink clicked in the bags")
M.now = M.now + 100
UseItemByName("Haunch of Meat")
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 433)
check(LastSent().text == "Mmm, Haunch of Meat.", "{itemName} is the item used with /use")
M.now = M.now + 100
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 433)
check(LastSent().text == "Mmm, .", "{itemName} is blank when no item use was seen recently")

-- A trigger switched from an item to eat or drink, as saved before the fix.
SpeakEasyDB.triggers = { { event = "EAT_DRINK", sceneId = "meal", chance = 100, cooldown = 0, enabled = true,
    options = { spell = "Food", item = "Leg Meat" } } }
L.Db.Load()
check(SpeakEasyDB.triggers[1].options.item == nil and SpeakEasyDB.triggers[1].options.spell == nil,
    "a leftover item is dropped from a non spell trigger when loading")
M.now = M.now + 100
C_Container.UseContainerItem(0, 1)
M.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 430)
check(LastSent().text == "Mmm, Conjured Water.", "eat or drink names what you drank, not an old item")

Triggers({ { event = "MOUNT", sceneId = "growl" } })
sentBefore = #M.sent
M.mounted = true
M.Fire("UNIT_AURA", "player")
M.now = M.now + 100
M.Fire("UNIT_AURA", "player")
check(#M.sent == sentBefore + 1, "mounting fires once")
M.mounted = nil

Triggers({ { event = "ENTER_COMBAT", sceneId = "empty" } })
chatBefore, sentBefore = #M.chat, #M.sent
M.Fire("PLAYER_REGEN_DISABLED")
check(#M.sent == sentBefore and #M.chat == chatBefore, "a trigger on an empty scene is skipped silently")

print("Scene buttons")
local rota = L.Db.FindScene("rota")
check(L.Macro.Pickup(rota) and M.macros[1].body == "/speakeasy rota" and M.macros[1].name == "Rota" and M.picked == 1, "drag creates the macro")
L.Macro.Pickup(rota)
check(#M.macros == 1, "dragging again reuses the macro")
L.Db.RenameScene(rota, "Rotation")
check(M.macros[1].name == "Rotation" and M.macros[1].body == "/speakeasy rota", "rename updates the macro name, body unchanged")
M.combat = true
L.Db.RenameScene(rota, "Rot3")
check(M.macros[1].name == "Rotation", "rename waits in combat")
M.combat = nil
M.Fire("PLAYER_REGEN_ENABLED")
check(M.macros[1].name == "Rot3", "rename made once combat ends")

CreateMacro("Clash", 1, "/cast Fireball")
local clash = NewScene("Clash", { "x" })
L.Macro.Pickup(clash)
check(M.macros[2].body == "/cast Fireball" and M.macros[3].body == "/speakeasy clash", "a macro of yours with the same name is left alone")

M.combat = true
check(not L.Macro.Pickup(clash), "no macro made in combat")
M.combat = nil

while #M.macros < 120 do CreateMacro("x", 1, "x") end
check(L.Macro.Pickup(NewScene("Side", { "x" })) and M.macros[121].perCharacter, "character slot used when account slots are full")
while #M.macros < 138 do CreateMacro("y", 1, "y", true) end
chatBefore = #M.chat
check(not L.Macro.Pickup(NewScene("Full", { "x" })) and ChatHas("/speakeasy full", chatBefore + 1), "full slots print the /speakeasy text")

local oldButton = NewScene("Old", { "x" })
CreateMacro("Old", 1, "/sl old")
oldButton.macroName = "Old"
M.Fire("PLAYER_LOGIN")
check(M.macros[#M.macros].body == "/speakeasy old", "an old /sl button is rewritten to /speakeasy at login")

print("Error handling")
M.sendError = "chat broke"
chatBefore = #M.chat
local okPress = pcall(Press, "solo")
check(okPress and ChatHas("chat broke", chatBefore + 1), "an error while sending is printed, not raised")
M.sendError = nil

IsMounted = function() error("api gone") end
local okEvent = pcall(M.Fire, "UNIT_AURA", "player")
check(okEvent, "an error in an event handler is contained")
IsMounted = function() return M.mounted end

local broken = NewScene("Broken", { "x" })
broken.lines = "junk"
check(pcall(Press, "broken"), "a damaged scene in memory does not raise")

check(pcall(SlashCmdList.SPEAKEASY, nil), "/speakeasy with no text does not raise")

print("Per character set")
local accountCount = #SpeakEasyDB.scenes
L.Db.SetCharacterSet(true)
check(L.Db.Set() == SpeakEasyCharDB and #SpeakEasyCharDB.scenes == accountCount, "character set starts as a copy")
L.Db.AddScene("Mine")
check(#SpeakEasyDB.scenes == accountCount, "account set untouched")
L.Db.SetCharacterSet(false)
check(L.Db.Set() == SpeakEasyDB, "back to the account set")

print(M.failures == 0 and "ALL PASSED" or (M.failures .. " FAILED"))
