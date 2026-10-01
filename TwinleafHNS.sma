#include < amxmodx > 
#include < fakemeta > 
#include < json >
#include < cstrike >
#include <engine>
#include <hamsandwich>
#include <xs>
#include <fakemeta_util>
#include <fun>
#include <reapi>

new NotPretendModel[169][] = {"sprites/voiceicon.spr","models/w_kevlar.mdl","models/w_battery.mdl","models/w_antidote.mdl","models/w_security.mdl",
"models/w_longjump.mdl","models/w_assault.mdl","models/w_thighpack.mdl","models/v_awp.mdl","models/w_awp.mdl","models/rshell_big.mdl",
"models/w_9mmclip.mdl","models/v_g3sg1.mdl","models/w_g3sg1.mdl","models/rshell.mdl","models/v_ak47.mdl",
"models/w_ak47.mdl","models/v_scout.mdl","models/w_scout.mdl","models/v_m249.mdl","models/w_m249.mdl","models/v_m4a1.mdl",
"models/w_m4a1.mdl","models/v_sg552.mdl","models/w_sg552.mdl","models/v_aug.mdl","models/w_aug.mdl","models/v_sg550.mdl","models/w_sg550.mdl",
"models/v_m3.mdl","models/w_m3.mdl","models/shotgunshell.mdl","models/v_xm1014.mdl","models/w_xm1014.mdl","models/w_shotbox.mdl","models/v_usp.mdl",
"models/w_usp.mdl","models/shield/v_shield_usp.mdl","models/pshell.mdl","models/v_mac10.mdl","models/w_mac10.mdl","models/v_ump45.mdl",
"models/w_ump45.mdl","models/v_fiveseven.mdl","models/w_fiveseven.mdl","models/shield/v_shield_fiveseven.mdl","models/v_p90.mdl","models/w_p90.mdl",
"models/v_deagle.mdl","models/shield/v_shield_deagle.mdl","models/w_deagle.mdl","models/v_p228.mdl","models/w_p228.mdl","models/shield/v_shield_p228.mdl","models/v_knife.mdl",
"models/shield/v_shield_knife.mdl","models/w_knife.mdl","models/v_glock18.mdl","models/w_glock18.mdl","models/shield/v_shield_glock18.mdl",
"models/v_mp5.mdl","models/w_mp5.mdl","models/v_tmp.mdl","models/w_tmp.mdl","models/v_elite.mdl","models/w_elite.mdl","models/v_flashbang.mdl",
"models/shield/v_shield_flashbang.mdl","models/v_hegrenade.mdl","models/shield/v_shield_hegrenade.mdl","models/v_smokegrenade.mdl",
"models/shield/v_shield_smokegrenade.mdl","models/v_c4.mdl","models/w_backpack.mdl","models/v_galil.mdl","models/w_galil.mdl","models/v_famas.mdl",
"models/w_famas.mdl","models/w_weaponbox.mdl","sprites/zerogxplode.spr","sprites/WXplo1.spr","sprites/steam1.spr","sprites/bubble.spr",
"sprites/bloodspray.spr","sprites/blood.spr","sprites/smokepuff.spr","sprites/eexplo.spr","sprites/fexplo.spr","sprites/fexplo1.spr",
"sprites/radio.spr","sprites/b-tele1.spr","sprites/c-tele1.spr","sprites/ledglow.spr","sprites/laserbeam.spr","sprites/laserdot.spr",
"models/grenade.mdl","sprites/explode1.spr","models/player.mdl","models/player/leet/leet.mdl","models/player/gign/gign.mdl","models/player/vip/vip.mdl",
"models/player/gsg9/gsg9.mdl","models/player/guerilla/guerilla.mdl","models/player/arctic/arctic.mdl","models/player/sas/sas.mdl","models/player/terror/terror.mdl","models/player/urban/urban.mdl","models/p_ak47.mdl","models/p_aug.mdl","models/p_awp.mdl","models/p_c4.mdl","models/w_c4.mdl","models/p_deagle.mdl","models/shield/p_shield_deagle.mdl","models/p_flashbang.mdl","models/shield/p_shield_flashbang.mdl","models/p_hegrenade.mdl","models/shield/p_shield_hegrenade.mdl","models/p_glock18.mdl","models/shield/p_shield_glock18.mdl","models/p_p228.mdl","models/shield/p_shield_p228.mdl","models/p_smokegrenade.mdl","models/shield/p_shield_smokegrenade.mdl","models/p_usp.mdl","models/shield/p_shield_usp.mdl","models/p_fiveseven.mdl","models/shield/p_shield_fiveseven.mdl","models/p_knife.mdl","models/shield/p_shield_knife.mdl","models/w_flashbang.mdl","models/w_hegrenade.mdl","models/p_sg550.mdl","models/p_g3sg1.mdl","models/p_m249.mdl","models/p_m3.mdl","models/p_m4a1.mdl","models/p_mac10.mdl","models/p_mp5.mdl","models/p_ump45.mdl","models/p_p90.mdl","models/p_scout.mdl","models/p_sg552.mdl","models/w_smokegrenade.mdl","models/p_tmp.mdl","models/p_elite.mdl","models/p_xm1014.mdl","models/p_galil.mdl","models/p_famas.mdl","models/p_shield.mdl","models/w_shield.mdl","sprites/shadow_circle.spr","sprites/wall_puff1.spr","sprites/wall_puff2.spr","sprites/wall_puff3.spr","sprites/wall_puff4.spr","sprites/black_smoke1.spr","sprites/black_smoke2.spr","sprites/black_smoke3.spr","sprites/black_smoke4.spr","sprites/gas_puff_01.spr","sprites/fast_wallpuff1.spr","sprites/pistol_smoke1.spr","sprites/pistol_smoke2.spr","sprites/rifle_smoke1.spr","sprites/rifle_smoke2.spr","sprites/rifle_smoke3.spr","models/hgibs.mdl","models/agibs.mdl"}

