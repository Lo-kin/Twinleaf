#include <amxmodx>
#include <engine>
#include <hamsandwich>
#include <fakemeta>	
#include <engine>
#include <xs>
#include <json>
#include <Twinleaf>

#define MAX_CUMEVENTS 256

public plugin_init()
{
    register_plugin("Twinleaf 趣味", "0.0.1", "Tredam" , "github.com/Lo-kin" , "双叶服务器趣味功能");
    register_impulse(100, "OnMarry");
}

enum _:PlayerInfo
{
    PI_CumTimes,
    PI_CumCount,
    PI_BeingCumTimes,
    PI_BeingCumCount,

    PI_BeingCumPart[MAX_BODYHITS],

    Float:PI_LastCumTime,
    Float:PI_CumDuration,

    PI_MarryID,
    bool:PI_OnMarry,
    PI_BeingCumEvents[MAX_CUMEVENTS],
}
new PlayerInfo[33][PlayerInfo];

enum _:CumEvent
{
    CE_Source,
    Float:CE_CumTime,
    CE_CumBodyPart
}

public OnMarry(id)
{
    new aimID;
    new aimBody;
    new Float:aimDistance = get_user_aiming(id , aimID , aimBody);
    if (aimID != 0 && aimBody != 0)
    {
        new targetName[32];
        get_user_name(aimID , targetName , 32);
        MarryMenu(id , aimID);
        client_print_color(id , 0 , "你向 %s 求婚了!" , targetName);
    }
    return PLUGIN_HANDLED;
}

public MarryMenu(source , target)
{
    new sourceName[32];
    get_user_name(source , sourceName , 32);
    new title[48];
    format(title , charsmax(title) , "%s向你求婚! >_<" , sourceName);
    new arg[6];
    format(arg , charsmax(arg) , "%d" , source);
    new menu = menu_create(title , "MarryMenuHandler");
    menu_additem(menu , "接受求婚" , arg);
    menu_additem(menu , "拒绝求婚" , arg);
    menu_setprop(menu , MPROP_EXIT, MEXIT_NEVER);
    menu_display(target , menu);
}

public MarryMenuHandler(target , menu , item)
{
    new szData[6], szName[64];
	new _access, item_callback;
	menu_item_getinfo( menu, item, _access, szData,charsmax( szData ), szName,charsmax( szName ), item_callback);
	new source = str_to_num(szData);

    new sourceName[32];
    get_user_name(source , sourceName , 32);
    new targetName[32];
    get_user_name(target , targetName , 32);
    if (item == 0)
    {
        client_print_color(0 , 0 , "恭喜 %s 和 %s 喜结良缘!" , sourceName , targetName);
    }
    else
    {
        client_print_color(source , 0 , "%s 拒绝了你的求婚!" , targetName);
    }
}

public OnAim(id)
{
    new aimID;
    new aimBody;
    new Float:aimDistance = get_user_aiming(id , aimID , aimBody);

    if (aimID != 0 && aimBody != 0)
    {
        if (aimDistance <= 100.0)
        {
            new SourceName[32];
            get_user_name(id , SourceName , 32);
            new TargetName[32];
            get_user_name(aimID , TargetName , 32);
            client_print_color(id , 0 , "() -> %s %d" , TargetName , aimBody);
            client_print_color(aimID , 0 , "() %s -> %d" , SourceName , aimBody);
        }
    }
}
