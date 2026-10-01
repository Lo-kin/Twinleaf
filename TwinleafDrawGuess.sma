#include <amxmodx>
#include <fakemeta>	
#include <hamsandwich>
#include <fakemeta_util>
#include <string>
#include <xs>
#include <engine_stocks>
#include <json>
#include <newmenus>
#include <amxmisc>
#include <engine>
#include <Twinleaf>

#define TASK_HINT 1000
#define TASK_KEY 1300
#define TASK_SET_R_DECAL 2000

#define MAX_POINTS 4096
#define WORD_LENGTH 32
#define HINT_DELAY 30
#define MAX_WORDS 512

new LibPath[64] = "addons/amxmodx/configs/dg_lib.json";

new PlayerList[32][128];
new int:PlayerRoll = 0;
new PainterID;
new PainterName[128];
new Float:ScoreList[64][2];
new RecordPosition = 0;

//new WordBuffer[MAX_WORDS * 4 * WORD_LENGTH];
new WordLibrary[MAX_WORDS][4][WORD_LENGTH];
new WordLibraryCache[128][4][WORD_LENGTH];
new Answer[32];
new WordCount = 0;
new WordCacheCount = 0;

new HintStep = 0;
new RolledWord = 0;
new StartGuessTime = 0;
new LastHintTime = 0;

new LastTime;
new Canvas[MAX_POINTS][3];
new int:CanvasPointer;
new CanvasID[MAX_POINTS];

new VoteBanWord[512];
new BanWordPos =  0;
new CurrentBanTimes = 0;

new bool:IsAnswering;
new bool:DrawBegin;
new bool:IsSwap;

public plugin_init()
{
    register_plugin("Twinleaf 你画我猜",  PluginVersion , PluginAuthor , PluginLink , "你画我猜");
	register_forward(FM_PlayerPreThink, "Draw")
	register_clcmd("say /task" , "RollToNext" ,  -1 , "提问");
	register_clcmd("say_team" , "Reply" ,  -1 , "填答案");
	register_clcmd("say /next" , "ForceRollNext" ,  -1 , "强制下一人");
	register_clcmd("say dgmenu" , "DGMenu" , -1 , "No test")
	CanvasPointer = -1; 
	register_forward(FM_ClientDisconnect , "ClientDisconnected" );
	register_forward(FM_ClientConnect , "ClientConnected" );
}

public plugin_precache()
{
	LoadWordLibrary();
}

public ClientDisconnected(id)
{
	if (PainterID == id)
	{
		PainterID = 0;
		remove_task(TASK_HINT);
		remove_task(TASK_KEY + id);
	}
	//IsAnswering = false;
	
	remove_task(TASK_SET_R_DECAL + id);
}

public ClientConnected(id)
{
	set_task(10.0, "Set_r_decals", id + TASK_SET_R_DECAL);
	AddScore(id , true);
}

public Set_r_decals(id)
{
	client_cmd(id - TASK_SET_R_DECAL, "r_decals 8192")
}

public Task(id)
{
	if (IsAnswering == true)
	{
		client_print_color(id , id , "^4[TwT] ^3%s ^1 当前正在进行 " , PainterName);
		return PLUGIN_CONTINUE;
	}
	else
	{
		if(!is_user_alive(id) || is_user_spec(id))
		{
			remove_task(TASK_HINT);
			remove_task(TASK_KEY + id);
			RollToNext(id);
		}
		else
		{
			remove_task(TASK_HINT);
			remove_task(TASK_KEY + id);
			ClearCanvas();
			set_task(30.0, "GiveAllHint", TASK_HINT , "" , 0 ,"b");
			set_task(0.1, "ListenKey", TASK_KEY + id , _,_, "b");
			
			Answer = RollWord();
			IsAnswering = true;
			PainterID = id;
			get_user_name(id , PainterName , 128);
			client_print_color(0 , id , "^4[TwT] ^3%s ^1 轮到你来画画了" , PainterName);
			client_print_color(id , id , "^4[TwT] ^3%s ^1,你的主题是 %s" , PainterName , Answer);
			client_print_color(id , id , "^4[TwT] ^1按下^3[E]^1画画 , 按下^3[R]^1清除画布");
			client_print_color(0 , id , "^4[TwT] ^1按下^3[U]^1输入你的答案");
			play_soundeffect(0 , SE_StartUp);
			LastHintTime = get_gametime();
		}
	}
	return PLUGIN_HANDLED;
}

