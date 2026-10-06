#include <amxmodx>
#include <fakemeta>	
#include <cstrike>
#include <engine>
#include <hamsandwich>
#include <sqlx>
#include <xs>
#include <fakemeta_util>

new m_list[][] = {"tl_shinobu" , "tl_nep" , "tl_teto" , "tl_homura" , "tl_liukon" , "tl_miku" , "tl_neru"};
new count = 7;
new roll = 0;

public plugin_init()
{
    register_plugin("Twinleaf 测试", "PluginVersion" , "PluginAuthor" , "PluginLink" , "测试");

    register_clcmd("say test" , "Ham_Spawn_post");
	RegisterHamPlayer(Ham_Spawn, "Ham_Spawn_post", 1);

}

public plugin_precache()
{
    for (new i = 0; i < count; i++)
    {
        new path[128];
        format(path, charsmax(path), "models/player/%s/%s.mdl", m_list[i], m_list[i]);
        precache_model(path);
    }
}

public Ham_Spawn_post(id)
{
	if(is_user_alive(id))
	{
        fm_strip_user_weapons(id);
        roll = (roll + 1) % count;
		cs_set_user_model(id , m_list[roll] , false);
    }
}