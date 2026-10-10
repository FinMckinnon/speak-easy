# SpeakEasy: WoW RP Addon Requirements

Oct 10, 2026

## Overview and goals

SpeakEasy (working name) lets a roleplayer write pools of lines grouped into scenes such as Combat or Tavern, then press one action bar button to say a random line from that scene. Lines never repeat back to back and every line gets used before any comes round again.

**Goals**

- Write and organise lines in game, no file editing
- One button per scene, dragged straight onto the action bar
- Automatic triggers on game events (combat start, low health) that play a scene for you
- Varied output: smart rotation, optional emote, variables inserted from a picker
- Stay inside Blizzard rules: Say and Yell only ever go out on a key press
- Never crash: any error is caught, reported once in chat, and the rest of the addon keeps working

**Non goals for v1**

- Multi character scripted scenes (Curtain Call already covers this)
- Syncing lines between players

## Core concepts

| Concept | What it is | Key settings |
| --- | --- | --- |
| Scene | A named context holding a pool of lines, e.g. Combat, Tavern, Greeting | Name, icon, channel, default emote, cooldown, enabled |
| Line | One message the character can say | Text (max 255 chars), optional emote, enabled toggle |
| Emote | A built in WoW emote played alongside the line, e.g. /dance, /bow | Emote token, timing (before or after the line) |
| Variable | A placeholder like `{targetName}` filled in at send time | Picked from the Insert variable menu |
| Trigger | A game event that plays a scene automatically | Event, scene, chance %, cooldown, enabled |
| Rotation | How the next line is picked | Shuffle bag per scene |
| Scene button | A WoW macro whose body is `/speakeasy <scene>`, dragged onto a bar | Created and updated by the addon |

**Rotation rule (shuffle bag)**

1. When a scene's bag is empty, copy all enabled lines into it and shuffle.
2. If the first line in the new bag equals the last line played, swap it with a random later line.
3. Each press takes the next line from the bag.
4. Adding, editing, removing, enabling, disabling or reordering a line resets that scene's bag.

Result: no line repeats back to back, and every line is used once per cycle.

**Edge cases**

| Enabled lines | Button press | Trigger fires | Editor |
| --- | --- | --- | --- |
| 0 (none, or all disabled) | Sends nothing. Prints "Combat has no lines yet" to your chat only, at most once per 10 s | Skipped silently | Empty list hint: "No lines yet. Click New to add one." Scene name shows a warning marker |
| 1 | Sends that line every press; the no repeat rule is waived; cooldown still applies | Plays that line | Hint under the list: "Add a second line to enable rotation" |
| 2 | Strictly alternates (a natural result of the rule) | Same | Nothing extra |
| 3 or more | Normal shuffle bag | Same | Nothing extra |

- A line with an emote and no text counts as a line.
- If a line resolves to empty text after variables (e.g. only `{guild}` with no guild) and has no emote, it is skipped and the next line in the bag is used. If every line resolves empty, treat the scene as having 0 lines for that press.
- The bag is runtime only. On /reload it rebuilds, so the first press after a reload can repeat the last line from before the reload; acceptable for v1.

**Emote precedence:** a line's own emote wins; otherwise the scene default; otherwise none. A line with only an emote and no text is valid.

## Functional requirements

**Scenes**

- FR1: Create, rename, duplicate, delete and reorder scenes. Delete asks for confirmation.
- FR2: Each scene has a name (unique, used in the slash command), an icon, a chat channel, an optional default emote and an optional cooldown.
- FR3: Channel options: Say, Emote (custom /e text), Yell, Party, Raid, Instance, and Auto (group chat if grouped, else Say).
- FR4: A scene can be disabled without deleting it; its button then does nothing and prints a short notice.

**Lines**

