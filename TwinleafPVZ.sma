#include <amxmodx>
#include <engine>
#include <hamsandwich>
#include <fakemeta>
#include <xs>
#include <pathfinder>
#include <fakemeta_util>
#include <Twinleaf>

#define Block_size 64
#define BlockStart_x 0
#define BlockStart_y 0
#define BlockCount_x 10
#define BlockCount_y 5

new g_iBeamSprite;

enum _:SoundGroup
{
    SG_WoodDmg,
    SG_WoodBuid,
    SG_ZombieBreathe,
    SG_ZombieAttack,
    SG_ZombieHurt,
    SG_PlayerBreath,
    SG_PlayerHurt,
    SG_WavePrepare,
    SG_WaveStart,
    SG_WaveEnd,
}
enum _:SoundList
{
    SL_Count,
    SL_List[128],
}
new SG_List[SoundGroup][SoundList] =
{
    {3 , {23 , 24 , 25  }},
    {2 , {2 , 3  }},
    {1 , {26 }},
    {3 , {8 , 9 , 10 }},
    {2 , {27 , 28 }},
    {2 , {11 , 12 }},
    {1 , {13 }},
    {1 , {17 }},
    {3 , {18 , 19 , 20 }},
    {3 , {14 , 15 , 16 }}
};
new SoundRootPath[64] = "Twinleaf/LeafGuard/";
new SoundStack[29][64] = 
{
    "bell.wav",
    "bell1.wav",
    "build_1.wav",
    "build_2.wav",
    "claw_miss1.wav",
    "claw_miss2.wav",
    "computalk2.wav",
    "game_start.wav",
    "zm_atk_1.wav",
    "zm_atk_2.wav",
    "zm_atk_3.wav",
    "player_idle_1.wav",
    "player_idle_2.wav",
    "player_low_hp.wav",
    "wave_end_1.wav",
    "wave_end_2.wav",
    "wave_end_3.wav",
    "wave_prepare.wav",
    "wave_start_1.wav",
    "wave_start_2.wav",
    "wave_start_3.wav",
    "win.wav",
    "wood_broken.wav",
    "wood_dmg_1.wav",
    "wood_dmg_2.wav",
    "wood_dmg_3.wav",
    "zm_breath.wav",
    "zm_hurt_1.wav",
    "zm_hurt_2.wav",
};
new SoundStackCount = 29;

enum _:BarrierInfo
{
    BI_EntID,
    BI_Num,
    Float:BI_MaxHealth,
    Float:BI_Health,
    bool:BI_IsBreak,
    Float:BI_Position[3],
}
new BI_Class[32] = "func_wall_toggle";
new BI_List[32][BarrierInfo];
new BI_Count = 0;

enum _:MonsterInfo
{
    MI_EntID,
    MI_Type,
    Float:MI_Health,
    Float:MI_Damage,
    Float:MI_Speed,
    Float:MI_AtkRange,
    Float:MI_LastAttackTime,
    Float:MI_AttackDuration,
    MI_TargetBarrier,
    MI_KillReward,
    bool:MI_IsAlive,
    Float:MI_CreateTime,
    MI_AliveTick,
    Array:MI_Path,
    MI_PathPointer,
    Float:MI_PathUpdateTime,
    Float:MI_PathUpdateDuration,
    MI_Target,
    MI_Attempt,
    MI_MaxAttempt,
    Float:MI_LastJump,
    Float:MI_JumpDuration,
}
new MonsterList[256][MonsterInfo];
new MonsterCount = 0;

enum _:MonsterType
{
    MT_Normal,
    MT_Speed,
    MT_Tank
}
new MT_List[MonsterType][MonsterInfo] = {
    {0 , 0 , 100.0 , 5.0 , 120.0 , 64.0 , 0.0 , 1.0 , -1 , 5 , true} ,
    {0 , 1 , 100.0 , 3.0 , 260.0 , 64.0 , 0.0 , 0.7 , -1 , 8 , true} ,
    {0 , 2 , 300.0 , 10.0 , 80.0 , 64.0 , 0.0 , 3.0 , -1 , 10 , true} ,
}
new MT_NameList[MonsterType][32] = {"Normal Zombie" , "Speed Zombie" , "Tank Zombie"};
new MT_ModelList[MonsterType][64] = {
    "models/player/gsg9/gsg9.mdl",
    "models/player/gsg9/gsg9.mdl",
    "models/player/gsg9/gsg9.mdl",
}

enum _:MonsterSpwanPoint
{
    MSP_EntID,
    Float:MSP_Position[3],
    MSP_SpwanCount,
    MSP_Target,
}
new MSP_Class[32] = "info_target";
new MSP_List[32][MonsterSpwanPoint];
new MSP_Count = 0;

enum _:EquipInfo
{
    EI_Cost,
    EI_Level,
    Float:EI_Damage,
}

enum _:PlayerInfo
{
    PI_ID,
    PI_Money,
    Float:PI_Speed,
    PI_Killed,
    PI_Equips[3],
    bool:PI_IsEmpty,
    Float:PI_RestoreDuration,
    Float:PI_LastRestoreTime,
    PI_RestoreCount
}
new PI_List[33][PlayerInfo];
new PI_Count = 0;

