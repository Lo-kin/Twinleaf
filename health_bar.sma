#include < amxmodx >
#include < cstrike >
#include < fakemeta >
#include < hamsandwich >
#include < Twinleaf >

#define VERSION 		"3.0"

new const HEALTH_BAR_MODEL[ ] = "sprites/health.spr";

new g_playerBar[ 33 ], g_isAlive[ 33 ], CsTeams: g_playerTeam[ 33 ], g_playerBot[ 33 ], g_playerMaxHealth[ 33 ], g_showHB[ 33 ];
new pcvarBotSupport, pcvarShowMode, pcvarSpec, cvarSpec, cvarShowMode, cvarBotSupport;
new g_maxPlayers, fwShowMode, botRegistered, msg_SayText;
new g_botQuotaPointer;

new enable_plugin = false;

public plugin_init( ) 
{

	register_plugin( "Health Bar", VERSION, "Bboy Grun" );
	if (enable_plugin == true)
	{
		register_cvar( "Health_Bars", VERSION, FCVAR_SERVER | FCVAR_SPONLY );
		set_cvar_string( "Health_Bars", VERSION );

		
		register_event( "HLTV", "evNewRound", "a", "1=0", "2=0" );
		register_event( "DeathMsg", "evDeathMsg", "a" );
		register_event( "Health", "evHealth", "be" );
		
		RegisterHam( Ham_Spawn, "player", "fwHamSpawn", true );
		
		register_clcmd( "say hb", "hbHandle" );
		register_clcmd( "say /hb", "hbHandle" );
		
		pcvarShowMode = 		register_cvar( "health_ShowMode", "2" );
		pcvarBotSupport = 		register_cvar( "health_BotSupport", "1" );
		pcvarSpec = 			register_cvar( "health_ShowToSpectators", "1" );
		
		g_maxPlayers = get_maxplayers( );
		msg_SayText = get_user_msgid( "SayText" );
		g_botQuotaPointer = get_cvar_pointer( "bot_quota" );
		
		new playerBar, allocString = engfunc( EngFunc_AllocString, "env_sprite" );
		
		for( new id = 1; id <= g_maxPlayers; id ++ )
		{
			g_playerBar[ id ] = engfunc( EngFunc_CreateNamedEntity, allocString );
			
			playerBar = g_playerBar[ id ];
			
			if( pev_valid( playerBar ) )
			{
				set_pev( playerBar, pev_scale, 0.1 );
				engfunc( EngFunc_SetModel, playerBar, HEALTH_BAR_MODEL );
			}
		}
		
		evNewRound( );
	}
}

public plugin_init_bots( id )
{
	RegisterHamFromEntity( Ham_Spawn, id, "fwHamSpawn", 1 );
	fwHamSpawn( id );
}

public plugin_precache( )
{
	if (RemainModelSlot > 1)
	{
		precache_model( HEALTH_BAR_MODEL );
		enable_plugin = true;
	}
}

public client_putinserver( id )
{
	g_isAlive[ id ] = 0;
	g_playerTeam[ id ] = CS_TEAM_SPECTATOR;
	g_playerBot[ id ] = is_user_bot( id );
	g_playerMaxHealth[ id ] = 0;
	g_showHB[ id ] = true;
	
	if( cvarBotSupport && !botRegistered && g_playerBot[ id ] && g_botQuotaPointer )
	{
		set_task( 0.4, "plugin_init_bots", id );
		botRegistered = 1;
	}
}

public client_disconnect( id )
{
	g_isAlive[ id ] = 0;
	g_playerTeam[ id ] = CS_TEAM_UNASSIGNED;
	g_playerBot[ id ] = 0;
	g_playerMaxHealth[ id ] = 0;
	g_showHB[ id ] = false;
}

public hbHandle( id ) // [ ^4 = GREEN ] [ ^3 = Team Color ] [ ^1 = client con_color value ]
{
	g_showHB[ id ] = !g_showHB[ id ];
	
	message_begin( MSG_ONE_UNRELIABLE, msg_SayText, .player = id );
	write_byte( id );
	write_string
	( 
		g_showHB[ id ] ?
		"^4[ HEALTH BARS ]^3 Enabled for you^1 ! Write /hb to^4 disable^1 it"
		:
		"^4[ HEALTH BARS ]^3 Disabled for you^1 ! Write /hb to^4 enable^1 it" 
	);
	message_end( );
}