public Reply(id)
{
	new AnswerName[128];
	get_user_name(id , AnswerName , 128);
	new Args[16][128];
	ReadArg(Args , false);
	if (id == PainterID)
	{
		client_print_color(0 , id , "^4[TwT] ^3%s ^1你不可以回答" , AnswerName , Answer);
		return PLUGIN_HANDLED;
	}
	if (IsAnswering == true)
	{
		new replyAnswer[128];
		copy(replyAnswer , 128 , Args[0]);
		if (equali(Answer , replyAnswer , 128) == true)
		{
			AddScore(id , false)
			client_print_color(0 , id , "^4[TwT] ^3%s ^1回答正确，答案是 %s" , AnswerName , Answer);
			set_user_LeafCoin_delta(id , 10);
			IsAnswering = false;
			ClearCanvas();
			RollToNext(id);
		}
		else
		{
			client_print_color(0 , id , "^4[TwT] ^3%s ^1猜了词语 %s" , AnswerName , replyAnswer);
		}

		return PLUGIN_HANDLED;
	}
	else
	{
		client_print_color(id , id , "^4[TwT] ^3%s ^1 当前没有人提出你画我猜 ， 输入/task 提出一个吧" , AnswerName);
		return PLUGIN_CONTINUE;
	}
}

public Draw(id)
{
	if (id != PainterID)
	{
		return PLUGIN_CONTINUE;
	}
	new NowTime;
	NowTime = get_gametime();
	if (pev(PainterID , pev_button) & IN_USE)
	{
		DrawBegin = true;
	}
	else
	{
		return PLUGIN_HANDLED;
	}
	if (NowTime - LastTime <= 100)//1's / 100000 tick
	{
		return;
	}
	else
	{
		LastTime = NowTime
	}
	CanvasPointer += 1;
	if (CanvasPointer >= MAX_POINTS - 1)
	{
		CanvasPointer = 0
	}
	new Float:EndViewPoint[3];
	fm_get_aim_origin(PainterID , EndViewPoint)
	new drawDecal = 179;
	if (IsSwap == true)
	{
		drawDecal = 29;
	}
	CreateDecal(EndViewPoint , drawDecal)
}

public SetStartTime()
{
	StartGuessTime = get_gametime();
}

public RollToNext(id)
{
	if (IsAnswering == true)
	{
		new AnswerName[128];
		get_user_name(id , AnswerName , 128);
		client_print_color(id , id , "^4[TwT] ^3%s ^1 当前进行中..." , AnswerName);
		return PLUGIN_CONTINUE;
	}
	ForceRollNext(id)
}

public ForceRollNext(id)
{
	IsAnswering = false;
	new int:PlayerCount;
	new Players[MAX_PLAYERS];
	get_players(Players , PlayerCount , "" , "")
	new SkipCount = 0;
	while (true)
	{
		if (SkipCount >= PlayerCount)
		{
			break;
		}
		if (PlayerRoll < 0 || PlayerRoll > PlayerCount || Players[PlayerRoll] == 0 )
		{
			PlayerRoll = 0;
		}
		else
		{
			if (PlayerRoll <= PlayerCount - 1)
			{
				if (Players[PlayerRoll + 1] == 0)
				{
					PlayerRoll = 0;
				}
				else
				{
					PlayerRoll += 1;
				}
			}
		}
		new CurrentID;
		CurrentID = Players[PlayerRoll];
		new tn[32];
		new name[32];
		get_user_team(CurrentID , tn , 32)
		get_user_name(CurrentID , name , 32);
		
		if (is_user_spec(CurrentID) == false && is_user_alive(CurrentID) == true)
		{
			break;
		}
		else
		{
			SkipCount += 1;
		}
	}
	Task(Players[PlayerRoll]);
}

