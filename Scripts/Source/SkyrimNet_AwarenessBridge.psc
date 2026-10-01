Scriptname SkyrimNet_AwarenessBridge extends Quest
{Nearby OStim plus engine facts. Context only. Reboots on save load. No parkour.}

float Property MaxDistance = 5000.0 Auto
float Property PulseSeconds = 10.0 Auto
float Property HugDistance = 250.0 Auto

Actor[] _lastActors
String[] _confirmedLoc
String[] _pendingLoc
int[] _pendingHits
String[] _idleLatch
int _lastCount = 0
Spell _wadeWaistSpell
GlobalVariable _lootTrigger
bool _arraysReady = false
bool _otrackerLoaded = false
int _endedThread = -1

int LIVE_SCENE_MS = 900000
int LIVE_END_MS = 60000
int LIVE_STATE_MS = 30000

Event OnInit()
    EnsureArrays()
    Boot()
EndEvent

Function Boot()
    EnsureArrays()
    UnregisterForAllModEvents()
    ResolveWadeSpell()
    ResolveLootTrigger()
    _otrackerLoaded = (Game.GetModByName("OTracker.esp") != 255)
    _endedThread = -1
    RegisterForModEvent("ostim_thread_start", "OnOStimStart")
    RegisterForModEvent("ostim_thread_end", "OnOStimThreadEnd")
    if _otrackerLoaded
        RegisterForModEvent("otracker_thread_start", "OnOStimStart")
    endif
    RegisterForSingleUpdate(2.0)
    Debug.Trace("SkyrimNet_AwarenessBridge boot")
EndFunction

Function EnsureArrays()
    if _arraysReady
        return
    endif
    _lastActors = new Actor[16]
    _confirmedLoc = new String[16]
    _pendingLoc = new String[16]
    _pendingHits = new int[16]
    _idleLatch = new String[16]
    _lastCount = 0
    _arraysReady = true
EndFunction

Function ResolveWadeSpell()
    if _wadeWaistSpell != none
        return
    endif
    _wadeWaistSpell = Game.GetFormFromFile(0xD65, "WadeInWater.esp") as Spell
    if _wadeWaistSpell == none
        _wadeWaistSpell = Game.GetFormFromFile(0xD65, "WadeInWaterRedone.esp") as Spell
    endif
EndFunction

Function ResolveLootTrigger()
    if _lootTrigger != none
        return
    endif
    _lootTrigger = Game.GetFormFromFile(0x801, "LootingAnimations.esp") as GlobalVariable
EndFunction

Function SendInfo(string content, Actor originator, Actor target)
    if content == ""
        return
    endif
    SkyrimNetApi.RegisterPersistentEvent(content, originator, target)
EndFunction

Function SetLive(string eventId, string content, Actor originator, Actor target, int ttlMs)
    if eventId == "" || content == ""
        return
    endif
    SkyrimNetApi.RegisterShortLivedEvent(eventId, "awareness", content, eventId, ttlMs, originator, target)
EndFunction

Function ClearLive(string eventId, Actor originator)
    if eventId == ""
        return
    endif
    SkyrimNetApi.RegisterShortLivedEvent(eventId, "awareness", "", eventId, 100, originator, None)
EndFunction

Event OnUpdate()
    RegisterForSingleUpdate(PulseSeconds)
    PulseActorStates()
EndEvent

Event OnOStimStart(string eventName, string strArg, float numArg, Form sender)
    int threadID = numArg as int
    if threadID == _endedThread
        _endedThread = -1
    endif
    Actor[] participants = OThread.GetActors(threadID)
    if participants.Length < 2 && _otrackerLoaded
        participants = OTrackerScript.GetActors(threadID, 0.0)
    endif
    if participants.Length < 2
        return
    endif
    if !ShouldSendAwareness(participants)
        return
    endif
    ReportOStimMoment(threadID, participants, "", false)
EndEvent

Event OnOStimThreadEnd(string eventName, string json, float numArg, Form sender)
    int threadID = numArg as int
    Actor[] participants = OJSON.GetActors(json)
    if participants.Length < 2 && _otrackerLoaded
        participants = OTrackerScript.GetActors(threadID, 0.0)
    endif
    if threadID == _endedThread
        return
    endif
    if participants.Length < 2
        return
    endif
    if !ShouldSendAwareness(participants)
        return
    endif
    ReportOStimMoment(threadID, participants, json, true)
    _endedThread = threadID
EndEvent

