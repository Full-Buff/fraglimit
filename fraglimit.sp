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

// Core plugin variables
ConVar g_CvarFragLimit;
int g_PlayerFrags[MAXPLAYERS + 1];
int g_TeamFrags[4];
bool g_PluginEnabled;

// HUD related variables
Handle g_HudSync;
Handle g_HudUpdateTimer;
Handle g_CvarHudRedTeamColor[3];
Handle g_CvarHudBlueTeamColor[3];
Handle g_CvarHudTitleColor[3];
ConVar g_CvarHudEnabled;
ConVar g_CvarHudX;
ConVar g_CvarHudY;
ConVar g_CvarHudFadeEnabled;
ConVar g_CvarHudBlinkOnClose;

public void OnPluginStart()
{
	// Get the existing mp_fraglimit ConVar
	g_CvarFragLimit = FindConVar("mp_fraglimit");
	if (g_CvarFragLimit == null)
	{
		SetFailState("Failed to find mp_fraglimit ConVar!");
	}
	
	// Create HUD customization ConVars
	g_CvarHudEnabled = CreateConVar("sm_fraglimit_hud", "1", "Enable HUD display (0/1)", FCVAR_NOTIFY);
	g_CvarHudX = CreateConVar("sm_fraglimit_hud_x", "0.02", "X position for HUD (0.0-1.0)", FCVAR_NOTIFY);
	g_CvarHudY = CreateConVar("sm_fraglimit_hud_y", "0.02", "Y position for HUD (0.0-1.0)", FCVAR_NOTIFY);
	
	// Red team color
	g_CvarHudRedTeamColor[0] = CreateConVar("sm_fraglimit_hud_red_r", "255", "Red team Red color (0-255)", FCVAR_NOTIFY);
	g_CvarHudRedTeamColor[1] = CreateConVar("sm_fraglimit_hud_red_g", "64", "Red team Green color (0-255)", FCVAR_NOTIFY);
	g_CvarHudRedTeamColor[2] = CreateConVar("sm_fraglimit_hud_red_b", "64", "Red team Blue color (0-255)", FCVAR_NOTIFY);
	
	// Blue team color
	g_CvarHudBlueTeamColor[0] = CreateConVar("sm_fraglimit_hud_blue_r", "64", "Blue team Red color (0-255)", FCVAR_NOTIFY);
	g_CvarHudBlueTeamColor[1] = CreateConVar("sm_fraglimit_hud_blue_g", "64", "Blue team Green color (0-255)", FCVAR_NOTIFY);
	g_CvarHudBlueTeamColor[2] = CreateConVar("sm_fraglimit_hud_blue_b", "255", "Blue team Blue color (0-255)", FCVAR_NOTIFY);
	
	// Title color
	g_CvarHudTitleColor[0] = CreateConVar("sm_fraglimit_hud_title_r", "255", "Title Red color (0-255)", FCVAR_NOTIFY);
	g_CvarHudTitleColor[1] = CreateConVar("sm_fraglimit_hud_title_g", "255", "Title Green color (0-255)", FCVAR_NOTIFY);
	g_CvarHudTitleColor[2] = CreateConVar("sm_fraglimit_hud_title_b", "255", "Title Blue color (0-255)", FCVAR_NOTIFY);
	
	// Effects
	g_CvarHudFadeEnabled = CreateConVar("sm_fraglimit_hud_fade", "1", "Enable fade effect (0/1)", FCVAR_NOTIFY);
	g_CvarHudBlinkOnClose = CreateConVar("sm_fraglimit_hud_blink", "1", "Blink when close to limit (0/1)", FCVAR_NOTIFY);
	
	// Create HUD synchronizer
	g_HudSync = CreateHudSynchronizer();
	
	// Hook events
	HookEvent("player_death", OnPlayerDeathEvent);
	HookEvent("teamplay_round_start", OnRoundStart);
	HookEvent("teamplay_game_over", OnGameEnd);
	
	RegAdminCmd("sm_fragstatus", Command_FragStatus, ADMFLAG_GENERIC, "Shows current frag counts");
	
	AutoExecConfig(true, "fraglimit");
}

