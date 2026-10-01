#include <amxmodx>
#include <ttt>
#include <Twinleaf>

#define MAX_MESSAGE 256

enum _:UIContent
{
    UIMessage[MAX_MESSAGE],

    int:UIRed,
    int:UIGreen,
    int:UIBlue,

    Float:UIPosX,
    Float:UIPosY,

    int:UIEffect,
    Float:UIEffectTime,
    Float:UIDisplayTime,
    Float:UIFadein,
    Float:UIFadeout,

    int:UIChannal,
    Float:UIAlpha,
    UIBackground[4]
}

new trailor_list[32];
new trailor_count;
new DisplayTo = 0;

public SetUIMessage(property[UIContent], msg[MAX_MESSAGE])
{
    copy(property[UIMessage] , MAX_MESSAGE , msg);
}

public SetUIAlpha(property[UIContent], Float:alpha)
{
    property[UIAlpha] = alpha;
}

public SetUIChannel(property[UIContent], channel)
{
    property[UIChannal] = channel;
}

public SetUIColor(property[UIContent] , color[3])
{
    property[UIRed] = color[0];
    property[UIGreen] = color[1];
    property[UIBlue] = color[2];
}

public SetUIBGColor(property[UIContent] , color[4])
{
    copy(property[UIBackground], 4 ,color);
}

public SetUIPosition(property[UIContent] , xy[2])
{
    property[UIPosX] = xy[0];
    property[UIPosY] = xy[1];
}

public SetUITime(property[UIContent] , Float:dptime)
{
    property[UIDisplayTime] = dptime;
}

public SetUIFade(property[UIContent] , Float:intime , Float:outtime)
{
    property[UIFadein] = intime;
    property[UIFadeout] = outtime;
}

public InitUI(uicontent[UIContent])
{
    SetUIPosition(uicontent , {-1.0 , -1.0});
    SetUIColor(uicontent , {255 , 255 , 255});
    SetUIAlpha(uicontent, 1);
    SetUITime(uicontent, 5.0);
    SetUIBGColor(uicontent , {255 , 255 , 255 , 0});

    SetUIMessage(uicontent , "欢迎光临先生 ！^n要先吃饭，先洗澡 ^n还是先吃我呢");
    uicontent[UIMessage] = "Test Message";
    return true;
}

public ShowUI(uicontent[UIContent] , bool:IsDirector)
{
    new message[MAX_MESSAGE];
    copy(message , MAX_MESSAGE ,uicontent[UIMessage]);
    new red = uicontent[UIRed];
    new green = uicontent[UIGreen];
    new blue = uicontent[UIBlue];
    new Float:x = uicontent[UIPosX];
    new Float:y = uicontent[UIPosY];
    new efftype = uicontent[UIEffect];
    new Float:efftime = uicontent[UIEffectTime];
    new Float:dptime = uicontent[UIDisplayTime];
    new Float:fdin = uicontent[UIFadein];
    new Float:fdout = uicontent[UIFadeout];
    new channel = uicontent[UIChannal];
    new Float:alpha = uicontent[UIAlpha];
    new bg[4];
    copy(bg, 4, uicontent[UIBackground]);
    /*
    console_print(-1, "Display Property :");
    console_print(-1 , "%s" , message);
    console_print(-1 , "red : %d" , red);
    console_print(-1 , "green : %d" , green);
    console_print(-1 , "blue : %d" , blue);
    console_print(-1 , "x : %f" , x);
    console_print(-1 , "y : %f" , y);
    console_print(-1 , "et : %d" , efftype);
    console_print(-1 , "ett : %f" , efftime);
    console_print(-1 , "dpt : %f" , dptime);
    console_print(-1 , "in : %f" , fdin);
    console_print(-1 , "out : %f" , fdout);
    console_print(-1 , "cnl : %d" , channel);
    console_print(-1 , "alp : %f" , alpha);
    */
    if (IsDirector == true)
    {
        set_dhudmessage(
            /*RGB*/red, green, blue,
            /*xy rate*/x , y, 
            /*effects & time*/efftype, efftime, 
            /*display time*/dptime, 
            /*fadein/out time*/fdin, fdout);
        show_dhudmessage(0,message);
    }
    else
    {
        set_hudmessage(
            /*RGB*/red, green, blue,
            /*xy rate*/x , y, 
            /*effects & time*/efftype, efftime, 
            /*display time*/dptime, 
            /*fadein/out time*/fdin, fdout,
            /*channel*/channel, 
            /*alpha*/alpha, bg);
        if (DisplayTo == 1)
        {
            for (new i = 0;i < trailor_count; i ++)
            {
                show_hudmessage(trailor_list[i],message);
            }
        }
        else
        {
            show_hudmessage(0,message);
        }
    }
}

new UITitle[UIContent];
new UIAliveList[UIContent];
new UIHelpMsg[UIContent];