enum _:AttackWave
{
    Float:AW_WaitTime,
    //Float:AW_NextSpwanTimer,
    AW_CurrentSpwan,
    AW_SpwanTypeList[128],
    AW_SpwanCount,
}
new AW_List[64][AttackWave];
new AW_Count = 0;

enum _:TotalWave
{
    TW_Count,
    TW_Current,
    Float:TW_WaveGap,
    TW_Wave[64]
}
new TotalWaveInfo[TotalWave] = {30 , 0 , 30.0 , ...};

new PairZmsB[][2] = {{1 , 1} , {2 , 2} , {3 , 3} , {5 , 4} , {6 , 5} , {8 , 6} , {9 , 7} , {10 , 8} , {11 , 9} , {12 , 10} , {13 , 11} , {14 , 12}};

public plugin_init()
{
    register_plugin("Twinleaf LeafGuard",  "PluginVersion" , "PluginAuthor" , "PluginLink" , "");
    
    register_think("npc_zombie" , "npc_think");
    //RegisterHam(Ham_TakeDamage , "info_target" , "DmgZombie");
    RegisterHam(Ham_Killed , "info_target" , "KilledZombie");

    register_clcmd("say sl" , "showlist");
    register_clcmd("say start" , "SpwanWave");
    register_clcmd("say weapon" , "WeaponStore");
    register_clcmd("say killall" , "killallzm");
    register_forward(FM_TraceLine, "traceline_forward" , 1);
    set_task(0.1 , "ListenUserKey" , 1919810 , _ , _ ,"b");
    Init();
	set_task(0.1,"checkstuck",0,"",0,"b")
}

public killallzm(id)
{
    for (new i = 0;i < 256;i ++)
    {
        if (MonsterList[i][MI_IsAlive] == true)
        {
            if (is_valid_ent(MonsterList[i][MI_EntID]))
            {
                ExecuteHamB(Ham_TakeDamage, MonsterList[i][MI_EntID] , id, id, 999999, DMG_CLUB);
            }
            MonsterList[i][MI_IsAlive] = false;
            MonsterCount --;
        }
    }
}

new const Float:size[][3] = {
	{0.0, 0.0, 1.0}, {0.0, 0.0, -1.0}, {0.0, 1.0, 0.0}, {0.0, -1.0, 0.0}, {1.0, 0.0, 0.0}, {-1.0, 0.0, 0.0}, {-1.0, 1.0, 1.0}, {1.0, 1.0, 1.0}, {1.0, -1.0, 1.0}, {1.0, 1.0, -1.0}, {-1.0, -1.0, 1.0}, {1.0, -1.0, -1.0}, {-1.0, 1.0, -1.0}, {-1.0, -1.0, -1.0},
	{0.0, 0.0, 2.0}, {0.0, 0.0, -2.0}, {0.0, 2.0, 0.0}, {0.0, -2.0, 0.0}, {2.0, 0.0, 0.0}, {-2.0, 0.0, 0.0}, {-2.0, 2.0, 2.0}, {2.0, 2.0, 2.0}, {2.0, -2.0, 2.0}, {2.0, 2.0, -2.0}, {-2.0, -2.0, 2.0}, {2.0, -2.0, -2.0}, {-2.0, 2.0, -2.0}, {-2.0, -2.0, -2.0},
	{0.0, 0.0, 3.0}, {0.0, 0.0, -3.0}, {0.0, 3.0, 0.0}, {0.0, -3.0, 0.0}, {3.0, 0.0, 0.0}, {-3.0, 0.0, 0.0}, {-3.0, 3.0, 3.0}, {3.0, 3.0, 3.0}, {3.0, -3.0, 3.0}, {3.0, 3.0, -3.0}, {-3.0, -3.0, 3.0}, {3.0, -3.0, -3.0}, {-3.0, 3.0, -3.0}, {-3.0, -3.0, -3.0},
	{0.0, 0.0, 4.0}, {0.0, 0.0, -4.0}, {0.0, 4.0, 0.0}, {0.0, -4.0, 0.0}, {4.0, 0.0, 0.0}, {-4.0, 0.0, 0.0}, {-4.0, 4.0, 4.0}, {4.0, 4.0, 4.0}, {4.0, -4.0, 4.0}, {4.0, 4.0, -4.0}, {-4.0, -4.0, 4.0}, {4.0, -4.0, -4.0}, {-4.0, 4.0, -4.0}, {-4.0, -4.0, -4.0},
	{0.0, 0.0, 5.0}, {0.0, 0.0, -5.0}, {0.0, 5.0, 0.0}, {0.0, -5.0, 0.0}, {5.0, 0.0, 0.0}, {-5.0, 0.0, 0.0}, {-5.0, 5.0, 5.0}, {5.0, 5.0, 5.0}, {5.0, -5.0, 5.0}, {5.0, 5.0, -5.0}, {-5.0, -5.0, 5.0}, {5.0, -5.0, -5.0}, {-5.0, 5.0, -5.0}, {-5.0, -5.0, -5.0}
}
new stuck[256];
public checkstuck() 
{
    new monster
	static Float:origin[3]
	static Float:mins[3], hull
	static Float:vec[3]
	static o,i
	for(i=0; i< 256; i++)
    {
        monster = MonsterList[i][MI_EntID];
        if (is_valid_ent(monster) == false) continue;
		pev(monster, pev_origin, origin)
		hull = pev(monster, pev_flags) & FL_DUCKING ? HULL_HEAD : HULL_HUMAN
		if (!is_hull_vacant(origin, hull,monster) && !(pev(monster,pev_solid) & SOLID_NOT))
        {
			++stuck[monster]
			pev(monster, pev_mins, mins)
			vec[2] = origin[2]
			for (o=0; o < sizeof size; ++o) {
				vec[0] = origin[0] - mins[0] * size[o][0]
				vec[1] = origin[1] - mins[1] * size[o][1]
				vec[2] = origin[2] - mins[2] * size[o][2]
				if (is_hull_vacant(vec, hull,monster)) {
					engfunc(EngFunc_SetOrigin, monster, vec)
					set_pev(monster,pev_velocity,{0.0,0.0,0.0})
					o = sizeof size
				}
			}
		}
		else
		{
			stuck[monster] = 0
		}
	}
}

