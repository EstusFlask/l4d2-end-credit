#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define PLUGIN_VERSION "1.0.0"
#define MAP_CHANGER_LIBRARY "map_changer"
#define MAP_CHANGER_TIMING_CVAR "mapchanger_finale_change_type"
#define CHANGE_AFTER_CREDITS 8

ConVar g_cvMapChangerTiming;
bool g_bApplyingTiming;

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

    BindMapChangerCvar();
}

public void OnAllPluginsLoaded()
{
    BindMapChangerCvar();
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, MAP_CHANGER_LIBRARY))
    {
        // map_changer registers its library before creating its ConVars.
        RequestFrame(Frame_BindMapChangerCvar);
    }
}

public void OnConfigsExecuted()
{
    BindMapChangerCvar();
}

public void OnPluginEnd()
{
    if (g_cvMapChangerTiming != null)
    {
        g_cvMapChangerTiming.RemoveChangeHook(OnMapChangerTimingChanged);
    }
}

void Frame_BindMapChangerCvar(any data)
{
    BindMapChangerCvar();
}

void Frame_ApplyCreditsTiming(any data)
{
    ApplyCreditsTiming();
}

void BindMapChangerCvar()
{
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
