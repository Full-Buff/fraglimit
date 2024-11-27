// FragLimit.sp

#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <tf2>

enum TFWinReason
{
    TFWinReason_Unused0 = 0,
    TFWinReason_AllPointsCaptured,
    TFWinReason_OpponentsDead,
    TFWinReason_TimeLimit,
    TFWinReason_PointLimit,
    TFWinReason_Other,
    TFWinReason_Stalemate,
    TFWinReason_DefendUntilTimeLimit,
    TFWinReason_EscortEnded,
    TFWinReason_ArenaRound,
    TFWinReason_CappedDuringOvertime,
    TFWinReason_RoundTimerExpired,
    TFWinReason_Victory,
    TFWinReason_Humiliation,
    TFWinReason_SuddenDeath,
    TFWinReason_PayloadPushed,
    TFWinReason_OtherTeamQuit,
    TFWinReason_ScoreReached,
    TFWinReason_Stalemate_SuddenDeath,
    TFWinReason_Stalemate_TimeExpired,
    TFWinReason_Koth,
    TFWinReason_CaptureTheFlag,
    TFWinReason_Passtime,
    TFWinReason_PasstimeOvertime
};


public Plugin myinfo = {
    name = "FragLimit",
    author = "Fuko",
    description = "Adds mp_fraglimit functionality to current gamemode.",
    version = "1.0",
    url = ""
};

Handle gCvarFragLimit;
int gPlayerFrags[MAXPLAYERS + 1];
int gTeamFrags[TFTeam_Blue + 1]; // Indices 0 to 3

public void OnPluginStart()
{
    // Create the mp_fraglimit ConVar https://wiki.alliedmods.net/ConVars_(SourceMod_Scripting)
    gCvarFragLimit = CreateConVar(
    					"dm_fraglimit", 
    					"5", 
    					"Frag limit for the server", 
    					_, 
    					false, 
    					0, 
    					true, 
    					1000); // Does this have some upper limit?? We will see. Maybe capped by a buffer size.

    // Hook the player_death event
    HookEvent("player_death", OnPlayerDeathEvent, EventHookMode_Post);

    // Reset team frags
    ResetTeamFrags();
}

public void OnMapStart()
{
    // Reset frags at the start of the map
    ResetPlayerFrags();
    ResetTeamFrags();
}

public void OnClientPutInServer(int client)
{
    // Initialize player frags when they join
    gPlayerFrags[client] = 0;
}

public void OnClientDisconnect(int client)
{
    // Reset frags when a player disconnects
    gPlayerFrags[client] = 0;
}

public void OnPlayerDeathEvent(Handle event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(GetEventInt(event, "userid"));
    int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

    // Check if the attacker is valid and not the same as the victim
    if (attacker > 0 && attacker != victim && IsClientInGame(attacker))
    {
        gPlayerFrags[attacker]++;
        int attackerTeam = GetClientTeam(attacker);

        // Increment team frags
        gTeamFrags[attackerTeam]++;

        int fragLimit = GetConVarInt(gCvarFragLimit);

        // Check if the team has reached the frag limit
        if (gTeamFrags[attackerTeam] >= fragLimit)
        {
            char sTeamName[32];
            GetCustomTeamName(attackerTeam, sTeamName, sizeof(sTeamName));
            PrintToChatAll("\x04[FragLimit]\x01 Team %s has reached the frag limit!", sTeamName);

            // End the round and declare the winner using the SZF method
            EndRound(attackerTeam);

            // Reset frags for the next round
            ResetPlayerFrags();
            ResetTeamFrags();
        }
    }
}

public void ResetPlayerFrags()
{
    // Reset all player frags
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            gPlayerFrags[i] = 0;
        }
    }
}

public void ResetTeamFrags()
{
    // Reset team frags
    gTeamFrags[TFTeam_Red] = 0;
    gTeamFrags[TFTeam_Blue] = 0;
    gTeamFrags[TFTeam_Unassigned] = 0;
}

public void GetCustomTeamName(int team, char[] name, int maxlen)
{
    // Define arrays of team IDs and team names
    int teamIDs[] = {TFTeam_Red, TFTeam_Blue};
    char teamNames[][] = {
        "Red",
        "Blue"
    };

    // Get the number of teams in the array
    int numTeams = sizeof(teamIDs);

    // Loop through the team IDs to find a match
    for (int i = 0; i < numTeams; i++)
    {
        if (team == teamIDs[i])
        {
            strcopy(name, maxlen, teamNames[i]);
            return;
        }
    }

    // If no match is found, set name to "Unknown"
    strcopy(name, maxlen, "Unknown");
}


public void EndRound(int winningTeam)
{
    // Get the tf_gamerules entity
    int gamerules = FindEntityByClassname(-1, "tf_gamerules");
    if (gamerules != -1)
    {
        // Set the winning team
        SetEntProp(gamerules, Prop_Send, "m_iWinningTeam", winningTeam);

        // Force map reset to end the round
        SetEntProp(gamerules, Prop_Send, "m_bForceMapReset", 1);

        // Fire the teamplay_round_win event
        Handle event = CreateEvent("teamplay_round_win");
        if (event != INVALID_HANDLE)
        {
            SetEventInt(event, "team", winningTeam);
            SetEventInt(event, "winreason", TFWinReason_TimeLimit); // Use a valid win reason
            SetEventInt(event, "flagcaplimit", 0);
            SetEventBool(event, "full_round", true);
            SetEventInt(event, "round_time", 0);
            FireEvent(event);
        }
    }
}