stock bool:is_hull_vacant(const Float:origin[3], hull,id) {
	static tr
	engfunc(EngFunc_TraceHull, origin, origin, 0, hull, id, tr)
	if (!get_tr2(tr, TR_StartSolid) || !get_tr2(tr, TR_AllSolid)) //get_tr2(tr, TR_InOpen))
		return true
	
	return false
}

public plugin_precache()
{
    g_iBeamSprite = precache_model( "sprites/laserbeam.spr" );
    for (new i = 0;i < SoundStackCount;i ++)
    {
        new path[128];
        format(path , 128 , "%s%s" , SoundRootPath , SoundStack[i]);
        precache_sound(path);
    }
}

public ShowHud(string[])
{
    set_hudmessage(255, 92, 92, 0.6, 0.91, 1, 0.3, 3.0, 1.0, 0.75, -1);
    show_hudmessage(0, string);
}

public ListenUserKey()
{
    for (new playerPos = 0;playerPos < 32;playerPos ++)
    {
        if (PI_List[playerPos][PI_IsEmpty] == false)
        {
            new ent = PI_List[playerPos][PI_ID];
            if (pev(ent , pev_button) & IN_USE)
            {
                if (get_gametime() - PI_List[playerPos][PI_LastRestoreTime] >= PI_List[playerPos][PI_RestoreDuration])
                {
                    PI_List[playerPos][PI_LastRestoreTime] = get_gametime();
                    for (new i = 0 ; i < BI_Count;i ++)
                    {
                        if (EntityRange(ent , BI_List[i][BI_EntID]) <= 64.0)
                        {
                            DeltaEntityHealth(BI_List[i][BI_EntID] , ent , 20.0);
                            PI_List[playerPos][PI_RestoreCount] ++;
                            console_print(0 ,"match %d" , i);
                            break;
                        }
                    }
                }
            }
            if (pev(ent , pev_button) & IN_RELOAD)
            {
                WeaponStore(ent , 0);
            }
        }
    }
}

public KilledZombie(this, idattacker, shouldgib)
{
    for (new i = 0;i < 256;i ++)
    {
        if (MonsterList[i][MI_EntID] == this)
        {
            for (new j = 0;j < 32;j ++)
            {
                if (PI_List[j][PI_ID] == idattacker)
                {
                    PI_List[j][PI_Money] += MonsterList[i][MI_KillReward];
                    client_print(idattacker , print_radio , "杀死 %s , 获得 %d$" , MT_NameList[MonsterList[i][MI_Type]] , MonsterList[i][MI_KillReward]);
                    break;
                }
            }
            ArrayDestroy(MonsterList[i][MI_Path]);
            MonsterList[i][MI_IsAlive] = false;
            MonsterCount --;
            break;
        }
    }
    new current_wave = TotalWaveInfo[TW_Current];
    new aw_pos = TotalWaveInfo[TW_Wave][current_wave];
    if (MonsterCount <= 0 && AW_List[aw_pos][AW_SpwanCount] <= AW_List[aw_pos][AW_CurrentSpwan])
    {
        PushWave();
    }
}

public DmgZombie(this , wpn , idatk , Float:dmg , dmgbits)
{
    new thisname[32];
    pev(this , pev_classname , thisname , 32);
    new atkname[32];
    pev(idatk , pev_classname , atkname , 32);
    new wpnname[32];
    pev(wpn , pev_classname , wpnname , 32);
    console_print(0 , "%s 用 %s  %s %f %d" , atkname , wpnname , thisname , dmg , dmgbits);
}

public traceline_forward(Float:start[3], Float:end[3], conditions, id, trace)
{
    if (id >= 1 && id <= 33)
    {
        new ent = get_tr2(trace, TR_pHit);
        if (ent >= 1)
        {
            new Float:range = EntityRange(ent , id);
            new Float:health = GetEntityHealth(ent);
            client_print(id , print_center , "Health %f , distance %f" , health , range);
        }
    }
}