Function ReportOStimMoment(int threadID, Actor[] participants, string json, bool ending)
    string sceneId = ""
    if json != ""
        sceneId = OJSON.GetScene(json)
    endif
    if sceneId == ""
        sceneId = OThread.GetScene(threadID)
    endif
    if sceneId == "" && !ending
        Utility.Wait(0.3)
        sceneId = OThread.GetScene(threadID)
    endif
    string kind = MoodKind(sceneId)
    string names = BuildNamesString(participants)
    string nearby = NearbyLine(names, kind, ending)
    Actor originator = participants[0]
    Actor target = none
    if participants.Length > 1
        target = participants[1]
    endif
    int ttl = LIVE_SCENE_MS
    if ending
        ttl = LIVE_END_MS
    endif
    SendInfo(nearby, originator, target)
    SetLive("sn_ostim_" + threadID, nearby, originator, target, ttl)
    SendPersonalMoods(participants, kind, ending, ttl)
EndFunction

Function SendPersonalMoods(Actor[] participants, string kind, bool ending, int ttl)
    int i = 0
    while i < participants.Length
        Actor me = participants[i]
        Actor other = none
        if i == 0 && participants.Length > 1
            other = participants[1]
        elseif i > 0
            other = participants[0]
        endif
        if me && other
            string line = PersonalLine(me, other, kind, ending)
            SendInfo(line, me, other)
            SetLive("sn_ostim_a_" + me.GetFormID(), line, me, other, ttl)
        endif
        i += 1
    endwhile
EndFunction

string Function NearbyLine(string names, string kind, bool ending)
    if ending
        if kind == "kiss"
            return names + " just shared a kiss nearby."
        elseif kind == "embrace"
            return names + " just shared a close embrace nearby."
        elseif kind == "cuddle"
            return names + " just finished cuddling nearby."
        elseif kind == "dance"
            return names + " just finished a close dance nearby."
        elseif kind == "tender"
            return names + " just shared a tender moment nearby."
        elseif kind == "heated"
            return names + " just finished a heated, intimate encounter nearby."
        endif
        return names + " just finished an intimate encounter nearby."
    endif
    if kind == "kiss"
        return names + " are sharing a kiss nearby."
    elseif kind == "embrace"
        return names + " are sharing a close embrace nearby."
    elseif kind == "cuddle"
        return names + " are cuddled close nearby."
    elseif kind == "dance"
        return names + " are dancing close nearby."
    elseif kind == "tender"
        return names + " are sharing a tender moment nearby."
    elseif kind == "heated"
        return names + " are sharing a heated, intimate encounter nearby."
    endif
    return names + " are sharing an intimate encounter nearby."
EndFunction

string Function PersonalLine(Actor me, Actor other, string kind, bool ending)
    string a = me.GetDisplayName()
    string b = other.GetDisplayName()
    if ending
        if kind == "kiss"
            return a + " just shared a kiss with " + b + "."
        elseif kind == "embrace"
            return a + " just held " + b + " in a close embrace."
        elseif kind == "cuddle"
            return a + " just cuddled close with " + b + "."
        elseif kind == "dance"
            return a + " just danced close with " + b + "."
        elseif kind == "tender"
            return a + " just shared a tender moment with " + b + "."
        elseif kind == "heated"
            return a + " just shared a heated, intimate moment with " + b + "."
        endif
        return a + " just shared a private moment with " + b + "."
    endif
    if kind == "kiss"
        return a + " is sharing a kiss with " + b + "."
    elseif kind == "embrace"
        return a + " is holding " + b + " in a close embrace."
    elseif kind == "cuddle"
        return a + " is cuddled close with " + b + "."
    elseif kind == "dance"
        return a + " is dancing close with " + b + "."
    elseif kind == "tender"
        return a + " is sharing a tender moment with " + b + "."
    elseif kind == "heated"
        return a + " is in a heated, intimate moment with " + b + "."
    endif
    return a + " is close with " + b + " in a private moment."
EndFunction

