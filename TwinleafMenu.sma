#include <amxmodx>
#include <fakemeta>	
#include <cstrike>
#include <engine>
#include <Twinleaf>
#include <hamsandwich>
#include <sqlx>

#define SHOWQQ_TASK 521734

public plugin_init()
{
    register_plugin("Twinleaf 菜单", "1.0.0", "Tredam" , "github.com/Lo-kin" , "双叶服务器菜单");
	register_clcmd("say menu" , "MainMenu" , -1 , "No test");
	register_clcmd("say help" , "ShowMOTD" , -1 , "No test");
	RegisterHam(Ham_Item_Deploy, "weapon_knife", "Ham_Knife_Deploy_post", 1);
	RegisterHam(Ham_Item_Deploy, "weapon_usp", "Ham_Usp_Deploy_post", 1);

	RegisterHam(Ham_Item_AddToPlayer , "weapon_c4" , "GetC4");
    register_event( "ItemStatus" , "GetDefuser" , "b" , "1=2");

	RegisterHamPlayer(Ham_Spawn, "Ham_Spawn_post", 1);
	set_task(45.0, "ShowQQ", SHOWQQ_TASK , "" , 0 ,"b");
}

public ShowMOTD(id)
{
	show_motd(id, "addons/amxmodx/configs/rules_ttt/test.html", "游戏帮助");
}

public ShowQQ()
{
	client_print_color(0 ,0 , "^4[雙葉]:^1欢迎加入双叶公园QQ群 :^4 1098491779");
}

public MainMenu(id)
{
	play_soundeffect(id , SE_StartUp);
	new Money = get_user_LeafCoin(id);
	new Exp = get_user_Experience(id);
	new name[32];
	get_user_name(id , name , 32);
	new UserInfo[128];
	formatex(UserInfo ,  128 , "\d玩家:\w%s \d叶子币:\y%d \d经验:\r%d " , name , Money , Exp);
	new Title[64];
	formatex(Title , 64 , "[雙葉]:\d你好呀, %s" , name);
	new menu = menu_create(Title , "MainSelection");
	menu_addtext2(menu , UserInfo);
	menu_additem(menu , "我的信息");
	menu_additem(menu , "双叶小卖铺");
	menu_additem(menu , "MP3 菜单");
	menu_additem(menu , "小工具");
	menu_additem(menu , "列出所有服务器");
	menu_setprop(menu , MPROP_EXIT, MEXIT_ALL);
	menu_display(id , menu);
}

public MainSelection(id , menu , item)
{
	play_soundeffect(id , SE_OpenMenu);
	switch (item)
	{
		case 1:
		{
			UserInfoMenu(id);
		}
		case 2:
		{
			StoreMenu(id);
		}
		case 3:
		{
			MP3Menu(id);	
		}
		case 4:
		{
			tl_utils(id);
		}
		case 5:
		{
			ServerMenu(id);
		}

	}
	
	menu_destroy(menu);
}

public UserInfoMenu(id)
{
	new name[32];
	get_user_name(id , name , 32);
	new menutitle[128];
	formatex(menutitle , 128 , "[雙葉]:\d%s , 这是您的信息" , name);

	new menu = menu_create(menutitle , "UserInfoSelection");
	new UserItemData[ItemData];
	new showinfo[128];
	new signtime[64];
	
	get_user_sign_time(id , signtime);
	formatex(showinfo , 128 , "\d注册时间:\w%s" , signtime);
	menu_additem(menu , showinfo);
	formatex(showinfo , 128 , "\d叶子币:\w%d" , get_user_LeafCoin(id));
	menu_additem(menu , showinfo);
	formatex(showinfo , 128 , "\d在线时长:\w%d" , get_user_OnlineTime(id));
	menu_additem(menu , showinfo);
	formatex(showinfo , 128 , "\d经验:\w%d" , get_user_Experience(id));
	menu_additem(menu , showinfo);
	
	get_user_current_model(id ,UserItemData ,  IT_Knife);
	formatex(showinfo , 128 , "\d当前小刀:\w%s" , UserItemData[ID_Name]);
	menu_additem(menu , showinfo);
	get_user_current_model(id ,UserItemData , IT_Usp);
	formatex(showinfo , 128 , "\d当前USP:\w%s" , UserItemData[ID_Name]);
	menu_additem(menu , showinfo);
	get_user_current_model(id ,UserItemData , IT_Player);
	formatex(showinfo , 128 , "\d当前角色:\w%s" ,  UserItemData[ID_Name]);
	menu_additem(menu , showinfo);
	get_user_current_model(id ,UserItemData , IT_Title);
	formatex(showinfo , 128 , "\d当前称号:\w%s" ,  UserItemData[ID_Name]);
	menu_additem(menu , showinfo);
	menu_display(id , menu);
}

public UserInfoSelection(id , menu , item)
{
	menu_destroy(menu);
}

public MP3Menu(id)
{
	new menu = menu_create("MP3 菜单" , "MP3MenuSelection");
	menu_additem(menu , "MP3 列表");
	menu_additem(menu , "MP3 设置");
	menu_display(id , menu);
}

public MP3MenuSelection(id , menu , item)
{
	play_soundeffect(id , SE_OpenMenu);
	switch (item)
	{
		case 0:
		{
			show_mma_list(id);
		}
		case 1:
		{
			show_mma_config(id);
		}
	}
	menu_destroy(menu);
}