public void OnMapStart()
{
	ResetScores();
	g_PluginEnabled = true;
	
	// Start HUD update timer
	if (g_HudUpdateTimer != null)
	{
		KillTimer(g_HudUpdateTimer);
	}
	g_HudUpdateTimer = CreateTimer(1.0, Timer_UpdateHUD, _, TIMER_REPEAT);
}

public void OnMapEnd()
{
	g_PluginEnabled = false;
	if (g_HudUpdateTimer != null)
	{
		KillTimer(g_HudUpdateTimer);
		g_HudUpdateTimer = null;
	}
}

public Action Command_FragStatus(int client, int args)
{
    if (!g_PluginEnabled) return Plugin_Handled;
    
    ReplyToCommand(client, "[FragLimit] Current team scores:");
    ReplyToCommand(client, "Red Team: %d", g_TeamFrags[TFTeam_Red]);
    ReplyToCommand(client, "Blue Team: %d", g_TeamFrags[TFTeam_Blue]);
    ReplyToCommand(client, "Frag Limit: %d", GetConVarInt(g_CvarFragLimit));
    
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
    if (!g_PluginEnabled) return;
    
    int victim = GetClientOfUserId(GetEventInt(event, "userid"));
    int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    bool isSuicide = (victim == attacker || attacker == 0);
    
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
            GetCustomTeamName(attackerTeam, teamName, sizeof(teamName));
            
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

// Also need to add this if it's missing
stock void GetCustomTeamName(int team, char[] name, int maxlen)
{
    switch (team)
    {
        case TFTeam_Red:
            strcopy(name, maxlen, "Red");
        case TFTeam_Blue:
            strcopy(name, maxlen, "Blue");
        default:
            strcopy(name, maxlen, "Unknown");
    }
}

public Action Timer_UpdateHUD(Handle timer)
{
	if (!g_PluginEnabled || !g_CvarHudEnabled.BoolValue)
		return Plugin_Continue;
	
	UpdateHUDForAllPlayers();
	return Plugin_Continue;
}

void UpdateHUDForAllPlayers()
{
	if (g_HudSync == null)
		return;
	
	float x = g_CvarHudX.FloatValue;
	float y = g_CvarHudY.FloatValue;
	int fragLimit = g_CvarFragLimit.IntValue;
	bool shouldBlink = g_CvarHudBlinkOnClose.BoolValue;
	
	// Get colors
	int redColors[3], blueColors[3], titleColors[3];
	for (int i = 0; i < 3; i++)
	{
		redColors[i] = GetConVarInt(g_CvarHudRedTeamColor[i]);
		blueColors[i] = GetConVarInt(g_CvarHudBlueTeamColor[i]);
		titleColors[i] = GetConVarInt(g_CvarHudTitleColor[i]);
	}
	
	// Check if teams are close to limit
	bool redClose = (g_TeamFrags[TFTeam_Red] >= fragLimit - 5);
	bool blueClose = (g_TeamFrags[TFTeam_Blue] >= fragLimit - 5);
	
	// Calculate fade effect
	float fadeIn = g_CvarHudFadeEnabled.BoolValue ? 0.1 : 0.0;
	float fadeOut = g_CvarHudFadeEnabled.BoolValue ? 0.5 : 0.0;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i))
			continue;
		
		// Clear previous HUD
		ClearSyncHud(i, g_HudSync);
		
		// Show title
		SetHudTextParams(x, y, 1.1, titleColors[0], titleColors[1], titleColors[2], 255, 0, 0.0, fadeIn, fadeOut);
		ShowSyncHudText(i, g_HudSync, "Frag Limit: %d", fragLimit);
		
		// Show Red team score with blinking if close
		float redY = y + 0.025;
		if (shouldBlink && redClose)
		{
			float time = GetGameTime();
			if (RoundToFloor(time * 2.0) % 2 == 0)
			{
				SetHudTextParams(x, redY, 1.1, redColors[0], redColors[1], redColors[2], 255, 0, 0.0, fadeIn, fadeOut);
				ShowSyncHudText(i, g_HudSync, "Red Team: %d", g_TeamFrags[TFTeam_Red]);
			}
		}
		else
		{
			SetHudTextParams(x, redY, 1.1, redColors[0], redColors[1], redColors[2], 255, 0, 0.0, fadeIn, fadeOut);
			ShowSyncHudText(i, g_HudSync, "Red Team: %d", g_TeamFrags[TFTeam_Red]);
		}
		
		// Show Blue team score with blinking if close
		float blueY = y + 0.05;
		if (shouldBlink && blueClose)
		{
			float time = GetGameTime();
			if (RoundToFloor(time * 2.0) % 2 == 0)
			{
				SetHudTextParams(x, blueY, 1.1, blueColors[0], blueColors[1], blueColors[2], 255, 0, 0.0, fadeIn, fadeOut);
				ShowSyncHudText(i, g_HudSync, "Blue Team: %d", g_TeamFrags[TFTeam_Blue]);
			}
		}
		else
		{
			SetHudTextParams(x, blueY, 1.1, blueColors[0], blueColors[1], blueColors[2], 255, 0, 0.0, fadeIn, fadeOut);
			ShowSyncHudText(i, g_HudSync, "Blue Team: %d", g_TeamFrags[TFTeam_Blue]);
		}
	}
}

