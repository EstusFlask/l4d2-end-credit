#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define PLUGIN_VERSION "1.1.1"
#define MAP_CHANGER_LIBRARY "map_changer"
#define MAP_CHANGER_TIMING_CVAR "mapchanger_finale_change_type"
#define CHANGE_AFTER_CREDITS 8

ConVar g_cvMapChangerTiming;
bool g_bApplyingTiming;
bool g_bMapChangerLoaded;
bool g_bCreditsStarted;
bool g_bLobbyGuardHooked;
bool g_bLoggedLobbyBlock;
UserMsg g_umStatsCrawlMsg;
UserMsg g_umDisconnectToLobby;

public Plugin myinfo =
{
    name = "[L4D2] Keep End Credits (Map Changer compatibility)",
    author = "OpenAI Codex",
    description = "Makes map_changer v1.0.5 wait for the end-credit statistics before changing campaign.",
    version = PLUGIN_VERSION,
    url = ""
};

public void OnPluginStart()
{
    CreateConVar(
        "l4d2_keep_end_credits_version",
        PLUGIN_VERSION,
        "Keep End Credits plugin version.",
        FCVAR_NOTIFY | FCVAR_DONTRECORD
    );

    g_umStatsCrawlMsg = GetUserMessageId("StatsCrawlMsg");
    g_umDisconnectToLobby = GetUserMessageId("DisconnectToLobby");
    HookUserMessage(g_umStatsCrawlMsg, OnStatsCrawlMsg, false);

    g_bMapChangerLoaded = LibraryExists(MAP_CHANGER_LIBRARY);
    BindMapChangerCvar();
}

public void OnAllPluginsLoaded()
{
    g_bMapChangerLoaded = LibraryExists(MAP_CHANGER_LIBRARY);
    BindMapChangerCvar();
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, MAP_CHANGER_LIBRARY))
    {
        g_bMapChangerLoaded = true;
        // map_changer registers its library before creating its ConVars.
        RequestFrame(Frame_BindMapChangerCvar);
    }
}

public void OnLibraryRemoved(const char[] name)
{
    if (!StrEqual(name, MAP_CHANGER_LIBRARY))
    {
        return;
    }

    g_bMapChangerLoaded = false;
    ResetLobbyGuard();

    if (g_cvMapChangerTiming != null)
    {
        g_cvMapChangerTiming.RemoveChangeHook(OnMapChangerTimingChanged);
        g_cvMapChangerTiming = null;
    }
}

public void OnConfigsExecuted()
{
    BindMapChangerCvar();
}

public void OnMapStart()
{
    ResetLobbyGuard();
}

public void OnMapEnd()
{
    ResetLobbyGuard();
}

public void OnPluginEnd()
{
    if (g_cvMapChangerTiming != null)
    {
        g_cvMapChangerTiming.RemoveChangeHook(OnMapChangerTimingChanged);
    }

    UnhookUserMessage(g_umStatsCrawlMsg, OnStatsCrawlMsg, false);
    DisableLobbyGuard();
}

void Frame_BindMapChangerCvar(any data)
{
    BindMapChangerCvar();
}

void Frame_ApplyCreditsTiming(any data)
{
    ApplyCreditsTiming();
}

void Frame_EnableLobbyGuard(any data)
{
    if (!g_bCreditsStarted || g_bLobbyGuardHooked)
    {
        return;
    }

    // map_changer installs its own hook while handling StatsCrawlMsg. Waiting
    // one frame keeps its hook first, so it still selects and loads the next
    // map. This second hook remains active for any per-client duplicate
    // DisconnectToLobby messages that map_changer v1.0.5 no longer catches.
    HookUserMessage(g_umDisconnectToLobby, OnDisconnectToLobby, true);
    g_bLobbyGuardHooked = true;
}

void BindMapChangerCvar()
{
    if (!g_bMapChangerLoaded)
    {
        return;
    }

    ConVar cvar = FindConVar(MAP_CHANGER_TIMING_CVAR);
    if (cvar == null)
    {
        return;
    }

    if (g_cvMapChangerTiming != cvar)
    {
        if (g_cvMapChangerTiming != null)
        {
            g_cvMapChangerTiming.RemoveChangeHook(OnMapChangerTimingChanged);
        }

        g_cvMapChangerTiming = cvar;
        g_cvMapChangerTiming.AddChangeHook(OnMapChangerTimingChanged);
    }

    ApplyCreditsTiming();
}

void OnMapChangerTimingChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (!g_bApplyingTiming && StringToInt(newValue) != CHANGE_AFTER_CREDITS)
    {
        // Defer the correction so every listener sees one clean follow-up change.
        RequestFrame(Frame_ApplyCreditsTiming);
    }
}

void ApplyCreditsTiming()
{
    if (g_cvMapChangerTiming == null || g_bApplyingTiming)
    {
        return;
    }

    if (g_cvMapChangerTiming.IntValue == CHANGE_AFTER_CREDITS)
    {
        return;
    }

    g_bApplyingTiming = true;
    g_cvMapChangerTiming.IntValue = CHANGE_AFTER_CREDITS;
    g_bApplyingTiming = false;

    LogMessage(
        "Set %s to %d: the selected/automatic next map will load after the end credits finish.",
        MAP_CHANGER_TIMING_CVAR,
        CHANGE_AFTER_CREDITS
    );
}

Action OnStatsCrawlMsg(UserMsg msgId, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
    if (!g_bMapChangerLoaded
        || g_cvMapChangerTiming == null
        || !(g_cvMapChangerTiming.IntValue & CHANGE_AFTER_CREDITS))
    {
        return Plugin_Continue;
    }

    g_bCreditsStarted = true;
    g_bLoggedLobbyBlock = false;
    RequestFrame(Frame_EnableLobbyGuard);
    return Plugin_Continue;
}

Action OnDisconnectToLobby(UserMsg msgId, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
    if (!g_bCreditsStarted)
    {
        return Plugin_Continue;
    }

    if (!g_bLoggedLobbyBlock)
    {
        g_bLoggedLobbyBlock = true;
        LogMessage("Blocked duplicate DisconnectToLobby messages while map_changer loads the next campaign.");
    }

    return Plugin_Handled;
}

void ResetLobbyGuard()
{
    g_bCreditsStarted = false;
    g_bLoggedLobbyBlock = false;
    DisableLobbyGuard();
}

void DisableLobbyGuard()
{
    if (!g_bLobbyGuardHooked)
    {
        return;
    }

    UnhookUserMessage(g_umDisconnectToLobby, OnDisconnectToLobby, true);
    g_bLobbyGuardHooked = false;
}