public AddScore(id , IsInit)
{
	if (RecordPosition >= 64)
	{
		RecordPosition = 0;
	}
	new ScoreBase =  floatpower(2 , 4 - HintStep);
	if (IsInit == true)
	{
		ScoreBase = 0;
	}
	new EndPos = 0;
	for (new i = 0; i < RecordPosition; i++)
	{
		if (ScoreList[i][0] == id)
		{
			ScoreList[i][1] += ScoreBase;
			
			for (new j = i + 1;j < RecordPosition;j ++)
			{
				if (ScoreList[j][1] >  ScoreList[i][1])
				{
					EndPos = j - 1;
				}
				else
				{
					if (j == RecordPosition - 1)
					{
						EndPos = j;
					}
				}
			}
			SwapScore(i , EndPos);
			return;
		}
		else
		{
			if (ScoreList[i][1] > ScoreBase)
			{
				if (i == 0)
				{
					EndPos = 0;
				}
				else
				{
					EndPos = i - 1
				}
			}
		}
	}
	new insertPos = InsertScore(id , floatpower(2 , 4 - HintStep));
	SwapScore(EndPos , insertPos);

	return;
}

public InsertScore(id , value)
{
	ScoreList[RecordPosition][0] = id;
	ScoreList[RecordPosition][1] = value;
	RecordPosition += 1;
	return RecordPosition - 1;
}

public SwapScore(poss , pose)
{
	if (poss < 0 || poss >= RecordPosition || pose < 0 || pose >= RecordPosition)
	{
		return false;
	}
	if (poss > pose)
	{
		new id = ScoreList[poss][0];new value = ScoreList[poss][1];
		for (new i = poss; i > pose; i --)
		{
			ScoreList[i][0] = ScoreList[i - 1][0];
			ScoreList[i][1] = ScoreList[i - 1][1];
		}
		ScoreList[pose][0] = id;
		ScoreList[pose][1] = value;
	}
	else if (poss < pose)
	{
		new id = ScoreList[poss][0];new value = ScoreList[poss][1];
		for (new i = poss + 1; i < pose; i ++)
		{
			ScoreList[i - 1][0] = ScoreList[i][0];
			ScoreList[i - 1][1] = ScoreList[i][1];
		}
		ScoreList[pose][0] = id;
		ScoreList[pose][1] = value;
	}
	return true;
}

public RollWord()
{
	new int:RolledPos = random(WordCount);
	if (RolledPos >= WordCount)
	{
		RolledPos = 0;
	}
	RolledWord = RolledPos;
	return WordLibrary[RolledWord][0];
}

public ReadArg(container[][] , bool:IsDivideBySpace)
{
	//获取的是整个语句 而非参数 例如: say /task 1 获得的是 /task 1
	//say的语句默认带有引号
	new argString[128];
	new argLength = read_argc();
	read_args(argString , charsmax(argString));
	remove_quotes(argString);

	if (IsDivideBySpace == false)
	{
		copy(container[0] , 128 , argString);
		return 1;
	}
	new head = 0;
	new tail = 0;
	
	new CurrentArgPos = 0;
	if (argLength == 0)
	{
		return 0;
	}
	new WordLength = -1;
	for (tail = 0; tail < charsmax(argString) - 1; tail ++)//int 32 = char " "
	{
		if (argString[tail] == 32)
		{
			CurrentArgPos += 1;
			head = tail
			WordLength = -1;
			if (CurrentArgPos >= 16)
			{
				break;
			}
		}
		else
		{
			if (head == 32)
			{
				head = tail
				CurrentArgPos += 1;
			}
			WordLength += 1;
			container[CurrentArgPos][WordLength] = argString[tail];
		}
	}
	return CurrentArgPos + 1;
}

new Float:LastCleanTime;

public ClearCanvas()
{
	new Float:nowtime = get_gametime();
	if (nowtime - LastCleanTime >= 1.0)
	{
		LastCleanTime = nowtime;
		CanvasPointer = 0;
		fm_cs_remove_decals()
	}
}