public Init()
{
    new ClassName[32];
    new NoPairCount = 0;
    for (new i = find_ent_by_class(-1 , MSP_Class);i != 0; i = find_ent_by_class(i , MSP_Class))
    {
        new bool:PairFlag = false;
        new zmspwan;
        entity_get_string(i , EV_SZ_targetname , ClassName , 32);
        if (strfind(ClassName , "zmspawn") == -1)
        {
            continue;
        }
        zmspwan = str_to_num(ClassName[7]);
        pev(i , pev_origin , MSP_List[MSP_Count][MSP_Position]);
        MSP_List[MSP_Count][MSP_EntID] = i;
        MSP_Count ++;
        for (new j = find_ent_by_class(-1 , BI_Class);j != 0; j = find_ent_by_class(j , BI_Class))
        {
            new barricade;
            entity_get_string(j , EV_SZ_targetname , ClassName , 32);
            if (strfind(ClassName , "barricade") == -1)
            {
                continue;
            }
            barricade = str_to_num(ClassName[9]);
            for (new k = 0;k < sizeof(PairZmsB);k ++)
            {
                if (PairZmsB[k][0] == zmspwan && PairZmsB[k][1] == barricade)
                {
                    remove_entity(j);
                    continue;
                    PairFlag = true;
                    new Float:entmin[3];
                    new Float:entmax[3];
                    entity_get_vector(j , EV_VEC_absmin , entmin);
                    entity_get_vector(j , EV_VEC_absmax , entmax);
                    xs_vec_add(entmax , entmin , entmax);
                    xs_vec_mul_scalar(entmax , 0.5 , BI_List[BI_Count][BI_Position]);
                    BI_List[BI_Count][BI_EntID] = j;
                    BI_List[BI_Count][BI_Num] = barricade;
                    BI_List[BI_Count][BI_MaxHealth] = 1000.0;
                    BI_List[BI_Count][BI_Health] = 100.0;
                    BI_List[BI_Count][BI_IsBreak] = false;
                    MSP_List[MSP_Count][MSP_Target] = j;
                    BI_Count ++;
                    
                    break;
                }
            }
        }
        if (PairFlag == false)
        {
            console_print(0 , "MSP %d has no barricade" , zmspwan);
            NoPairCount++;
        }
    }
    console_print(0 , "MSP : %d , BI : %d , no_pair : %d" ,MSP_Count , BI_Count , NoPairCount);
    for (new i = 0;i < 32;i ++)
    {
        PI_List[i][PI_Money] = 0;
        PI_List[i][PI_IsEmpty] = true;
    }
    for (new i = 0 ; i < TotalWaveInfo[TW_Count] ; i ++)
    {
        AW_List[i][AW_WaitTime] = 2.0;
        AW_List[i][AW_CurrentSpwan] = 0;
        for (new j = 0 ; j < random_num(5 + i * 2, 25 + i * 2); j ++)
        {
            AW_List[i][AW_SpwanTypeList][j] = random_num(0 , MonsterType - 1);
            AW_List[i][AW_SpwanCount] ++;
        }
        TotalWaveInfo[TW_Wave][i] = AW_Count;
        AW_Count ++;
    }
}

public showlist()
{
    for (new i = 0;i < 256;i ++)
    {
        if (MonsterList[i][MI_IsAlive] == true)
        {
            console_print(0 , "Zombie %d : %d %f %d" , i , MonsterList[i][MI_EntID] , MonsterList[i][MI_Health] , MonsterList[i][MI_TargetBarrier]);
        }
    }
}

public client_putinserver(id)
{
    for (new i = 0;i < 32; i ++)
    {
        if (PI_List[i][PI_IsEmpty] == true)
        {
            PI_List[i][PI_ID] = id;
            PI_List[i][PI_Money] = 0;
            PI_List[i][PI_IsEmpty] = false;
            PI_List[i][PI_RestoreDuration] = 1.0;
            PI_List[i][PI_Speed] = 250;
            copy(PI_List[i][PI_Equips] , 0 , {0 , 0 , 0});
            PI_Count ++;
            break;
        }
    }
}

public client_disconnected(id , bool:drop , msg[] , len)
{
    if (drop == true)
    {
        for (new i = 0;i < 32;i ++)
        {
            if (PI_List[i][PI_ID] == id)
            {
                PI_List[i][PI_IsEmpty] = true;
                PI_Count --;
                break;
            }
        }
    }
}

