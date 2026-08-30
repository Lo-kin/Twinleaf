#include <amxmodx>
#include <engine>
#include <hamsandwich>
#include <fakemeta>	
#include <engine>
#include <xs>
#include <json>
#include <Twinleaf>

#define CoordLength 512

new VoiceItems[128][VoiceItem];
new VoiceCount = 0;
new rootVIPath[32] = "Twinleaf/Voice/";

enum _:Vector3
{
    Float:Vec3_X,
    Float:Vec3_Y,
    Float:Vec3_Z
}

new cvar_tl_enable_tp , cvar_tl_enable_push , cvar_tl_tp_save_velocity;

public plugin_init()
{
    register_plugin("Twinleaf 小工具", "1.0.0", "Tredam" , "github.com/Lo-kin" , "双叶服务器小工具");
    
    cvar_tl_enable_tp = register_cvar("tl_enable_tp", "1");
    cvar_tl_enable_push = register_cvar("tl_enable_push", "1");
    cvar_tl_tp_save_velocity = register_cvar("tl_tp_save_velocity", "0");

    register_clcmd("say ", "catch_command");

    RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack", 0);
    RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_knife", "CrowbarAttack2_Check_Pre", 0);
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_knife", "CrowbarAttack2_Check_Post", 0);

    set_task(60.0 , "OnlineReward" , 32196424 , "" , 0 , "b");
}

public OnlineReward()
{
    new int:PlayerCount;
	new Players[MAX_PLAYERS];
	get_players(Players , PlayerCount , "" , "")

    for (new i = 0;i < PlayerCount;i ++)
    {
        client_print_color(Players[i] , print_team_grey , "^4[雙葉]:^1在线奖励已发放~");
        set_user_OnlineTime_delta(Players[i] , 1);
        set_user_Experience_delta(Players[i] , 1);
        if (get_user_OnlineTime(Players[i]) % 5 == 0)
        {
            set_user_LeafCoin_delta(Players[i] , 20);
        }
    }
}

public plugin_precache()
{
    new JSON:Root = json_parse("addons/amxmodx/configs/sound-manifest.json" , true);
    if (Root == Invalid_JSON)
    {
        return PLUGIN_CONTINUE;
    }
	else
	{
        new JSON:voice_origin = json_object_get_value(Root , "voice");
        if (voice_origin != Invalid_JSON)
		{
            new count = json_array_get_count(voice_origin);
            for (new i = 0; i < count;i ++)
            {
                new JSON:item = json_array_get_value(voice_origin , i);
                if (item != Invalid_JSON)
                {
                    new JSON:voice_name = json_object_get_value(item , "name");
                    new JSON:voice_path = json_object_get_value(item , "path");

                    if (voice_name != Invalid_JSON && voice_path != Invalid_JSON)
                    {
                        new name[64];
                        new path[128];
                        json_get_string(voice_name , name , 64);
                        json_get_string(voice_path , path , 128);
                        formatex(VoiceItems[i][VI_Path] , 64 , "%s%s" , rootVIPath , path);
                        copy(VoiceItems[i][VI_Name] , 64 , name);
                        VoiceItems[i][VI_Count] = 0;
                        VoiceCount += 1;
                    }
                    json_free(voice_name);
                    json_free(voice_path);
                }
                json_free(item);
            }
        }
	}
    json_free(Root);
    for (new i = 0;i < VoiceCount;i ++)
    {
        precache_sound(VoiceItems[i][VI_Path]);
        VoiceItems[i][VI_Count] = 0;
    }
}

public plugin_natives()
{
    register_native("tl_utils" , "native_utils");
}

public native_utils(plugin , params)
{
    new id = get_param(1);
    UtilsMenu(id);
}

public catch_command(id)
{
    new argString[128];
	new argLength = read_argc();
	read_args(argString , charsmax(argString));
	remove_quotes(argString);
    if (strlen(argString) >= 1)
    {
        new item[ItemData];
        get_user_current_model(id , item , IT_Title);
        new tag[32];
        copy(tag , 128 , item[ID_Name]);
        new user_name[32];
        get_user_name(id , user_name , 32);
        //play_soundeffect(0 , SE_Send_Message);
        client_print_color(0 , id , "^4[%s]^3%s^1 : %s" , tag , user_name , argString);
    }
    return PLUGIN_HANDLED_MAIN;
}

//小工具管理
public UtilsMenu(id)
{
    play_soundeffect(id , SE_OpenMenu);
    new menu = menu_create("[雙葉]:这里是服务器小工具列表~" , "UtilesHandler");
    if (get_pcvar_num(cvar_tl_enable_tp) != 1)
    {
        menu_additem(menu , "\dTP菜单");
    }
    else
    {
        menu_additem(menu , "TP菜单");
    }
    menu_additem(menu , "语音菜单");
    menu_additem(menu , "投票重启服务器");
    menu_additem(menu , get_pcvar_num(cvar_tl_enable_push) ? "右键推人[已开启]" : "\d右键推人[已关闭]");
    menu_display(id , menu);
}

