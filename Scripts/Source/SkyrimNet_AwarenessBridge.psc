Scriptname SkyrimNet_AwarenessBridge extends Quest
{Nearby OStim plus engine facts. Unprompted comment + body on confirmed edges.}

float Property MaxDistance = 5000.0 Auto
float Property PulseSeconds = 10.0 Auto
float Property HugDistance = 250.0 Auto
float Property ReactCooldown = 45.0 Auto

Actor[] _lastActors
String[] _confirmedLoc
String[] _pendingLoc
int[] _pendingHits
String[] _idleLatch
float[] _lastX
float[] _lastY
float[] _lastZ
int[] _hasPos
Form[] _bundleItem
int _lastCount = 0
Spell _wadeWaistSpell
GlobalVariable _lootTrigger
Form _nffIgnoreToken
bool _arraysReady = false
bool _otrackerLoaded = false
bool _clamberLoaded = false
int _endedThread = -1
Actor[] _ostimBusy
int _ostimBusyCount = 0
float _lastReactTime = -1000.0
string _lastReactKey = ""
Actor _reactSpeaker
string _reactStance = ""
string _reactFact = ""
string _reactAction = ""

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
    ResolveNffToken()
    _otrackerLoaded = (Game.GetModByName("OTracker.esp") != 255)
    _clamberLoaded = (Game.GetModByName("evgCLAMBER.esp") != 255)
    _endedThread = -1
    RegisterForModEvent("ostim_thread_start", "OnOStimStart")
    RegisterForModEvent("ostim_thread_end", "OnOStimThreadEnd")
    if _otrackerLoaded
        RegisterForModEvent("otracker_thread_start", "OnOStimStart")
    endif
    RegisterForSingleUpdate(2.0)
    SkyrimNetApi.RegisterDecorator("get_awareness_reaction", "SkyrimNet_AwarenessBridgeLib", "GetAwarenessReaction")
    SkyrimNetApi.RegisterAction("Bundle_Up", "When cold, put on a hood, cloak, scarf, cape, poncho, gloves, or hood from your inventory.", \
        "SkyrimNet_AwarenessBridgeLib", "BundleUp_IsEligible", \
        "SkyrimNet_AwarenessBridgeLib", "BundleUp_Execute", \
        "", "PAPYRUS", \
        1, "")
    SkyrimNetApi.RegisterAction("Unbundle", "When warm, take off the warmth item from BundleUp.", \
        "SkyrimNet_AwarenessBridgeLib", "Unbundle_IsEligible", \
        "SkyrimNet_AwarenessBridgeLib", "Unbundle_Execute", \
        "", "PAPYRUS", \
        1, "")
    Debug.Trace("SkyrimNet_AwarenessBridge boot")
EndFunction

Function EnsureArrays()
    if !_arraysReady
        _lastActors = new Actor[16]
        _confirmedLoc = new String[16]
        _pendingLoc = new String[16]
        _pendingHits = new int[16]
        _idleLatch = new String[16]
        _ostimBusy = new Actor[16]
        _ostimBusyCount = 0
        _lastCount = 0
        _arraysReady = true
    endif
    if _lastX == none
        _lastX = new float[16]
        _lastY = new float[16]
        _lastZ = new float[16]
        _hasPos = new int[16]
        _bundleItem = new Form[16]
    endif
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

Function ResolveNffToken()
    if _nffIgnoreToken != none
        return
    endif
    _nffIgnoreToken = Game.GetFormFromFile(0x1CFC8D, "nwsFollowerFramework.esp")
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
    Actor originator = participants[0]
    string place = PlaceSuffix(originator, true)
    string nearby = NearbyLine(names, kind, ending, place)
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
    SendPersonalMoods(participants, kind, ending, ttl, place)
    if ending
        ClearOStimBusy()
    else
        MarkOStimBusy(participants)
        ReactToFact("ostim:" + threadID, nearby, "ostim", originator, target)
    endif
EndFunction

Function SendPersonalMoods(Actor[] participants, string kind, bool ending, int ttl, string place)
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
            string line = PersonalLine(me, other, kind, ending, place)
            SendInfo(line, me, other)
            SetLive("sn_ostim_a_" + me.GetFormID(), line, me, other, ttl)
        endif
        i += 1
    endwhile
EndFunction

