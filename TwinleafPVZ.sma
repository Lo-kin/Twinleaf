#include <amxmodx>
#include <engine>
#include <hamsandwich>
#include <fakemeta>
#include <xs>

#define Block_size 64
#define BlockStart_x 0
#define BlockStart_y 0
#define BlockCount_x 10
#define BlockCount_y 5

enum _:SoundGroup
{
    SG_WoodDmg,
    SG_WoodBuid,
    SG_ZombieBreathe,
    SG_ZombieAttack,
    SG_ZombieHurt,
    SG_PlayerBreath,
    SG_PlayerHurt,
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
};
new SoundRootPath[64] = "sound/Twinleaf/LeafGuard/";
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
new BI_Class[32] = "func_wall";
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
    Float:MI_CreateTime
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
    MSP_Target
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

public plugin_init()
{
    register_plugin("Twinleaf LeafGuard", "0.0.1", "Tredam" , "github.com/Lo-kin" , "");
    
    register_think("npc_zombie" , "npc_think");
    //RegisterHam(Ham_TakeDamage , "info_target" , "DmgZombie");
    RegisterHam(Ham_Killed , "info_target" , "KilledZombie");

    register_clcmd("say start" , "SpwanWave");
    register_forward(FM_TraceLine, "traceline_forward" , 1);
    set_task(0.1 , "ListenUserKey" , 1919810 , _ , _ ,"b");
    Init();
}

public plugin_precache()
{
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

public WeaponMenu(id)
{
    
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
                    for (new i = 1 ; i < BI_Count;i ++)
                    {
                        console_print(0 , "On Using %d " ,playerPos );
                        if (EntityRange(ent , BI_List[i][BI_EntID]) <= 64.0)
                        {
                            DeltaEntityHealth(i , ent , 20);
                            PI_List[playerPos][PI_RestoreCount] ++;
                            console_print(0 ,"match %d" , i);
                            break;
                        }
                        
                    }
                }
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
            /*
            new hudmsg[128];
            format(hudmsg , 128 , "杀死 %s , 获得 %d$" , MT_NameList[MonsterList[i][MI_Type]] , MonsterList[i][MI_KillReward]);
            ShowHud(hudmsg);*/
            
            for (new j = 0;j < 32;j ++)
            {
                if (PI_List[j][PI_ID] == idattacker)
                {
                    PI_List[j][PI_Money] += MonsterList[i][MI_KillReward];
                    client_print(idattacker , print_radio , "杀死 %s , 获得 %d$" , MT_NameList[MonsterList[i][MI_Type]] , MonsterList[i][MI_KillReward]);
                    break;
                }
            }
            MonsterList[i][MI_IsAlive] = false;
            MonsterCount --;
            break;
        }
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
    if (find_player("k" , id) != 0)
    {
        new ent = get_tr2(trace, TR_pHit);
        if (ent >= 1)
        {
            new Float:health = GetEntityHealth(ent);
            client_print(id , print_center , "Health %f" , health);
            
        }
    }
}

public Init()
{
    /*
    for (new i = 0;i <= entity_count();i ++)
    {
        new cname[32];
        pev(i , pev_classname , cname , 32);
        console_print(0 , "(%s)" , cname);
    }*/
    for (new i = find_ent_by_class(-1 , MSP_Class);i != 0; i = find_ent_by_class(i , MSP_Class))
    {
        new group[32];
        entity_get_string(i , EV_SZ_targetname , group , 32);
        new targetNum = str_to_num(group);
        if (targetNum != 0)
        {
            pev(i , pev_origin , MSP_List[MSP_Count][MSP_Position]);
            MSP_List[MSP_Count][MSP_EntID] = i;
            MSP_List[MSP_Count][MSP_Target] = targetNum;
            MSP_Count ++;
        }
    }
    for (new i = find_ent_by_class(-1 , BI_Class);i != 0; i = find_ent_by_class(i , BI_Class))
    {
        new group[32];
        entity_get_string(i , EV_SZ_targetname , group , 32);
        new targetNum = str_to_num(group);
        if (targetNum != 0)
        {
            new Float:entmin[3];
            new Float:entmax[3];
            entity_get_vector(i , EV_VEC_absmin , entmin);
            entity_get_vector(i , EV_VEC_size , entmax);
            xs_vec_add_scaled(entmin , entmax , 0.5 , BI_List[BI_Count][BI_Position]);
            BI_List[BI_Count][BI_EntID] = i;
            BI_List[BI_Count][BI_Num] = targetNum;
            BI_List[BI_Count][BI_MaxHealth] = 1000.0;
            BI_List[BI_Count][BI_Health] = 1000.0;
            BI_List[BI_Count][BI_IsBreak] = false;
            BI_Count ++;     
        }
    }
    new no_comp_count = 0;
    for (new i = 0;i < MSP_Count;i ++)
    {
        new bool:FindFlag = false
        for (new j = 0;j < BI_Count;j ++)
        {
            if (MSP_List[i][MSP_Target] == BI_List[j][BI_Num])
            {
                MSP_List[i][MSP_Target] = j;
                FindFlag = true;
                break;
            }
        }
        if (FindFlag == false)
        {
            no_comp_count ++;
            MSP_List[i][MSP_Target] = -1;
        } 
    }
    console_print(0 , "MSP : %d , BI : %d , no_comp : %d" ,MSP_Count , BI_Count , no_comp_count);

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

public client_putinserver(id)
{
    for (new i = 0;i < 32; i ++)
    {
        if (PI_List[i][PI_IsEmpty] == true)
        {
            PI_List[i][PI_ID] = id;
            PI_List[i][PI_Money] = 0;
            PI_List[i][PI_IsEmpty] = false;
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
            if (PI_List[id][PI_ID] == id)
            {
                PI_List[id][PI_IsEmpty] = true;
                PI_Count --;
                break;
            }
        }
    }
}

public SpwanWave()
{
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
                }
                console_print(0 , "Wave %d / %d" , AW_List[aw_pos][AW_CurrentSpwan] + 1 , AW_List[aw_pos][AW_SpwanCount]); 
                OnSpwan(random_num(0 , BI_Count) , AW_List[aw_pos][AW_SpwanTypeList][zm_pos]);
                AW_List[aw_pos][AW_CurrentSpwan] += 1;
                set_task(AW_List[aw_pos][AW_WaitTime] , "SpwanWave");
            }
            else
            {
                console_print(0 , "Total Wave %d / %d" , TotalWaveInfo[TW_Current] , TotalWaveInfo[TW_Count]); 
                AW_List[aw_pos][AW_CurrentSpwan] = 0;
                TotalWaveInfo[TW_Current] += 1;
                set_task(TotalWaveInfo[TW_WaveGap] , "SpwanWave");
                new hudmsg[128];
                format(hudmsg , 128 , "%d / %d 已完成 , %f 秒后下一回合" , TotalWaveInfo[TW_Current] , TotalWaveInfo[TW_Count] , TotalWaveInfo[TW_WaveGap])
                ShowHud(hudmsg);
            }
        }
    }
}

