#include <Twinleaf>
#include <amxmodx>
#include <fakemeta>	
#include <cstrike>
#include <engine>
#include <hamsandwich>
#include <sqlx>
#include <xs>

#define SHOWQQ_TASK 521734

new bool:tr_open[33];
new tr_select[33];
new tr_lock[33];
new tr_lastmenu[33];

public plugin_init()
{
    register_plugin("Twinleaf 菜单", PluginVersion , PluginAuthor , PluginLink , "双叶服务器菜单");
	register_clcmd("say menu" , "MainMenu");
	register_clcmd("say help" , "ShowMOTD");
	RegisterHam(Ham_Item_Deploy, "weapon_knife", "Ham_Knife_Deploy_post", 1);
	RegisterHam(Ham_Item_Deploy, "weapon_usp", "Ham_Usp_Deploy_post", 1);

	RegisterHam(Ham_Item_AddToPlayer , "weapon_c4" , "GetC4");
    register_event( "ItemStatus" , "GetDefuser" , "b" , "1=2");

	RegisterHamPlayer(Ham_Spawn, "Ham_Spawn_post", 1);
	set_task(45.0, "ShowQQ", SHOWQQ_TASK , "" , 0 ,"b");

	//register_forward(FM_TraceLine, "traceline_forward" , 1);
}

public EntityMenu(id)
{
	tr_open[id] = true;
	new menu = menu_create("实体信息" , "EntityMenuHandeler");
	tr_lastmenu[id] = menu;
	if (tr_select[id] >= 33)
	{
		new entClass[32];
		new entName[32];
		new Float:entPos[3];
		new Float:entOnlyTrigger
		pev(tr_select[id] , pev_classname , entClass , 32);
		pev(tr_select[id] , pev_targetname , entName , 32);

		new Float:entmin[3];
        new Float:entmax[3];
        entity_get_vector(tr_select[id] , EV_VEC_absmin , entmin);
        entity_get_vector(tr_select[id] , EV_VEC_size , entmax);
        xs_vec_add_scaled(entmin , entmax , 0.5 , entPos);

		pev(tr_select[id] , pev_spawnflags , entOnlyTrigger);

		new entMessage[64];
		format(entMessage , 64 , "实体类型:[%s]" , entClass);
		menu_addtext2(menu , entMessage);
		format(entMessage , 64 , "实体名称:[%s]" , entName);
		menu_addtext2(menu , entMessage);
		format(entMessage , 64 , "实体坐标:[%.2f , %.2f , %.2f]" , entPos[0] , entPos[1] , entPos[2]);
		menu_addtext2(menu , entMessage);
		format(entMessage , 64 , "实体仅由其他实体触发:[%f]" , entOnlyTrigger);
		menu_addtext2(menu , entMessage);
		menu_additem(menu , "删除实体");
		menu_additem(menu , "关闭追踪");
	}
	else
	{
		menu_addtext2(menu , "未瞄准到任何实体");
	}
	menu_display(id , menu);
}

public EntityMenuHandeler(id , menu , item)
{
	if (item == 3)
	{
		set_pev(tr_select[id] , pev_spawnflags , 0.0);
	}
	if (item == 4)
	{
		remove_entity(tr_select[id]);
		tr_select[id] = -1;
	}
	if (item == 5)
	{
		tr_open[id] = false
	}
	//menu_destroy(menu);
}

public traceline_forward(Float:start[3], Float:end[3], conditions, id, trace)
{
	if (tr_open[id] == true)
	{
		new hitent = get_tr2(trace , TR_pHit);
		if (hitent != -1 && hitent >= 33)
		{
			menu_destroy(tr_lastmenu[id]);
			tr_select[id] = hitent;
			EntityMenu(id);
		}
	}
} 

public ShowMOTD(id)
{
	show_motd(id, "addons/amxmodx/configs/rules_ttt/test.html", "游戏帮助");
}

