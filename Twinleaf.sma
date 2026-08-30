#include <Twinleaf>
#include <amxmodx>
#include <json>
#include <easy_http>

new APIKey[64] = "abk_c9Sx1Jw_2WXyo-7QExqkjmd53tIkXXKQoMTew2NWkZI"; 
new ConversationID[64] = "5eea4fab-a22c-43f9-beeb-0a8d69d7f78d";
new bool:Ready = true;

new AstrBotAddr[48] = "http://localhost:6185/api/v1/chat";

new tl_SpeakLength = 0;
new tl_SpeakCount = 0;

new CachedChat[6][256];
new CachedChatCount = 0;

new cvar_tl_enable_reply;

enum _:UserSpeak
{
    US_Name[32],
    US_Content[256],
}

public plugin_init()
{
    register_plugin("Twinleaf 本体", "1.0.0", "Tredam" , "github.com/Lo-kin" , "看板娘双叶");
    
    register_clcmd("say tlinfo" , "tl_info");
    register_clcmd("say" , "GetSay");

    cvar_tl_enable_reply = register_cvar("tl_enable_reply", "1");
}

public tl_info(id)
{
    new sessionidinfo[72];
    new chatcountinfo[64];
    new chatlengthinfo[64];
    format(sessionidinfo , charsmax(sessionidinfo) , "会话ID: %s" , ConversationID);
    format(chatcountinfo , charsmax(chatcountinfo) , "双叶发言缓存: %d条" , tl_SpeakCount);
    format(chatlengthinfo , charsmax(chatlengthinfo) , "双叶发言总长度: %d字节" , tl_SpeakLength);
    new menu = menu_create("双叶信息" , "tl_info_handler");
    menu_additem(menu , "测试");
    menu_addtext2(menu , sessionidinfo);
    menu_addtext2(menu , chatcountinfo);
    menu_addtext2(menu , chatlengthinfo);
    menu_display(id , menu);
}

public tl_info_handler(id , menu , item)
{

}

public GetSay(id)
{
    if (get_pcvar_num(cvar_tl_enable_reply) == 1)
    {
        new argString[128];
        new argLength = read_argc();
        read_args(argString , charsmax(argString));
        remove_quotes(argString);
        new name[32];
        get_user_name(id , name , 32);
        new usdata[UserSpeak];
        copy(usdata[US_Name] , charsmax(usdata[US_Name]) , name);
        copy(usdata[US_Content] , charsmax(usdata[US_Content]) , argString);
        if (random_float(0.0 , 1.0) < 0.3 || containi(usdata[US_Content] , "双叶"))
        {
            if (charsmax(usdata[US_Content]) >= 2 && contain(usdata[US_Content] , "menu") == -1 && contain(usdata[US_Content] , "rtv") == -1)
            {
                console_print(0 , "触发双叶回复: %s" , argString);
                tl_Reply(usdata);
            }

        }
    }
}

public tl_Reply(content[UserSpeak])
{
    if (Ready == false)
    {
        console_print(0 , "还未就绪");
    }
    else
    {    
        new MsgBody[512] = "{^"username^":^"%s^",^"session_id^":^"%s^",^"message^":^"%s：%s^",^"enable_streaming^": false,^"_skip_user_history^": true}";
        format(MsgBody , 512 , MsgBody , "tredam" , ConversationID , content[US_Name] , content[US_Content]);
        new EzHttpOptions:options_id = ezhttp_create_options();
        ezhttp_option_set_header(options_id, "Content-Type", "application/json");
        ezhttp_option_set_header(options_id, "X-API-Key", APIKey);
        ezhttp_option_set_body(options_id, MsgBody);
        ezhttp_post(AstrBotAddr , "tl_complete" , options_id);
        console_print(0 , "发送请求: %s" , MsgBody);
    }
}

public tl_complete(EzHttpRequest:request_id)
{
    if (ezhttp_get_error_code(request_id) != EZH_OK)
    {
        new error[64]
        ezhttp_get_error_message(request_id, error, charsmax(error))
        server_print("Response error: %s", error);
        return
    }
    new response_body[2048];
    ezhttp_get_data(request_id, response_body, 2048);
    new path[64] = "addons/amxmodx/response.txt";
    ezhttp_save_data_to_file(request_id, path);

    new szData[256], szSample[256], iTextLength, iLine;
        
    while (read_file(path, iLine, szData, charsmax(szData), iTextLength) != 0)
    {
        if (iLine > 2048)
            break
        parse(szData, szSample, charsmax(szSample))
        if (contain(szData, "data:") == -1)
        {
            iLine++
            continue
        }
        else
        {
            copy(szData , charsmax(szData) - 6 , szData[6]);
            new JSON:MsgJson = json_parse(szData , false);
            if (MsgJson != Invalid_JSON)
            {
                new MsgType[16];
                json_object_get_string(MsgJson , "type" , MsgType , charsmax(MsgType));
                if (equal(MsgType , "plain"))
                {
                    new MsgContent[256];
                    json_object_get_string(MsgJson , "data" , CachedChat[CachedChatCount] , 256);
                    CachedChatCount += 1;
                }
            }
            json_free(MsgJson);
        }
        if (szSample[0] == ';' || !szSample[0])
        {
            iLine++
            continue
        }
        iLine++
    }
    console_print(0 , "Cached %d messages from stream." , CachedChatCount);
    set_task(0.1 , "ReleaseCachedChat" , 32196213424 , "" , 0 , "a" , 1);
}

new speakPos = 0;
public ReleaseCachedChat()
{
    if (speakPos >= CachedChatCount)
    {
        speakPos = 0;
        CachedChatCount = 0;
        return;
    }
    tl_client_print_color(0 , 0 , CachedChat[speakPos]);
    speakPos += 1;
    set_task(random_float(0.5 , 3.0) , "ReleaseCachedChat" , 32196213424 , "" , 0 , "a" , 1);
}

public tl_client_print_color(const reciver , const sender , content[])
{
    tl_SpeakLength += charsmax(content);
    tl_SpeakCount += 1;
    client_print_color(reciver , sender , "^4[雙葉]^1:%s" , content);
}