new const ITEM_CLASS[32] = "hns_item";

new Array:ArModel;
new mapmodel;
new GTempData[128];

enum _:PlayerProperty
{
    PP_EntID,
    PP_PlayerID,
    PP_CatchCount,
    PP_Catched[32],
    PP_Money,
    Float:PP_LockPosition[3],
    bool:PP_IsLocked,
}
new GameProperty[32][PlayerProperty];

new HiderCount = 0 , SeekerCount = 0;
new const c4[][]={"weapon_c4","func_bomb_target","info_bomb_target"};
public bool:IsEnd = false;

public plugin_init( ) 
{ 
	register_plugin( 
		.plugin_name = "Twinleaf 躲猫猫", 
		.version = "0.1", 
		.author = "Tredam" ) 

    register_clcmd("say hnsmenu" , "HNSMenu");
    register_think(ITEM_CLASS , "npc_think");
    RegisterHam(Ham_Killed , "info_target" , "ItemKilled");
    RegisterHam(Ham_Killed , "player" , "PlayerDeath");
    register_event("HLTV", "RoundStart", "a", "1=0", "2=0");
    RegisterHam(Ham_Spawn, "player", "fwHamPlayerSpawnPost", 1);
    for(new ent;ent < sizeof c4;++ent)
        remove_entity_name(c4[ent]);
    for (new i = -1;i != 0;i = find_ent_by_class(-1 , "func_bomb_target"))
    {
        remove_entity(i);
    }

	server_print( "[Model Precache] Map Entity Count: %i", mapmodel )
}

public plugin_precache( ) 
{ 
	ArModel = ArrayCreate( 64, 1 ) 
	register_forward( FM_PrecacheModel, "fw_PrecacheModel_Post", 1 ) 
}

