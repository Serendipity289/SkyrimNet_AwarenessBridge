# SkyrimNet Awareness Bridge

Start-game-enabled quest with a player alias so it reboots after save load.  
No world objects. No Creation Kit required. Does not install OStimNet.

Install this folder as a Vortex mod (`ESP` + `Scripts\*.pex`) and Deploy.  
Enable `SkyrimNet_AwarenessBridge.esp` after `SkyrimNet.esp`.

## What it sends to SkyrimNet

Uses `RegisterPersistentEvent` (no dialogue reaction).

### OStim, nearby only (same cell or within 5000 units)

- Start/end nearby line, plus one personal line per involved NPC
- Mood comes from the playing scene name/tags/actions (kiss, embrace, cuddle, dance, tender, heated). Default is a private/intimate moment
- End is `ostim_thread_end` only. OTracker is used to recover the actor list

### Player and followers, checked every 10 seconds

Engine facts (the same ones that fire the animation packs):

- Swimming: `IsSwimming` / underwater
- Wading: in water, not swimming (Wade In Water / EVG wade)
- Injured / exhausted / clutching their head: EVG health/stamina/magicka thresholds
- Cold / shield-in-rain: EVG weather facts
- Looting: LootingAnimations `LA_AnimTrigger` (player)
- Hug / eat / dance / cheer from active animation names  
  e.g. `Taliesin and Sarah Stormbringer are hugging.`  
  OStim scenes are not also reported as hugs

Not sent: parkour, horse (SkyrimNet already has mounted), running, sneaking, sitting, distant kills, vanilla HUD subtitles.

Does not command NPCs. Context only. No DirectNarration. No LLM actions.

## After updating

Load a save (the quest form is new so it starts itself).  
If Events still stay empty, open the console once:

```
startquest SkyrimNet_AwarenessBridgeQuest
```
