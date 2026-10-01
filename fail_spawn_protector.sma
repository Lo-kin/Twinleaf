// Uncomment 'AUTO_SPAWNCREATOR' if your want to enable auto spawn creator
#define AUTO_SPAWNCREATOR

#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#if defined AUTO_SPAWNCREATOR
#include <engine>
#endif

// Credit: https://forums.alliedmods.net/showpost.php?p=717994&postcount=2
#define PlayerHullSize(%1)  ((pev(%1, pev_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN)
#define PlayerNotMove 1994

enum Coord_e 
{ 
	Float:x, 
	Float:y, 
	Float:z 
}

new bool:g_bPlayerIdle[33]
new g_iPlayerPos[33][3]
new g_iStartDistance, g_iMaxAttempts

#if defined AUTO_SPAWNCREATOR
new bool:g_bServerReload, bool:g_bRemoveTerrorOriSpawn, bool:g_bRemoveCTOriSpawn

new g_sEntFile[256]
new g_iPlayers[32], g_iNum
new g_iNowTerrorSpawnNum, g_iNowCTSpawnNum
new g_iTerrorMaxSpawn, g_iCTMaxSpawn
#endif

public plugin_init() 
{
	register_plugin("Fail Spawns Protector", "1.2", "zmd94")
	
	#if defined AUTO_SPAWNCREATOR
	register_logevent("Fail_RoundStart", 2, "1=Round_Start")
	#endif
	RegisterHam(Ham_Spawn, "player", "Fail_PlayerSpawn_Pre")
	RegisterHam(Ham_Spawn, "player", "Fail_PlayerSpawn_Post", 1)
	RegisterHam(Ham_TakeDamage, "player", "Fail_PlayerDamage")
	
	g_iStartDistance = register_cvar("fw_StartDistance", "32") // First search distance for finding a free location in map
	g_iMaxAttempts = register_cvar("fw_MaxAttempts", "128") // How many times to search in an area for a free space 
	#if defined AUTO_SPAWNCREATOR
	g_iTerrorMaxSpawn = register_cvar("fw_TerrorMaxSpawn", "0") // Maximum Terror spawn entities | If you want to disable it, just add "0" value
	g_iCTMaxSpawn = register_cvar("fw_CTMaxSpawn", "32") // Maximum CT spawn entities | If you want to disable it, just add "0" value
	
	// Retrieve spawn entity
	SpawnPointCount()
	#endif
}

#if defined AUTO_SPAWNCREATOR
public plugin_precache()
{
	get_localinfo("amxx_configsdir", g_sEntFile, charsmax(g_sEntFile))
	
	new szMapName[32]
	get_mapname(szMapName, charsmax(szMapName))
	strtolower(szMapName)
	format(g_sEntFile, charsmax(g_sEntFile), "%s/fw_file", g_sEntFile)

	if(!dir_exists(g_sEntFile))
	{
		mkdir(g_sEntFile)
		format(g_sEntFile, charsmax(g_sEntFile), "%s/%s.ini", g_sEntFile, szMapName)
		return
	}
	
	format(g_sEntFile, charsmax(g_sEntFile), "%s/%s.ini", g_sEntFile, szMapName)
	server_print("[Fail Spawn Protector] Creating new file")
	
	new Ent, Var, NewSpawnEnt, IsSpawnExceedLimit
	new szData[256]
	new PlayerTeam[10], RequiredSpawnEnt[10], SpawnLimit[10], SaveOrigin[3][10], SaveAngles[3][10]
	new Float:Origin[3], Float:Angles[3]
	
	new iFile = fopen(g_sEntFile, "rt")
	if(!iFile)
		return
	
	while(!feof(iFile))
	{
		fgets(iFile, szData, charsmax(szData))
		trim(szData)
		if(!szData[0] || szData[0] == ';' || (szData[0] == '/' && szData[1] == '/'))
			continue
			
		parse(szData, PlayerTeam, 9, SpawnLimit, 9, RequiredSpawnEnt, 9, SaveOrigin[0], 9, SaveOrigin[1], 9, SaveOrigin[2], 9, SaveAngles[0], 9, SaveAngles[1], 9, SaveAngles[2], 9)
		
		NewSpawnEnt = str_to_num(RequiredSpawnEnt)
		IsSpawnExceedLimit = str_to_num(SpawnLimit)
		Origin[0] = str_to_float(SaveOrigin[0]); Origin[1] = str_to_float(SaveOrigin[1]); Origin[2] = str_to_float(SaveOrigin[2]);
		Angles[0] = str_to_float(SaveAngles[0]); Angles[1] = str_to_float(SaveAngles[1]); Angles[2] = str_to_float(SaveAngles[2]);

		if(equali(PlayerTeam,"T"))
		{
			if(IsSpawnExceedLimit)
			{
				g_bRemoveTerrorOriSpawn = true
			}
			
			for(Var = 1; Var <= NewSpawnEnt; Var++)
			{
				Ent = create_entity("info_player_deathmatch")
				engfunc(EngFunc_SetOrigin, Ent, Origin)
				set_pev(Ent, pev_angles, Angles)
				DispatchSpawn(Ent)
			}
		}
		else if(equali(PlayerTeam,"CT"))
		{
			if(IsSpawnExceedLimit)
			{
				g_bRemoveCTOriSpawn = true
			}
			
			for(Var = 1; Var <= NewSpawnEnt; Var++)
			{
				Ent = create_entity("info_player_start")
				engfunc(EngFunc_SetOrigin, Ent, Origin)
				set_pev(Ent, pev_angles, Angles)
				DispatchSpawn(Ent)
			}
		}
	}
	
	fclose(iFile)
	
	server_print("[Fail Spawn Protector] Deleting old file")
	delete_file(g_sEntFile)
}