string Function NearbyLine(string names, string kind, bool ending, string place)
    if ending
        if kind == "kiss"
            return names + " just shared a kiss" + place + "."
        elseif kind == "embrace"
            return names + " just shared a close embrace" + place + "."
        elseif kind == "cuddle"
            return names + " just finished cuddling" + place + "."
        elseif kind == "dance"
            return names + " just finished a close dance" + place + "."
        elseif kind == "tender"
            return names + " just shared a tender moment" + place + "."
        elseif kind == "heated"
            return names + " just finished a heated, intimate encounter" + place + "."
        endif
        return names + " just finished an intimate encounter" + place + "."
    endif
    if kind == "kiss"
        return names + " are sharing a kiss" + place + "."
    elseif kind == "embrace"
        return names + " are sharing a close embrace" + place + "."
    elseif kind == "cuddle"
        return names + " are cuddled close" + place + "."
    elseif kind == "dance"
        return names + " are dancing close" + place + "."
    elseif kind == "tender"
        return names + " are sharing a tender moment" + place + "."
    elseif kind == "heated"
        return names + " are sharing a heated, intimate encounter" + place + "."
    endif
    return names + " are sharing an intimate encounter" + place + "."
EndFunction

string Function PersonalLine(Actor me, Actor other, string kind, bool ending, string place)
    string a = me.GetDisplayName()
    string b = other.GetDisplayName()
    if ending
        if kind == "kiss"
            return a + " just shared a kiss with " + b + place + "."
        elseif kind == "embrace"
            return a + " just held " + b + " in a close embrace" + place + "."
        elseif kind == "cuddle"
            return a + " just cuddled close with " + b + place + "."
        elseif kind == "dance"
            return a + " just danced close with " + b + place + "."
        elseif kind == "tender"
            return a + " just shared a tender moment with " + b + place + "."
        elseif kind == "heated"
            return a + " just shared a heated, intimate moment with " + b + place + "."
        endif
        return a + " just shared a private moment with " + b + place + "."
    endif
    if kind == "kiss"
        return a + " is sharing a kiss with " + b + place + "."
    elseif kind == "embrace"
        return a + " is holding " + b + " in a close embrace" + place + "."
    elseif kind == "cuddle"
        return a + " is cuddled close with " + b + place + "."
    elseif kind == "dance"
        return a + " is dancing close with " + b + place + "."
    elseif kind == "tender"
        return a + " is sharing a tender moment with " + b + place + "."
    elseif kind == "heated"
        return a + " is in a heated, intimate moment with " + b + place + "."
    endif
    return a + " is close with " + b + " in a private moment" + place + "."
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

string Function LocomotionState(Actor npc, int slot)
    if npc.IsSwimming() || PO3_SKSEFunctions.IsActorUnderwater(npc)
        RememberPos(npc, slot)
        return "swimming"
    endif
    return SlopeState(npc, slot)
EndFunction

string Function SlopeFromAnim(string anim)
    if anim == ""
        return ""
    endif
    if AnimHas(anim, "steepDOWN") || AnimHas(anim, "fRDOWN") || AnimHas(anim, "mRDOWN") || AnimHas(anim, "fWDOWN") || AnimHas(anim, "mWDOWN")
        return "scrambling down a steep slope"
    endif
    if AnimHas(anim, "fRUP") || AnimHas(anim, "mRUP") || AnimHas(anim, "fWUP") || AnimHas(anim, "mWUP")
        return "climbing a steep slope"
    endif
    return ""
EndFunction

Function RememberPos(Actor npc, int slot)
    if slot < 0 || _lastX == none
        return
    endif
    RememberPosAt(slot, npc.GetPositionX(), npc.GetPositionY(), npc.GetPositionZ())
EndFunction

Function RememberPosAt(int slot, float x, float y, float z)
    _lastX[slot] = x
    _lastY[slot] = y
    _lastZ[slot] = z
    _hasPos[slot] = 1
EndFunction