public OnSpwan(MSP , type)
{
    for (new i = 0;i < 128;i ++)
    {
        if (MonsterList[i][MI_IsAlive] == false)
        {
            new ent = CreateZombie(MSP_List[MSP][MSP_Position] , type);
            if (ent > 0)
            {
                copyf(MonsterList[MonsterCount] , MonsterInfo , MT_List[type]);
                MSP_List[MSP][MSP_SpwanCount] ++;
                MonsterList[MonsterCount][MI_EntID] = ent;
                MonsterList[MonsterCount][MI_CreateTime] = get_gametime();
                MonsterList[MonsterCount][MI_TargetBarrier] = MSP_List[MSP][MSP_Target];
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
    entity_set_float(ent , EV_FL_gravity , 800.0);

    entity_set_string(ent , EV_SZ_classname , "npc_zombie");
    entity_set_string(ent , EV_SZ_targetname , MT_NameList[type]);
    entity_set_model(ent , MT_ModelList[type]);
    entity_set_int(ent , EV_INT_solid , SOLID_BBOX);
    entity_set_int(ent , EV_INT_movetype , MOVETYPE_STEP);
    
    entity_set_byte(ent,EV_BYTE_controller1,125);
    entity_set_byte(ent,EV_BYTE_controller2,125);
    entity_set_byte(ent,EV_BYTE_controller3,125);
    entity_set_byte(ent,EV_BYTE_controller4,125);
    
    new Float:maxs[3] = {16.0,16.0,36.0};
    new Float:mins[3] = {-16.0,-16.0,-36.0};
    entity_set_size(ent,mins,maxs);

    entity_set_float(ent,EV_FL_animtime,2.0);
    entity_set_float(ent,EV_FL_framerate,1.0);
    entity_set_int(ent,EV_INT_sequence,4);

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
    new MPos = 0;
    for (new i = 0;i < 256;i ++)
    {
        if (iEnt == MonsterList[i][MI_EntID])
        {
            if (MonsterList[i][MI_TargetBarrier] >= 0 && MonsterList[i][MI_TargetBarrier] < BI_Count)
            {
                new target_b = MonsterList[i][MI_TargetBarrier];
                if (BI_List[target_b][BI_IsBreak] == false)
                {
                    targetid = BI_List[target_b][BI_EntID];
                    xs_vec_copy(BI_List[target_b][BI_Position] , targetPos);
                }
            }
            MPos = i;
        }
    }
    entity_set_aim(iEnt, targetPos , MonsterList[MPos][MI_Speed]);
    ZombieTryAttack(MPos , targetid);

    if ((get_gametime() - MonsterList[MPos][MI_TargetBarrier]) / 5 == 0)
    {
        EmitSound(iEnt , SG_ZombieBreathe);
    }   
    set_pev(iEnt, pev_nextthink, get_gametime() + 0.01)
}

entity_set_aim(ent, const Float:origin[3] , const Float:velocity) 
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
                DeltaEntityHealth(victim , mEnt , MonsterList[MIPos][MI_Damage])
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
                if (entity_get_int(BI_List[i][BI_EntID], EV_INT_solid ) != SOLID_BSP)
                {
                    entity_set_int(BI_List[i][BI_EntID], EV_INT_solid , SOLID_BSP);
                }
            }
            else
            {
                BI_List[i][BI_Health] = value;
            }
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
    ExecuteHamB(Ham_TakeDamage, ent, ent, source, value, DMG_CLUB);
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
        format(path , 128 , "%s%s" , SoundRootPath , SoundStack[SG_List[sgtype][SL_List][random_num(0 , SG_List[sgtype][SL_Count])]])
        emit_sound(ent, CHAN_AUTO, path, VOL_NORM, 1, 0, PITCH_NORM);
    }
}

public copyf(Float:dest[] , const len ,const Float:source[])
{
    for (new i = 0;i < len;i ++)
    {
        dest[i] = source[i];   
    }
}