public SpwanWave()
{
    /*
    new alive_players[32];
    new alive_count = 0;
    get_players(alive_players , alive_count , "a");
    if (alive_count == 0)
    {
        new hudmsg[128];
        format(hudmsg , 128 , "回合失败" , TotalWaveInfo[TW_Current] , TotalWaveInfo[TW_Count] , TotalWaveInfo[TW_WaveGap])
        ShowHud(hudmsg);
        for (new i = 0; i < 256; i ++)
        {
            MonsterList[i][MI_IsAlive] = false;
        }
        return;
    }*/
    new current_wave = TotalWaveInfo[TW_Current];
    if (current_wave >= 0 && current_wave < 64)
    {
        new aw_pos = TotalWaveInfo[TW_Wave][current_wave];
        if (aw_pos >= 0 && aw_pos < AW_Count)
        {
            new zm_pos = AW_List[aw_pos][AW_CurrentSpwan];
            if (zm_pos >= 0 && zm_pos < AW_List[aw_pos][AW_SpwanCount])
            {
                if (zm_pos == 0)
                {
                    new hudmsg[128];
                    format(hudmsg , 128 , "回合开始" , TotalWaveInfo[TW_Current] , TotalWaveInfo[TW_Count] , TotalWaveInfo[TW_WaveGap])
                    ShowHud(hudmsg);
                    EmitSound(0 , SG_WaveStart);
                }
                console_print(0 , "Wave in %d %d / %d" , AW_List[aw_pos][AW_SpwanCount] % MSP_Count, AW_List[aw_pos][AW_CurrentSpwan] + 1 , AW_List[aw_pos][AW_SpwanCount]); 
                OnSpwan( AW_List[aw_pos][AW_SpwanCount] % MSP_Count , AW_List[aw_pos][AW_SpwanTypeList][zm_pos]); 
                AW_List[aw_pos][AW_CurrentSpwan] += 1;
                set_task(AW_List[aw_pos][AW_WaitTime] , "SpwanWave");
            }
        }
    }
}

public PushWave()
{
    console_print(0 , "Total Wave %d / %d" , TotalWaveInfo[TW_Current] , TotalWaveInfo[TW_Count]);
    new current_wave = TotalWaveInfo[TW_Current];
    new aw_pos = TotalWaveInfo[TW_Wave][current_wave];
    AW_List[aw_pos][AW_CurrentSpwan] = 0;
    TotalWaveInfo[TW_Current] += 1;
    set_task(TotalWaveInfo[TW_WaveGap] , "SpwanWave");
    new hudmsg[128];
    format(hudmsg , 128 , "%d / %d 已完成 , %f 秒后下一回合" , TotalWaveInfo[TW_Current] , TotalWaveInfo[TW_Count] , TotalWaveInfo[TW_WaveGap])
    ShowHud(hudmsg);
    EmitSound(0 , SG_WaveEnd);
}

public OnSpwan(MSP , type)
{
    for (new i = 0;i < 128;i ++)
    { 
        if (MonsterList[i][MI_IsAlive] == false)
        {
            new ent = CreateZombie(MSP_List[MSP][MSP_Position] , type);
            if (MonsterCount >= 256)
            {
                remove_entity(MonsterList[255][MI_EntID]);
                MonsterCount --;
            }
            if (ent > 0)
            {
                for (new j = 0;j < 256;j ++)
                {
                    if (MonsterList[j][MI_IsAlive] == false)
                    {
                        MonsterList[j][MI_IsAlive] = true;
                        copyf(MonsterList[j] , MonsterInfo , MT_List[type]);
                        MSP_List[MSP][MSP_SpwanCount] ++;
                        MonsterList[j][MI_EntID] = ent;
                        MonsterList[j][MI_CreateTime] = get_gametime();
                        MonsterList[j][MI_TargetBarrier] = MSP_List[MSP][MSP_Target];
                        MonsterList[j][MI_PathUpdateDuration] = 0.1;
                        MonsterList[j][MI_PathUpdateTime] = 0.0;
                        MonsterList[j][MI_Attempt] = 0;
                        MonsterList[j][MI_MaxAttempt] = 5;
                        MonsterList[j][MI_JumpDuration] = 5.0;
                        break;
                    }
                }
                MonsterCount++;
            }
            return i;
        }
    }
    return -1;
}

public CreateZombie(Float:origin[3] , type)
{
    new ent = create_entity("info_target");
    if (ent <= 0)
    {
        return ent;
    }
    //entity_set_int(ent , EV_INT_iuser1 , MonsterCount);
    entity_set_origin(ent , origin);
    entity_set_float(ent , EV_FL_takedamage , DAMAGE_AIM);
    entity_set_float(ent , EV_FL_health , MT_List[type][MI_Health]);
    entity_set_float(ent , EV_FL_gravity , 400.0);

    entity_set_string(ent , EV_SZ_classname , "npc_zombie");
    entity_set_string(ent , EV_SZ_targetname , MT_NameList[type]);
    entity_set_model(ent , MT_ModelList[type]);
    entity_set_int(ent , EV_INT_solid , SOLID_SLIDEBOX);
    entity_set_int(ent , EV_INT_movetype , MOVETYPE_STEP);
    
    new Float:maxs[3] = {16.0,16.0,36.0};
    new Float:mins[3] = {-16.0,-16.0,-36.0};
    entity_set_size(ent,mins,maxs);

	entity_set_float(ent, EV_FL_animtime, get_gametime());
	entity_set_float(ent, EV_FL_frame, 0.0);
	entity_set_float(ent, EV_FL_framerate,  1.0);
	entity_set_int(ent, EV_INT_sequence, 1.0);

    entity_set_float(ent,EV_FL_nextthink,halflife_time() + 0.01);
    drop_to_floor(ent);

    return ent;
}

