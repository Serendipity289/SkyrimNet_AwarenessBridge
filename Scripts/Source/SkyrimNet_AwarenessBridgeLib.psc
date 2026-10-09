Scriptname SkyrimNet_AwarenessBridgeLib Hidden
{Decorator helpers. Quest form 0xB00 in SkyrimNet_AwarenessBridge.esp.}

SkyrimNet_AwarenessBridge Function Q() Global
    return Game.GetFormFromFile(0xB00, "SkyrimNet_AwarenessBridge.esp") as SkyrimNet_AwarenessBridge
EndFunction

string Function GetAwarenessReaction(Actor akActor) Global
    SkyrimNet_AwarenessBridge bridge = Q()
    if !bridge
        return "{}"
    endif
    return bridge.ReactionJson(akActor)
EndFunction

bool Function BundleUp_IsEligible(Actor akActor, string contextJson, string paramsJson) Global
    SkyrimNet_AwarenessBridge bridge = Q()
    if !bridge
        return false
    endif
    return bridge.BundleUpEligible(akActor)
EndFunction

Function BundleUp_Execute(Actor akActor, string contextJson, string paramsJson) Global
    SkyrimNet_AwarenessBridge bridge = Q()
    if bridge
        bridge.BundleUpExecute(akActor)
    endif
EndFunction

bool Function Unbundle_IsEligible(Actor akActor, string contextJson, string paramsJson) Global
    SkyrimNet_AwarenessBridge bridge = Q()
    if !bridge
        return false
    endif
    return bridge.UnbundleEligible(akActor)
EndFunction

Function Unbundle_Execute(Actor akActor, string contextJson, string paramsJson) Global
    SkyrimNet_AwarenessBridge bridge = Q()
    if bridge
        bridge.UnbundleExecute(akActor)
    endif
EndFunction