public UtilesHandler(id , menu , item)
{
    if (item == 0)
    {
        if (get_pcvar_num(cvar_tl_enable_tp) == 1)
        {
            TPMenu(id);
        }
    }
    if (item == 1)
    {
        VoiceMenu(id);
    }
    if (item == 2)
    {
        VoteRes(id);
    }
    
}

//存点tp
enum _:PositionInfo
{
    Float:PI_Forward[Vector3],
    Float:PI_Position[Vector3]
}

enum _:PlayerCoord
{
    PC_Current,
    PC_Count,
    PC_CoordList[CoordLength]
}

new PlayerData[33][PlayerCoord];
new PlayerCoords[33][CoordLength][PositionInfo];

public CopyF(Float:Target[] , Float:Source[] ,const length)
{
    for (new i = 0; i < length;i ++)
    {
        Target[i] = Source[i];
    }
}

public RecordCoord(id , Float:output[PositionInfo])
{
    pev(id , pev_angles , output[PI_Forward]);
    pev(id , pev_origin , output[PI_Position]);

    for (new i = 0; i < CoordLength - 1;i ++)
    {
        CopyF(PlayerCoords[id][i][PI_Forward] , PlayerCoords[id][i + 1][PI_Forward] , 3);
        CopyF(PlayerCoords[id][i][PI_Position] , PlayerCoords[id][i + 1][PI_Position] , 3);
    }
    PlayerData[id][PC_Count] += 1;
    PlayerData[id][PC_Current] = CoordLength - 1;

    CopyF(PlayerCoords[id][CoordLength - 1][PI_Forward] , output[PI_Forward] , 3);
    CopyF(PlayerCoords[id][CoordLength - 1][PI_Position] , output[PI_Position] , 3);
}

public ReadLast(const id , Float:output[PositionInfo])
{
    if (PlayerData[id][PC_Count] == 0)
    {
        pev(id , pev_angles , output[PI_Forward]);
        pev(id , pev_origin , output[PI_Position]);
    }
    else
    {
        if (PlayerData[id][PC_Current] == 0 || CoordLength + 1 - PlayerData[id][PC_Current]> PlayerData[id][PC_Count])
        {
            PlayerData[id][PC_Current] = CoordLength - 1;
        }
        else
        {
            PlayerData[id][PC_Current] -= 1;
        }
        ReadCoord(id , output);
    }

}

public ReadCoord(const id , Float:output[PositionInfo])
{
    new current = PlayerData[id][PC_Current];
    CopyF(output , PlayerCoords[id][current] , PositionInfo);
}

public TPMenu(const id)
{
    if (get_pcvar_num(cvar_tl_enable_tp) == true)
    {
        play_soundeffect(id , SE_OpenMenu);
        new menu = menu_create("[雙葉]:禁忌的魔法..." , "TPMenuHandler");
        menu_additem(menu , "记录存点");
        menu_additem(menu , "读取存点");
        menu_additem(menu , "读取上一个存点");
        menu_addtext(menu , get_pcvar_num(cvar_tl_enable_push) ? "\dTP作弊[已开启]" : "\dTP作弊[已关闭]");
        menu_display(id , menu);
    }
}

public TPMenuHandler(const id , menu , item)
{
    new Float:positioninfo[PositionInfo];
    switch (item)
    {
        case 0:
        {
            RecordCoord(id , positioninfo);
        }
        case 1:
        {
            ReadCoord(id , positioninfo);
            set_pev(id , pev_origin , positioninfo[PI_Position]);
            set_pev(id , pev_angles , positioninfo[PI_Forward]);
            if (get_pcvar_num(cvar_tl_tp_save_velocity) == 0)
            {
                set_pev(id , pev_velocity , {0.0 , 0.0 , 0.0});
            }
        }
        case 2:
        {
            ReadLast(id , positioninfo);
            set_pev(id , pev_origin , positioninfo[PI_Position]);
            set_pev(id , pev_angles , positioninfo[PI_Forward]);
            if (get_pcvar_num(cvar_tl_tp_save_velocity) == 0)
            {
                set_pev(id , pev_velocity , {0.0 , 0.0 , 0.0});
            }
        }
    }
    if (item <= 2 && item >= 0)
    {
        TPMenu(id);
    }
    menu_destroy(menu);
}

//右键推人
new checkcrowbar2[33];