public npc_think(iEnt)
{
    if(!pev_valid(iEnt))
    {
        return;
    }
    new targetid = get_closest_player(iEnt);
    new Float:targetPos[3];
    pev(targetid , pev_origin , targetPos);
    new MPos = -1;
    for (new i = 0;i < 256;i ++)
    {
        if (iEnt == MonsterList[i][MI_EntID])
        {
            /*
            if (MonsterList[i][MI_IsAlive] == false)
            {
                return;
            }
            new target_b = 0;
            for (new j = 0;j < BI_Count;j ++)
            {
                if (MonsterList[i][MI_TargetBarrier] == BI_List[j][BI_EntID])
                {
                    target_b = j;
                    break;
                }
            }
            if (BI_List[target_b][BI_IsBreak] == false)
            {
                GetEntityOrigin(MonsterList[i][MI_TargetBarrier] , targetPos);
                targetid = MonsterList[i][MI_TargetBarrier];
            }*/
            MPos = i;
        }
    }
    if (MPos != -1)
    {
        new Float:ctime = get_gametime();
        new bool:changed = false;
        if (MonsterList[MPos][MI_Target] == targetid)
        {
            changed = true;
        }
        NPC_Pather(MPos , targetid,  changed , targetPos);
        if (ctime - MonsterList[MPos][MI_LastJump] >= MonsterList[MPos][MI_JumpDuration])
        {
            entity_set_aim(iEnt, targetPos , MonsterList[MPos][MI_Speed] , true);
        }
        else 
        {
            entity_set_aim(iEnt, targetPos , MonsterList[MPos][MI_Speed] , false);
        }
        ZombieTryAttack(MPos , targetid); 
        
        MonsterList[MPos][MI_AliveTick] ++;
        if (MonsterList[MPos][MI_AliveTick] % 500 == 0)
        {
            EmitSound(iEnt , SG_ZombieBreathe);
        }   
        set_pev(iEnt, pev_nextthink, get_gametime() + 0.01)
    }
    else
    {
        console_print(0 , "Zombie %d not found in MonsterList" , iEnt);
        remove_entity(iEnt);
    }
}

entity_set_aim(ent, const Float:origin[3] , const Float:velocity , bool:IsJump) 
{ 
    static Float:ent_origin[3], Float:angles[3];
    
    pev(ent, pev_origin, ent_origin) 
     
    xs_vec_sub(origin, ent_origin, ent_origin) 
    xs_vec_normalize(ent_origin, ent_origin) 
    vector_to_angle(ent_origin, angles) 
     
    angles[0] = 0.0 
     
    set_pev(ent, pev_angles, angles)

    static Float: Direction[3] 
    angle_vector(angles, ANGLEVECTOR_FORWARD, Direction) 
    xs_vec_mul_scalar(Direction, velocity, Direction)
    if (IsJump == true)
    {
        Direction[2] += 800.0;
    }
    set_pev(ent, pev_velocity, Direction)
    
    // Run Sequence
    if(pev(ent, pev_sequence) != 5) Util_PlayAnimation(ent, 4);
}

Util_PlayAnimation(index, sequence, Float: framerate = 1.0)
{
    set_pev(index, pev_animtime, get_gametime())
    set_pev(index, pev_framerate,  framerate)
    set_pev(index, pev_frame, 0.0)
    set_pev(index, pev_sequence, sequence)
} 

get_closest_player(ent)
{
    new iPlayers[32], iNum;
    get_players(iPlayers, iNum, "a");
    if (iNum == 1)
    {
        return iPlayers[0];
    }
    new iClosestPlayer = 0, Float:flClosestDist = 9999.0;
    new iPlayer, Float:flDist;
    
    for (new i = 0; i < iNum; i++)
    {
        iPlayer = iPlayers[i];
        
        if (!is_user_alive(iPlayer))
            continue;

        flDist = entity_range(iPlayer, ent);

        if (flDist < flClosestDist)
        {
            iClosestPlayer = iPlayer;
            flClosestDist = flDist;
        }
    }
    return iClosestPlayer;
}

public ZombieTryAttack(MIPos , victim)
{
    if (MIPos >= 0 && MIPos < 256 && victim >= 1)
    {
        new mEnt = MonsterList[MIPos][MI_EntID];
        if (EntityRange(mEnt , victim) <= MonsterList[MIPos][MI_AtkRange])
        {
            if (get_gametime() - MonsterList[MIPos][MI_LastAttackTime] >= MonsterList[MIPos][MI_AttackDuration])
            {
                MonsterList[MIPos][MI_LastAttackTime] = get_gametime();
                DeltaEntityHealth(victim , mEnt , -MonsterList[MIPos][MI_Damage])
                return true;
            }
        }
    }
    return false;
}

public Float:GetEntityHealth(ent)
{
    for (new i = 0;i < BI_Count;i ++)
    {
        if (ent == BI_List[i][BI_EntID])
        {
            return BI_List[i][BI_Health];
        }
    }
    return entity_get_float(ent , EV_FL_health);
}

