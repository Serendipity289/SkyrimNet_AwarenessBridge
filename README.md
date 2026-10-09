# SkyrimNet Awareness Bridge

Start-game-enabled quest with a player alias so it reboots after save load.  
No world objects. No Creation Kit required. Does not install OStimNet.

Current pack: **1.1.0** (ESP filename is still `SkyrimNet_AwarenessBridge.esp`).

Install this folder as a Vortex mod (`ESP` + `Scripts\*.pex` + `SKSE\Plugins\SkyrimNet\external`) and Deploy.  
Enable `SkyrimNet_AwarenessBridge.esp` after `SkyrimNet.esp` and `OStim.esp`.

## Requirements

Tested on Skyrim Special Edition **1.6.1170**.

### Required

| Mod | Why |
| --- | --- |
| [SKSE64](https://skse.silverlock.org/) matching the game version | Papyrus plugin load |
| [Address Library for SKSE Plugins](https://www.nexusmods.com/skyrimspecialedition/mods/32444) | SKSE plugin common requirement |
| [powerofthree's Papyrus Extender](https://www.nexusmods.com/skyrimspecialedition/mods/22854) | Followers, swim/underwater/in-water, active animation names |
| [SkyrimNet](https://github.com/MinLL/SkyrimNet-GamePlugin/releases) (tested **Beta 25.1**) | `RegisterPersistentEvent` / `RegisterShortLivedEvent` |
| [OStim Standalone](https://www.nexusmods.com/skyrimspecialedition/mods/98163) **7.3.4 or later** (tested **7.5.1**) | Scene start/end, actor list, scene name/tags/actions |
| [OTracker - Thread Actors Recordkeeping](https://www.nexusmods.com/skyrimspecialedition/mods/108264) **2.0.1** | Actor-list fallback; this pack is compiled against it |
| [PapyrusUtil SE](https://www.nexusmods.com/skyrimspecialedition/mods/13048) | Required by OTracker 2.x |

Load order for the ESPs: `SkyrimNet.esp`, then `OStim.esp`, then `OTracker.esp`, then `SkyrimNet_AwarenessBridge.esp`.

### Optional

These are looked up at runtime. Missing them only drops that one fact.

| Mod | Extra fact |
| --- | --- |
| [Loki's Wade in Water](https://www.nexusmods.com/skyrimspecialedition/mods/42854) or [Wade in Water Redone](https://www.nexusmods.com/skyrimspecialedition/mods/71418) | Extra wading check (`0xD65`) |
| [Dynamic Looting and Harvesting Animations](https://www.nexusmods.com/skyrimspecialedition/mods/114547) | Player looting (`LootingAnimations.esp` / `LA_AnimTrigger`) |
| [EVG CLAMBER - Slope Animations](https://www.nexusmods.com/skyrimspecialedition/mods/114753) | Steep terrain facts |
| Extra OStim animation packs | Richer scene names/tags for mood lines |
| SeverActions | Wait / Sit / Follow become the body beat |

Not required: SkyUI, OStimNet, CHIM, a sequences pack.

## What it sends to SkyrimNet

Uses `RegisterPersistentEvent` (no dialogue reaction from the Event itself).

### OStim, nearby only (same cell or within 5000 units)

- Start/end nearby line, plus one personal line per involved NPC
- Mood comes from the playing scene name/tags/actions (kiss, embrace, cuddle, dance, tender, heated). Default is a private/intimate moment
- Location is appended when the cell has a name, for example `at The Bannered Mare`. Otherwise `nearby`
- End is `ostim_thread_end` only. OTracker is used to recover the actor list

### Player and followers, checked every 10 seconds

Engine facts (the same ones that fire the animation packs):

- Swimming: `IsSwimming` / underwater
- Wading: in water, not swimming (Wade In Water / EVG wade)
- Injured / exhausted / clutching their head: EVG health/stamina/magicka thresholds
- Cold / shield-in-rain: EVG weather facts
- Looting: LootingAnimations `LA_AnimTrigger` (player)
- Hug / eat / dance / cheer from active animation names  
  e.g. `Lydia and the Dragonborn are hugging.`  
  OStim scenes are not also reported as hugs
- Steep terrain (EVG Clamber): climbing / scrambling down a steep slope

### Papyrus actions NPCs may choose

- `Bundle_Up`: when cold/snow outdoors, equip one non-torso warmth piece
- `Unbundle`: when warm, take off the piece `Bundle_Up` put on

### Unprompted reaction (comment you can hear)

On each confirmed start (not every 10s of the same swim):

- Nearest follower who is not in the OStim scene gets a speaking turn
- Followers keep following (this plugin does not issue Wait / Sit / Follow)
- Same fact will not fire again for 45 seconds
- OStim participants still get Event lines. They do not get this extra speaking turn. Observers may.

Does not command NPCs into OStim. No LLM scene control.

## After updating

Load a save (the quest form is new so it starts itself).  
If Events still stay empty, open the console once:

```
startquest SkyrimNet_AwarenessBridgeQuest
```
