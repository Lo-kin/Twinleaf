#if (defined(_twinleaf_included))
	#endinput
#endif
#define _twinleaf_included

enum _:LotteryAwards
{
    LA_Gray,
    LA_White,
    LA_Gold,
    LA_Scarlet
}

enum _:ItemData
{
    ID_ID,
    ID_Name[64],
    ID_Price,
    ID_Quality,
	ID_V_Model[128],
	ID_P_Model[128]
}

enum _:ItemType
{
    IT_Player,
	IT_Knife,
	IT_Usp,
    IT_Title
}

enum _:ItemStack
{
	IS_Count,
    IS_Default[ItemData],
	IS_List[128],//enum not support 2-d array,so instead quote
};

enum _:UserData
{
    UD_SteamID[255],
    UD_GameName[32],
    UD_Experience,
    UD_LeafCoin,
    UD_SignInTime[64],
    UD_OnlineTime,
    UD_StorageCount,
    UD_StorageItems[1024],
    bool:UD_IsConnected,
    UD_KnifeData[ItemData],
    UD_UspData[ItemData],
	UD_PlayerData[ItemData],
    UD_TitleData[ItemData],
    UD_MatchData[256],
    UD_UserTitle[32]
};

enum _:SoundEffct
{
    SE_Lottery_Process,
    SE_Gain_Item,
    SE_OpenMenu,
    SE_StartUp,
    SE_Equip,
    SE_Cost_Money,
    SE_Gain_Money,
    SE_Game_Fail,
    SE_Send_Message
}

enum _:VoiceItem
{
    VI_Path[64],
    VI_Name[64],
    VI_Count,
}

enum _:UserTitle
{
    UT_ID,
    UT_Price,
    UT_Title[32],
    UT_Special,
    UT_SpecialID[64],
}

native show_mma_list(const id);

native show_mma_config(const id);

native broadcast_bgm(const id , bgm);

native get_userinfo(const id , output[]);

native get_user_sign_time(const id , output[]);
//-----------
native get_user_LeafCoin(const id);

native set_user_LeafCoin(const id ,const value);

native set_user_LeafCoin_delta(const id , const delta);
//----------
native get_user_OnlineTime(const id);

native set_user_OnlineTime(const id ,const value);

native set_user_OnlineTime_delta(const id , const delta);
//-----------
native get_user_Experience(const id);

native set_user_Experience(const id ,const value);

native set_user_Experience_delta(const id , const delta);
//-------------

//mt = ItemType(enum)
native get_model(const pos , out[ItemData] ,const mt);

native get_model_by_id(const id , out[ItemData] ,const mt);

native get_model_count(const mt);

//return count
native get_user_items(const id , out[] ,const mt);

native get_user_current_model(const id , out[ItemData] ,const mt);

native add_user_item(const id ,const wpid ,const mt);

native set_user_current_model(const id , const wpid ,const mt);

native get_if_user_has_item(const id , const mdid ,const mt);

native user_purchase_item(const id ,const mdid ,const mt);

//USE SoundEffct Enum
native play_soundeffect(const id , const se);

native tl_utils(const id);