public bool:SetEntityHealth(ent , Float:value)
{
    for (new i = 0;i < BI_Count;i ++)
    {
        if (ent == BI_List[i][BI_EntID])
        {
            new bool:IsNegative = value < BI_List[i][BI_Health];
            if (value >= BI_List[i][BI_MaxHealth])
            {
                BI_List[i][BI_Health] = BI_List[i][BI_MaxHealth];
                return false;
            }
            else if (value <= 0 && IsNegative == true)
            {
                BI_List[i][BI_IsBreak] = true;
                entity_set_int(BI_List[i][BI_EntID], EV_INT_solid , SOLID_NOT)
            }
            else if (value / BI_List[i][BI_MaxHealth] >= 0.2 && IsNegative == false)
            {
                BI_List[i][BI_IsBreak] = false;
                entity_set_int(BI_List[i][BI_EntID], EV_INT_solid , SOLID_BSP);
            }
            BI_List[i][BI_Health] = value;
        }
    }
    set_pev(ent , pev_health , value);
    return true;
}

public Float:DeltaEntityHealth(ent , source , Float:value)
{
    for (new i = 0;i < BI_Count;i ++)
    {
        if (ent == BI_List[i][BI_EntID])
        {
            if (value < 0)
            {
                EmitSound(ent , SG_WoodDmg);
            }
            else if (value > 0)
            {
                EmitSound(ent , SG_WoodBuid);
            }
            SetEntityHealth(ent , BI_List[i][BI_Health] + value);
            return BI_List[i][BI_Health];
        }
    }
    ExecuteHamB(Ham_TakeDamage, ent, source, source, -value, DMG_CLUB);
    return pev(ent , pev_health);
}

public Float:EntityRange(a , b)
{
    new Float:origina[3] , Float:originb[3] , Float:lenab[3];
    GetEntityOrigin(a , origina);
    GetEntityOrigin(b , originb);
    xs_vec_sub(origina , originb , lenab);
    return xs_vec_len(lenab);
}

public GetEntityOrigin(ent , Float:output[3])
{
    for (new i = 0;i < BI_Count;i ++)
    {
        if (BI_List[i][BI_EntID] == ent)
        {
            xs_vec_copy(BI_List[i][BI_Position] , output);
            return;
        }
    }
    pev(ent , pev_origin , output);
    return;
}

public EmitSound(ent , sgtype)
{
    if (sgtype >= 0 && sgtype < SoundGroup)
    {
        new path[128];
        format(path , 128 , "%s%s" , SoundRootPath , SoundStack[SG_List[sgtype][SL_List][random_num(0 , SG_List[sgtype][SL_Count] - 1)]]);
        emit_sound(ent, CHAN_AUTO, path, VOL_NORM, 1, 0, PITCH_NORM);
    }
}

enum _:WeaponItem
{
    WI_Cost,
    WI_Name[32],
    WI_Class[32],
}
const WeaponCount = 14;
new WI_List[WeaponCount][WeaponItem] = {
    {10 , "M4A1" , "weapon_m4a1"},
    {15 , "AK47" , "weapon_ak47"},
    {20 , "AWP" , "weapon_awp"},
    {5 , "Glock18" , "weapon_glock18"},
    {5 , "USP" , "weapon_usp"},
    {5 , "Deagle" , "weapon_deagle"},
    {5 , "P228" , "weapon_p228"},
    {5 , "FiveSeven" , "weapon_fiveseven"},
    {5 , "MP5" , "weapon_mp5navy"},
    {5 , "TMP" , "weapon_tmp"},
    {20 , "P90" , "weapon_p90"},
    {5 , "Galil" , "weapon_galil"},
    {5 , "Famas" , "weapon_famas"},
    {50 , "M249" , "weapon_m249"},
};

public WeaponStore(id , page)
{
    new player = GetPlayer(id);
    if (player < 0)
    {
        return;
    }
    new title[64];
    format(title , 64 , "武器商店 - 金钱 %d$" , PI_List[player][PI_Money]);
    new menu = menu_create(title , "WeaponStoreHandler");
    for (new i = 0;i < WeaponCount;i ++)
    {
        if (WI_List[i][WI_Cost] > 0)
        {
            new item[64];
            format(item , 64 , "%s - %d$" , WI_List[i][WI_Name] , WI_List[i][WI_Cost]);
            menu_additem(menu , item);
        }
    }
    menu_display(id , menu , page);
}

public WeaponStoreHandler(id , menu , item)
{
    menu_destroy(menu);
    new player = GetPlayer(id);
    if (item >= 0 && item < WeaponCount)
    {
        if (PI_List[player][PI_Money] >= WI_List[item][WI_Cost])
        {
            PI_List[player][PI_Money] -= WI_List[item][WI_Cost];
            fm_give_item(id , WI_List[item][WI_Class]);
            client_print_color(id , print_center , "^4[Store]^1购买 ^3%s ^1成功" , WI_List[item][WI_Name]);
            WeaponStore(id , item / 7);
        }
        else
        {
            client_print_color(id , print_center , "^4[Store]^1购买 ^3%s ^1失败, 金钱不足" , WI_List[item][WI_Name]);
        }
    }
}

public copyf(Float:dest[] , const len ,const Float:source[])
{
    for (new i = 0;i < len;i ++)
    {
        dest[i] = source[i];   
    }
}

public GetPlayer(id)
{
    for (new i = 0;i < 32;i ++)
    {
        if (PI_List[i][PI_ID] == id)
        {
            return i;
        }
    }
    return -1;
}

