#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>

#define PLUGIN "New Camera View"
#define VERSION "1.0"
#define AUTHOR "DadoDz"

// Uncomment the line below to enable only 3RD Person View without menu
// #define ONLY_3RD_PERSON_VIEW

new g_iCamera[33];

// Menu keys
const KEYSMENU = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9|MENU_KEY_0;

public plugin_precache() precache_model("models/rpgrocket.mdl");

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);

    register_clcmd("say /camera", "cmdCamera");
    register_clcmd("say camera", "cmdCamera");
    register_clcmd("say /cam", "cmdCamera");
    register_clcmd("say cam", "cmdCamera");

    register_menu("Camera View Menu", KEYSMENU, "menu_camera_view");
}

public client_putinserver(id) g_iCamera[id] = 0;
public client_disconnected(id) g_iCamera[id] = 0;

public cmdCamera(id)
{
    if (!is_user_connected(id) || !is_user_alive(id))
        return PLUGIN_HANDLED;

    #if defined ONLY_3RD_PERSON_VIEW
        three_person_view(id);
    #else
        camera_view_menu(id);
    #endif

    return PLUGIN_HANDLED;
}

three_person_view(id)
{
    if (!is_user_connected(id) || !is_user_alive(id))
        return PLUGIN_HANDLED;

    if (g_iCamera[id] == 1)
    {
		set_view(id, CAMERA_NONE);
		g_iCamera[id] = 0;
    }
    else
    {
		set_view(id, CAMERA_3RDPERSON);
		g_iCamera[id] = 1;
    }

    return PLUGIN_HANDLED;
}

camera_view_menu(id)
{
    if (!is_user_connected(id) || !is_user_alive(id))
        return PLUGIN_HANDLED;

    static menu[250], len;
    len = 0

	// Title
    len += formatex(menu[len], charsmax(menu) - len, "\r•  \yCamera View Menu  \r•^n^n");
	
	// 1. 3RD Person View
    if(g_iCamera[id] != 1)
	    len += formatex(menu[len], charsmax(menu) - len, "\y•\r 1 \y• \w 3RD Person\r View^n");
    else 
        len += formatex(menu[len], charsmax(menu) - len, "\y•\r 1 \y• \w 3RD Person\r View \d[Selected]^n");

	// 2. UP Left View
    if(g_iCamera[id] != 2)
	    len += formatex(menu[len], charsmax(menu) - len, "\y•\r 2 \y• \w UP Left\r View^n");
    else 
        len += formatex(menu[len], charsmax(menu) - len, "\y•\r 2 \y• \w UP Left\r View \d[Selected]^n");

	// 3. Top Down View
    if(g_iCamera[id] != 3)
	    len += formatex(menu[len], charsmax(menu) - len, "\y•\r 3 \y• \w Top Down\r View^n");
    else 
        len += formatex(menu[len], charsmax(menu) - len, "\y•\r 3 \y• \w Top Down\r View \d[Selected]^n");

	// 4. Normal View
    if(g_iCamera[id] != 0)
	    len += formatex(menu[len], charsmax(menu) - len, "\y•\r 4 \y• \w Normal\r View^n");
    else 
        len += formatex(menu[len], charsmax(menu) - len, "\y•\r 4 \y• \w Normal\r View \d[Selected]^n");

    // 0. Exit
    len += formatex(menu[len], charsmax(menu) - len, "^n\y•\r 0 \y• \w Exit");

	// Fix for AMXX custom menus
    if (pev_valid(id) == 2)
		set_pdata_int(id, 205, 0, 5);

    show_menu(id, KEYSMENU, menu, -1, "Camera View Menu");

    return PLUGIN_HANDLED;
}

public menu_camera_view(id, key)
{
    if (!is_user_connected(id) || !is_user_alive(id))
        return PLUGIN_HANDLED;

    switch(key)
    {
        case 0:
        {
            if(g_iCamera[id] != 1)
            {
                set_view(id, CAMERA_3RDPERSON);
                g_iCamera[id] = 1;
            }
        }
        case 1:
        {
            if(g_iCamera[id] != 2)
            {
                set_view(id, CAMERA_UPLEFT)
                g_iCamera[id] = 2;
            }
        }
        case 2:
        {
            if(g_iCamera[id] != 3)
            {
                set_view(id, CAMERA_TOPDOWN);
                g_iCamera[id] = 3;
            }
        }
        case 3:
        {
            if(g_iCamera[id] != 0)
            {
                set_view(id, CAMERA_NONE);
                g_iCamera[id] = 0;
            }
        }
    }

    return PLUGIN_HANDLED;
}