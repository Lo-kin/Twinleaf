#include <amxmodx>
#include <fakemeta>	
#include <cstrike>
#include <engine>
#include <Twinleaf>
#include <sqlx>
#include <json>
#include <engine>

enum _:IntField
{
    IF_LeafCoin,
    IF_OnlineTime,
    IF_Experience
}
new UserDataField[IntField][32] = {"LeafCoin" , "OnlineTime" , "Exp"};

new JsonObjectNames[4][] = {
    "player",
    "knife",
    "usp",
    "title"
};

new SoundRootPath[32] = "sound/Twinleaf/SE";
new SoundResource[SoundEffct][32] = {"lottery_process.wav" , "gain_item.wav" , "agree.wav" , "startup.wav" , "equip.wav" , "cost_money.wav" , "gain_money.wav" , "fail.wav" , "send_message.wav"};

new CurrentPlayers[32][UserData];
new ModelStorage[ItemType][ItemStack];
new ModelStacks[512][ItemData];
new g_ModelCount = 0;

new Handle:g_SqlTuple;

public plugin_init()
{
    register_plugin("Twinleaf 模型", "1.0.0", "Tredam" , "github.com/Lo-kin" , "双叶后台数据管理");

    //register_clcmd("say test" , "LotteryBegin" , -1 , "");
    //register_clcmd("say testlo" , "OnLottery" , -1 , "");
    InitItemData(-1 , 0 , "默认" , "models/ttt/v_crowbar.mdl" , "models/ttt/p_crowbar.mdl" , ModelStorage[ IT_Knife][IS_Default]);
    InitItemData(-1 , 0 , "默认" , "models/v_usp.mdl" , "models/p_usp.mdl" , ModelStorage[IT_Usp][IS_Default]);
    InitItemData(-1 , 0 , "默认" , "models/player/gsg9/gsg9.mdl" , "gsg9" , ModelStorage[IT_Player][IS_Default])
    InitItemData(-1 , 0 , "默认" , "" , "" , ModelStorage[IT_Title][IS_Default])

    for (new i = 0; i < 32; i++)
    {
        CurrentPlayers[i][UD_IsConnected] = false;
        UpdateUserItemDataByPos(i ,ModelStorage[IT_Usp][IS_Default] , IT_Usp);
        UpdateUserItemDataByPos(i ,ModelStorage[IT_Knife][IS_Default] , IT_Knife);
    }
    //InitQualityItem();
}

public plugin_natives()
{
    register_native("get_userinfo" , "native_GetUserInfo");

    register_native("get_user_sign_time" , "native_GetUserSignTime");
    
    register_native("get_user_LeafCoin" ,       "native_GetUserLeafCoin");
    register_native("set_user_LeafCoin" ,       "native_SetUserLeafCoin");
    register_native("set_user_LeafCoin_delta" , "native_SetUserLeafCoinDelta");

    register_native("get_user_OnlineTime" ,       "native_GetUserOnlineTime");
    register_native("set_user_OnlineTime" ,       "native_SetUserOnlineTime");
    register_native("set_user_OnlineTime_delta" , "native_SetUserOnlineTimeDelta");

    register_native("get_user_Experience" ,       "native_GetUserExperience");
    register_native("set_user_Experience" ,       "native_SetUserExperience");
    register_native("set_user_Experience_delta" , "native_SetUserExperienceDelta");
    
    register_native("get_model" , "native_GetModel");
    register_native("get_model_by_id" , "native_GetModelByID");
    register_native("get_model_count" , "native_GetModelCount");

    register_native("get_user_items" , "native_GetUserItems");
    register_native("add_user_item" , "native_AddUserModelItem");

    register_native("get_user_current_model" , "native_GetUserCurrentModel");
    register_native("set_user_current_model" , "native_SetUserModelPrimary");

    register_native("get_if_user_has_item" , "native_GetIfUserHasItem");
    
    register_native("user_purchase_item" , "native_PurchaseItem");

    register_native("play_soundeffect" , "native_PlaySoundEffect");
}