new Float:theta = 64.0;
public NPC_Pather(mid , targetID , bool:ChangeTarget , Float:out[3])
{
    new Float:start[3];
    new Float:end[3];
    new Float:TargetPos[3];
    new Float:selfPos[3];
    new Float:HullSize[3] = {16.0 , 16.0 , 16.0};
    new Float:current_time = get_gametime();
    new Float:tmpa[3];
    new float:tmpb[3];
    pev(targetID , pev_origin ,TargetPos);
    pev(MonsterList[mid][MI_EntID] , pev_origin , selfPos);
    if (current_time - MonsterList[mid][MI_PathUpdateTime] >= MonsterList[mid][MI_PathUpdateDuration])
    {
        new Array:new_path;
        if (GeneratePath(selfPos , TargetPos , new_path) == true)
        {
            if (ArraySize(new_path) >= 0)
            {
                new bool:update = true;

                if (Invalid_Array != MonsterList[mid][MI_Path])
                {
                    ArrayGetArray(new_path , 0 , start , 3);
                    ArrayGetArray(MonsterList[mid][MI_Path] , MonsterList[mid][MI_PathPointer] , end , 3);
                    if (!xs_vec_equal(start , end))
                    {
                        update = false;   
                    }
                    else
                    {
                        ArrayDestroy(MonsterList[mid][MI_Path]);
                    }
                }
                if (update == true)
                {
                    MonsterList[mid][MI_PathUpdateTime] = current_time;
                    ArrayPushArray(new_path , TargetPos , 3);
                    ArrayInsertArrayBefore(new_path , 0 , selfPos);
                    for (new i = 0;i < ArraySize(new_path) - 1 ;i ++)
                    {
                        ArrayGetArray(new_path , i , start , 3);
                        for (new j = i + 1;j < ArraySize(new_path) - 1;j ++)
                        {
                            ArrayGetArray(new_path , j , end , 3);
                            /*
                            xs_vec_add(tmpa , HullSize , tmpa);
                            xs_vec_sub(tmpb , HullSize , tmpb);
                            xs_vec_add(tmpa , start , tmpa);
                            xs_vec_add(tmpb , end , tmpb);
                            */
                            if (!IsWallBetween(start , end))
                            {
                                ArrayDeleteItem(new_path , j);
                                break;
                            }
                        
                        }
                    }

                    MonsterList[mid][MI_PathPointer] = 0;
                    MonsterList[mid][MI_Path] = new_path; 
                }
            }
            else
            {
                ArrayDestroy(new_path);
            }
        }
    }
    if (Invalid_Array != MonsterList[mid][MI_Path])
    {
        ArrayGetArray(MonsterList[mid][MI_Path] , MonsterList[mid][MI_PathPointer] , TargetPos , 3);
        if (xs_vec_distance(selfPos , TargetPos) <= theta)
        {
            MonsterList[mid][MI_PathPointer] ++;
            if (MonsterList[mid][MI_PathPointer] >= ArraySize(MonsterList[mid][MI_Path]))
            {
                MonsterList[mid][MI_Attempt] ++;
                if (MonsterList[mid][MI_Attempt] >= MonsterList[mid][MI_MaxAttempt])
                {
                    MonsterList[mid][MI_Attempt] = 0;
                    ArrayDestroy(MonsterList[mid][MI_Path]);
                    return;
                }
                pev(targetID , pev_origin ,TargetPos);
                MonsterList[mid][MI_PathPointer] --;
                ArrayPushArray(MonsterList[mid][MI_Path] , TargetPos , 3);
            }
        }
        /*
        ArrayGetArray(MonsterList[mid][MI_Path] , MonsterList[mid][MI_PathPointer] , out , 3);
        for (new i = 0;i < ArraySize(MonsterList[mid][MI_Path]) - 1;i ++)
        {
            ArrayGetArray(MonsterList[mid][MI_Path] , i , start , 3);
            ArrayGetArray(MonsterList[mid][MI_Path] , i + 1 , end , 3);
            beam(start , end , 0.3);
        }*/
    }
}

stock beam(Float:origin1[3], Float:origin2[3], Float:seconds) {
	message_begin(MSG_BROADCAST ,SVC_TEMPENTITY);
	write_byte(TE_BEAMPOINTS);
	write_coord(floatround(origin1[0]));	// start position
	write_coord(floatround(origin1[1]));
	write_coord(floatround(origin1[2]));
	write_coord(floatround(origin2[0]));	// end position
	write_coord(floatround(origin2[1]));
	write_coord(floatround(origin2[2]));
	write_short(g_iBeamSprite);	// sprite index
	write_byte(0);	// starting frame
	write_byte(10);	// frame rate in 0.1's
	write_byte(floatround(seconds*10));	// life in 0.1's
	write_byte(10);	// line width in 0.1's
	write_byte(1);	// noise amplitude in 0.01's
	write_byte(255);	// Red
	write_byte(0);	// Green
	write_byte(0);	// Blue
	write_byte(127);	// brightness
	write_byte(10);	// scroll speed in 0.1's
	message_end();
}