string Function SlopeState(Actor npc, int slot)
    if !_clamberLoaded || slot < 0 || _lastX == none
        return ""
    endif
    if npc.IsOnMount()
        RememberPos(npc, slot)
        return ""
    endif
    string fromAnim = SlopeFromAnim(PO3_SKSEFunctions.GetActiveGamebryoAnimation(npc))
    float x = npc.GetPositionX()
    float y = npc.GetPositionY()
    float z = npc.GetPositionZ()
    string fromDelta = ""
    if _hasPos[slot] != 0
        float dx = x - _lastX[slot]
        float dy = y - _lastY[slot]
        float dz = z - _lastZ[slot]
        float horiz = Math.sqrt(dx * dx + dy * dy)
        if horiz >= 80.0 && horiz <= 6000.0
            float slope = dz / horiz
            if slope >= 0.35 && slope <= 2.0
                fromDelta = "climbing a steep slope"
            elseif slope <= -0.35 && slope >= -2.0
                fromDelta = "scrambling down a steep slope"
            endif
        endif
    endif
    RememberPosAt(slot, x, y, z)
    if fromAnim != ""
        return fromAnim
    endif
    return fromDelta
EndFunction

Function UpdateLocomotion(Actor npc)
    int slot = EnsureSlot(npc)
    if slot < 0
        return
    endif
    string loc = LocomotionState(npc, slot)
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
        ReactToFact("loc:" + npc.GetFormID() + ":" + loc, sentence, loc, npc, None)
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
        string prevIdle = _idleLatch[slot]
        _idleLatch[slot] = ""
        if prevIdle == "huddling in the cold"
            string sentence = npc.GetDisplayName() + " is no longer huddling in the cold."
            SendInfo(sentence, npc, None)
            SetLive("sn_idle_" + npc.GetFormID(), sentence, npc, None, LIVE_END_MS)
        endif
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
            ReactToFact("idle:hug", sentence, "hugging", npc, other)
        else
            string sentence = npc.GetDisplayName() + " is hugging someone."
            SendInfo(sentence, npc, None)
            SetLive(liveId, sentence, npc, None, LIVE_STATE_MS)
            ReactToFact("idle:hug", sentence, "hugging", npc, None)
        endif
        return
    endif
    string line = npc.GetDisplayName() + " is " + kind + "."
    SendInfo(line, npc, None)
    SetLive(liveId, line, npc, None, LIVE_STATE_MS)
    ReactToFact("idle:" + npc.GetFormID() + ":" + kind, line, kind, npc, None)
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
    if _lastX != none
        _lastX[slot] = 0.0
        _lastY[slot] = 0.0
        _lastZ[slot] = 0.0
        _hasPos[slot] = 0
        _bundleItem[slot] = none
    endif
    _lastCount += 1
    return slot
EndFunction

string Function LocationName(Actor a)
    if !a
        return ""
    endif
    Location loc = a.GetCurrentLocation()
    if loc
        string n = loc.GetName()
        if n != ""
            return n
        endif
    endif
    Cell c = a.GetParentCell()
    if c
        return c.GetName()
    endif
    return ""
EndFunction

string Function PlaceSuffix(Actor a, bool fallbackNearby)
    string n = LocationName(a)
    if n != ""
        return " at " + n
    endif
    if fallbackNearby
        return " nearby"
    endif
    return ""
EndFunction

Function MarkOStimBusy(Actor[] participants)
    EnsureArrays()
    _ostimBusyCount = 0
    int i = 0
    while i < participants.Length && _ostimBusyCount < 16
        if participants[i]
            _ostimBusy[_ostimBusyCount] = participants[i]
            _ostimBusyCount += 1
        endif
        i += 1
    endwhile
EndFunction

Function ClearOStimBusy()
    _ostimBusyCount = 0
EndFunction

bool Function IsOStimBusy(Actor a)
    if !a
        return false
    endif
    int i = 0
    while i < _ostimBusyCount
        if _ostimBusy[i] == a
            return true
        endif
        i += 1
    endwhile
    return false
EndFunction

Actor Function PickSpeaker(Actor originator)
    Actor player = Game.GetPlayer()
    if !player
        return none
    endif
    Actor[] teammates = PO3_SKSEFunctions.GetPlayerFollowers()
    if teammates == none
        return none
    endif
    Actor best = none
    float bestD = MaxDistance
    int i = 0
    while i < teammates.Length
        Actor n = teammates[i]
        if n && n != originator && n != player && !n.IsDead() && !IsOStimBusy(n)
            float d = n.GetDistance(player)
            if d < bestD
                best = n
                bestD = d
            endif
        endif
        i += 1
    endwhile
    return best
EndFunction