public plugin_precache()
{
    g_SqlTuple = SQL_MakeDbTuple("127.0.0.1" , "root" , "caibinxx" , "Twinleaf");
    new g_Error[512];
    new ErrorCode,Handle:SqlConnection = SQL_Connect(g_SqlTuple,ErrorCode,g_Error,511)
    new Handle:Queries[4]

    SQL_SetCharset(g_SqlTuple , "utf8");
    SQL_SetCharset(SqlConnection , "utf8");
    
    new mapname[32];
	get_mapname(mapname, 31);
    new entity_count = 0;
	new JSON:ReadFromFile = json_parse("map_entity_count.json" , true);
	if (ReadFromFile == Invalid_JSON)
	{
		json_free(ReadFromFile);
		console_print(-1 , "failed to parse map entity count");
	}
	else
	{
		entity_count = json_object_get_number(ReadFromFile , mapname);
		json_free(ReadFromFile);
	}
    new last;
    new start;
    entity_count = 512 - 220 - entity_count;

    precache_model("models/ttt/v_crowbar.mdl");

    for (new i = 0;i < SoundEffct;i ++)
    {
        new path[64];
        GetSoundPath(i , path);
        precache_generic(path);
    }

    Queries[0] = SQL_PrepareQuery(SqlConnection,"SELECT * FROM PlayerModel");
    Queries[1] = SQL_PrepareQuery(SqlConnection,"SELECT * FROM KnifeModel");
    Queries[2] = SQL_PrepareQuery(SqlConnection,"SELECT * FROM UspModel");
    Queries[3] = SQL_PrepareQuery(SqlConnection,"SELECT * FROM UserTitle");

    for(new Count;Count < ItemType;Count++)
    {
        if(!SQL_Execute(Queries[Count]))
        {
            // if there were any problems
            SQL_QueryError(Queries[Count],g_Error,511)
            set_fail_state(g_Error)
        }
        else
        {
            new m_id;
            new price;
            new name[255];
            new vm_path[255];
            new pm_path[255];
            new mt = Count;
            new Handle:Query = Queries[mt];
            while (SQL_MoreResults(Query) != 0 && (entity_count > 0 || mt == IT_Title))
            {
                
                m_id = SQL_ReadResult(Query , 0);
                SQL_ReadResult(Query , 1 , name , 255);
                ModelStacks[g_ModelCount][ID_Quality] = SQL_ReadResult(Query , 2);
                price = SQL_ReadResult(Query , 3);
                SQL_ReadResult(Query , 4 , vm_path , 255);
                SQL_ReadResult(Query , 5 , pm_path , 255);
                new c_count = ModelStorage[mt][IS_Count];
                ModelStorage[mt][IS_List][c_count] = g_ModelCount;
                if (Count == 3)
                {
                    InitItemData(m_id , price , name , vm_path , "" , ModelStacks[g_ModelCount]);
                }
                else
                {
                    last = precache_model(vm_path);
                    entity_count -= 1;
                    //precache_model(pm_path);
                    InitItemData(m_id , price , name , vm_path , pm_path, ModelStacks[g_ModelCount]);
                }
                g_ModelCount += 1;
                ModelStorage[mt][IS_Count] += 1;
                SQL_NextRow(Query);
            }
        }
        SQL_FreeHandle(Queries[Count]);
    }
    console_print(-1 , "precached %d model" , last - start);
    
    SQL_FreeHandle(SqlConnection);
}

public InitItemData(id , price , name[] , modelv[] , modelp[] , out[ItemData])
{
    out[ID_ID] = id;
    out[ID_Price] = price;
    copy(out[ID_Name] , 64 , name);
    copy(out[ID_V_Model] , 128 , modelv);
    copy(out[ID_P_Model] , 128 , modelp);
}

public CopyItemData(dest[] , source[])
{
    dest[ID_ID] = source[ID_ID];
    dest[ID_Price] = source[ID_Price];
    copy(dest[ID_Name] , 64 , source[ID_Name]);
    copy(dest[ID_V_Model] , 128 , source[ID_V_Model])
    copy(dest[ID_P_Model] , 128 , source[ID_P_Model])
}

public UpdateUserItemData(id , data[ItemData] , ItemType)
{
    UpdateUserItemDataByPos(GetUserPosition(id) , data , ItemType);
}

public UpdateUserItemDataByPos(pos , data[ItemData] , it)
{
    if (pos >= 0 && pos < 32)
    {
        if (it >= 0 && it < ItemType)
        {
            CopyItemData(CurrentPlayers[pos][UD_KnifeData + it * ItemData] , data);
        }
    }
}

public GetSoundPath(se , path[])
{
    if (se >= 0 && se < SoundEffct)
    {
        formatex(path , 64 , "%s/%s" , SoundRootPath , SoundResource[se]);
        return true;
    }
    return false;
}

public PlaySound(id , se)
{
    if (se >= 0 && se < SoundEffct)
    {
        new path[64];
        GetSoundPath(se , path);
        client_cmd(id , "spk %s" , path);
        return true;
    }
    else if (id == 0)
    {
        new path[64];
        GetSoundPath(se , path);
        new players[32];
        new playercount;
        get_players(players , playercount);
        for (new i = 0; i < playercount;i ++)
        {   
            client_cmd(players[i] , "spk %s" , path);
        }
        return true;
    }
    return false;
}

