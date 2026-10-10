# SpeakEasy: Roleplay Emote Wheel & Lines

SpeakEasy is a World of Warcraft roleplay addon. Hold a key to open an emote wheel around your cursor, or press one action bar button to say a random line from a scene you've written. It's for roleplayers who want their character to talk and emote without typing the same lines over and over.

## What it does

- **Emote wheel**: hold a key, point at a slot and let go. Each slot holds a scene or a single emote, and you can have up to 9 pages of 8.
- **Scenes**: write a pool of lines for a situation, like Greeting, Combat or Tavern, and choose the channel: Say, Yell, Emote, Party, Raid, Instance, or Auto.
- **Lines that don't repeat**: every line in a scene gets said once before any comes round again, and never the same one twice in a row.
- **Bar buttons**: drag a scene onto your action bar and pick any icon for it. Each press says the next line.
- **Variables**: drop in your target's name, the zone, the time of day and more from a menu while you write.
- **Triggers**: play a scene when you enter combat, cast a spell, eat or drink, mount up, die, reach an inn or city, or target an NPC.
- **Emotes with lines**: give a line its own emote, or a scene a default one, so your character waves as they say hello.

## Getting started

1. Type `/speakeasy` or click the minimap button.
2. Look through the four starter scenes, then edit them or write your own.
3. On the Emote Wheel tab, set a key for the wheel and fill its slots.
4. On the Scenes tab, drag a scene's icon from the bottom right onto your action bar.

## Questions

### Which versions of WoW does it work on?

It's built for Retail, Classic Era, Mists of Pandaria Classic, Anniversary and WoW Forever, but so far it has only been tested on Retail. If you play on one of the others, I'd really appreciate hearing whether it works for you.

### Can my character speak automatically in combat?

Yes, with triggers. Emote, party, raid and instance lines go out straight away. Outside instances, the game only lets Say and Yell go out from a key press, so those lines wait and go out with your next key press, usually your next ability.

### Why didn't my trigger say anything?

Each trigger has a chance and a cooldown, and only one trigger line plays every few seconds. Type `/speakeasy debug` and chat will tell you why each trigger did or didn't play.

### Can I put plain emotes on the wheel, without any lines?

Yes. Any slot can hold a single emote, like /dance or /bow.

### Why is there no low health trigger on Retail?

Retail keeps your health hidden from addons, so it can't tell when you're low. The trigger is there on Classic and Forever.

## Commands

- **/speakeasy**: open the window
- **/speakeasy &lt;scene&gt;**: say the next line of a scene
- **/speakeasy mute**: pause every trigger, handy for raids
- **/speakeasy debug**: show why triggers do or don't fire

## Install

Download `SpeakEasy.zip` and put the `SpeakEasy` folder in `World of Warcraft\_retail_\Interface\AddOns`, or the matching folder for your version, such as `_classic_era_`.

Ideas and bug reports are welcome, so let me know what you'd like it to do.

## Licence

MIT. Copyright (c) 2026 Finlay McKinnon. See [LICENSE](LICENSE).