string Function StanceFor(string kind)
    if kind == "ostim" || kind == "heated"
        return "look_away"
    endif
    if kind == "injured" || kind == "exhausted" || kind == "clutching their head"
        return "help"
    endif
    if kind == "looting"
        return "comment"
    endif
    return "comment"
EndFunction

bool Function ShouldKeepFollow(Actor npc)
    if !npc
        return false
    endif
    Actor player = Game.GetPlayer()
    if player && npc == player
        return false
    endif
    if npc.IsOnMount()
        return true
    endif
    if SkyrimNetApi.HasPackage(npc, "FollowPlayer") != 0
        return true
    endif
    if npc.IsPlayerTeammate()
        return true
    endif
    Faction companion = Game.GetFormFromFile(0x084D1B, "Skyrim.esm") as Faction
    if companion && npc.IsInFaction(companion)
        return true
    endif
    ResolveNffToken()
    if _nffIgnoreToken && npc.GetItemCount(_nffIgnoreToken) > 0
        return true
    endif
    return false
EndFunction

bool Function IsFollowMutatingAction(string name)
    if name == ""
        return false
    endif
    if name == "Wait" || name == "WaitHere" || name == "WAITHERE" || name == "Sit" || name == "SIT"
        return true
    endif
    if name == "Follow" || name == "FOLLOW" || name == "AccompanyTarget" || name == "ACCOMPANYTARGET"
        return true
    endif
    if name == "StopAccompanying" || name == "STOPACCOMPANYING" || name == "PauseFollow" || name == "StopFollow" || name == "StartFollow"
        return true
    endif
    return false
EndFunction

string Function ActionFor(string kind, Actor speaker)
    if ShouldKeepFollow(speaker)
        return ""
    endif
    if kind == "eating" || kind == "dancing" || kind == "cheering"
        return FirstRegistered("Sit", "Wait", "")
    endif
    if kind == "climbing a steep slope" || kind == "scrambling down a steep slope"
        return ""
    endif
    if kind == "swimming" || kind == "wading waist-deep in water"
        return FirstRegistered("Wait", "Follow", "")
    endif
    return FirstRegistered("Wait", "Sit", "")
EndFunction

string Function FirstRegistered(string a, string b, string c)
    if a != "" && SkyrimNetApi.IsActionRegistered(a)
        return a
    endif
    if b != "" && SkyrimNetApi.IsActionRegistered(b)
        return b
    endif
    if c != "" && SkyrimNetApi.IsActionRegistered(c)
        return c
    endif
    return ""
EndFunction

Function ReactToFact(string factKey, string fact, string kind, Actor originator, Actor target)
    if factKey == "" || fact == ""
        return
    endif
    float now = Utility.GetCurrentRealTime()
    if factKey == _lastReactKey && (now - _lastReactTime) < ReactCooldown
        return
    endif
    Actor speaker = PickSpeaker(originator)
    if !speaker
        return
    endif
    _lastReactKey = factKey
    _lastReactTime = now
    _reactSpeaker = speaker
    _reactFact = fact
    _reactStance = StanceFor(kind)
    _reactAction = ActionFor(kind, speaker)
    if _reactAction != "" && !IsFollowMutatingAction(_reactAction)
        SkyrimNetApi.ExecuteAction(_reactAction, speaker, "{}")
    else
        _reactAction = ""
    endif
    SkyrimNetApi.DirectNarration("", speaker, Game.GetPlayer())
EndFunction

string Function ReactionJson(Actor akActor)
    if !akActor
        return "{}"
    endif
    bool keep = ShouldKeepFollow(akActor)
    bool reacting = (akActor == _reactSpeaker && _reactStance != "")
    if !keep && !reacting
        return "{}"
    endif
    string json = "{"
    if reacting
        json += "\"stance\":\"" + _reactStance + "\",\"fact\":\"" + _reactFact + "\",\"action\":\"" + _reactAction + "\""
        if keep
            json += ","
        endif
    endif
    if keep
        json += "\"keep_follow\":true"
    endif
    json += "}"
    return json
EndFunction

string Function LowerChar(string c)
    string upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    int idx = StringUtil.Find(upper, c)
    if idx < 0
        return c
    endif
    return StringUtil.GetNthChar("abcdefghijklmnopqrstuvwxyz", idx)
EndFunction

string Function LowerString(string s)
    string out = ""
    int n = StringUtil.GetLength(s)
    int i = 0
    while i < n
        out += LowerChar(StringUtil.GetNthChar(s, i))
        i += 1
    endwhile
    return out