- FR5: Add, edit, delete, duplicate and reorder lines within a scene, in the style of the Windows environment variables dialog.
- FR6: Each line has an enabled checkbox, so lines can be parked without deleting them.
- FR7: The editor shows a live character counter and blocks saving over 255 characters.
- FR8: Each line can optionally pick an emote from a searchable list of the game's emotes.
- FR9: An Insert variable button opens a menu of supported variables (see table below) and inserts the chosen one at the cursor. Users never need to remember the syntax.
- FR10: Unknown variables are highlighted in the editor and left as typed when sent.

| Variable | Inserts | Fallback when empty |
| --- | --- | --- |
| `{targetName}` | Current target's name | "friend" (editable) |
| `{targetClass}` | Target's class | Left blank |
| `{targetRace}` | Target's race | Left blank |
| `{playerName}` | Your character's name (RP name in a later version) | Never empty |
| `{playerClass}` | Your class | Never empty |
| `{playerRace}` | Your race | Never empty |
| `{zone}` | Current zone, e.g. Elwynn Forest | Never empty |
| `{subZone}` | Current subzone, e.g. Lion's Pride Inn | Falls back to zone |
| `{guild}` | Your guild name | Left blank |
| `{timeOfDay}` | morning, afternoon, evening or night from game time | Never empty |
| `{healthPercent}` | Your current health, e.g. 27% | Never empty |
| `{spellName}` | Spell that fired a Spell cast trigger | Left blank |

**Playing**

- FR11: `/speakeasy <scene>` plays the next line of that scene using the rotation rule.
- FR12: Each play sends at most one chat message and one emote.
- FR13: Optional per scene cooldown; presses during it are ignored with no message spam.
- FR14: A Test button in the editor prints the resolved line to your own chat frame only.

**Scene button**

- FR15: A draggable icon at the bottom right of the editor. Dragging it creates or updates a macro named after the scene and puts it on the cursor to drop on any bar.
- FR16: Renaming a scene updates its macro so existing bar buttons keep working.
- FR17: If macro slots are full, show a clear message plus the `/speakeasy <scene>` text to paste manually.

**Storage**

- FR18: Scenes and triggers are account wide by default, with an optional per character override set, saved via SavedVariables so nothing is lost on /reload or logout.

**Triggers**

- FR19: A Triggers tab lists event triggers. Each maps one event to one scene, with a chance % (default 30%), its own cooldown (default 60 s) and an enabled toggle.
- FR20: v1 events: enter combat, leave combat, low health (threshold %, default 30%), death, cast a named spell, mount up, enter a rest area (inn or city), target an NPC.
- FR21: Channels Emote, Party, Raid and Instance are sent immediately when a trigger fires.
- FR22: Say and Yell are sent immediately only inside instances. Elsewhere the line is primed: a small prompt shows the line and the next press of the Speak keybind sends it. A primed line expires after 8 seconds (adjustable).
- FR23: A global mute toggle (slash command and minimap right click) pauses all triggers, e.g. during raids.
- FR24: Only one trigger line per 10 seconds across all triggers, so a busy fight can't chain several lines.

**Error handling**

- FR25: Every entry point the game calls (events, slash commands, key bindings, clicks, widget callbacks) runs inside an error guard. An error prints one short chat message (the same error at most once per 10 s) and never raises a Lua error popup.
- FR26: SavedVariables are validated on load. Values of the wrong type, unknown channels or events, duplicate ids and over long text are repaired or dropped, so a damaged file cannot break the addon.
- FR27: Each variable is resolved on its own; a failing client API blanks only that variable.
- FR28: Events missing on a client version are skipped at registration rather than erroring.

## UI layout and UX flow

One window, two panes, modelled on the Windows environment variables dialog: pick a scene on the left, manage its lines on the right, drag its button from the bottom right corner.