string Function MoodKind(string sceneId)
    if sceneId == ""
        return ""
    endif
    string nm = OMetadata.GetName(sceneId)
    if nm != "" && StringUtil.Find(nm, "$") == 0
        nm = ""
    endif
    string blob = sceneId + nm
    bool noKiss = TextHas(blob, "NoKiss") || TextHas(blob, "nokiss")
    if OMetadata.HasSceneTag(sceneId, "kiss") || OMetadata.FindAction(sceneId, "kissing") >= 0 || (!noKiss && (TextHas(blob, "Kiss") || TextHas(blob, "kiss")))
        return "kiss"
    endif
    if OMetadata.HasSceneTag(sceneId, "dance") || OMetadata.FindAction(sceneId, "dancing") >= 0 || TextHas(blob, "Dance") || TextHas(blob, "dance")
        return "dance"
    endif
    if OMetadata.HasSceneTag(sceneId, "cuddle") || OMetadata.HasSceneTag(sceneId, "cuddling") || OMetadata.FindAction(sceneId, "cuddling") >= 0 || TextHas(blob, "Cuddle") || TextHas(blob, "cuddle")
        return "cuddle"
    endif
    if OMetadata.HasSceneTag(sceneId, "hug") || OMetadata.HasSceneTag(sceneId, "embrace") || OMetadata.FindAction(sceneId, "hug") >= 0 || TextHas(blob, "Hug") || TextHas(blob, "hug") || TextHas(blob, "Embrace") || TextHas(blob, "embrace")
        return "embrace"
    endif
    if OMetadata.HasSceneTag(sceneId, "aggressive") || OMetadata.HasSceneTag(sceneId, "rough")
        return "heated"
    endif
    if OMetadata.HasSceneTag(sceneId, "loving") || OMetadata.HasSceneTag(sceneId, "sensual") || OMetadata.HasSceneTag(sceneId, "romantic") || OMetadata.HasSceneTag(sceneId, "passionate") || OMetadata.HasSceneTag(sceneId, "sfw") || OMetadata.FindAction(sceneId, "holdinghand") >= 0
        return "tender"
    endif
    return ""
EndFunction

bool Function TextHas(string hay, string needle)
    return hay != "" && needle != "" && StringUtil.Find(hay, needle) >= 0
EndFunction

bool Function ShouldSendAwareness(Actor[] participants)
    Actor player = Game.GetPlayer()
    if !player
        return false
    endif
    int i = 0
    while i < participants.Length
        Actor a = participants[i]
        if a && (a.GetParentCell() == player.GetParentCell() || player.GetDistance(a) < MaxDistance)
            return true
        endif
        i += 1
    endwhile
    return false
EndFunction

string Function BuildNamesString(Actor[] actors)
    if actors.Length == 0
        return "Someone"
    endif
    string names = actors[0].GetDisplayName()
    int i = 1
    while i < actors.Length
        if i == actors.Length - 1 && actors.Length > 2
            names += ", and "
        elseif i > 0
            names += " and "
        endif
        names += actors[i].GetDisplayName()
        i += 1
    endwhile
    return names
EndFunction

Function PulseActorStates()
    ResolveWadeSpell()
    Actor player = Game.GetPlayer()
    if !player
        return
    endif

    Actor[] teammates = PO3_SKSEFunctions.GetPlayerFollowers()
    if teammates == none
        teammates = new Actor[1]
    endif

    UpdateLocomotion(player)
    UpdateOneShotIdle(player, teammates)

    int i = 0
    while i < teammates.Length
        Actor npc = teammates[i]
        if npc && npc != player && !npc.IsDead()
            UpdateLocomotion(npc)
            UpdateOneShotIdle(npc, teammates)
        endif
        i += 1
    endwhile
EndFunction

string Function LocomotionState(Actor npc)
    if npc.IsSwimming() || PO3_SKSEFunctions.IsActorUnderwater(npc)
        return "swimming"
    endif
    return ""
EndFunction

Function UpdateLocomotion(Actor npc)
    int slot = EnsureSlot(npc)
    if slot < 0
        return
    endif
    string loc = LocomotionState(npc)
    if loc == _pendingLoc[slot]
        _pendingHits[slot] = _pendingHits[slot] + 1
    else
        _pendingLoc[slot] = loc
        _pendingHits[slot] = 1
    endif
    if _pendingHits[slot] < 2
        return
    endif
    string prev = _confirmedLoc[slot]
    if loc == prev
        return
    endif
    _confirmedLoc[slot] = loc
    string liveId = "sn_loc_" + npc.GetFormID()
    if loc != ""
        string sentence = npc.GetDisplayName() + " is " + loc + "."
        SendInfo(sentence, npc, None)
        SetLive(liveId, sentence, npc, None, LIVE_STATE_MS)
    elseif prev != ""
        string sentence = npc.GetDisplayName() + " is no longer " + prev + "."
        SendInfo(sentence, npc, None)
        SetLive(liveId, sentence, npc, None, LIVE_END_MS)
    endif
EndFunction