public plugin_init()
{
    register_plugin("Custom Hud Message", "0.1", "Tredam");

    InitUI(UITitle);
    SetUIMessage(UITitle , "游戏标题");
    SetUIPosition(UITitle , {-1.0 , 0.3});

    InitUI(UIHelpMsg);
    SetUIColor(UIHelpMsg , {20 , 255 , 30});
    SetUIChannel(UIHelpMsg , 4);
    SetUIMessage(UIHelpMsg , "游戏规则");
    SetUIPosition(UIHelpMsg , {0.7 , -1.0});

    
    InitUI(UIAliveList);
    SetUIChannel(UIAliveList , 3);
    SetUIMessage(UIAliveList , "叛徒列表");
    SetUIColor(UIAliveList , {255 , 50 , 0});
    SetUIPosition(UIAliveList , {0.8 , 0.1});

    set_task(1.0, "DisplayHelp", 1241433, "", 0, "b");
}

new prepareTime = 15;
public ResetPrepare()
{
    prepareTime = 15;
}

public OnPrepare()
{
    prepareTime --;
    if (prepareTime <= 0)
    {
        remove_task(1241476);
    }
    else
    {
        new FullMsg[MAX_MESSAGE];
        formatex(FullMsg, MAX_MESSAGE,"游戏开始还有 %d 秒" , prepareTime);
        SetUIMessage(UITitle , FullMsg);
        SetUITime(UITitle , 1.1);
        ShowUI(UITitle , true);
    }
}

public DisplayHelp()
{
    new FullMsg[MAX_MESSAGE];
    formatex(FullMsg, MAX_MESSAGE,"%s", "游戏帮助:^n按[B]打开商店^n输入 menu 打开服务器菜单^n输入 /ttt 打开ttt信息");
    SetUIMessage(UIHelpMsg , FullMsg);
    SetUITime(UIHelpMsg , 5.0);
    ShowUI(UIHelpMsg , false);
}

public trailor_msg()
{
    new msg[256];
    add(msg , 256 , "叛徒列表:");
    for (new i  = 0;i < trailor_count;i ++)
    {
        add(msg , 256 , "^n");
        new name[32];
        get_user_name(trailor_list[i] , name , 32);
        if (is_user_alive(trailor_list[i]) == true)
        {
            add(msg , 256 , "[O存活]");
        }
        else
        {
            add(msg , 256 , "[X死亡]");
        }
        add(msg , 256 , name);
    }
    SetUIMessage(UIAliveList , msg);
    SetUITime(UIAliveList , 1.1);
    ShowUI(UIAliveList , false);
}

public ttt_winner(team)
{
    new players[32];
    new playercount;
    get_players(players , playercount);
    for (new i = 0 ;i < playercount;i ++)
    {   
        new id = players[i];
        new pstate = ttt_get_playerdata(id , PD_PLAYERSTATE);
        new name[32];
        get_user_name(id , name , 32);
        if (is_user_alive(players[i]) == true)
        {
            if (team == PC_TRAITOR && pstate == PC_TRAITOR)
            {
                set_user_LeafCoin_delta(id , 20);
                client_print_color(id , id , "^4[OwO] ^3%s ^1作为叛徒胜利, 获得 %d 叶子币" , name , 20);
            }
            else if ((team == PC_INNOCENT || team == PC_DETECTIVE) && (pstate == PC_INNOCENT || pstate == PC_DETECTIVE))
            {
                set_user_LeafCoin_delta(id , 20);
                client_print_color(id , id , "^4[OwO] ^3%s ^1作为警探/平民胜利, 获得 %d 叶子币" , name , 20);

            }
        }
    }
    new Msg[MAX_MESSAGE];
    if (team == PC_TRAITOR)
    {
        formatex(Msg, MAX_MESSAGE, "%s 胜利", "叛徒");
    }
    else if (team == PC_INNOCENT || team == PC_DETECTIVE)
    {
        formatex(Msg, MAX_MESSAGE, "%s 胜利", "平民");
    }
    else
    {
        formatex(Msg, MAX_MESSAGE, "%s", "平局");
    }
    new FullMsg[MAX_MESSAGE];
    formatex(FullMsg, MAX_MESSAGE, "%s ^n___________________", Msg);
    SetUIMessage(UITitle , FullMsg);
    SetUITime(UITitle , 20.0);
    ShowUI(UITitle , true);
}

public ttt_gamemode(mode)
{
    if (task_exists(1241433) == false)
    {
        set_task(1.0, "DisplayHelp", 1241433, "", 0, "b");
    }
    if (mode == GAME_PREPARING)
    {
        if (task_exists(1241423) == true)
        {
            remove_task(1241423);
        }
        if (task_exists(1241476) == true)
        {
            remove_task(1241476);
        }
        ResetPrepare();
        set_task(1.0, "OnPrepare", 1241476, "", 0, "b");
    }
    else if (mode == GAME_STARTED)
    {
        DisplayTo = 1;
        trailor_count = 0;
        new players[32];
        new playercount;
        get_players(players , playercount);
        for (new i = 0;i < playercount;i ++)
        {
            if (ttt_get_playerdata(players[i] , PD_PLAYERSTATE) == PC_TRAITOR)
            {
                trailor_list[trailor_count] = players[i];
                trailor_count++;
            }
        }
        set_task(1.0, "trailor_msg", 1241423, "", 0, "b");
        new FullMsg[MAX_MESSAGE];
        formatex(FullMsg, MAX_MESSAGE,"%s", "游戏开始");
        SetUIMessage(UITitle , FullMsg);
        SetUITime(UITitle , 1.5);
        ShowUI(UITitle , true);
    }
    else if (mode == GAME_ENDED)
    {
        DisplayTo = 0;
    }
}