public fw_PrecacheModel_Post( const Model[ ] )
{
    new bool:IsNotPretend = false;
	for(new i = 0; i < 169; i++ ) 
	{ 
        if (equal(Model , NotPretendModel[i]))
        {
            IsNotPretend = true;
            break;
        }
	}
    for (new i = 0;i < ArraySize( ArModel ); i++)
    {
		ArrayGetString( ArModel, i, GTempData, sizeof( GTempData ) ) 
		if( equal( GTempData, Model ) || strfind(Model , ".spr") != -1)
        {
            IsNotPretend = true;
            break; 
        } 
    }
	if( IsNotPretend == false)
    {
        mapmodel ++;
        ArrayPushString( ArModel, Model ) 
    } 
	return FMRES_IGNORED 
}

public client_putinserver(id)
{
    if (get_playersnum() == 2)
    {
        server_cmd("sv_restart 1");
    }
}

public client_disconnected(id)
{
    for (new i = 0;i < 32;i ++)
    {
        if (GameProperty[i][PP_PlayerID] == id)
        {
            PlayerDeath(id , id , 0);
        }
    }
}

public PlayerDeath(this, idattacker, shouldgib)
{
    for (new i = 0;i < 32;i ++)
    {
        if (this == GameProperty[i][PP_PlayerID] && GameProperty[i][PP_EntID] != -1)
        {
            remove_entity(GameProperty[i][PP_EntID]);
        }
    }
    new userName[32] , CSTeams:userTeam;
    get_user_name(this , userName , 32);
    userTeam = cs_get_user_team(this);
    if (userTeam == CS_TEAM_T)
    {
        HiderCount --;
        if (HiderCount <= 0)
        {
            ForceRoundEnd(CS_TEAM_CT);
        }
    }
    else if (userTeam == CS_TEAM_CT)
    {
        SeekerCount --;
        if (HiderCount <= 0)
        {
            ForceRoundEnd(CS_TEAM_T);
        }
    }
    client_print_color(0 , this , "^4[HNS]^3%s^1死了!现在场上存活(躲藏者:搜查者=%d:%d)" , userName , HiderCount , SeekerCount);
}

public ItemKilled(this, idattacker, shouldgib)
{
    new catchedID = -1;
    for (new i = 0;i < 32;i ++)
    {
        if (this == GameProperty[i][PP_EntID])
        {
            ExecuteHam(Ham_TakeDamage , GameProperty[i][PP_PlayerID] , idattacker, idattacker, 9999999.0, DMG_GENERIC);
            catchedID = GameProperty[i][PP_PlayerID];
        }
    }
    for (new i = 0;i < 32;i ++)
    {
        if (idattacker == GameProperty[i][PP_PlayerID])
        {
            if (catchedID != -1)
            {
                GameProperty[i][PP_Catched][PP_CatchCount] = catchedID;
                GameProperty[i][PP_CatchCount] ++;
                GameProperty[i][PP_Money] ++;

                new sname[32] , hname[32];
                get_user_name(idattacker , sname , 32);
                get_user_name(catchedID , hname , 32);
                client_print_color(0 , idattacker , "^4[HNS]^3%s^1抓住了^3%s^1!这是他抓到的第%d个人" , sname , hname , GameProperty[i][PP_CatchCount]);
            }
            break;
        }
    }
}

public HNSMenu(id)
{
    if (cs_get_user_team(id) == CS_TEAM_CT) return;
    new menu = menu_create("躲猫猫菜单" , "HNSMenuHandler");
    for (new i = 0;i < 32;i ++)
    {
        if (GameProperty[i][PP_PlayerID] == id)
        {
            if (GameProperty[i][PP_EntID] != -1)
            {
                menu_additem(menu , "锁定模型");
            }
            break;
        }
    }
    menu_display(id , menu);
}