EndFunction

bool Function WarmthText(string blob)
    string t = LowerString(blob)
    if StringUtil.Find(t, "fur") >= 0
        return true
    endif
    if StringUtil.Find(t, "hood") >= 0
        return true
    endif
    if StringUtil.Find(t, "cloak") >= 0
        return true
    endif
    if StringUtil.Find(t, "scarf") >= 0
        return true
    endif
    if StringUtil.Find(t, "cape") >= 0
        return true
    endif
    if StringUtil.Find(t, "poncho") >= 0
        return true
    endif
    if StringUtil.Find(t, "glove") >= 0
        return true
    endif
    if StringUtil.Find(t, "mittens") >= 0
        return true
    endif
    return false
EndFunction

bool Function IsWarmthItem(Form item)
    Armor arm = item as Armor
    if !arm
        return false
    endif
    if Math.LogicalAnd(arm.GetSlotMask(), 4) != 0
        return false
    endif
    return WarmthText(arm.GetName() + " " + PO3_SKSEFunctions.GetDescription(arm))
EndFunction

Form Function FindWarmthUnworn(Actor npc)
    Form[] items = PO3_SKSEFunctions.AddItemsOfTypeToArray(npc, 26, true, false, false)
    if items == none
        return none
    endif
    int i = 0
    while i < items.Length
        if IsWarmthItem(items[i])
            return items[i]
        endif
        i += 1
    endwhile
    return none
EndFunction

bool Function IsColdForBundle(Actor npc)
    if !npc || npc.IsInInterior()
        return false
    endif
    Weather w = Weather.GetCurrentWeather()
    if w && w.GetClassification() == 4
        return true
    endif
    return false
EndFunction

bool Function IsWarmForUnbundle(Actor npc)
    if !npc
        return false
    endif
    if npc.IsInInterior()
        return true
    endif
    Weather w = Weather.GetCurrentWeather()
    if !w
        return true
    endif
    return w.GetClassification() != 4
EndFunction

int Function BundleSlot(Actor npc)
    if !npc
        return -1
    endif
    return EnsureSlot(npc)
EndFunction

bool Function BundleUpEligible(Actor npc)
    if !npc || npc.IsDead()
        return false
    endif
    Actor player = Game.GetPlayer()
    if player && npc == player
        return false
    endif
    if IsOStimBusy(npc)
        return false
    endif
    if !IsColdForBundle(npc)
        return false
    endif
    int slot = BundleSlot(npc)
    if slot < 0
        return false
    endif
    Form worn = _bundleItem[slot]
    if worn && npc.IsEquipped(worn)
        return false
    endif
    if worn
        _bundleItem[slot] = none
    endif
    return FindWarmthUnworn(npc) != none
EndFunction

Function BundleUpExecute(Actor npc)
    if !npc || npc.IsDead()
        return
    endif
    int slot = BundleSlot(npc)
    if slot < 0
        return
    endif
    Form worn = _bundleItem[slot]
    if worn && npc.IsEquipped(worn)
        return
    endif
    Form item = FindWarmthUnworn(npc)
    if !item
        return
    endif
    npc.EquipItem(item, false, true)
    _bundleItem[slot] = item
    SendInfo(npc.GetDisplayName() + " puts on " + item.GetName() + ".", npc, None)
EndFunction

bool Function UnbundleEligible(Actor npc)
    if !npc || npc.IsDead()
        return false
    endif
    Actor player = Game.GetPlayer()
    if player && npc == player
        return false
    endif
    if !IsWarmForUnbundle(npc)
        return false
    endif
    int slot = BundleSlot(npc)
    if slot < 0
        return false
    endif
    Form worn = _bundleItem[slot]
    if !worn
        return false
    endif
    if !npc.IsEquipped(worn)
        _bundleItem[slot] = none
        return false
    endif
    return true
EndFunction

Function UnbundleExecute(Actor npc)
    if !npc
        return
    endif
    int slot = BundleSlot(npc)
    if slot < 0
        return
    endif
    Form worn = _bundleItem[slot]
    if worn && npc.IsEquipped(worn)
        npc.UnequipItem(worn, false, true)
        SendInfo(npc.GetDisplayName() + " takes off " + worn.GetName() + ".", npc, None)
    endif
    _bundleItem[slot] = none
EndFunction
