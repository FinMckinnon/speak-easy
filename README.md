# SpeakEasy: Roleplay Emote Wheel & Lines

<span style="font-size: 14px;">SpeakEasy is a <strong>roleplay addon for World of Warcraft</strong> with an emote wheel and scenes of lines you say from one button. Hold one key to open an <strong>emote wheel</strong> around your cursor, point at a scene or an emote and let go to play it. Write <strong>scenes</strong> such as Combat, Tavern or Greeting, each a pool of lines, and press <strong>one action bar button</strong> to say a random line from it. Lines never repeat back to back, and every line gets used before any comes round again.&nbsp;</span>

<span style="font-size: 14px;">It works on <strong>Retail, Classic Era, Mists of Pandaria Classic, Anniversary and WoW Forever</strong>. Everything is written in game, nothing to edit in files, and it stays inside Blizzard's rules: <strong>Say and Yell only ever go out on a key press</strong>.&nbsp;</span>

<span style="font-size: 14px;">I want this project to be as community involved as possible, so please feel free to comment or message me ideas!<br><br>Happy Roleplaying!<br></span>

## <span style="font-size: 16px;"><strong>Key Features at a Glance</strong></span>

<span style="font-size: 14px;"><strong>Emote Wheel</strong>: Hold one key, point at a scene or emote and let go, with up to 9 pages of 8 slots<br>
<strong>Scenes</strong>: Group lines by situation, each with its own channel, default emote and cooldown<br>
<strong>One Button per Scene</strong>: Drag the scene's icon straight onto an action bar, with any icon you like<br>
<strong>Smart Rotation</strong>: No back to back repeats, and every line is used once per cycle<br>
<strong>Variables</strong>: Insert {targetName}, {zone}, {timeOfDay} and more from a menu, no syntax to learn<br>
<strong>Triggers</strong>: Play a scene when you enter combat, cast a spell, eat or drink, mount up and more<br>
<strong>Spam Safe</strong>: Scene cooldowns, trigger chance and cooldown, and a gap between any two trigger lines<br>
<strong>Every Version</strong>: Retail, Classic Era, Mists of Pandaria Classic, Anniversary and WoW Forever<br>


## Installation

To install SpeakEasy, download **SpeakEasy.zip** then place the **SpeakEasy** folder into your Addons folder for your World of Warcraft installation, regularly at `C:\Program Files (x86)\World of Warcraft\#GAMEVERSION#\Interface\AddOns` where GAMEVERSION represents your Game Version of World of Warcraft.

---

## **Features & Customisation**

#### <span style="font-size: 18px;"><strong>Getting Started</strong></span>

<span style="font-size: 14px;">Type this command&nbsp;in the chat window, or click the minimap button, to open the window:</span>

/speakeasy

<span style="font-size: 14px;">The starter scenes (Greeting, Farewell, Combat and Tavern) are there on first launch, already on the wheel.</span>

---

#### <span style="font-size: 18px;"><strong>Emote Wheel</strong></span>

- <span style="font-size: 14px;"><strong>Hold to Open</strong>: Set the wheel key on the Emote Wheel tab, hold it, point at a slot and let go to play it. Let go in the middle to cancel.</span>
- <span style="font-size: 14px;"><strong>Scenes or Emotes</strong>: Each of the 8 slots holds a scene, a single emote, or nothing, placed where you want them.</span>
- <span style="font-size: 14px;"><strong>Pages</strong>: Up to 9 pages. Scroll the mouse wheel or click the arrows beside the wheel to change page, and choose whether it opens on the last page used or always on page 1.</span>
- <span style="font-size: 14px;"><strong>Size</strong>: Make the wheel as big or small as you need, and preview it in the middle of the screen.</span>
- <span style="font-size: 14px;"><strong>Settings at Hand</strong>: Click the cog under the wheel to jump straight to its settings.</span>

---

#### <span style="font-size: 18px;"><strong>Scenes and Lines</strong></span>

- <span style="font-size: 14px;"><strong>Channels</strong>: Say, Emote (/e text), Yell, Party, Raid, Instance, or Auto (group chat when grouped, else Say).</span>
- <span style="font-size: 14px;"><strong>Emotes with Lines</strong>: Give a line its own emote, or a whole scene a default one. A line can be just an emote.</span>
- <span style="font-size: 14px;"><strong>Line Editor</strong>: A live character counter, a preview with the variables filled in, and a Test button that prints to your chat only. Enter saves.</span>
- <span style="font-size: 14px;"><strong>Park Lines</strong>: Untick a line to stop it being said without deleting it.</span>
- <span style="font-size: 14px;"><strong>Cooldowns</strong>: Each scene has its own cooldown so a quick double press doesn't spam.</span>

---

#### <span style="font-size: 18px;"><strong>Scene Buttons</strong></span>

<span style="font-size: 14px;">Drag the icon at the bottom right of the Scenes tab onto any action bar. Pressing it says the scene's next line. Click the icon next to a scene's name to pick its button icon: search by spell name, such as <strong>hammer</strong>, or shift-click a spell or item. Renaming a scene keeps its buttons working, and right clicking the drag icon gives you the <strong>/speakeasy</strong> command to paste into your own macros.</span>

---

#### <span style="font-size: 18px;"><strong>Variables</strong></span>

<span style="font-size: 14px;">Pick these from the <strong>Insert variable</strong> menu in the line editor, each with a live example:</span>

- <span style="font-size: 13px;">{targetName}, {targetClass}, {targetRace}</span>
- <span style="font-size: 13px;">{playerName}, {playerClass}, {playerRace}, {guild}</span>
- <span style="font-size: 13px;">{zone}, {subZone}, {timeOfDay}</span>
- <span style="font-size: 13px;">{spellName} and {itemName}, from the spell or item that set off a trigger</span>
- <span style="font-size: 13px;">{healthPercent} (not on Retail, where the game keeps health hidden from addons)</span>

---

#### <span style="font-size: 18px;"><strong>Triggers</strong></span>

<span style="font-size: 14px;">Play a scene by itself when something happens: <strong>enter or leave combat, cast a spell or use an item</strong> (eating and drinking included), <strong>death, mount up, enter a rest area, target an NPC</strong>, and <strong>low health</strong> where the game allows it. Each trigger has its own chance and cooldown, and only one trigger line plays every few seconds, so a busy fight can't chain several.</span>

<span style="font-size: 14px;"><strong>Say and Yell</strong>: Outside instances the game only lets Say and Yell go out from a key press, so a trigger's Say or Yell line waits and goes out with your <strong>next key press</strong>, your next ability for example. Prefer a prompt? Turn that off and send it with the Speak key instead. Emote, Party, Raid and Instance lines always go out straight away.</span>

<span style="font-size: 14px;"><strong>Mute</strong>: Pause every trigger with <strong>/speakeasy mute</strong> or a right click on the minimap button, for raids or quiet moments.</span>

---

#### <span style="font-size: 18px;"><strong>Test Your Setup</strong></span>

<span style="font-size: 14px;">Use the <strong>"Test line"</strong> button to see how a line comes out, in your own chat only. If a trigger doesn't fire when you expect, type <strong>/speakeasy debug</strong> and chat shows why each trigger did or didn't play.</span>

---

## Licence

SpeakEasy is released under the [MIT License](https://opensource.org/license/mit). Copyright (c) 2026 Finlay McKinnon. See [LICENSE](LICENSE).