public ListenKey()
{
	if (!(pev(PainterID , pev_button) & IN_USE) && pev(PainterID , pev_oldbuttons) & IN_USE)
	{
		//IsSwap = false;
	}
	if (pev(PainterID , pev_button) & IN_USE)
	{

	}
	if (!(pev(PainterID , pev_button) & IN_RELOAD) && pev(PainterID , pev_oldbuttons) & IN_RELOAD)
	{
		//IsSwap = true;
		ClearCanvas();
	}
	if (pev(PainterID , pev_button) & IN_RELOAD)
	{
		ClearCanvas();
	}
}

public GiveAllHint()
{
	if (HintStep >= 3)
	{
		client_print_color(0 , PlayerRoll , "^4[TwT] ^1三次提示用尽 , 仍然没有人回答正确");
		client_print_color(0 , PlayerRoll , "^4[TwT] ^1答案是 %s" , Answer);
		HintStep = 0;
		ForceRollNext(0);
		play_soundeffect(0 , SE_Game_Fail);
		return;
	}
	new CurrentHint[32];
	switch (HintStep)
	{
		case 0:
		{
			formatex(CurrentHint ,  32 , "这个答案有 %d 个字" , strlen(WordLibrary[RolledWord][0]) / 3);
		}
		case 1:
		{
			formatex(CurrentHint ,  32 , "%s" , WordLibrary[RolledWord][1]);
		}
		case 2:
		{
			formatex(CurrentHint ,  32 , "%s" , WordLibrary[RolledWord][random(1) + 2]);
		}
	}
	play_soundeffect(0 , SE_Lottery_Process);
	client_print_color(0 , PlayerRoll , "^4[TwT] ^3第 %d / 3次提示 ：^1%s" , HintStep + 1 , CurrentHint);
	LastHintTime = get_gametime();
	HintStep += 1;
}

public CopyVec(Float:Container[] ,const Float:Object[] , len)
{
	new i;
	for (i = 0;i < len;i++)
	{
		Container[i] = Object[i]
	}
}

public CreateDecal(Float:Origin[3] , DecalID)
{
	new int:PlayerCount;
	new Players[MAX_PLAYERS];
	get_players(Players , PlayerCount , _ , _)
	for (new i = 0;i < PlayerCount; i ++)
	{
		if (is_user_connected(Players[i]) == true)
		{
			message_begin(MSG_ONE, SVC_TEMPENTITY , _ , Players[i]);
			write_byte(TE_WORLDDECAL);
			engfunc(EngFunc_WriteCoord, Origin[0]);
			engfunc(EngFunc_WriteCoord, Origin[1]);
			engfunc(EngFunc_WriteCoord, Origin[2]);
			write_byte(DecalID)
			message_end();
		}
	}
}
//203 弹孔 179玻璃 29大弹孔

public is_user_spec(id)
{
	new teamname[128];
	get_user_team(id , teamname , 128);
	return (equali(teamname , "SPECTATOR" , 128) || equali(teamname , "UNASSIGNED" , 128));
}

//JSON 题库
public WriteIntoLibrary()
{
	//最大128问题 ， 每个问题最大3个提示+1个答案 ， 每个string最大32 WORD_LENGTH
	new JSON:Rootjson = json_init_object();
	new JSON:WordLib = json_init_object();
	new JSON:WordCache = json_init_object();

	new i , j;
	for (i = 0; i < WordCount; i ++)
	{
		new JSON:AnswerHints = json_init_array();
		for (j = 1; j < 4 ; j++)
		{
			json_array_append_string(AnswerHints , WordLibrary[i][j]);
		}
		json_object_set_value(WordLib , WordLibrary[i][0] , AnswerHints);
		json_free(AnswerHints);
	}
	for (i = 0; i < WordCacheCount; i ++)
	{
		new JSON:AnswerHints = json_init_array();
		for (j = 1; j < 4 ; j++)
		{
			json_array_append_string(AnswerHints , WordLibraryCache[i][j]);
		}
		json_object_set_value(WordCache , WordLibraryCache[i][0] , AnswerHints);
		json_free(AnswerHints);
	}
	json_object_set_value(Rootjson , "WordLib" , WordLib);
	json_object_set_value(Rootjson , "WordCache" , WordCache);
	json_object_set_number(Rootjson , "LibCount" , 0);
	json_object_set_number(Rootjson , "CacheCount" , 0);
	json_free(WordLib);
	json_free(WordCache);
	json_serial_to_file(Rootjson, LibPath, true);
	json_free(Rootjson);
}