//Native Start
public native_GetUserLeafCoin(plugin, params)
{
    if (params == 1)
    {
        return GetLeafCoin(get_param(1));
    }
    return -1;
}

public native_SetUserLeafCoin(plugin, params)
{
    if (params == 2)
    {
        SetLeafCoin(get_param(1) , get_param(2));
        return true;
    }
    return false;
}

public native_SetUserLeafCoinDelta(plugin, params)
{
    if (params == 2)
    {
        DeltaLeafCoin(get_param(1) , get_param(2));
        return true;
    }
    return false;
}

public native_GetUserExperience(plugin, params)
{
    if (params == 1)
    {
        return GetExperience(get_param(1));
    }
    return -1;
}

public native_SetUserExperience(plugin, params)
{
    if (params == 2)
    {
        SetExperience(get_param(1) , get_param(2));
        return true;
    }
    return false;
}

public native_SetUserExperienceDelta(plugin, params)
{
    if (params == 2)
    {
        DeltaExperience(get_param(1) , get_param(2));
        return true;
    }
    return false;
}


public native_GetUserOnlineTime(plugin, params)
{
    if (params == 1)
    {
        return GetOnlineTime(get_param(1));
    }
    return -1;
}

public native_SetUserOnlineTime(plugin, params)
{
    if (params == 2)
    {
        SetOnlineTime(get_param(1) , get_param(2));
        return true;
    }
    return false;
}

public native_SetUserOnlineTimeDelta(plugin, params)
{
    if (params == 2)
    {
        DeltaOnlineTime(get_param(1) , get_param(2));
        return true;
    }
    return false;
}

public native_GetUserSignTime(plugin, params)
{
    if (params == 2)
    {
        new pos =  GetUserPosition(get_param(1));
        if (pos != -1)
        {
            new signtime[64];
            copy(signtime , 64 , CurrentPlayers[pos][UD_SignInTime]);
            set_array(2 , signtime , 64);
            return true;
        }
    }
    return false;
}

public native_GetUserInfo(plugin, params)
{
    if (params == 2)
    {
        new pos =  GetUserPosition(get_param(1));
        if (pos != -1)
        {
            set_array(2 , CurrentPlayers[pos] , UserData);
            return 1;
        }
    }
    return -1;
}

public native_GetUserItems(plugin, params)
{
    if (params == 3)
    {
        new id = get_param(1);
        new mt = get_param(3)
        new model_list[256];
        new model_count;
        model_count = GetUserItems(id , model_list , mt);
        set_array(2 , model_list , 256);
        return model_count;
    }
    return -1;
}

public native_GetModel(plugin, params)
{
    if (params == 3)
    {
        new pos = get_param(1);
        new mt = get_param(3);
        new item[ItemData];
        GetModel(mt , pos , item);
        set_array(2 , item , ItemData);
        return true;
    }
    return false;
}

public native_GetModelByID(plugin, params)
{
    if (params == 3)
    {
        new id = get_param(1);
        new mt = get_param(3);
        new pos = GetModelPos(id , mt);
        if (pos != -1)
        {
            set_array(2 , ModelStacks[ModelStorage[mt][IS_List][pos]] , ItemData);
            return true;
        }
    }
    return false;
}

public native_GetModelCount(plugin, params)
{
    if (params == 1)
    {
        new mt = get_param(1);
        return ModelStorage[mt][IS_Count];
    }
    return -1;
}

public native_GetUserCurrentModel(plugin, params)
{
    if (params == 3)
    {
        new id = get_param(1);
        new mt = get_param(3);
        new pos = GetUserPosition(id);
        if (pos != -1)
        {
            set_array(2 , CurrentPlayers[pos][ItemData * mt + UD_KnifeData] , 256);
        }
        return true;
    }
    return false;
}

public native_AddUserModelItem(plugin, params)
{
    if (params == 3)
    {
        new id = get_param(1);
        new mt = get_param(3);
        new model_id = get_param(2);
        AddUserModelItem(id , model_id , mt);
    }
}

public native_SetUserModelPrimary(plugin, params)
{
    if (params == 3)
    {
        new id = get_param(1);
        new model_id = get_param(2);
        new mt = get_param(3);
        SetUserModelPrimary(id , model_id , mt);
    }
}

public native_GetIfUserHasItem(plugin, params)
{
    if (params == 3)
    {
        new id = get_param(1);
        new mdid = get_param(2);
        new mt = get_param(3);
        return GetIfUserHasItem(id , mdid , mt);
    }
    return false;
}