void DisplayTopPlayers()
{
    // Create arrays to store player info
    int playerIds[MAXPLAYERS+1];
    int playerScores[MAXPLAYERS+1];
    int playerCount = 0;
    
    // Collect valid players and their scores
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i))
        {
            playerIds[playerCount] = i;
            playerScores[playerCount] = g_PlayerFrags[i];
            playerCount++;
        }
    }
    
    // Simple bubble sort because trying to use ArrayList.Sort/CustomSort just doesnt compile '_'
    for (int i = 0; i < playerCount - 1; i++)
    {
        for (int j = 0; j < playerCount - i - 1; j++)
        {
            if (playerScores[j] < playerScores[j + 1])
            {
                // Swap scores
                int tempScore = playerScores[j];
                playerScores[j] = playerScores[j + 1];
                playerScores[j + 1] = tempScore;
                
                // Swap IDs
                int tempId = playerIds[j];
                playerIds[j] = playerIds[j + 1];
                playerIds[j + 1] = tempId;
            }
        }
    }
    
    PrintToChatAll("\x04[FragLimit]\x01 Top 5 Players this round:");
    
    int displayCount = playerCount > 5 ? 5 : playerCount;
    for (int i = 0; i < displayCount; i++)
    {
        char playerName[64];
        int playerId = playerIds[i];
        GetClientName(playerId, playerName, sizeof(playerName));
        
        int team = GetClientTeam(playerId);
        char teamColor[7];
        teamColor = team == TFTeam_Red ? "\x07FF4040" : "\x0799CCFF";
        
        PrintToChatAll("%d. %s%s\x01 - %d frags", i + 1, teamColor, playerName, playerScores[i]);
    }
}

// And update the sort function to match the correct signature
public int SortPlayersByFrags(int index1, int index2, Handle array, Handle hndl)
{
    ArrayList arrayList = view_as<ArrayList>(array);
    
    int[] player1 = new int[2];
    int[] player2 = new int[2];
    
    arrayList.GetArray(index1, player1, 2);
    arrayList.GetArray(index2, player2, 2);
    
    if (player1[1] > player2[1]) return -1;
    if (player1[1] < player2[1]) return 1;
    return 0;
}

// Modify your EndRound function to include the top players display
void EndRound(int winningTeam)
{
	// Display top players before ending the round
	DisplayTopPlayers();
	
	int gameRules = FindEntityByClassname(-1, "tf_gamerules");
	if (gameRules == -1)return;
	
	SetEntProp(gameRules, Prop_Send, "m_iWinningTeam", winningTeam);
	
	Event roundWin = CreateEvent("teamplay_round_win", true);
	if (roundWin != null)
	{
		roundWin.SetInt("team", winningTeam);
		roundWin.SetInt("winreason", view_as<int>(TFWinReason_PointLimit));
		roundWin.SetBool("full_round", true);
		roundWin.Fire();
	}
	
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