```
+----------------------------------------------------------------------------+
| SpeakEasy                                                             x  |
+----------------------------------------------------------------------------+
| +----------------------+  [Channel: Say v] [Default emote: none v] [CD: 2s]|
| | Scenes               |  +-------------------------------------+ +-------+|
| | [ Combat          ]  |  | On  Line                      Emote | |  New  ||
| |   Tavern             |  |-------------------------------------| | Edit  ||
| |   Greeting           |  | [x] For {zone}!               Charge| |Delete ||
| |   Farewell           |  | [x] Is that all you've got,   none  | |       ||
| |                      |  |     {targetName}?                   | |Move up||
| |                      |  | [ ] Not today. (disabled)     Roar  | |Move dn||
| |                      |  | [x] *slowly draws her blade*  none  | +-------+|
| |                      |  |                                     |          |
| | [New][Rename][Delete]|  +-------------------------------------+          |
| +----------------------+                                                   |
| [Scenes] [Triggers]  (tabs)                                                |
+----------------------------------------------------------------------------+
| [Test line]  Prints to your chat only        Drag Combat to a bar  [ SL ]  |
+----------------------------------------------------------------------------+
```

The selected scene's settings sit above its lines; the draggable button (bottom right) always reflects the selected scene.

**Main flow**

1. Open with `/speakeasy` or the minimap button. First launch shows the starter scenes.
2. Select a scene. The right pane loads its settings and lines.
3. Click New or double click a line to open the line editor.
4. Drag the button at the bottom right onto an action bar. The macro is created or updated on drag.
5. Close the window and press the bar key in game to say the next line.

**Line editor dialog**

- Multi line text box with a live counter (e.g. 42 / 255), red past the limit.
- Emote picker: searchable dropdown of the game's emotes, plus "none".
- Insert variable button: opens a menu of the variables, each with a one line description and a live example (e.g. `{zone}` shows Elwynn Forest). Clicking one inserts it at the cursor.
- Preview line under the box shows the text with variables resolved for your current situation.
- Test, Save and Cancel. Enter saves, Escape cancels.

**Triggers tab**

- A second tab beside Scenes, listing rows of: enabled checkbox, event, scene, chance %, cooldown.
- New trigger opens a small dialog: pick event (with its options, e.g. health threshold or spell name), pick scene, set chance and cooldown.
- A primed Say or Yell line appears in a small movable prompt with the line text and a countdown; pressing the Speak keybind sends it.

**Small UX details**

- Empty scene shows a hint ("No lines yet. Click New to add one.") instead of a blank list.
- Disabled lines are greyed but still editable.
- Window position and size are remembered; the window closes with Escape like other panels.
- Tooltip on the scene button explains drag to bar, and right click to copy the `/speakeasy` command.

## Technical constraints and design decisions

| Constraint | Impact | Decision |
| --- | --- | --- |
| Say and Yell need a hardware event outside instances (Retail since 8.2.5, Classic Era since 1.15.9) | Triggers cannot send them automatically in the open world | Button presses send directly. Triggers send Emote and group channels directly and prime Say and Yell lines for the Speak keybind (FR22) |
| `CreateMacro` and `EditMacro` are blocked in combat | Can't make or rename buttons mid fight | Macro body is only `/speakeasy <scene>`, so editing lines never touches the macro. Queue renames until `PLAYER_REGEN_ENABLED` |
| Macro slots are limited (shared account pool plus per character pool) | Many scenes could fill them | Create macros only on drag, reuse existing ones by name, show the fallback from FR17 |
| 255 character chat limit | Long lines fail once variables expand | Enforce in editor, check again after substitution and trim with a warning |
| `DoEmote` takes an emote token, not slash text | Need a mapping | Build the emote list from the game's emote tokens at load, show friendly names |
| Multiple game versions (Retail, Classic, Forever) | Settings, UI and combat event APIs differ | Own standalone window, no dependence on the new Settings panel; small compatibility shim |
| Retail 12 secret values: health (and possibly other combat values) can be shown but not compared or calculated with | Low health trigger and `{healthPercent}` cannot work there | Detect the restriction at runtime (`issecretvalue` exists), not by version number. Unsupported events and variables are hidden from the editors, existing ones are marked "not on this game version", and secret values are skipped without an error. Each game install keeps its own SavedVariables, so no per version config file is needed |
| Chat spam reports | A legal button or trigger can still get actioned | Default 2 s cooldown per scene, trigger chance and cooldown, plus the global trigger limit (FR24) |