public native_PurchaseItem(plugin, params)
{
    if (params == 3)
    {
        new id = get_param(1);
        new mdid = get_param(2);
        new mt = get_param(3);
        return PurchaseItem(id , mdid , mt);
    }
    return false;
}

public native_PlaySoundEffect(plugin, params)
{
    if (params == 2)
    {
        new id = get_param(1);
        new se = get_param(2);
        return PlaySound(id , se);
    }
    return false;
}
//Native End

public GetModel(const mt ,const mdpos , output[])
{
    if (mt >= 0 && mt < ItemType)
    {
        if (mdpos >= 0 && mdpos < ModelStorage[mt][IS_Count])
        {
            CopyItemData(output , ModelStacks[ModelStorage[mt][IS_List][mdpos]]);
            return 1;
        }
        else
        {
            CopyItemData(output , ModelStorage[mt][IS_Default]);
        }
    }
    return -1;
}

public GetItemPos(id , mt)
{
    for (new i = 0 ;i < ModelStorage[mt][IS_Count];i ++)
    {
        if (ModelStacks[ModelStorage[mt][IS_List][i]][ID_ID] == id)
        {
            return i;
        }
    }
    return -1;
}

public GetUserPosition(id)
{
    new steamid[256];
    get_user_authid(id , steamid , 256);
    for (new i = 0; i < 32; i++)
    {
        if (equali(steamid , CurrentPlayers[i][UD_SteamID]) == true)
        {
            return i;
        }
    }
    return -1;
}

public GetEmptyPosition(id)
{
    for (new i = 0; i < 32; i++)
    {
        if (CurrentPlayers[i][UD_IsConnected] == false)
        {
            return i;
        }
    }
    return -1;
}

public client_putinserver(id)
{
    new pos = GetEmptyPosition(id);
    new steamid[256];
    get_user_authid(id , steamid , 256);
    new name[32];
    get_user_name(id , name , 32);
    client_print_color(0 , id , "^4[OMO] ^3%s ^1加入了游戏......" , name)
    GetUserData(id);
    if (pos != -1)
    {
        copy(CurrentPlayers[pos][UD_SteamID] , 32 , steamid); 
        CurrentPlayers[pos][UD_IsConnected] = true;
    }
}

public client_disconnected(id)
{
    new steamid[256];
    get_user_authid(id , steamid , 256);
    new pos = GetUserPosition(id);
    if (pos != -1)
    {
        CurrentPlayers[pos][UD_IsConnected] = true;
        for (new mt = 0;mt < ItemType;mt ++)
        {
            UpdateUserItemDataByPos(pos ,ModelStorage[mt][IS_Default] , mt);
        }
    }
}

public LoadUserInfo(Handle:Query , id)
{
    if (SQL_MoreResults(Query) == 0)
    {
        console_print(-1 , "Load User Info Failed.");
    }
    else
    {
        new steamid[128];
        new userip[128];
        new signtime[64];
        new itemdata[2048];
        new onlinetime;
        new lm;
        new exp;
        SQL_ReadResult(Query , 0 , steamid , 128);
        SQL_ReadResult(Query , 2 , userip , 128);
        lm = SQL_ReadResult(Query , 4);
        SQL_ReadResult(Query , 5 , signtime , 64);
        onlinetime = SQL_ReadResult(Query , 6);
        SQL_ReadResult(Query , 8 , itemdata , 2048);
        exp = SQL_ReadResult(Query , 9);
        new players[32];
        new playercount;
        get_players(players , playercount);
        new pos = GetUserPosition(id);
        if (pos != -1)
        {
            CurrentPlayers[pos][UD_LeafCoin] = lm;
            copy(CurrentPlayers[pos][UD_SignInTime] , 64 , signtime);
            copy(CurrentPlayers[pos][UD_StorageItems] , 2048 , itemdata);
            CurrentPlayers[pos][UD_OnlineTime] = onlinetime;
            CurrentPlayers[pos][UD_Experience] = exp;
            LoadUserPrimary(id , itemdata);            
        }
    }
}