Function UpdateOneShotIdle(Actor npc, Actor[] teammates)
    int slot = EnsureSlot(npc)
    if slot < 0
        return
    endif
    string kind = IdleKind(npc)
    if kind == ""
        _idleLatch[slot] = ""
        return
    endif
    if kind == _idleLatch[slot]
        return
    endif
    _idleLatch[slot] = kind
    string liveId = "sn_idle_" + npc.GetFormID()
    if kind == "hugging"
        Actor other = FindHugPartner(npc, teammates)
        if other
            string sentence = npc.GetDisplayName() + " and " + other.GetDisplayName() + " are hugging."
            SendInfo(sentence, npc, other)
            SetLive(liveId, sentence, npc, other, LIVE_STATE_MS)
        else
            string sentence = npc.GetDisplayName() + " is hugging someone."
            SendInfo(sentence, npc, None)
            SetLive(liveId, sentence, npc, None, LIVE_STATE_MS)
        endif
        return
    endif
    string line = npc.GetDisplayName() + " is " + kind + "."
    SendInfo(line, npc, None)
    SetLive(liveId, line, npc, None, LIVE_STATE_MS)
EndFunction

string Function IdleKind(Actor npc)
    bool inWater = PO3_SKSEFunctions.IsActorInWater(npc)
    bool wading = inWater && !npc.IsSwimming() && !PO3_SKSEFunctions.IsActorUnderwater(npc)
    if !wading && _wadeWaistSpell != none && npc.HasSpell(_wadeWaistSpell) && !npc.IsSwimming()
        wading = true
    endif
    if wading
        return "wading waist-deep in water"
    endif

    Actor player = Game.GetPlayer()
    if player && npc == player && _lootTrigger != none && _lootTrigger.GetValue() != 0.0
        return "looting"
    endif

    if npc.GetActorValuePercentage("Health") < 0.5
        return "injured"
    endif
    if npc.GetActorValuePercentage("Stamina") < 0.5
        return "exhausted"
    endif
    if npc.GetActorValuePercentage("Magicka") < 0.3
        return "clutching their head"
    endif

    if !npc.IsInInterior()
        Weather w = Weather.GetCurrentWeather()
        if w
            int cls = w.GetClassification()
            if cls == 4
                return "huddling in the cold"
            endif
            if cls == 3 && npc.GetEquippedShield() != none
                return "using a shield as cover from the rain"
            endif
        endif
    endif

    string anim = PO3_SKSEFunctions.GetActiveGamebryoAnimation(npc)
    if anim == ""
        return ""
    endif
    if AnimHas(anim, "ostim") || AnimHas(anim, "OStim")
        return ""
    endif
    if AnimHas(anim, "hug") || AnimHas(anim, "Hug") || AnimHas(anim, "embrace") || AnimHas(anim, "Embrace")
        return "hugging"
    endif
    if AnimHas(anim, "eat") || AnimHas(anim, "Eat") || AnimHas(anim, "soup") || AnimHas(anim, "Soup")
        return "eating"
    endif
    if AnimHas(anim, "dance") || AnimHas(anim, "Dance")
        return "dancing"
    endif
    if AnimHas(anim, "cheer") || AnimHas(anim, "Cheer") || AnimHas(anim, "applaud") || AnimHas(anim, "Applaud")
        return "cheering"
    endif
    return ""
EndFunction

bool Function AnimHas(string anim, string needle)
    return StringUtil.Find(anim, needle) >= 0
EndFunction

Actor Function FindHugPartner(Actor npc, Actor[] teammates)
    Actor player = Game.GetPlayer()
    Actor best = none
    float bestDist = HugDistance
    int i = 0
    while i < teammates.Length
        Actor other = teammates[i]
        if other && other != npc && !other.IsDead()
            float d = npc.GetDistance(other)
            if d < bestDist
                string kind = IdleKind(other)
                if kind == "hugging" || d < 120.0
                    best = other
                    bestDist = d
                endif
            endif
        endif
        i += 1
    endwhile
    if player && npc.GetDistance(player) < HugDistance
        if best == none || npc.GetDistance(player) <= bestDist
            best = player
        endif
    endif
    return best
EndFunction

int Function EnsureSlot(Actor npc)
    int i = 0
    while i < _lastCount
        if _lastActors[i] == npc
            return i
        endif
        i += 1
    endwhile
    if _lastCount >= 16
        return -1
    endif
    int slot = _lastCount
    _lastActors[slot] = npc
    _confirmedLoc[slot] = ""
    _pendingLoc[slot] = ""
    _pendingHits[slot] = 0
    _idleLatch[slot] = ""
    _lastCount += 1
    return slot
EndFunction