// Execute after plugin_precache and before plugin_init
public pfn_keyvalue(entid)
{
	// Remove all original spawns
	new EntName[32], Key[32], Value[32]
	copy_keyvalue(EntName, charsmax(EntName), Key, charsmax(Key), Value, charsmax(Value))
		
	if(g_bRemoveCTOriSpawn && equal(EntName, "info_player_start"))
	{
		// Filter out custom spawns
		if(is_valid_ent(entid) && entity_get_int(entid,EV_INT_iuser1) != 1)
		{
			server_print("[Fail Spawn Protector] CT original spawn is remove")
			remove_entity(entid)
		}
	}
	
	if(g_bRemoveTerrorOriSpawn && equal(EntName, "info_player_deathmatch"))
	{
		// Filter out custom spawns
		if(is_valid_ent(entid) && entity_get_int(entid,EV_INT_iuser1) != 1)
		{
			server_print("[Fail Spawn Protector] Terror original spawn is remove")
			remove_entity(entid)
		}
	}
}

public SpawnPointCount()
{
	new Target = -1
	new TerrorEnts, CTEnts, SpawnExceedLimit
	new RequiredSpawnEnt
	
	new bool:Found
	new szData[256], PlayerTeam[32]
	new Float:EntityOrigin[3], Float:EntityAngles[3]
	
	new iFile = fopen(g_sEntFile, "a+")
	if(!iFile)
		return
	
	while((Target = find_ent_by_class(Target, "info_player_deathmatch")))
	{
		if(pev_valid(Target))
		{
			TerrorEnts = TerrorEnts + 1
			
			if(!Found)
			{
				pev(Target, pev_origin, EntityOrigin)
				pev(Target, pev_angles, EntityAngles)
				Found = true
			}
		}
	}
	
	new g_iTerrorSpawnNeed = get_pcvar_num(g_iTerrorMaxSpawn)
	if(get_pcvar_num(g_iTerrorMaxSpawn) && TerrorEnts != g_iTerrorSpawnNeed)
	{
		if(TerrorEnts < g_iTerrorSpawnNeed)
		{
			RequiredSpawnEnt = g_iTerrorSpawnNeed - TerrorEnts
			server_print("[Fail Spawn Protector] Required %d more Terror spawn entities!", RequiredSpawnEnt)
			SpawnExceedLimit = 0
		}
		else if(TerrorEnts > g_iTerrorSpawnNeed)
		{
			server_print("[Fail Spawn Protector] Required %d less Terror spawn entities!", TerrorEnts - g_iTerrorSpawnNeed)
			RequiredSpawnEnt = g_iTerrorSpawnNeed
			SpawnExceedLimit = 1
		}
		
		PlayerTeam = "T"
		formatex(szData, charsmax(szData), "%s %d %d %.1f %.1f %.1f %.1f %.1f %.1f^n", PlayerTeam, SpawnExceedLimit, RequiredSpawnEnt, EntityOrigin[0], EntityOrigin[1], EntityOrigin[2], 0, EntityAngles[1], 0)
		fputs(iFile, szData)
		
		server_print("[Fail Spawn Protector] Auto reload")
		g_bServerReload = true
	}
	
	Found = false
	while((Target = find_ent_by_class(Target, "info_player_start")))
	{
		if(pev_valid(Target))
		{
			CTEnts = CTEnts + 1
			
			if(!Found)
			{
				pev(Target, pev_origin, EntityOrigin)
				pev(Target, pev_angles, EntityAngles)
				Found = true
			}
		}
	}
	
	new g_iCTSpawnNeed = get_pcvar_num(g_iCTMaxSpawn)
	if(get_pcvar_num(g_iCTMaxSpawn) && CTEnts != g_iCTSpawnNeed)
	{
		if(CTEnts < g_iCTSpawnNeed)
		{
			RequiredSpawnEnt = g_iCTSpawnNeed - CTEnts
			server_print("Required %d more CT spawn entities!", RequiredSpawnEnt)
			SpawnExceedLimit = 0
		}
		else if(CTEnts > g_iCTSpawnNeed)
		{
			server_print("[Fail Spawn Protector] Required %d less CT spawn entities!", CTEnts - g_iCTSpawnNeed)
			RequiredSpawnEnt = g_iCTSpawnNeed
			SpawnExceedLimit = 1
		}
		
		PlayerTeam = "CT"
		formatex(szData, charsmax(szData), "%s %d %d %.1f %.1f %.1f %.1f %.1f %.1f^n", PlayerTeam, SpawnExceedLimit, RequiredSpawnEnt, EntityOrigin[0], EntityOrigin[1], EntityOrigin[2], 0, EntityAngles[1], 0)
		fputs(iFile, szData)
		
		server_print("[Fail Spawn Protector] Auto reload")
		g_bServerReload = true
	}
	
	fclose(iFile)
	server_print("[Fail Spawn Protector] CS Spawn Entity: %d || Terror Spawn Entity: %d", CTEnts, TerrorEnts)
	
	g_iNowTerrorSpawnNum = TerrorEnts
	g_iNowCTSpawnNum = CTEnts
	
	if(g_bServerReload)
	{
		server_print("[Fail Spawn Protector] Server is reloading")
		
		// Reload server?
		//server_cmd("reload")
	}
}