public fw_TraceAttack(ent, attacker, Float:Damage, Float:fDir[3], ptr, iDamageType)
{
	if (!is_user_alive(attacker))
	{
		return 1;
	}
	if (!is_user_alive(ent))
	{
		return 1;
	}
	if (checkcrowbar2[attacker] && get_user_weapon(attacker) == CSW_KNIFE && get_pcvar_num(cvar_tl_enable_push) == true)
	{
		new Float:vec[3] = 0.0;
		new Float:origin1[3] = 0.0;
		new Float:origin2[3] = 0.0;
		pev(ent, pev_origin , origin1);
		pev(attacker, pev_origin, origin2);
		xs_vec_sub(origin1, origin2, vec);
		xs_vec_div_scalar(vec, floatdiv(vector_length(vec), 500.0), vec);
		set_pev(ent, pev_velocity, vec);
		return 4;
	}
	return 1;
}

public CrowbarAttack2_Check_Post(ent)
{
	if (!pev_valid(ent))
	{
		return 0;
	}
	new id = pev(ent, pev_owner);
	checkcrowbar2[id] = 0;
	return 0;
}

public CrowbarAttack2_Check_Pre(ent)
{
	if (!pev_valid(ent))
	{
		return 0;
	}
	new id = pev(ent, pev_owner);
	checkcrowbar2[id] = 1;
	return 0;
}

//服务器重启
new PlayerVote[32];
new VotePointer = 0;

public VoteRes(id)
{
    new speakinfo[128];
	for (new i = 0;i < VotePointer; i ++)
	{
		if (PlayerVote[i] == id)
		{
			new Name[32];
			get_user_team(id , Name , 32);
            formatex(speakinfo , 128 , "^4[投票]^3%s ^1你已经投票重启过了!" , Name);
            client_print_color(0 , id , speakinfo);
			return  PLUGIN_HANDLED;
		}
	}
	new Players[32];
	new PlayerCount;
	get_players(Players , PlayerCount , "" , "")
	VotePointer += 1;
	PlayerVote[VotePointer] = id;
    
    formatex(speakinfo , 128 , "^4[投票]^1现在一共有 ^4%d ^1票支持投票重启!" , VotePointer);
	client_print_color(0 , id , speakinfo);
	if (VotePointer * 2 >= PlayerCount)
	{
        client_print_color(0 , id , "^4[投票] ^1正在重启...");
		server_cmd("sv_restart 1");
        VotePointer = 0;
	}
}

//语音菜单
new Float:LastVoiceTime[33];
new Float:VoiceDuration = 0.5;

new LastVoicePage[33];

public VoiceMenu(id)
{
    play_soundeffect(id , SE_OpenMenu);
    new menu = menu_create("语音列表" , "VoiceHandler");
    for (new i = 0;i < VoiceCount;i ++)
    {
        new voiceinfo[128];
        formatex(voiceinfo , 128 , "[%d]%s" , VoiceItems[i][VI_Count] , VoiceItems[i][VI_Name]);
        menu_additem(menu , voiceinfo);
    }
    menu_display(id , menu , LastVoicePage[id]);
}

public VoiceHandler(id , menu , item)
{
    new Float:nowtime = get_gametime();
    if (nowtime - LastVoiceTime[id] >= VoiceDuration)
    {
        LastVoiceTime[id] = nowtime;
        menu_destroy(menu);
        LastVoicePage[id] = item / 5;
        if (item >= 0)
        {
            EmitVoice(id , item);
            VoiceMenu(id);
        }
    }
    else
    {
	    client_print_color(id , id , "^4[语音] ^1还有 ^4%.4f ^1秒才能使用" , nowtime - LastVoiceTime[id]);
        VoiceMenu(id);
    }
    LastVoicePage[id] = item / 5;
}

public EmitVoice(id , const voice_pos)
{
    if (voice_pos >= 0 && voice_pos < VoiceCount)
    {
        emit_sound(id, CHAN_AUTO, VoiceItems[voice_pos][VI_Path], VOL_NORM, 0.001, 0, PITCH_NORM);
        VoiceItems[voice_pos][VI_Count] += 1;
        new name[32];
        get_user_name(id , name , 32);
        client_print_color(0 , id , "^4[语音]^3%s ^1%s" , name , VoiceItems[voice_pos][VI_Name]);
    }
}

//帮助
new HelpText[6][128] = {
    "欢迎加入双叶公园QQ群 :1098491779",
    "按下 Y 输入 menu 打开服务器菜单",
    "按下 Y 输入 help 打开TTT帮助信息",
    "按下 Y 输入 /task 启动你画我猜",
    "按下 Y 输入 /next 跳过当前你画我猜",
    "按下 U 输入 你画我猜的答案"
};

enum _:ModHelp
{
    MH_DrawGuess,
    MH_TTT,
    HM_Ghost,
}

public ShowHelp(id)
{
    client_print_color(id , id , "^4[雙葉]:^1% s" , HelpText[random_num(0, 2)] );
}


public FastMessage(id)
{

}