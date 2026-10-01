SkyrimNet Awareness Bridge
==========================
Start-game-enabled quest with a player alias so it reboots after save load.
No world objects. No Creation Kit required. Does not install OStimNet.

Install this folder as a Vortex mod (ESP + Scripts\*.pex) and Deploy.
Enable SkyrimNet_AwarenessBridge.esp after SkyrimNet.esp and OStim.esp.

Required (tested Skyrim SE 1.6.1170)
  - SKSE64 matching the game version
  - Address Library for SKSE Plugins (Nexus 32444)
  - powerofthree's Papyrus Extender (Nexus 22854)
  - SkyrimNet Beta 25.1+ (github.com/MinLL/SkyrimNet-GamePlugin)
  - OStim Standalone 7.3.4+ (Nexus 98163; tested 7.5.1)
  - OTracker 2.0.1 (Nexus 108264)
  - PapyrusUtil SE (Nexus 13048; needed by OTracker 2.x)

Optional (missing only drops that fact)
  - Loki's Wade in Water (Nexus 42854) or Wade in Water Redone (Nexus 71418)
  - Looting Animations (Nexus 77377)
  - Extra OStim animation packs (richer mood names/tags)

Not required: SkyUI, OStimNet, CHIM, a sequences pack.

What it sends to SkyrimNet (RegisterPersistentEvent, no dialogue reaction):

OStim, nearby only (same cell or within 5000 units)
  - start/end nearby line, plus one personal line per involved NPC
  - Mood comes from the playing scene name/tags/actions (kiss, embrace,
    cuddle, dance, tender, heated). Default is a private/intimate moment.
  End is ostim_thread_end only. OTracker is used to recover the actor list.

Player and followers, checked every 10 seconds
  Engine facts (same ones that fire the animation packs):
  - Swimming: IsSwimming / underwater
  - Wading: in water, not swimming (Wade In Water / EVG wade)
  - Injured / exhausted / clutching their head: EVG health/stamina/magicka thresholds
  - Cold / shield-in-rain: EVG weather facts
  - Looting: LootingAnimations LA_AnimTrigger (player)
  - Hug / eat / dance / cheer from active animation names
    e.g. "Taliesin and Sarah Stormbringer are hugging."
    OStim scenes are not also reported as hugs.

Not sent: parkour, horse (SkyrimNet already has mounted), running, sneaking,
sitting, distant kills, vanilla HUD subtitles.

Does not command NPCs. Context only. No DirectNarration. No LLM actions.

After updating, load a save (the quest form is new so it starts itself).
If Events still stay empty, open the console once:
  startquest SkyrimNet_AwarenessBridgeQuest