public HNSMenuHandler(id, menu , item)
{
    if (item == 0)
    {
        for (new i = 0;i < 32;i ++)
        {
            if (id == GameProperty[i][PP_PlayerID])
            {
                if (GameProperty[i][PP_EntID] != -1)
                {
                    if (GameProperty[i][PP_IsLocked] == true)
                    {
                        set_pev(GameProperty[i][PP_PlayerID] , pev_origin , GameProperty[i][PP_LockPosition]);
                        set_pev(id, pev_movetype, MOVETYPE_WALK);
                        GameProperty[i][PP_IsLocked] = false;
                    }
                    else
                    {
                        GameProperty[i][PP_IsLocked] = true;
                        pev(id , pev_origin , GameProperty[i][PP_LockPosition]);
                        set_pev(id, pev_movetype, MOVETYPE_NOCLIP);
                        
                    }
                    if (entity_get_int(GameProperty[i][PP_EntID] , EV_INT_solid) == SOLID_SLIDEBOX)
                    {
                        entity_set_int(GameProperty[i][PP_EntID] , EV_INT_solid , SOLID_NOT);
                    }
                    else
                    {
                        entity_set_int(GameProperty[i][PP_EntID] , EV_INT_solid , SOLID_SLIDEBOX);
                    }
                    break;
                }
            }
            HNSMenu(id);
        }
    }
    menu_destroy(menu);
}

public SetPlayerDefault(id)
{
    for (new i = 0;i < 32;i ++)
    {
        if (id == GameProperty[i][PP_PlayerID])
        {
            set_pev(id, pev_movetype, MOVETYPE_WALK);
            GameProperty[i][PP_CatchCount] = 0;
            GameProperty[i][PP_IsLocked] = false;
            if (is_valid_ent(GameProperty[i][PP_EntID]) == true)
            {
                remove_entity(GameProperty[i][PP_EntID]);
            }
            GameProperty[i][PP_EntID] = -1;
            set_user_rendering(id , kRenderFxNone , 255 , 255 , 255 , kRenderNormal , 255);
            set_pev(id, pev_solid, SOLID_SLIDEBOX);
        }
    }
}

public PretendTo(id , path[])
{
    set_pev(id, pev_solid, SOLID_NOT);
    set_user_rendering(id , kRenderFxNone , 0 , 0 , 0 , kRenderTransAlpha , 0);
    for (new i = 0;i < 32;i ++)
    {
        if (id == GameProperty[i][PP_PlayerID])
        {
            if (GameProperty[i][PP_EntID] != -1)
            {
                remove_entity(GameProperty[i][PP_EntID]);
            }
            break;
        }
    }
    new ent = create_entity("info_target");
    if (ent <= 0)
    {
        return ent;
    }
    GameProperty[id][PP_EntID] = ent;
    GameProperty[id][PP_PlayerID] = id ;
    entity_set_float(ent , EV_FL_takedamage , DAMAGE_AIM);
    entity_set_float(ent , EV_FL_health , 100.0);
    entity_set_float(ent , EV_FL_gravity , 800.0);

    entity_set_string(ent , EV_SZ_classname , ITEM_CLASS);
    entity_set_model(ent , path);
    entity_set_int(ent , EV_INT_solid , SOLID_NOT);
    entity_set_int(ent , EV_INT_movetype , MOVETYPE_NOCLIP);
    new Float:maxs[3] = {32.0,32.0,32.0};
    new Float:mins[3] = {-32.0,-32.0,-32.0};
    entity_set_size(ent,mins,maxs);

    entity_set_float(ent,EV_FL_nextthink,halflife_time() + 0.01);
    drop_to_floor(ent);
}

