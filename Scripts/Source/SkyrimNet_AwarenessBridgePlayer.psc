Scriptname SkyrimNet_AwarenessBridgePlayer extends ReferenceAlias
{Re-register awareness pulse after every save load.}

Event OnInit()
    SkyrimNet_AwarenessBridge q = GetOwningQuest() as SkyrimNet_AwarenessBridge
    if q
        q.Boot()
    endif
EndEvent

Event OnPlayerLoadGame()
    SkyrimNet_AwarenessBridge q = GetOwningQuest() as SkyrimNet_AwarenessBridge
    if q
        q.Boot()
    endif
EndEvent