public fwAddToFullPack( es, e, ent, host, host_flags, player, p_set )
{
	if( !player && !g_playerBot[ host ] && ( g_isAlive[ host ] || cvarSpec ) && g_showHB[ host ] )
	{
		new user;
				
		for( user = g_maxPlayers; user > 0; -- user )
		{
			if( g_playerBar[ user ] == ent )
			{	
				if( user != host && g_isAlive[ user ] && ( !g_playerBot[ user ] || cvarBotSupport ) 
				&& ( cvarShowMode == 2 || g_playerTeam[ host ] == g_playerTeam[ user ] ) )
				{
					new Float: playerOrigin[ 3 ];
					pev( user, pev_origin, playerOrigin );
								
					playerOrigin[ 2 ] += 30.0;
							
					set_es( es, ES_Origin, playerOrigin );
				}
				else
				{
					set_es( es, ES_Effects, EF_NODRAW );
				}
				
				break;
			}
		}
	}
}

public fwHamSpawn( id )
{
	if( cvarShowMode && is_user_alive( id ) )
	{
		new Float: playerOrigin[ 3 ];
		pev( id, pev_origin, playerOrigin );
		
		g_isAlive[ id ] = 1;
		g_playerTeam[ id ] = cs_get_user_team( id );/*
		if (g_playerTeam[ id ] == CS_TEAM_T)
		{
			set_pev( g_playerBar[ id ], pev_rendercolor , Float:{255.0 , 0.0 , 0.0} );
		}
		else if (g_playerTeam[ id ] == CS_TEAM_CT)
		{
			set_pev( g_playerBar[ id ], pev_rendercolor , Float:{0.0 , 0.0 , 255.0} );
		}*/
		engfunc( EngFunc_SetOrigin, g_playerBar[ id ], playerOrigin );
		evHealth( id );
	}
}

public evDeathMsg( )
{
	new id = read_data( 2 );
	
	g_isAlive[ id ] = 0;
	g_playerTeam[ id ] = cs_get_user_team( id );
	g_playerMaxHealth[ id ] = 0;
}

public evHealth( id )
{
	new hp = get_user_health( id );
	
	if( g_playerMaxHealth[ id ] < hp )
	{
		g_playerMaxHealth[ id ] = hp;
		set_pev( g_playerBar[ id ], pev_frame, 99.0 );
	}
	else
	{
		set_pev( g_playerBar[ id ], pev_frame, 0.0 + ( ( ( hp - 1 ) * 100 ) / g_playerMaxHealth[ id ] ) );
	}
}

public evNewRound( )
{
	cvarShowMode = 		get_pcvar_num( pcvarShowMode );
	cvarSpec = 		get_pcvar_num( pcvarSpec );
	new valueBotSupport = 	get_pcvar_num( pcvarBotSupport );
	
	if( cvarShowMode > 0 )
	{
		if( !fwShowMode )
		{
			fwShowMode = register_forward( FM_AddToFullPack, "fwAddToFullPack", true );
			for( new id = 1; id <= g_maxPlayers; set_pev( g_playerBar[ id ++ ], pev_effects, 0 ) ) { }
		}
	}
	else
	{
		if( fwShowMode )
		{
			unregister_forward( FM_AddToFullPack, fwShowMode, true );
			fwShowMode = 0;
			for( new id = 1; id <= g_maxPlayers; set_pev( g_playerBar[ id ++ ], pev_effects, EF_NODRAW ) ) { }
		}
	}
	
	if( valueBotSupport && !botRegistered )
	{	
		for( new id = 1; id <= g_maxPlayers; id ++ )
		{
			if( g_playerBot[ id ] )
			{
				plugin_init_bots( id );
				botRegistered = 1;
				break;
			}
		}
	}
	
	cvarBotSupport = valueBotSupport;
}
