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

public Plugin myinfo =  {
	name = "FragLimit", 
	author = "Fuko.dev", 
	description = "Extends mp_fraglimit functionality to all game modes.", 
	version = "1.0", 
	url = ""
};

ConVar g_CvarFragLimit;
int g_PlayerFrags[MAXPLAYERS + 1];
int g_TeamFrags[4];
bool g_PluginEnabled;

public void OnPluginStart()
{
	// Get the existing mp_fraglimit ConVar
	g_CvarFragLimit = FindConVar("mp_fraglimit");
	if (g_CvarFragLimit == null)
	{
		SetFailState("Failed to find mp_fraglimit ConVar!");
	}
	
	HookEvent("player_death", OnPlayerDeathEvent);
	HookEvent("teamplay_round_start", OnRoundStart);
	HookEvent("teamplay_game_over", OnGameEnd);
	
	RegAdminCmd("sm_fragstatus", Command_FragStatus, ADMFLAG_GENERIC, "Shows current frag counts");
}

public void OnMapStart()
{
	ResetScores();
	g_PluginEnabled = true;
}

public void OnMapEnd()
{
	g_PluginEnabled = false;
}

public Action Command_FragStatus(int client, int args)
{
	if (!g_PluginEnabled)return Plugin_Handled;
	
	ReplyToCommand(client, "[FragLimit] Current team scores:");
	ReplyToCommand(client, "Red Team: %d", g_TeamFrags[TFTeam_Red]);
	ReplyToCommand(client, "Blue Team: %d", g_TeamFrags[TFTeam_Blue]);
	ReplyToCommand(client, "Frag Limit: %d", g_CvarFragLimit.IntValue);
	
	return Plugin_Handled;
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	ResetScores();
}

public void OnGameEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_PluginEnabled = false;
}

public void OnPlayerDeathEvent(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_PluginEnabled)return;
	
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	bool isSuicide = (victim == attacker || attacker == 0);
	
	// Need to test the below further before first launch. Not sure if it will give a kill count to 
	// whoever gets the kill credit when someone suicides by rocket damage or something else. 
	// It should, otherwise thatd be a way people can deny kills for the other team, as well as a way
	// they can get a health/ammo reset for free.
	
	// Only process valid kills (not suicides or world damage)
	if (!isSuicide && IsValidClient(attacker))
	{
		int attackerTeam = GetClientTeam(attacker);
		
		// Increment scores
		g_PlayerFrags[attacker]++;
		g_TeamFrags[attackerTeam]++;
		
		int fragLimit = GetConVarInt(g_CvarFragLimit);
		
		// Check if team reached the limit
		if (g_TeamFrags[attackerTeam] >= fragLimit)
		{
			char teamName[32];
			GetTeamName(attackerTeam, teamName, sizeof(teamName));
			
			PrintToChatAll("\x04[FragLimit]\x01 %s team has won with %d frags!", 
				teamName, g_TeamFrags[attackerTeam]);
			
			EndRound(attackerTeam);
		}
		// Notify when teams are close to winning
		else if (g_TeamFrags[attackerTeam] == fragLimit - 5)
		{
			PrintToChatAll("\x04[FragLimit]\x01 %s team needs 5 more frags to win!", 
				attackerTeam == TFTeam_Red ? "Red" : "Blue");
		}
	}
}

void ResetScores()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_PlayerFrags[i] = 0;
	}
	
	for (int i = 0; i < sizeof(g_TeamFrags); i++)
	{
		g_TeamFrags[i] = 0;
	}
}

void EndRound(int winningTeam)
{
	int gameRules = FindEntityByClassname(-1, "tf_gamerules");
	if (gameRules == -1)return;
	
	// Set winning team and force round end
	SetEntProp(gameRules, Prop_Send, "m_iWinningTeam", winningTeam);
	
	Event roundWin = CreateEvent("teamplay_round_win", true);
	if (roundWin != null)
	{
		roundWin.SetInt("team", winningTeam);
		roundWin.SetInt("winreason", view_as<int>(TFWinReason_PointLimit));
		roundWin.SetBool("full_round", true);
		roundWin.Fire();
	}
	
	// Force round restart
	CreateTimer(3.0, Timer_RestartRound);
}

public Action Timer_RestartRound(Handle timer)
{
	int gameRules = FindEntityByClassname(-1, "tf_gamerules");
	if (gameRules != -1)
	{
		SetEntProp(gameRules, Prop_Send, "m_bInSetup", true);
		CreateTimer(0.1, Timer_SetupEnd);
	}
	return Plugin_Stop;
}

public Action Timer_SetupEnd(Handle timer)
{
	int gameRules = FindEntityByClassname(-1, "tf_gamerules");
	if (gameRules != -1)
	{
		SetEntProp(gameRules, Prop_Send, "m_bInSetup", false);
	}
	return Plugin_Stop;
}

bool IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && 
		!IsFakeClient(client) && GetClientTeam(client) > 1);
} 