public PurchaseItem(id , mdid , mt)
{
    new item_data[ItemData];
    if (GetModel(mt , mdid , item_data) == -1)
    {
        return false;
    }
	new name[32];
	get_user_name(id , name , 32);
	if (GetIfUserHasItem(id , item_data[ID_ID] , mt) == true)
	{
		SetUserModelPrimary(id , item_data[ID_ID] , mt);
        return true;
	}
	else
	{
        new userLeaf;
        if (mt == IT_Title)
        {
            userLeaf = GetExperience(id);
        }
        else
        {
            userLeaf = GetLeafCoin(id);
        }
		if (userLeaf >= item_data[ID_Price])
		{
			DeltaLeafCoin(id , -item_data[ID_Price]);
			AddUserModelItem(id , item_data[ID_ID] , mt);
			SetUserModelPrimary(id , item_data[ID_ID] , mt);
			client_print_color(0 , id , "^4[雙葉]:^1富哥 ^3%s ^1花 ^4%d ^1购买了 ^4%s" , name , item_data[ID_Price] , item_data[ID_Name]);
            return true;
		}
		else
		{
			client_print_color(id ,id , "^4[雙葉]:^1你的钱似乎不够买这个 ^4(%d/%d) (切)" , userLeaf ,item_data[ID_Price]);
            return false;
		}
	}
    return false;
}

public bool:SetExperience(id , value)
{
    new pos = GetUserPosition(id);
    if (pos != -1)
    {
        CurrentPlayers[pos][UD_Experience] = value;
        SetUserDataInt(id , value , IF_Experience);
        return true
    }
    return false;
}

public bool:DeltaExperience(id , delta)
{
    new pos = GetUserPosition(id);
    client_print_color(id , print_team_grey , "^4[雙葉]:^1Exp ^3%d ^1-> ^3%d ^3[%d]" , CurrentPlayers[pos][UD_Experience] , CurrentPlayers[pos][UD_Experience] + delta , delta);
    if (pos != -1)
    {
        return SetExperience(id , CurrentPlayers[pos][UD_Experience] + delta);
    }
}

public bool:SetOnlineTime(id , value)
{
    new pos = GetUserPosition(id);
    if (pos != -1)
    {
        CurrentPlayers[pos][UD_OnlineTime] = value;
        SetUserDataInt(id , value , IF_OnlineTime);
        return true
    }
    return false;
}

public bool:DeltaOnlineTime(id , delta)
{
    new pos = GetUserPosition(id);
    if (pos != -1)
    {
        return SetOnlineTime(id , CurrentPlayers[pos][UD_OnlineTime] + delta);
    }
}

public bool:SetLeafCoin(id , value)
{
    new pos = GetUserPosition(id);
    if (pos != -1)
    {
        CurrentPlayers[pos][UD_LeafCoin] = value;
        SetUserDataInt(id , value , IF_LeafCoin);
        return true;
    }
    return false;
}

public bool:DeltaLeafCoin(id , delta)
{
    new pos = GetUserPosition(id);
    if (pos != -1)
    {
        client_print_color(id , print_team_red , "^4[雙葉]:^1LeafCoin ^3%d ^1-> ^3%d ^3[%d]" , CurrentPlayers[pos][UD_LeafCoin] , CurrentPlayers[pos][UD_LeafCoin] + delta , delta);
        if (SetLeafCoin(id , CurrentPlayers[pos][UD_LeafCoin] + delta) == true)
        {
            if (delta >= 0)
            {
                PlaySound(id , SE_Gain_Money);
            }
            else
            {
                PlaySound(id , SE_Cost_Money);
            }
            return true;
        }
    }
    return false;
}

public GetLeafCoin(id)
{
    new pos = GetUserPosition(id);
    if (pos != -1)
    {
        return CurrentPlayers[pos][UD_LeafCoin];
    }
    return -1;
}

public GetOnlineTime(id)
{
    new pos = GetUserPosition(id);
    if (pos != -1)
    {
        return CurrentPlayers[pos][UD_OnlineTime];
    }
    return -1;
}

public GetExperience(id)
{
    new pos = GetUserPosition(id);
    if (pos != -1)
    {
        return CurrentPlayers[pos][UD_Experience];
    }
    return -1;
}

public Register(id)
{
    new steamid[128];
    new gamename[32];
    new password[32] = "test";
    new userip[128];
    get_user_authid(id ,steamid ,128);
    get_user_name(id , gamename , 32);
    get_user_ip(id , userip ,128);
    new QueryCache[512];
    formatex(QueryCache , 512 , "INSERT INTO UserInfo (SteamID, GameName, Pwd , LogIP , OnlineTime , OnlineState , Exp) VALUES ('%s','%s','%s','%s', %d, %d , %d);" , steamid , gamename , password , userip , 0 , 0 , 0);
    SQL_ThreadQuery(g_SqlTuple ,"SetUserInfoHandle" ,QueryCache);
}

public GetUserData(id)
{
    new steamid[128];
    get_user_authid(id ,steamid ,128);
    new QueryCache[512];
    formatex(QueryCache , 512 , "SELECT * FROM UserInfo WHERE SteamID='%s'", steamid);
    new userid[4];
    formatex(userid , 4 , "%d" , id);
    SQL_ThreadQuery(g_SqlTuple ,"GetUserInfoHandle" ,QueryCache , userid , 4);
}