public Fail_RoundStart()
{
	ResetCTCount()
	ResetTerrorCount()
}

public ResetCTCount()
{
	new iRandPlayer
	get_players(g_iPlayers, g_iNum, "ae", "CT")
	
	// If alive CT is more than spawn points
	if(g_iNum > g_iNowCTSpawnNum)
	{
		// Find random player
		iRandPlayer = g_iPlayers[random(g_iNum)]
		
		RandomPlayer(iRandPlayer)
		
		// Inform player
		set_hudmessage(random_num(10,255), random(256), random(256), -1.0, 0.20, 1, 0.1, 3.0, 0.05, 0.05, -1)
		show_hudmessage(iRandPlayer, "CT limit is %d. Just wait for next round!", g_iNowCTSpawnNum)
		
		// Retrieve again until alive Terror is equal to spawn points and add delay to prevent error
		set_task(0.5, "ResetCTCount")
	}
}

public ResetTerrorCount()
{
	new iRandPlayer
	get_players(g_iPlayers, g_iNum, "ae", "TERRORIST")
	
	// If alive Terror is more than spawn points
	if(g_iNum > g_iNowTerrorSpawnNum)
	{
		// Find random player
		iRandPlayer = g_iPlayers[random(g_iNum)]
		
		RandomPlayer(iRandPlayer)
		
		// Inform player
		set_hudmessage(random_num(10,255), random(256), random(256), -1.0, 0.20, 1, 0.1, 3.0, 0.05, 0.05, -1)
		show_hudmessage(iRandPlayer, "Terrorist limit is %d. Just wait for next round!", g_iNowTerrorSpawnNum)
		
		// Retrieve again until alive Terror is equal to spawn points and add delay to prevent error
		set_task(0.5, "ResetTerrorCount")
	}
}