public ShowQQ()
{
	client_print_color(0 ,0 , "^4[雙葉]:^1欢迎加入双叶公园QQ群 :^4 1098491779");
	client_print_color(0 ,0 , "^4[雙葉]:^1按下[Y]输入^3menu^1打开服务器菜单");
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

	menu_additem(menu , "管理菜单" , "" , ADMIN_MENU);
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
		case 6:
		{
			if (get_user_flags(id) & ADMIN_MENU)
			{
				AdminMenu(id);
			}
			else
			{
				client_print_color(id , 0 , "^4[雙葉]:^1你没有权限访问管理菜单");
			}
		}
	}
	
	menu_destroy(menu);
}

public AdminMenu(id)
{
	new menu = menu_create("[雙葉]:\d管理员菜单" , "AdminMenuHandler");
	menu_additem(menu , "多模组换图菜单");
	menu_additem(menu , "AMX指令菜单");
	menu_additem(menu , "更改实体属性")
	menu_display(id , menu);
}

public AdminMenuHandler(id , menu , item)
{
	if (item == 0)
	{
		client_cmd(id , "amx_multimod");
	}
	else if (item == 1)
	{
		client_cmd(id , "amxmodmenu");
	}
	else if (item == 2)
	{
		//EntityMenu(id);
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
	menu_additem(menu , "设置所有购买项到默认")
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
	if (item == 0)
	{
		for (new i = 0;i < ItemType;i ++)
		{
			set_user_current_model(id , -1 , i);
		}
		client_print(id , 0 , "全部重置好了")
	}
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
	menu_additem(menu , "购买RPG-7(100exp)");
	menu_additem(menu , "摸摸双叶头");
	menu_display(id , menu);
}

public StoreSelection(id , menu , item)
{
	menu_destroy(menu);
	play_soundeffect(id , SE_OpenMenu);
	if (item >= 0 && item < ItemType)
	{
		PurchaseItemMenu(id , item);
	}
	else if (item == 4)
	{
		/*
		if (get_user_Experience(id) < 100 && true == false)
		{
			client_print_color(id , 0 , "^4[雙葉]:^1经验不足, 无法购买RPG-7");
		}
		else if( callfunc_begin("give_rpg7","weapon_rpg7.amxx") == 1) 
		{
			callfunc_push_int(id);
			callfunc_end();
			set_user_Experience_delta(id , -100);
		}*/
	}
	else if (item == 5)
	{
		new motion = random_num(0 , 10000);
		if (motion >= 9990)
		{
			client_print_color(id , 0 , "^4[雙葉]:^1你摸了摸双叶的头, 双叶超开心");
			set_user_LeafCoin_delta(id , 10000);
		}
		else if (motion >= 9900)
		{
			client_print_color(id , 0 , "^4[雙葉]:^1你摸了摸双叶的头, 双叶很开心");
			set_user_LeafCoin_delta(id , 1000);
		}
		else if (motion >= 9000)
		{
			client_print_color(id , 0 , "^4[雙葉]:^1你摸了摸双叶的头, 双叶有点开心");
			set_user_LeafCoin_delta(id , 1);
		}
		else if (motion >= 8000)
		{
			client_print_color(id , 0 , "^4[雙葉]:^1你摸了摸双叶的头, 双叶有点不开心");
			set_user_LeafCoin_delta(id , -1);
		}
		else if (motion >= 7000)
		{
			client_print_color(id , 0 , "^4[雙葉]:^1你摸了摸双叶的头, 双叶很不开心");
			set_user_LeafCoin_delta(id , -5);
		}
		else if (motion >= 6550)
		{
			client_print_color(id , 0 , "^4[雙葉]:^1你摸了摸双叶的???, 双叶//O//w///O/害羞了");
			set_user_Experience_delta(id , 10);
		}
		else
		{
			client_print_color(id , 0 , "^4[雙葉]:^1你摸了摸双叶的头, 双叶哈气了");
			set_user_LeafCoin_delta(id , -10);
		}
		StoreMenu(id);
	}

	
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