public SetUserDataInt(id , value , method)
{
    if (method >= 0 && method < IntField)
    {
        new steamid[128];
        get_user_authid(id ,steamid ,128);
        new QueryCache[512];
        formatex(QueryCache , 512 , "UPDATE UserInfo SET %s=%d WHERE SteamID='%s'" , UserDataField[method] , value , steamid);
        SQL_ThreadQuery(g_SqlTuple ,"SetUserInfoHandle" ,QueryCache);
    }
}

public SetUserItemData(id , value[])
{
    new steamid[128];
    get_user_authid(id ,steamid ,128);
    new QueryCache[1024];
    formatex(QueryCache , 1024 , "UPDATE UserInfo SET StorageItems='%s' WHERE SteamID='%s'",value, steamid);
    SQL_ThreadQuery(g_SqlTuple ,"SetUserInfoHandle" ,QueryCache);
}

public SetUserInfoHandle(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
    if (CheckFail(FailState , Error , Errcode) == false)
    {
        return PLUGIN_CONTINUE;
    }
    return PLUGIN_CONTINUE;
}

public GetUserInfoHandle(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
    if (CheckFail(FailState , Error , Errcode) == false)
    {
        return PLUGIN_CONTINUE;
    }
    if (SQL_MoreResults(Query) == 0)
    {
        Register(str_to_num(Data));
    }
    else
    {
        LoadUserInfo(Query , str_to_num(Data));
    }
    return PLUGIN_CONTINUE;
}

public CheckFail(FailState , Error[] , Errcode)
{
    if(FailState == TQUERY_CONNECT_FAILED)
    {
        console_print(-1 , "Could not connect to SQL database.");
        return false;
    }
    else if(FailState == TQUERY_QUERY_FAILED)
    {
        console_print(-1 , "Query failed.");
        return false;
    }
    if(Errcode)
    {
        console_print(-1 , "Error on query: %s",Error);
        return false;
    }
    return true;
}

//JSON 库存
public GetUserCurrentModel(id , mt)
{
    new pos = GetUserPosition(id);
    new num;
    if (pos != -1)
    {
        new JSON:Root = json_parse(CurrentPlayers[pos][UD_StorageItems] , false);
        if (CheckUserStorageVaild(id , Root) == true)
        {
            new object_name[32] = "";
            format(object_name , 32 , "current_%s" , JsonObjectNames[mt]);
            num = json_object_get_number(Root , object_name);
        }
        json_free(Root);
    }
    return num;
}

public GetUserItems(id , item[] , mt)
{
    new pos = GetUserPosition(id);
    new count = -1;
    new JSON:Root = json_parse(CurrentPlayers[pos][UD_StorageItems] , false);
    if (CheckUserStorageVaild(id , Root) == false)
    {
        return count;
    }
	else
	{
        new JSON:model_origin = json_object_get_value(Root ,JsonObjectNames[mt]);
        if (model_origin != Invalid_JSON)
		{
            count = json_array_get_count(model_origin);
            for (new i = 0; i < count;i ++)
            {
                item[i] = json_array_get_number(model_origin , i);
            }
        }
        json_free(model_origin);
        json_free(Root);
    }
    return count;
}

public AddUserModelItem(id , item , mt)
{
    new pos = GetUserPosition(id);
    new JSON:Root = json_parse(CurrentPlayers[pos][UD_StorageItems] , false);
    if (CheckUserStorageVaild(id , Root) == false)
    {
        return PLUGIN_CONTINUE;
    }
	else
	{
        new JSON:model_origin = json_object_get_value(Root , JsonObjectNames[mt]);
        json_array_append_number(model_origin , item);
        json_object_set_value(Root , JsonObjectNames[mt] , model_origin);

        json_serial_to_string(Root , CurrentPlayers[pos][UD_StorageItems] , 2048);
		json_free(model_origin);
        json_free(Root);
        SetUserItemData(id ,CurrentPlayers[pos][UD_StorageItems]);
	}
    return PLUGIN_CONTINUE;
}