**Key decision:** the macro is a thin pointer (`/speakeasy combat`), and all content lives in SavedVariables. This sidesteps combat lockdown and the macro size limit, and lets one scene hold any number of lines.

## Scene wheel (built in v1)

Hold a hotkey to open a radial wheel of scenes around the cursor; move the mouse over a scene and release the key to play it. One key replaces several bar buttons.

**Requirements**

- FR29: A "Scene wheel" key binding, set from the Wheel tab or Key Bindings, AddOns. Holding it opens the wheel centred on the cursor; releasing it plays the slot under the cursor. Scenes play through the normal `/speakeasy` path, so rotation, cooldowns and emotes all apply.
- FR30: Releasing inside the ring's hole, or far outside the wheel, plays nothing (cancel).
- FR31: The wheel is a ring of 8 fixed slots (Top, Top right, ... Top left). Each slot holds a scene, a single emote, or nothing.
- FR32: 1 to 9 pages, chosen with a slider. Scrolling the mouse wheel while holding the key turns the page, wrapping round.
- FR33: A Wheel tab sets the key, the page count and the wheel size (0.5x to 2x), with a Preview button, and one sub tab per page laying out the 8 slot pickers as a compass around a ring picture.
- FR34: Disabled scenes and scenes with no enabled lines show greyed and do nothing when chosen. A new scene goes in the first empty slot.

**Feasibility**

| Question | Answer |
| --- | --- |
| Can a binding tell press from release? | Yes. A binding declared with `runOnUp="true"` in Bindings.xml is called with `"down"` on press and `"up"` on release. |
| Can the release send Say or Yell in the open world? | Expected yes: a key release is a hardware event, the same as the Speak key. Must be confirmed in game on Retail and Classic Era before release; if it fails, the wheel primes the line instead (FR22). |
| Can AceGUI draw the wheel? | No. AceGUI lays widgets out in Flow and List containers with no absolute or radial positioning, and recycles its frames between addons. The wheel is about ten plain `CreateFrame` buttons placed with `cos`/`sin` around the cursor, about 100 lines. AceGUI stays for the settings: the toggle per scene and, optionally, its `Keybinding` widget to set the key from the Options section. |
| Does it work in combat? | Yes. The wheel uses only non secure frames and `SendChatMessage`, neither of which combat lockdown blocks. Setting the key binding itself is blocked in combat, as for any binding. |
| Anything that stops it? | The cursor is hidden while a mouse button is held for camera turning, so the wheel needs the cursor free. With more than 8 scenes only the chosen 8 fit. |

**As built:** `UI/SpeakEasy_Wheel.lua`. The pick is by direction: anywhere in a slice's sector between the dead zone (35 px) and the outer edge (180 px) counts, not just the icon, so a quick flick works. The wheel key and the Speak key can both be set from the Options section (AceGUI `Keybinding` widget, blocked in combat), or from the game's Key Bindings, AddOns.

## Extra features: v1 vs later