public LoadWordLibrary()
{
	new JSON:ReadFromFile = json_parse(LibPath , true);
	if (ReadFromFile == Invalid_JSON)
	{
		json_free(ReadFromFile);
		console_print(-1 , "error");
		return PLUGIN_CONTINUE;
	}
	else
	{
		new libcount = json_object_get_number(ReadFromFile , "LibCount");
		new JSON:wordlib = json_object_get_value(ReadFromFile , "WordLib");
		if (libcount == Invalid_JSON|| wordlib == Invalid_JSON)
		{
			return PLUGIN_CONTINUE;
		}
		else
		{
			WordCount = 0;
			new i , j;
			for (i = 0;i < libcount;i ++)
			{
				new answer[WORD_LENGTH];
				json_object_get_name(wordlib , i , answer , WORD_LENGTH);
				new JSON:hints = json_object_get_value(wordlib , answer);
				copy(WordLibrary[i][0] , WORD_LENGTH , answer);
				for (j = 0; j < 3;j ++)
				{
					new singlehint[WORD_LENGTH];
					json_array_get_string(hints , j , singlehint , WORD_LENGTH);
					copy(WordLibrary[i][j + 1] , WORD_LENGTH , singlehint)
				}
				json_free(hints);
			}
			WordCount = libcount;
		}
		console_print(-1 , "[TWT] Loaded %d Words From File" , WordCount);
		json_free(wordlib);
		json_free(ReadFromFile);
	}
}
//JSON 结束

public BanWord()
{
	new CurrentPlayerCount = get_playersnum();
	CurrentBanTimes += 1;
	if (CurrentBanTimes >= CurrentPlayerCount / 2)
	{
		VoteBanWord[BanWordPos] = RolledWord;
		BanWordPos += 1;
		client_print_color(0 , 0 , "^4[TwT] ^1%s已经被ban了!" , Answer);
	}
}

/*
List of Colors for menus: ( there are no other colors available )
白 - \w
黄 - \y
红 - \r
灰色 - \d
右侧对齐 - \R
*/

public DGMenu(id)
{
	new SizeInfo[128];
	formatex(SizeInfo ,  128 , "\dV1.1.2 词库容量 %d / %d" , WordCount , MAX_WORDS)
	new menu = menu_create("你画我猜控制面板" , "DGMenuSelection");
	menu_addtext2(menu , SizeInfo);
	menu_additem(menu , "\w顶尖玩家TOP5");
	menu_additem(menu , "投票移除当前单词")
	menu_setprop(menu , MPROP_EXIT, MEXIT_ALL)
	menu_display(id , menu);
}

public TopMenu(id)
{
	new topmenu = menu_create("Top5" , "TopMenuSelection");
	for (new i = 0; i < min(5 , RecordPosition); i ++)
	{
		new name[32];
		new NameInfo[64];
		get_user_name(ScoreList[i][0] , name , 32);
		formatex(NameInfo ,  64 , "\w[%d]%s \t%.0f" , i + 1 , name , ScoreList[i][1])
		menu_addtext2(topmenu , NameInfo);
	}
	menu_setprop(topmenu , MPROP_EXIT, MEXIT_ALL)
	menu_display(id , topmenu);
}

public DGMenuSelection(id , menu , item)
{
	console_print(-1 , "%d" , item);
	switch(item)
	{
		case 1:
		{
			menu_destroy(menu);
			TopMenu(id)
		}
		case 2:
		{
			BanWord();
			new name[32];
			get_user_name(id , name , 32);
			new CurrentPlayerCount = get_playersnum();
			client_print_color(0 , id , "^4[TwT] ^3%s ^1投票ban当前词语 %d / %d" , name , CurrentBanTimes , CurrentPlayerCount / 2);
		}
	}
	menu_destroy(menu);
}

public TopMenuSelection(id , menu , item)
{

}