public StoreMenu(id)
{
	new menu = menu_create("[雙葉]:\d客官要来点什么" , "StoreSelection");
	menu_additem(menu , "人物模型");
	menu_additem(menu , "小刀模型");
	menu_additem(menu , "USP模型");
	menu_additem(menu , "称号小摊");
	menu_display(id , menu);
}

public StoreSelection(id , menu , item)
{
	play_soundeffect(id , SE_OpenMenu);
	if (item >= 0 && item <= ItemType)
	{
		PurchaseItemMenu(id , item);
	}
	menu_destroy(menu);
}

public PurchaseItemMenu(id , mt)
{
	new auth[64];
	get_user_authid(id , auth , 64);
	new item_count = get_model_count(mt);
	new menu = menu_create("[雙葉]:\d客官要来点什么呢" , "ItemSelection");
	for (new i = 0;i < item_count; i ++)
	{
		new item_data[ItemData];
		get_model(i , item_data , mt);

		new info[128];
		if (get_if_user_has_item(id , item_data[ID_ID] , mt) == true)
		{
			formatex(info , 128 , "%s\d[已购买] \R\y%d" , item_data[ID_Name] , item_data[ID_Price]);
		}
		else
		{
			formatex(info , 128 , "%s \R\y%d" , item_data[ID_Name] , item_data[ID_Price]);
		}
		
		new mtstr[6];
		formatex(mtstr , 6 ,"%d" , mt);
		if (mt == IT_Title)
		{
			if (item_data[ID_Quality] == 1 || strlen( item_data[ID_V_Model]) != 0)
			{
				if (equal(auth , item_data[ID_V_Model]) == false)
				{
					formatex(info , 128 , "\r%d. \d%s[非卖品] \R\y%d" ,i + 1,  item_data[ID_Name] , item_data[ID_Price]);
					menu_addtext2(menu , info);
					continue;
				}
			}
		}
		menu_additem(menu , info , mtstr , 0);	
	}
	menu_display(id , menu);
}

public ItemSelection(id , menu , item)
{
	play_soundeffect(id , SE_OpenMenu);
	if (item >= 0)
	{
		new szData[6], szName[64];
		new _access, item_callback;
		menu_item_getinfo( menu, item, _access, szData,charsmax( szData ), szName,charsmax( szName ), item_callback);

		new mt = str_to_num(szData);
		new bool:buystate = user_purchase_item(id , item , mt);
		if (buystate == true && mt == IT_Player)
		{
			new item_data[ItemData];
			get_model(item , item_data , IT_Player);
			cs_set_user_model(id , item_data[ID_P_Model] , false);
		}
	}
}

public Ham_Spawn_post(id)
{
	if(is_user_alive(id))
	{
		new item_data[ItemData];
		get_user_current_model(id , item_data , IT_Player);
		if (item_data[ID_ID] != -1)
		{
			cs_set_user_model(id , item_data[ID_P_Model] , false);
		}
		set_task(0.1 , "set_all_init");
	}
}

public Ham_Knife_Deploy_post(ent)
{
	if(pev_valid(ent) != 2)
        return
    static id; id = get_pdata_cbase(ent, 41, 4)
    if(get_pdata_cbase(id, 373) != ent)
        return
	new wpdata[ItemData];
	get_user_current_model(id , wpdata ,  IT_Knife);
    set_pev(id, pev_viewmodel2, wpdata[ID_V_Model])
}

public Ham_Usp_Deploy_post(ent)
{
	if(pev_valid(ent) != 2)
        return
    static id; id = get_pdata_cbase(ent, 41, 4)
    if(get_pdata_cbase(id, 373) != ent)
        return
	new wpdata[ItemData];
	get_user_current_model(id , wpdata , IT_Usp);
    set_pev(id, pev_viewmodel2, wpdata[ID_V_Model]) 
}

public get_weapon_owner(ent)
{
	return get_pdata_cbase(ent, 41, 4);
}

public ServerMenu(id)
{
	new menu = menu_create("服务器列表" , "ServerSelection");
	menu_addtext2(menu , "选择服务器连接");
	menu_additem(menu , "4399小游戏  ");
	menu_additem(menu , "TTT匪镇谍影 ");
	menu_setprop(menu , MPROP_EXIT, MEXIT_ALL);
	menu_display(id , menu);
}

public ServerSelection(id , menu , item)
{
	switch (item)
	{
		case 1:
		{
			client_cmd(id, "connect twinleaf.moe:27015");
		}
		case 2:
		{
			client_cmd(id, "connect twinleaf.moe:27020");
		}
	}
	menu_destroy(menu);
}

public GetIfUserHasItem(existlist[] , length , find)
{
    for (new i  = 0 ; i < length;i ++)
    {
        if (existlist[i] == find)
        {
            return true;
        }
    }
    return false;
}

public set_all_init()
{
    new players[32];
    new playercount;
    get_players(players , playercount);
    for (new i = 0;i < playercount;i ++)
    {
        cs_set_user_submodel(players[i] , 0);
    }
}

public GetDefuser(id)
{
    cs_set_user_submodel(id , 0);
}

public GetC4(ent , id)
{
    cs_set_user_submodel(id , 0);
}