public npc_think(iEnt)
{
    for (new i = 0;i < 32;i ++)
    {
        if (iEnt == GameProperty[i][PP_EntID] && GameProperty[i][PP_IsLocked] == false)
        {
            new Float:pos[3] , Float:ang[3] , Float:min[3];
            pev(GameProperty[i][PP_PlayerID] , pev_mins , min);
            pev(GameProperty[i][PP_PlayerID] , pev_origin , pos);
            pev(GameProperty[i][PP_PlayerID] , pev_angles , ang);
            ang[0] = 0.0 , min[0] = 0.0;
            xs_vec_add(pos , min , pos);
            set_pev(iEnt , pev_origin , pos);
            set_pev(iEnt , pev_angles , ang);
            break;
        }
    }
    set_pev(iEnt, pev_nextthink, get_gametime() + 0.01);
}

public fwHamPlayerSpawnPost(player)
{
    if (cs_get_user_team(player) == CS_TEAM_T)
    {
        fm_strip_user_weapons(player);
    }
}

public RoundStart()
{
    IsEnd = false;
    HiderCount = 0 , SeekerCount = 0;
    set_task(180.0 , "HiderWin" , 1008611);
    new Players[32];
    new PlayerCount = 0;
    get_players(Players , PlayerCount , "");
    for (new i = 0;i < PlayerCount;i ++)
    {
        new userID = Players[i];
        SetPlayerDefault(userID);
        new CSTeams:userTeam = cs_get_user_team(userID);
        if (userTeam == CS_TEAM_T)
        {
            HiderCount ++;
            new r = random_num(0 , mapmodel - 1);
            ArrayGetString( ArModel, r, GTempData, sizeof( GTempData ));
            PretendTo(userID , GTempData);
            client_print_color(userID , userID , "^4[HNS]^1你的物体是^3%s" , GTempData);
            
        }
        else if (userTeam == CS_TEAM_CT)
        {
            SeekerCount ++;
        }
    }
    client_print_color(0 , print_team_grey , "^4[HNS]^1回合开始!本局有^3%d^1个^4躲藏者^1和^3%d^1个^4搜查者。" , HiderCount , SeekerCount);
}

public HiderTaunt()
{
    new Players[32];
    new PlayerCount = 0;
    get_players(Players , PlayerCount , "ae" , "T");
    for (new i = 0;i < PlayerCount;i ++)
    {
        if (GameProperty[i][PP_PlayerID] == Players[i])
        {
            //GameProperty[i][PP_PlayerID]
        }
    }
}

public HiderWin()
{
    ForceRoundEnd(CS_TEAM_T);
}

new const MaxTop = 5;

public ForceRoundEnd(CSTeams:winner)
{
    if (task_exists(1008611) == true)
    {
        remove_task(1008611);
    }
    if (IsEnd == false)
    {
        IsEnd = true;
        if (winner == CS_TEAM_T)
        {
            rg_round_end(5.0 ,WINSTATUS_TERRORISTS , ROUND_TERRORISTS_WIN , "时间耗尽，躲藏者胜利！");
            client_print_color(0 , print_team_red , "^4[HNS]^3躲藏者^1胜利！" , HiderCount , SeekerCount);
        }
        else
        {
            rg_round_end(5.0 ,WINSTATUS_CTS , ROUND_CTS_WIN , "所有躲藏者都被抓住，搜查者胜利！");
            client_print_color(0 , print_team_red , "^4[HNS]^3搜查者^1胜利！" , HiderCount , SeekerCount);
        }
        /*
        new TopList[MaxTop];
        new TopCount = 0;
        for (new i = 0;i < 32;i ++)
        {

        }*/
    }
}

stock mdlsize(filename[],Float:vec[3]){
    new file = fopen(filename,"rb")
    
    if (!file)
    server_print("CANT OPEN %s", filename)
    
    fseek(file,160,SEEK_SET)
    new bboff
    fread(file,bboff,BLOCK_INT)
    fseek(file,bboff+8,SEEK_SET)
    new Float:size[6]
    fread_blocks(file,_:size,6,BLOCK_INT)
    fclose(file)
    vec[0]=size[3]-size[0]
    vec[1]=size[4]-size[1]
    vec[2]=size[5]-size[2]
}