| Feature | Why users want it | Release |
| --- | --- | --- |
| Smart rotation (shuffle bag) | Lines don't go stale | v1 |
| Optional emote per line and per scene | Body language with the words | v1 |
| Insert variable menu (`{targetName}`, `{zone}`...) | Lines feel reactive without learning syntax | v1 |
| Automatic triggers (combat, low health, death, spell cast...) | Character reacts without a button press | v1 |
| Per scene cooldown and global trigger limit | Avoids spam reports | v1 |
| Test button (local preview) | Check wording without saying it | v1 |
| Starter scene pack (Greeting, Farewell, Combat, Tavern) | Useful on first install | v1 |
| Scene wheel (hold a key, pick a scene with the mouse) | Many scenes from one key | v1 |
| Modifier variants: Shift press uses Emote channel, Ctrl uses Party | One button, several outputs | v1.1 |
| Line weighting (common vs rare lines) | Rare lines feel special | v1.1 |
| Import and export scenes as a text string | Share packs with friends and guilds | v1.1 |
| Per character profiles and copy between characters | Different characters, different voices | v1.1 |
| Scene icon picker from the game's icon list | Recognisable bar buttons | v1.1 |
| More trigger events (looting, quest complete, level up, emote received) | Wider coverage | v1.1 |
| Conditional lines (only in combat, only targeting an NPC) | Smarter picks | Later |
| Multi line sequences (say, pause, next press continues) | Short monologues | Later |
| TotalRP3 integration (RP name in `{playerName}`) | Consistent with RP profiles | Later |

## Data model and milestones

```lua
-- SavedVariables: SpeakEasyDB (account wide)
SpeakEasyDB = {
    version = 1,
    scenes = {
        {
            id = "combat",            -- stable key used by /speakeasy and the macro
            name = "Combat",          -- display name
            icon = 132147,            -- texture file ID
            channel = "SAY",          -- SAY, EMOTE, YELL, PARTY, RAID, INSTANCE_CHAT, AUTO
            defaultEmote = nil,       -- e.g. "ROAR"
            cooldown = 2,             -- seconds
            enabled = true,
            macroName = "Combat",     -- name of the macro made on drag, for rename sync
            lines = {
                { text = "For {zone}!", emote = "CHARGE", enabled = true },
                { text = "Is that all you've got, {targetName}?", enabled = true },
            },
        },
    },
    -- 1 to 9 pages of 8 slots: a scene id, "emote:<TOKEN>", or "" for empty
    wheelPages = {
        { "combat", "tavern", "emote:DANCE", "", "", "", "", "" },
    },
    triggers = {
        {
            event = "LOW_HEALTH",     -- ENTER_COMBAT, LEAVE_COMBAT, LOW_HEALTH, DEATH, SPELL_CAST, MOUNT, REST_AREA, TARGET_NPC
            options = { threshold = 30 },  -- spell = "Fireball" for SPELL_CAST
            sceneId = "combat",
            chance = 30,              -- percent
            cooldown = 60,            -- seconds
            enabled = true,
        },
    },
    settings = {
        triggersMuted = false,
        speakOnAnyKey = true,         -- a primed line goes out with your next key press
        wheelScale = 1,
        primeTimeout = 8,             -- seconds a primed Say or Yell line waits
        globalTriggerGap = 10,        -- seconds between any two trigger lines
        targetFallback = "friend",
        minimapAngle = 225,
        window = {},                  -- position and size
        prompt = {},                  -- primed line prompt position
    },
}

-- SavedVariablesPerCharacter: SpeakEasyCharDB = { useOwn = false, scenes = {...}, triggers = {...} }

-- Runtime only, rebuilt on load (not saved)
-- bags[sceneId] = { remaining = { lineIndex, ... }, last = lineIndex }
```

**Milestones**

1. Core: SavedVariables, `/speakeasy <scene>`, shuffle bag with edge cases, send with channel and emote.
2. Editor window: scene list, line list, line edit dialog with counter, emote picker and Insert variable menu.
3. Scene button: drag to create macro, rename sync, combat queue, slot full fallback.
4. Triggers: event handling, chance and cooldowns, priming and Speak keybind, mute toggle.
5. Polish: variable preview, Test button, starter pack.
6. Test on Retail, Classic Era and Forever, then publish to CurseForge.

**Open questions**

- Final name: SpeakEasy, or something else?
- Should the emote fire before or after the line by default? (v1 build: before.)