RandomPlayer(iRandPlayer)
{
	// Kill player
	user_kill(iRandPlayer, 1)
	
	// Reset function
	remove_task(iRandPlayer+PlayerNotMove)
	g_bPlayerIdle[iRandPlayer] = false
}
#endif

public Fail_PlayerSpawn_Pre(id) 
{
	g_bPlayerIdle[id] = true
}

public Fail_PlayerSpawn_Post(id) 
{
	if(is_user_alive(id)) 
	{
		if(is_player_trap(id))
		{
			New_Spawn_Location(id, get_pcvar_num(g_iStartDistance), get_pcvar_num(g_iMaxAttempts))
		}
		else
		{
			get_user_origin(id, g_iPlayerPos[id])
			set_task(2.0, "PlayerPosition", id+PlayerNotMove, _, _, "b")
		}
	}
}

// Credit to xPaw: https://forums.alliedmods.net/showthread.php?t=114857
public Fail_PlayerDamage(id, iInflictor, iAttacker, Float:flDamage, iDamageBits)
{
	return (g_bPlayerIdle[id] && iDamageBits == DMG_GENERIC && iAttacker == 0 && flDamage == 200.0) ? HAM_SUPERCEDE : HAM_IGNORED
}

New_Spawn_Location(id, i_StartDistance, i_MaxAttempts)
{
	// If the player is not alive
	if(!is_user_alive(id))  
		return -1

	new Float:vf_OriginalOrigin[Coord_e], Float:vf_NewOrigin[Coord_e]
	new i_Attempts, i_Distance;

	// This is to get the current player's origin
	pev(id, pev_origin, vf_OriginalOrigin)
	
	i_Distance = i_StartDistance

	while(i_Distance < 1000)
	{
		i_Attempts = i_MaxAttempts
		
		while(i_Attempts--)
		{
			vf_NewOrigin[x] = random_float(vf_OriginalOrigin[x] - i_Distance, vf_OriginalOrigin[x] + i_Distance)
			vf_NewOrigin[y] = random_float(vf_OriginalOrigin[y] - i_Distance, vf_OriginalOrigin[y] + i_Distance)
			vf_NewOrigin[z] = random_float(vf_OriginalOrigin[z] - i_Distance, vf_OriginalOrigin[z] + i_Distance)
			
			engfunc(EngFunc_TraceHull, vf_NewOrigin, vf_NewOrigin, DONT_IGNORE_MONSTERS, PlayerHullSize(id), id, 0)
			
			// Free space found
			if(get_tr2(0, TR_InOpen) && !get_tr2 (0, TR_AllSolid) && !get_tr2(0, TR_StartSolid))
			{
				// Set the new origin 
				engfunc(EngFunc_SetOrigin, id, vf_NewOrigin)
				return 1
			}
		}
		
		i_Distance += i_StartDistance
	}

	// Could not be found
	return 0
}

public PlayerPosition(id)
{
	id -= PlayerNotMove
	if(is_user_alive(id))
	{
		new g_iOrigin[3]
		get_user_origin(id, g_iOrigin)
		
		if(g_iOrigin[0] != g_iPlayerPos[id][0] && g_iOrigin[1] != g_iPlayerPos[id][1] && g_iOrigin[2] != g_iPlayerPos[id][2]) 
		{
			remove_task(id+PlayerNotMove)
			g_bPlayerIdle[id] = false
		}
	}
}

// If a space is vacant? Credits to VEN
stock is_player_trap(id)
{
	static Float:f_CurrentOrigin[3]
	pev(id, pev_origin, f_CurrentOrigin)
	
	engfunc(EngFunc_TraceHull, f_CurrentOrigin, f_CurrentOrigin, 0, PlayerHullSize(id), id, 0)
	
	if (get_tr2(0, TR_StartSolid) || get_tr2(0, TR_AllSolid) || !get_tr2(0, TR_InOpen))
		return true
	
	return false
}