public SetUserModelPrimary(id , wp_id , mt)
{
    new pos =  GetUserPosition(id);
    if (pos != -1)
    {
        new JSON:Root = json_parse(CurrentPlayers[pos][UD_StorageItems] , false);
        if (CheckUserStorageVaild(id , Root) == false)
        {
            return PLUGIN_CONTINUE;
        }
        else
        {
            new object_name[32] = "";
            format(object_name , 32 , "current_%s" , JsonObjectNames[mt]);
            json_object_set_number(Root , object_name , wp_id);
            json_serial_to_string(Root , CurrentPlayers[pos][UD_StorageItems] , 2048);
            json_free(Root);
            SetUserItemData(id ,CurrentPlayers[pos][UD_StorageItems]);
            new wp_pos = GetModelPos(wp_id , mt);
            UpdateUserItemDataByPos(pos ,ModelStacks[ModelStorage[mt][IS_List][wp_pos]] , mt);
            client_print_color(id ,id , "^4[雙葉]: ^3%s ^1给你装备好了" , ModelStacks[ModelStorage[mt][IS_List][wp_pos]][ID_Name]);
            PlaySound(id , SE_Equip);
        }
    }
    return PLUGIN_CONTINUE;
}

public LoadUserPrimary(id , buffer[])
{
    new pos =  GetUserPosition(id);
    if (pos != -1)
    {
        new JSON:Root = json_parse(buffer , false);
        if (CheckUserStorageVaild(id , Root) == false)
        {
            return false;
        }
        else
        {
            for (new mt = 0; mt < ItemType;mt ++)
            {
                new object_name[32];
                format(object_name , 32 , "current_%s" , JsonObjectNames[mt]);
                new itemid = json_object_get_number(Root , object_name);
                new md_pos = GetModelPos(itemid , mt);

                new item_data[ItemData];
                GetModel(mt , md_pos , item_data);
                UpdateUserItemDataByPos(pos ,item_data , mt);
                client_print_color(id ,id , "^4[雙葉]: ^3%s ^1给你装备好了" , item_data[ID_Name]);

                if (mt == IT_Player)
                {
                    if (md_pos == -1)
                    {
                        continue;
                    }
                    cs_set_user_model(id , item_data[ID_P_Model] , false);
                }
            }

            json_free(Root);
        }
    }
    return true;
}

public GetModelPos(mdid , mt)
{
    for (new i  = 0 ; i < ModelStorage[mt][IS_Count];i ++)
    {
        if (ModelStacks[ModelStorage[mt][IS_List][i]][ID_ID] == mdid)
        {
            return i;
        }
    }
    return -1;
}

public GetIfUserHasItem(id , mdid , mt)
{
    new model[256];
    new modelcount = GetUserItems(id , model , mt);
    for (new i  = 0 ; i < modelcount;i ++)
    {
        if (model[i] == mdid)
        {
            return true;
        }
    }
    return false;
}

public CreateEmptyStorage(id)
{
    new s_buffer[2048];
	new JSON:Rootjson = json_init_object();
    
    for (new mt = 0 ; mt < ItemType;mt ++)
    {
        new object_current[32];
        copy(object_current , 32 , JsonObjectNames[mt])
        new object_list[32];
        format(object_list , 32 , "current_%s" , object_current);
        new JSON:model_Storage = json_init_array();
        json_object_set_number(Rootjson , object_current , -1);
        json_object_set_value(Rootjson , object_list , model_Storage);
        json_free(model_Storage);
    }

    json_serial_to_string(Rootjson , s_buffer , 2048);
    new pos = GetUserPosition(id);
    copy(CurrentPlayers[pos][UD_StorageItems] ,2048 ,  s_buffer);

    json_free(Rootjson);

    SetUserItemData(id ,s_buffer);
}

