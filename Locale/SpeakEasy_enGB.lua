-- Every piece of text SpeakEasy shows the player.
local ADDON, L = ...

-- To translate, copy this file to SpeakEasy_<locale>.lua, list it after this
-- one in the .toc, and open it with a guard so it only overwrites the keys it changes:
--     if GetLocale() ~= "deDE" then return end
--     local ADDON, L = ...
--     L.Text.BUTTON_SAVE = "Speichern"
-- Anything a translation omits falls back to the English below.
L.Text = {
    -- General
    ADDON_NAME = "SpeakEasy",
    -- Shorter, for the start of chat messages.
    CHAT_NAME = "SpeakEasy",
    NONE = "none",
    NEW_SCENE = "New scene",
    COPY_SUFFIX = "copy",
    BINDING_SPEAK = "Speak primed line",
    BINDING_WHEEL = "Emote wheel (hold)",

    -- Tabs
    TAB_SCENES = "Scenes",
    TAB_TRIGGERS = "Triggers",
    TAB_SETTINGS = "Settings",
    TAB_WHEEL = "Emote Wheel",

    -- Headings and titles
    HEADING_WHEEL = "Emote wheel",
    HEADING_HOTKEYS = "Hotkeys",
    HEADING_SCENES = "Scenes",
    HEADING_TRIGGERS = "Triggers",
    HEADING_DELIVERY = "Delivery",
    HEADING_LINES = "Lines",
    HEADING_SLOTS = "Slots",
    HEADING_TRIGGER_LINES = "Say and Yell from triggers",
    HEADING_ALL_TRIGGERS = "All triggers",
    HEADING_GENERAL = "General",
    TITLE_ICON = "Icon: %s",
    TITLE_NEW_LINE = "New line: %s",
    TITLE_EDIT_LINE = "Edit line: %s",
    TITLE_NEW_TRIGGER = "New trigger",
    TITLE_EDIT_TRIGGER = "Edit trigger",

    -- Captions
    CAPTION_SLOTS = "Choose what each direction plays: a scene, or a single emote.",
    CAPTION_TRIGGER_LINES = "Outside instances the game only lets Say and Yell go out from a key press. "
        .. "So when a trigger plays a scene on Say or Yell there, its line waits for one. Emote, "
        .. "Party, Raid and Instance lines, and anything inside an instance, go out straight away.",
    CAPTION_HOTKEYS = "Also under the game's Key Bindings, AddOns.",

    -- Descriptions
    DESC_ANY_KEY = "The line waits unseen and goes out with whatever key you press next. Turn off to "
        .. "see a prompt and send it with the Speak key instead.",

    -- Buttons
    BUTTON_EDIT = "Edit",
    BUTTON_DELETE = "Delete",
    BUTTON_REMOVE = "Remove",
    BUTTON_RENAME = "Rename",
    BUTTON_COPY = "Duplicate",
    BUTTON_NEW_SCENE = "New scene",
    BUTTON_NEW_LINE = "New line",
    BUTTON_SAVE = "Save",
    BUTTON_CANCEL = "Cancel",
    BUTTON_YES = "Yes",
    BUTTON_OK = "OK",
    BUTTON_TEST = "Test",
    BUTTON_TEST_LINE = "Test line",
    BUTTON_NEW_TRIGGER = "New trigger",
    BUTTON_PREVIOUS = "Previous",
    BUTTON_NEXT = "Next",
    BUTTON_PREVIEW_WHEEL = "Preview",

    -- Labels
    LABEL_CHANNEL = "Channel",
    LABEL_DEFAULT_EMOTE = "Default emote",
    LABEL_COOLDOWN = "Cooldown (s)",
    LABEL_ENABLED = "Enabled",
    LABEL_LINE = "Line",
    LABEL_PREVIEW = "Preview:",
    LABEL_INSERT = "Insert variable",
    LABEL_EMOTE = "Emote",
    LABEL_EVENT = "Event",
    LABEL_THRESHOLD = "Health below (%)",
    LABEL_SPELL = "Add a spell or item: shift-click it, or type a name and press Enter",
    LABEL_SCENE = "Scene",
    LABEL_CHANCE = "Chance (%)",
    LABEL_TRIGGER_COOLDOWN = "Cooldown (seconds)",
    LABEL_MUTE = "Mute all triggers",
    LABEL_ANY_KEY = "Send trigger lines with my next key press",
    LABEL_CHARACTER_SET = "This character uses its own scenes and triggers",
    LABEL_PRIME_TIMEOUT = "A waiting line is dropped after (seconds)",
    LABEL_GLOBAL_GAP = "Seconds between any two trigger lines",
    LABEL_TARGET_FALLBACK = "{targetName} with no target",
    LABEL_WHEEL_PAGES = "Pages",
    LABEL_WHEEL_SIZE = "Wheel size",
    LABEL_WHEEL_REMEMBER = "Open the wheel on the last page used (off: always page 1)",
    LABEL_ICON_SEARCH = "Search by name, such as hammer (or shift-click a spell or item, or type an icon id)",

    -- Hints
    HINT_NO_SCENES = "No scenes. Click New to add one.",
    HINT_NO_LINES = "No lines yet. Click New to add one.",
    HINT_ALL_DISABLED = "Every line is off, so this scene says nothing.",
    HINT_ONE_LINE = "Add a second line to enable rotation.",
    HINT_TRIGGERS = "Triggers play a scene when something happens. Outside instances the game "
        .. "only allows Say and Yell from a key press, so those lines go out with your next key "
        .. "press (see Settings).",
    HINT_NO_TRIGGERS = "No triggers yet.",
    HINT_TEST = "Prints to your chat only",
    HINT_WHEEL = "Hold the key, point at a slot and let go. Let go in the middle to cancel. "
        .. "Scroll or click the arrows to change page.",
    HINT_NO_SPELLS = "No spells or items yet. Add one above.",

    -- Tooltips
    TOOLTIP_DRAG = "Drag to an action bar. Pressing it says the next line.",
    TOOLTIP_COPY = "Right click to copy /speakeasy %s",
    TOOLTIP_MINIMAP_LEFT = "Left click: open",
    TOOLTIP_MINIMAP_MUTE = "Right click: mute triggers",
    TOOLTIP_MINIMAP_UNMUTE = "Right click: unmute triggers",
    TOOLTIP_WHEEL_SETTINGS = "Wheel settings",
    TOOLTIP_ICON = "Change the icon",

    -- Emote wheel
    WHEEL_PAGE = "Page %d of %d",
    WHEEL_CANCEL = "Let go here to cancel",
    PAGE_NAME = "Page %d",
    EMPTY_SLOT = "(empty)",
    EMOTE_CHOICE = "Emote: %s",

    -- Wheel slots
    SLOT_1 = "Top",
    SLOT_2 = "Top right",
    SLOT_3 = "Right",
    SLOT_4 = "Bottom right",
    SLOT_5 = "Bottom",
    SLOT_6 = "Bottom left",
    SLOT_7 = "Left",
    SLOT_8 = "Top left",

    -- Searchable picker
    PICKER_SEARCH = "Type to search",
    PICKER_NONE = "Nothing matches",

    -- Icon picker
    ICON_ID = "Icon id %s",
    ICON_UNNAMED = "Unnamed icon",
    ICON_ALSO = "Also: %s",
    ICON_READING = "Reading spell names for search... %d%%",
    ICON_NONE = "Nothing matches. Try a spell or item name, or shift-click one.",
    ICON_PAGE = "%d of %d",

    -- Lists and rows
    DRAG_HINT = "Drag %s to a bar",
    EMOTE_ONLY = "(%s only)",
    MISSING_SCENE = "(missing scene)",
    LINE_COUNT = "%d lines",
    LINE_COUNT_ONE = "%d line",
    LINE_COUNT_NONE = "No lines",
    SCENE_OFF = "Off",
    LINES_SUMMARY = "%d of %d lines on. Double click a line to edit it.",
    TRIGGER_DETAIL = "%s  ·  %s  ·  %s",
    NOT_ON_CLIENT = "|cffff4040(not on this game version)|r",
    SECONDS = "%s s",
    COUNTER = "%d / %d",

    -- Line editor
    PREVIEW_EMPTY = "(nothing)",
    WARN_UNKNOWN = "Unknown, sent as typed: %s",

    -- Channels
    CHANNEL_SAY = "Say",
    CHANNEL_EMOTE = "Emote",
    CHANNEL_YELL = "Yell",
    CHANNEL_PARTY = "Party",
    CHANNEL_RAID = "Raid",
    CHANNEL_INSTANCE_CHAT = "Instance",
    CHANNEL_AUTO = "Auto",

    -- Trigger events
    EVENT_ENTER_COMBAT = "Enter combat",
    EVENT_LEAVE_COMBAT = "Leave combat",
    EVENT_LOW_HEALTH = "Low health",
    EVENT_DEATH = "Death",
    EVENT_SPELL_CAST = "Cast a spell or use an item",
    EVENT_EAT_DRINK = "Eat or drink",
    EVENT_SPELL_SHORT = "Cast %s",
    EVENT_ITEM_SHORT = "Use %s",
    EVENT_MORE = "and %d more",
    SPELL_VIA = "casts %s",
    EVENT_MOUNT = "Mount up",
    EVENT_REST_AREA = "Enter a rest area",
    EVENT_TARGET_NPC = "Target an NPC",
    EVENT_BELOW = "(below %s%%)",

    -- Variables, as shown in the Insert variable menu
    VARIABLE_ITEM = "%s  %s  (%s)",
    VAR_targetName = "Your target's name",
    VAR_targetClass = "Your target's class",
    VAR_targetRace = "Your target's race",
    VAR_playerName = "Your name",
    VAR_playerClass = "Your class",
    VAR_playerRace = "Your race",
    VAR_zone = "Current zone",
    VAR_subZone = "Current subzone",
    VAR_guild = "Your guild",
    VAR_timeOfDay = "Morning, afternoon, evening or night",
    VAR_healthPercent = "Your health",
    VAR_spellName = "Spell that fired a spell trigger",
    VAR_itemName = "The item you used, for item and eat or drink triggers",

    -- Variable examples
    EXAMPLE_ITEM = "Haunch of Meat",
    EXAMPLE_SPELL = "Fireball",
    EXAMPLE_BLANK = "blank now",

    -- Times of day
    TIME_MORNING = "morning",
    TIME_AFTERNOON = "afternoon",
    TIME_EVENING = "evening",
    TIME_NIGHT = "night",

    -- Prompts and popups
    PROMPT_NEW_SCENE = "Name the new scene:",
    PROMPT_RENAME_SCENE = "Rename the scene:",
    PROMPT_TITLE = "Press %s to speak (%d)",
    PROMPT_NO_KEY = "the Speak key (unbound) or click here",
    CONFIRM_DELETE_SCENE = "Delete the scene %s and all its lines?",

    -- Chat messages
    MSG_ERROR = "something went wrong, and was skipped:",
    MSG_NO_LINES = "%s has no lines yet.",
    MSG_SCENE_DISABLED = "%s is turned off.",
    MSG_NO_SCENE = "No scene called %s. Type /speakeasy to see your scenes.",
    MSG_TRIMMED = "The line was over 255 characters once filled in, so it was cut short.",
    MSG_TEST = "Test [%s]: %s (emote: %s)",
    MSG_TEST_EMPTY = "That line comes out empty right now.",
    MSG_MUTED = "Triggers muted.",
    MSG_UNMUTED = "Triggers unmuted.",
    MSG_WHEEL_EMPTY = "The wheel is empty. Fill its slots in /speakeasy, Wheel tab.",
    MSG_BIND_COMBAT = "Keys cannot be changed in combat.",
    MSG_MACRO_COMBAT = "Buttons cannot be made in combat. Try again after the fight.",
    MSG_MACRO_FULL = "Your macro slots are full. Make a macro yourself with this text: %s",
    MSG_NO_ICONS = "This game version does not list its icons.",

    -- Trigger debugging (/speakeasy debug)
    DEBUG_PREFIX = "|cff9a9aa5debug:|r ",
    DEBUG_ON = "Trigger debugging on: chat shows why each trigger does or does not fire. "
        .. "Type /speakeasy debug again to stop.",
    DEBUG_OFF = "Trigger debugging off.",
    DEBUG_EVENT = "%s %s: %d trigger(s) match.",
    DEBUG_MUTED = "skipped, triggers are muted.",
    DEBUG_GAP = "skipped, the gap between trigger lines has %d s left.",
    DEBUG_COOLDOWN = "%s: on cooldown for %d s more.",
    DEBUG_CHANCE = "%s: chance roll %d missed (needs %d or less).",
    DEBUG_NO_SCENE = "%s: its scene no longer exists.",
    DEBUG_SCENE = "%s: %s did not play, %s.",
    DEBUG_WHY_off = "the scene is turned off",
    DEBUG_WHY_cooldown = "the scene's own cooldown is running",
    DEBUG_WHY_nolines = "it has no lines that come out with text",
    DEBUG_PRIMED = "%s: chosen. Say and Yell outside instances wait for your next key press.",
    DEBUG_SENT = "%s: played.",

    -- Errors
    ERR_NAME_EMPTY = "A scene needs a name.",
    ERR_NAME_LONG = "That name is too long.",
    ERR_NAME_TAKEN = "Another scene already has that name.",
    ERR_NO_SPELL = "Add at least one spell or item.",
    ERR_NO_SCENE = "Pick a scene.",
}
