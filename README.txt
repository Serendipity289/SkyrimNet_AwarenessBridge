SkyrimNet Immersive Reactions 1.1.0
===================================
Separate line from SkyrimNet_AwarenessBridge (context-only).
Nearby companions speak about what they just noticed. Followers keep following.
Same ESP filename: do not install this and the original together.

Start-game-enabled quest with a player alias so it reboots after save load.
No world objects. No Creation Kit required. Does not install OStimNet.

Install this folder as a Vortex mod (ESP + Scripts + SKSE\Plugins\SkyrimNet\external) and Deploy.
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
  - Dynamic Looting and Harvesting Animations (Nexus 114547)
  - EVG CLAMBER - Slope Animations (Nexus 114753; steep terrain facts)
  - Extra OStim animation packs (richer mood names/tags)
  - SeverActions (Wait / Sit / Follow become the body beat)

Not required: SkyUI, OStimNet, CHIM, a sequences pack.

What it sends to SkyrimNet (Events, still recorded):

OStim, nearby only (same cell or within 5000 units)
  - start/end nearby line, plus one personal line per involved NPC
  - Names, mood (kiss, embrace, cuddle, dance, tender, heated), and
    location (e.g. "at The Bannered Mare"). Falls back to "nearby"
    when the cell has no name.
  End is ostim_thread_end only. OTracker is used to recover the actor list.

Player and followers, checked every 10 seconds
  Engine facts (same ones that fire the animation packs):
  - Swimming: IsSwimming / underwater
  - Wading: in water, not swimming (Wade In Water / EVG wade)
  - Injured / exhausted / clutching their head: EVG health/stamina/magicka thresholds
  - Cold / shield-in-rain: EVG weather facts
  - Looting: LootingAnimations LA_AnimTrigger (player)
  - Hug / eat / dance / cheer from active animation names
    e.g. "Lydia and the Dragonborn are hugging."
    OStim scenes are not also reported as hugs.
  - Steep terrain (EVG Clamber): climbing a steep slope / scrambling down a steep slope

Papyrus actions NPCs may choose
  - Bundle_Up: when cold/snow outdoors, equip one non-torso warmth piece
    (name or description has fur, hood, cloak, scarf, cape, poncho, glove, mittens)
  - Unbundle: when warm (indoors or not snow), take off the piece Bundle_Up put on

Unprompted reaction (comment you can hear)
  On each confirmed start (not every 10s of the same swim):
  - Nearest follower who is not in the OStim scene gets a speaking turn
    (empty DirectNarration to the player). Stance is comment / help / look_away.
  - Followers never get WaitHere / StopAccompanying / AccompanyTarget / Wait /
    Sit / Follow from this plugin. Custom NFF-tokened companions, mounted NPCs,
    teammates, and anyone with SkyrimNet FollowPlayer keep following.
  - 0751 also forbids those ACTION names on every keep-follow speaker turn,
    including dialogue that is not an AwarenessBridge reaction.
  - Same fact will not fire again for 45 seconds.
  - OStim participants still get Event lines (names, mood, location).
    They do not get this extra speaking turn. Observers may.

Not sent: horse (SkyrimNet already has mounted), running, sneaking,
sitting, distant kills, vanilla HUD subtitles.

Jev (typesafe/jev-1.13) is the planned ranker for who/stance/action.
This build uses a fast Papyrus stand-in with the same closed stances;
a SKSE DLL can replace ChooseSpeaker / StanceFor / ActionFor later.

After updating, load a save (the quest form is new so it starts itself).
If Events still stay empty, open the console once:
  startquest SkyrimNet_AwarenessBridgeQuest