public CheckUserStorageVaild(id , JSON:injson)
{
    if (json_get_type(injson) == JSONNull)
    {
        CreateEmptyStorage(id);
        return false;
    }
	if (injson == Invalid_JSON)
	{
		json_free(injson);
		console_print(-1 , "error Item Info");
		return false;
	}
    new needUpdate = 0;
    for (new mt = 0;mt < ItemType;mt ++)
    {
        new object_list[32];
        copy(object_list , 32 , JsonObjectNames[mt])
        new object_current[32];
        format(object_current , 32 , "current_%s" , object_list);
        
        if (json_object_has_value(injson , object_current) == false)
        {
            json_object_set_number(injson , object_current , -1);
            needUpdate = 1;
        }
        if (json_object_has_value(injson , object_list) == false)
        {
            new JSON:usp_Storage = json_init_array();
            json_object_set_value(injson , object_list , usp_Storage);
            json_free(usp_Storage);
            needUpdate = 1;
        }
    }
    if (needUpdate != 0)
    {
        new pos = GetUserPosition(id);
        json_serial_to_string(injson , CurrentPlayers[pos][UD_StorageItems] , 2048);
        SetUserItemData(id ,CurrentPlayers[pos][UD_StorageItems]);
    }
    return true;
}
/*
new LotteryNames[LotteryAwards][32] = {"普通" , "稀有" , "金色" , "猩红"};
new LotteryProbability[LotteryAwards] = {5 , 15 , 25 , 55};

public LotteryBegin(const id)
{
    new lcm = 825;
    new rollrange[LotteryAwards];
    new last = 0;
    for (new i = 0;i < LotteryAwards;i ++)
    {
        rollrange[i] = last + (lcm / LotteryProbability[i]);
        last =  rollrange[i]
    }
    new rolltime = 5;
    new rollresult[LotteryAwards];
    for (new i = 0;i < rolltime; i ++)
    {
        new c_roll = random(1103515245) % (lcm - 1);
        new last = 0;
        for (new i = 0;i < LotteryAwards;i ++)
        {
            if (c_roll >= last && c_roll < rollrange[i])
            {
                rollresult[i] += 1
                break
            }
            last = rollrange[i];
        }
    }
    new maxaward = LA_Gray;
    new maxresult = rollresult[0];
    for (new i = 1;i < LotteryAwards;i ++)
    {
        if (rollresult[i] > maxresult)
        {
            maxresult = rollresult[i];
            maxaward = i;
        }
    }

    new qitems[256];
    new qcount = GetQualityItem(maxaward , qitems);
    new rad = random(qcount - 1);
    new rolleditem = qitems[rad];
    new name[32];
    get_user_name(id , name , 32);




    client_print_color(0 ,id , "^4[雙葉]: ^3%s ^1通过抽奖抽到了 ^3[%s]%s" , name , LotteryNames[maxaward] , ModelStacks[rolleditem][ID_Name]);
    //return qitems[rolleditem];
}

new ItemQualityIndex[LotteryAwards][ItemType][256];
new ItemIndexCounts[LotteryAwards][ItemType];

public InitQualityItem()
{
    for (new i = 0;i < ItemType;i ++)
    {
        for (new j = 0;i < ModelStorage[i][IS_Count];j ++)
        {
            new quality = ModelStacks[ModelStorage[i][IS_List][j]][ID_Quality];
            ItemQualityIndex[quality][i][ItemIndexCounts[quality][i]] = ModelStorage[i][IS_List][j];
            ItemIndexCounts[quality][i]++;
        }
    }
}

public GetQualityItem(const la , const mt , output[256])
{
    if (la >= 0 && la < LotteryAwards)
    {
        for (new i = 0;i < ItemIndexCounts[la];i ++)
        {
            output[i] = ItemQualityIndex[la][i];
        }
        return ItemIndexCounts[la];
    }
    else
    {
        return -1;
    }
}

new lastmenu = -1;
new Float:remaintime = 30.0;
new offset = 0;
new lotterylist[] = {9 , 4 , 2 , 5 , 7 , 3 , 1 , 6};
new displayid = 0;

public OnLottery(id)
{
    remaintime = 30;
    displayid = id;
    lastmenu = menu_create("[雙葉]:\d测试" , "noway");
    LotteryDisplay();
}

public LotteryDisplay()
{
    remaintime--;
    offset = (offset + 1) % 8;
    menu_destroy(lastmenu);
	lastmenu = menu_create("[雙葉]:\d测试" , "noway");
    for (new i = offset;i < 8;i ++)
    {
        new showinfo[32];
        gettext(lotterylist[i] , showinfo);
        menu_additem(lastmenu , showinfo);
    }
    for (new i = 0;i < offset; i ++)
    {
        new showinfo[32];
        gettext(lotterylist[i] , showinfo);
        menu_additem(lastmenu , showinfo);
    }
	menu_display(displayid , lastmenu);
    if (remaintime > 0)
    {
        PlaySound(displayid , SE_Lottery_Process);
        set_task(getrolltime() , "LotteryDisplay" , 3157135 , "" , 0 , "a" , 1);
    }
    else
    {
        PlaySound(displayid , SE_Gain_Item);
        console_print(-1 , "%d" , lotterylist[offset]);
    }
}

public Float:getrolltime()
{
    new a = 1;
    new b = 0.03 - 30 * a;
    return 0.999 * (30 - remaintime) * (30 - remaintime) -29.07  * (30 - remaintime)  + 0.1;
}

public gettext(const num , output[])
{
    if (num >= 8)
    {
        formatex(output , 32 , "\r ------%d------" , num);
    }
    else if (num >= 6)
    {
        formatex(output , 32 , "\y ------%d------" , num);
    }
    else if (num >= 4)
    {
        formatex(output , 32 , "\w ------%d------" , num);
    }
    else
    {
        formatex(output , 32 , "\d ------%d------" , num);
    }
}

public noway(a , b , c)
{

}
*/