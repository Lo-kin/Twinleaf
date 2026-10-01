/* ������� AMXX-Studio ���İ��޸����� */
/* UTF-8 func by www.DT-Club.net */
      
#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <xs>
#include <cstrike>
#include <engine>
#include <fakemeta_util>


#define CustomItem(%0) (entity_get_int(%0, EV_INT_impulse) == WEAPON_SPECIAL_KEY)
#define get_bit(%1,%2) ((%1 & (1 << (%2 & 31))) ? true : false)
#define set_bit(%1,%2) %1 |= (1 << (%2 & 31))
#define reset_bit(%1,%2) %1 &= ~(1 << (%2 & 31))
#define IsConnected(%0) (1<=%0<=g_MaxPlayers && get_bit(g_connect, %0))

#define m_rgpPlayerItems_CWeaponBox 34
#define m_pPlayer 41
#define m_pNext 42
#define m_flNextPrimaryAttack 46
#define m_iShell 57
#define m_flNextAttack 83
#define m_flEjectBrass 111
#define m_rpgPlayerItems 367
#define m_rpgPlayerItems0 368
#define m_pActiveItem 373
#define m_fInReload 54
#define m_szAnimExtention 492

#define WEAPON_SPECIAL_KEY 1
#define WEAPON_BASE_ENT "weapon_ak47"
#define WEAPON_SPRITE_NAME "weapon_rpg7"
#define WEAPON_BASE_CSW CSW_AK47
#define WEAPON_EVENT "events/ak47.sc"
#define WEAPON_ANIM_TEXT "rpg7"
#define WEAPON_ROCKET_CLASS "rpg7_rocket"

#define WEAPON_SHOOT_DELAY 1.0
#define WEAPON_RECOIL 9.5
#define WEAPON_CLIP 1
#define WEAPON_AMMO 1
#define WEAPON_RELOAD_TIME 2.1
#define WEAPON_DRAW_DELAY 1.1

#define EXPLODE_DAMAGE 800.0 
#define EXPLODE_RADIUS 200.0

#define WEAPON_MODEL_VIEW "models/zombie_escape/v_rpg7.mdl"
#define WEAPON_MODEL_PLAYER "models/zombie_escape/p_rpg7.mdl"
#define WEAPON_MODEL_WORLD "models/zombie_escape/w_rpg7.mdl"
#define WEAPON_MODEL_ROCKET "models/zombie_escape/s_rpg7.mdl"
#define WEAPON_SOUND_SHOOT "weapons/rpg7_shoot.wav"
#define WEAPON_SPRITE_MUZZLEFLASH "sprites/smokepuff.spr"

#define ROCKET_EXPLOSION "sprites/fexplo.spr"
#define ROCKET_EXPLOSION_SMALL "sprites/eexplo.spr"
#define ROCKET_PUFF "sprites/effects/rainsplash.spr"

new const WEAPON_SOUNDS[][] = {
	"weapons/rpg7_reload.wav",
	"weapons/rpg7_draw.wav"
}
new const WEAPON_SPITES[][] = {
	"sprites/zombie_plague/640hud7.spr",
	"sprites/zombie_plague/640hud118.spr"
}

new g_connect, g_MaxPlayers, sExplo, sExploSmall, g_event, sMuzzleFlash, g_fw_index, g_smoke_id, g_iItemID, g_mode[33];
new cvar_show_tip = 0;
public plugin_init() {
	register_plugin("[Zombie Escape] Weapon: RPG-7", "0.7", "PlaneShfit1231 / Batcon");
	RegisterHam(Ham_Item_Deploy, WEAPON_BASE_ENT, "fw_Item_Deploy_Post", 1);
	RegisterHam(Ham_Item_Holster, WEAPON_BASE_ENT, "fw_Item_Holster_Post", 1);
	RegisterHam(Ham_Weapon_Reload, WEAPON_BASE_ENT, "fw_Weapon_Reload_Post", 1);
	RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_BASE_ENT, "fw_Weapon_PrimaryAttack");
	RegisterHam(Ham_Item_AddToPlayer, WEAPON_BASE_ENT, "fw_Item_AddToPlayer_Post", 1);
	RegisterHam(Ham_Item_PostFrame, WEAPON_BASE_ENT, "fw_Item_PostFrame");
	RegisterHam(Ham_TraceAttack, "func_breakable", "fw_TraceAttack");
	RegisterHam(Ham_TraceAttack, "hostage_entity", "fw_TraceAttack");
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack");
	RegisterHam(Ham_TraceAttack, "func_breakable", "fw_TraceAttack_Post", 1);
	RegisterHam(Ham_TraceAttack, "func_wall", "fw_TraceAttack_Post", 1);
	RegisterHam(Ham_TraceAttack, "func_door", "fw_TraceAttack_Post", 1);
	RegisterHam(Ham_TraceAttack, "func_plat", "fw_TraceAttack_Post", 1);
	RegisterHam(Ham_TraceAttack, "func_rotating", "fw_TraceAttack_Post", 1);
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack_Post", 1);
	RegisterHam(Ham_Spawn, "weaponbox", "fw_Spawn_Weaponbox_Post", 1);
	unregister_forward(FM_PrecacheEvent, g_fw_index, 1);
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1);
	register_forward(FM_SetModel, "fw_SetModel");
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent");
	register_touch(WEAPON_ROCKET_CLASS, "*", "fw_RocketTouch");
	register_think(WEAPON_ROCKET_CLASS, "fw_RocketThink" )
	//register_event("HLTV", "event_round_start", "a", "1=0", "2=0")
	cvar_show_tip = register_cvar("weapon_rpg7_show_tip", "1")		//�����Ѷ
	g_MaxPlayers = get_maxplayers();
	state WeaponBox_Disabled;
	register_clcmd(WEAPON_SPRITE_NAME, "hook_weapon");
	//register_clcmd("say test" , "give_rpg7" ,  -1 , "强制");
	//g_iItemID = ze_register_item("RPG 7", 80, 0); 
}
public plugin_precache() {
	static buffer[64], i;
	engfunc(EngFunc_PrecacheModel, WEAPON_MODEL_VIEW);
	engfunc(EngFunc_PrecacheModel, WEAPON_MODEL_PLAYER);
	engfunc(EngFunc_PrecacheModel, WEAPON_MODEL_WORLD);
	engfunc(EngFunc_PrecacheModel, WEAPON_MODEL_ROCKET);
	engfunc(EngFunc_PrecacheSound, WEAPON_SOUND_SHOOT);
	for(i = 0; i < sizeof WEAPON_SOUNDS;i++) engfunc(EngFunc_PrecacheSound, WEAPON_SOUNDS[i]);
	for(i = 0; i < sizeof WEAPON_SPITES;i++) engfunc(EngFunc_PrecacheGeneric, WEAPON_SPITES[i]);
	format(buffer, charsmax(buffer), "sprites/%s.txt", WEAPON_SPRITE_NAME);
	engfunc(EngFunc_PrecacheGeneric, buffer);
	sExplo = engfunc(EngFunc_PrecacheModel, ROCKET_EXPLOSION);
	sExploSmall = engfunc(EngFunc_PrecacheModel, ROCKET_EXPLOSION_SMALL);
	sMuzzleFlash = engfunc(EngFunc_PrecacheModel, WEAPON_SPRITE_MUZZLEFLASH);
	g_smoke_id = engfunc(EngFunc_PrecacheModel, ROCKET_PUFF)
	g_fw_index = register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1);
}
public client_putinserver(id) {
	set_bit(g_connect, id);
	g_mode[id] = 0;
}
public client_disconnected(id) {
	reset_bit(g_connect, id);
	g_mode[id] = 0;
}
public hook_weapon(id)	engclient_cmd(id, WEAPON_BASE_ENT);

public ze_select_item_pre(id, itemid)
{
    if (itemid != g_iItemID)       return    // This not our item?
   
    give_rpg7(id) 
}
 
public ze_select_item_post(id, itemid)
{
    // This is not our item, Block it here and don't execute the blew code
    if (itemid != g_iItemID)        return
   
    give_rpg7(id) 
}

public give_rpg7(id) {
	UTIL_DropWeapon(id, 1);
	if(!give_weapon(id)) return;
	emit_sound(id, CHAN_ITEM, "items/gunpickup2.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
	g_mode[id] = 0;
	static amount; amount = GetAmmoDifference(id, WEAPON_BASE_CSW, WEAPON_AMMO)
	if(amount) {
		AmmoPickup_Icon(id, 4, WEAPON_CLIP, amount);
		cs_set_user_bpammo(id, WEAPON_BASE_CSW, WEAPON_AMMO);
	}
}
public give_weapon(id) {
	new ent = create_entity(WEAPON_BASE_ENT);
	if(!is_valid_ent(ent)) return false;
	entity_set_int(ent, EV_INT_spawnflags, SF_NORESPAWN);
	entity_set_int(ent, EV_INT_impulse, WEAPON_SPECIAL_KEY);
	ExecuteHam(Ham_Spawn, ent);
	cs_set_weapon_ammo(ent, WEAPON_CLIP);
	if(!ExecuteHamB(Ham_AddPlayerItem, id, ent)) {
		entity_set_int(ent, EV_INT_flags, FL_KILLME);
		return true;
	}
	ExecuteHamB(Ham_Item_AttachToPlayer, ent, id);
	return true;
}
public fw_Item_PostFrame(ent) {
	if(!CustomItem(ent)) return HAM_IGNORED;
	static id; id = get_pdata_cbase(ent, m_pPlayer, 4);
	if(get_pdata_int(ent, m_fInReload, 4)) {
		static clip; clip = cs_get_weapon_ammo(ent);
		static ammo; ammo = cs_get_user_bpammo(id, WEAPON_BASE_CSW);
		static j; j = min(WEAPON_CLIP - clip, ammo); 
		cs_set_weapon_ammo(ent, clip+j);
		cs_set_user_bpammo(id, WEAPON_BASE_CSW, ammo-j);
		set_pdata_int(ent, m_fInReload, 0, 4);
	} 
	if(!g_mode[id] && get_pdata_float(id, m_flNextAttack, 5) <= 0.0 && get_user_button(id) & IN_ATTACK2) {
     		UTIL_PlayWeaponAnimation(id, cs_get_weapon_ammo(ent) == 1 ? 9 : 11);
		set_pdata_float(id, m_flNextAttack, 0.5, 5);
		set_pdata_int(id, 363, 65);
     		g_mode[id] = 1; 
	}
	else if(g_mode[id] && get_pdata_float(id, m_flNextAttack, 5) <= 0.0 && get_user_button(id) & IN_ATTACK2) {
		UTIL_PlayWeaponAnimation(id, cs_get_weapon_ammo(ent) == 1 ? 10 : 12);
		set_pdata_float(id, m_flNextAttack, 0.5, 5);
     		g_mode[id] = 0; 
	}
	if(g_mode[id] && pev(id, pev_weaponanim) == 0) UTIL_PlayWeaponAnimation(id, cs_get_weapon_ammo(ent) == 1 ? 1:3 );
	if(!g_mode[id]) set_pdata_int(id, 363, 90);
	return HAM_IGNORED;
}
public fw_Item_Deploy_Post(ent) {
	if(!CustomItem(ent)) return HAM_IGNORED;
	static id; id = get_pdata_cbase(ent, m_pPlayer, 4);
	entity_set_string(id, EV_SZ_viewmodel, WEAPON_MODEL_VIEW);
	entity_set_string(id, EV_SZ_weaponmodel, WEAPON_MODEL_PLAYER);
	if(cs_get_weapon_ammo(ent) == 1) UTIL_PlayWeaponAnimation(id, 7);
	else UTIL_PlayWeaponAnimation(id, 8);
	g_mode[id] = 0;
	set_pdata_string(id, m_szAnimExtention * 4, WEAPON_ANIM_TEXT, -1 , 20)
	set_pdata_float(id, m_flNextAttack, WEAPON_DRAW_DELAY, 5);
	message_begin(MSG_ONE, get_user_msgid("HideWeapon"), {0,0,0}, id);
	write_byte(1<<6);
	message_end();
	return HAM_IGNORED;
}
public fw_Item_Holster_Post(ent) {
	if(!CustomItem(ent)) return HAM_IGNORED;
	static id; id = get_pdata_cbase(ent, m_pPlayer, 4);
	message_begin(MSG_ONE, get_user_msgid("HideWeapon"), {0,0,0}, id);
	write_byte(0);
	message_end();
	return HAM_IGNORED;
}
public fw_Weapon_Reload_Post(ent) {
	if(!CustomItem(ent)) return HAM_IGNORED;
	static clip; clip = cs_get_weapon_ammo(ent);
	static id; id = get_pdata_cbase(ent, m_pPlayer, 4);
	if(cs_get_user_bpammo(id, WEAPON_BASE_CSW) <= 0 || clip >= WEAPON_CLIP) return HAM_SUPERCEDE;
	UTIL_PlayWeaponAnimation(id, 6);
	g_mode[id] = 0;
	set_pdata_float(get_pdata_cbase(ent, m_pPlayer, 4), m_flNextAttack, WEAPON_RELOAD_TIME, 5);
	return HAM_IGNORED;
}
public fw_Weapon_PrimaryAttack(ent) {
	if(!CustomItem(ent) || !cs_get_weapon_ammo(ent)) return HAM_IGNORED;
	ExecuteHam(Ham_Weapon_PrimaryAttack, ent);
	static id; id = get_pdata_cbase(ent, m_pPlayer, 4);
	emit_sound(id, CHAN_WEAPON, WEAPON_SOUND_SHOOT, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
	UTIL_PlayWeaponAnimation(id, g_mode[id] ? 5 : 4);
	set_pdata_float(ent, m_flNextPrimaryAttack, WEAPON_SHOOT_DELAY, 4);
	static Float:Punchangle[3]; entity_get_vector(id, EV_VEC_punchangle, Punchangle);
	xs_vec_mul_scalar(Punchangle, WEAPON_RECOIL, Punchangle);
	entity_set_vector(id, EV_VEC_punchangle, Punchangle);
	UTIL_MakeMuzzle(id)
	fw_Weapon_MakeRocket(id)
	g_mode[id] = 0;
	return HAM_SUPERCEDE;
}
public fw_Weapon_MakeRocket(id) {
	static Float:StartOrigin[3], Float:TargetOrigin[3], Float:angles[3], Float:angles_fix[3];
	if(!g_mode[id]) get_position(id, 30.0, 8.0, -8.0, StartOrigin);
	else get_position(id, 30.0, 1.0, -15.0, StartOrigin);
	pev(id,pev_v_angle,angles);
	static Ent; Ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
	if(!pev_valid(Ent)) return;
	angles_fix[0] = 360.0 - angles[0];
	angles_fix[1] = angles[1];
	angles_fix[2] = angles[2];
	set_pev(Ent, pev_movetype, MOVETYPE_TOSS);
	set_pev(Ent, pev_owner, id);
	entity_set_string(Ent, EV_SZ_classname, WEAPON_ROCKET_CLASS);
	engfunc(EngFunc_SetModel, Ent, WEAPON_MODEL_ROCKET);
	set_pev(Ent, pev_mins,{ -0.1, -0.1, -0.1 });
	set_pev(Ent, pev_maxs,{ 0.1, 0.1, 0.1 });
	set_pev(Ent, pev_origin, StartOrigin);
	set_pev(Ent, pev_angles, angles_fix);
	set_pev(Ent, pev_gravity, g_mode[id] ? 0.01 : -0.4);
	set_pev(Ent, pev_solid, SOLID_BBOX);
	set_pev(Ent, pev_frame, 0.0);
	set_pev(Ent, pev_nextthink, get_gametime() + 0.2)
	static Float:Velocity[3];
	fm_get_aim_origin(id, TargetOrigin);
	get_speed_vector(StartOrigin, TargetOrigin, 1500.0, Velocity);
	set_pev(Ent, pev_velocity, Velocity);
}
public fw_RocketThink(ent) {
	if(!pev_valid(ent)) return;
	new Float:Origin[3];
	pev(ent, pev_origin, Origin)
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_EXPLOSION);
	engfunc(EngFunc_WriteCoord, Origin[0]);
	engfunc(EngFunc_WriteCoord, Origin[1]);
	engfunc(EngFunc_WriteCoord, Origin[2]-10);
	write_short(g_smoke_id);
	write_byte(2);
	write_byte(40);
	write_byte(TE_EXPLFLAG_NOPARTICLES | TE_EXPLFLAG_NOSOUND | TE_EXPLFLAG_NODLIGHTS);
	message_end();
	set_pev(ent, pev_nextthink, get_gametime() + 0.07)
}
public fw_RocketTouch(Ent, Id) {
	if(!pev_valid(Ent)) return;
	static classnameptd[32]; pev(Id, pev_classname, classnameptd, 31);
	if (equali(classnameptd, "func_breakable")) ExecuteHamB(Ham_TakeDamage, Id, 0, 0, 300.0, DMG_GENERIC);
	new Float:originZ[3], Float:originX[3];
	pev(Ent, pev_origin, originX);
	entity_get_vector(Ent, EV_VEC_origin, originZ);
	engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, originX, 0);
	write_byte(TE_WORLDDECAL);
	engfunc(EngFunc_WriteCoord, originZ[0]);
	engfunc(EngFunc_WriteCoord, originZ[1]);
	engfunc(EngFunc_WriteCoord, originZ[2]);
	write_byte(engfunc(EngFunc_DecalIndex,"{scorch3"));
	message_end();
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_EXPLOSION);
	engfunc(EngFunc_WriteCoord, originZ[0]);
	engfunc(EngFunc_WriteCoord, originZ[1]);
	engfunc(EngFunc_WriteCoord, originZ[2] + 50);
	write_short(sExplo);
	write_byte(25);
	write_byte(30);
	write_byte(0);
	message_end();
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_EXPLOSION);
	engfunc(EngFunc_WriteCoord, originX[0]);
	engfunc(EngFunc_WriteCoord, originX[1] + 50);
	engfunc(EngFunc_WriteCoord, originX[2] + 80);
	write_short(sExploSmall);
	write_byte(25);
	write_byte(30);
	write_byte(TE_EXPLFLAG_NOPARTICLES | TE_EXPLFLAG_NOSOUND);
	message_end();
	fw_DamageRocket(Ent);
	remove_entity(Ent);
}
public fw_DamageRocket(Ent) {
	static Owner; Owner = pev(Ent, pev_owner);
	static Attacker;
	if(!is_user_alive(Owner)) {
		Attacker = 0;
		return;
	} 
	else {
		Attacker = Owner;
	}
	for(new i = 0; i < g_MaxPlayers; i++) {
		if(!is_user_alive(i)) continue;
		if(entity_range(i, Ent) > EXPLODE_RADIUS) continue;
		//if(!ze_is_user_zombie(i)) continue; 
		ExecuteHamB(Ham_TakeDamage, i, 0, Attacker, EXPLODE_DAMAGE, DMG_BULLET);
	}
}
public fw_Item_AddToPlayer_Post(ent, id) {
	switch(entity_get_int(ent, EV_INT_impulse)) {
		case 0: UTIL_Weaponlist(id, WEAPON_BASE_ENT, 2, 90, 0, 1, WEAPON_BASE_CSW, 0);
		case WEAPON_SPECIAL_KEY: UTIL_Weaponlist(id, WEAPON_SPRITE_NAME, 2, WEAPON_AMMO, 0, 1, WEAPON_BASE_CSW, 0);
	}
}
public fw_TraceAttack(entity, attacker, Float:damage) {
         if(!IsConnected(attacker) || !CustomItem(get_pdata_cbase(attacker, m_pActiveItem, 5))) return HAM_IGNORED;
         return HAM_SUPERCEDE;
}
public fw_TraceAttack_Post(entity, attacker, Float:damage, Float:fDir[3], ptr, damagetype) {
         if(!CustomItem(get_pdata_cbase(attacker, m_pActiveItem, 5))) return HAM_IGNORED;
         return HAM_SUPERCEDE;
}
public fw_Spawn_Weaponbox_Post(ent) {
	if(is_valid_ent(ent))
		state (is_valid_ent(entity_get_edict(ent, EV_ENT_owner))) WeaponBox_Enabled;
}
public fw_UpdateClientData_Post(id, SendWeapons, CD_Handle) {
        if(!is_user_alive(id) || !CustomItem(get_pdata_cbase(id, m_pActiveItem, 5))) return FMRES_IGNORED;
        set_cd(CD_Handle, CD_flNextAttack, 999999.0);
        return FMRES_HANDLED;
}
public fw_SetModel(entity) <WeaponBox_Enabled> {
	state WeaponBox_Disabled;
	if(!is_valid_ent(entity)) return FMRES_IGNORED;
	static i;
	for(i = 0; i < 6; i++) {
		static item; item = get_pdata_cbase(entity, m_rgpPlayerItems_CWeaponBox + i, 4);
		if(is_valid_ent(item) && CustomItem(item)) {
			entity_set_model(entity, WEAPON_MODEL_WORLD);
			return FMRES_SUPERCEDE;
		}
	}
	return FMRES_IGNORED;
}
public fw_SetModel() <WeaponBox_Disabled> {
	return FMRES_IGNORED;
}
public fw_PrecacheEvent_Post(type, name[]) {
	if(equal(WEAPON_EVENT, name)) {
		g_event = get_orig_retval();
		return FMRES_HANDLED;
	}
	return FMRES_IGNORED;
}
public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:iangles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2) {
	if(eventid != g_event || !IsConnected(invoker) || !CustomItem(get_pdata_cbase(invoker, m_pActiveItem, 5))) return FMRES_IGNORED;
	return FMRES_SUPERCEDE;
}
public UTIL_MakeMuzzle(id) {
	static Float:Origin[3];
	if(!g_mode[id]) get_position(id, 30.0, 8.0, -15.0, Origin);
	else get_position(id, 30.0, 1.0, -15.0, Origin);
	engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, Origin, id);
	write_byte(TE_EXPLOSION);
	engfunc(EngFunc_WriteCoord, Origin[0]);
	engfunc(EngFunc_WriteCoord, Origin[1]);
	engfunc(EngFunc_WriteCoord, Origin[2]);
	write_short(sMuzzleFlash)
	write_byte(9);
	write_byte(20);
	write_byte(TE_EXPLFLAG_NOPARTICLES | TE_EXPLFLAG_NOSOUND | TE_EXPLFLAG_NODLIGHTS);
	message_end();
}
stock GetEntityTouchDirect(ent, Float:target[3], speed) {
	static Float:vec[3];
	aim_at_origin(ent,target,vec);
	engfunc(EngFunc_MakeVectors, vec);
	global_get(glb_v_forward, vec);
	vec[0] *= speed;
	vec[1] *= speed;
	vec[2] *= speed * 0.1;
	set_pev(ent, pev_velocity, vec);
	new Float:angle[3];
	aim_at_origin(ent, target, angle);
	angle[0] = 0.0;
	entity_set_vector(ent, EV_VEC_angles, angle);
}
stock get_position(id,Float:forw, Float:right, Float:up, Float:vStart[]) {
	static Float:vOrigin[3], Float:vAngle[3], Float:vForward[3], Float:vRight[3], Float:vUp[3];
	pev(id, pev_origin, vOrigin);
	pev(id, pev_view_ofs, vUp);
	xs_vec_add(vOrigin, vUp, vOrigin);
	pev(id, pev_v_angle, vAngle);
	angle_vector(vAngle, ANGLEVECTOR_FORWARD, vForward);
	angle_vector(vAngle, ANGLEVECTOR_RIGHT, vRight);
	angle_vector(vAngle, ANGLEVECTOR_UP, vUp);
	vStart[0] = vOrigin[0] + vForward[0] * forw + vRight[0] * right + vUp[0] * up;
	vStart[1] = vOrigin[1] + vForward[1] * forw + vRight[1] * right + vUp[1] * up;
	vStart[2] = vOrigin[2] + vForward[2] * forw + vRight[2] * right + vUp[2] * up;
}
stock get_speed_vector(const Float:origin1[3],const Float:origin2[3],Float:speed, Float:new_velocity[3]) {
	new_velocity[0] = origin2[0] - origin1[0];
	new_velocity[1] = origin2[1] - origin1[1];
	new_velocity[2] = origin2[2] - origin1[2];
	static Float:num; num = floatsqroot(speed * speed / (new_velocity[0] * new_velocity[0] + new_velocity[1] * new_velocity[1] + new_velocity[2] * new_velocity[2]));
	new_velocity[0] *= num;
	new_velocity[1] *= num;
	new_velocity[2] *= num;
	return 1;
}
stock UTIL_PlayWeaponAnimation(id, Sequence) {
	entity_set_int(id, EV_INT_weaponanim, Sequence);
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, _, id);
	write_byte(Sequence);
	write_byte(0);
	message_end();
}
stock UTIL_DropWeapon(id, slot) {
        if(!(1 <= slot <= 2)) return 0;
        static iCount; iCount = 0;
        static iEntity; iEntity = get_pdata_cbase(id, (m_rpgPlayerItems + slot), 5);
        if(iEntity > 0) {
               static iNext;
               static szWeaponName[32];
               do{
                       iNext = get_pdata_cbase(iEntity, m_pNext, 4);
                       if(get_weaponname(cs_get_weapon_id(iEntity), szWeaponName, charsmax(szWeaponName))) {  
                               engclient_cmd(id, "drop", szWeaponName);
                               iCount++;
		       }
               } while(( iEntity = iNext) > 0);
	}
        return iCount;
}
stock UTIL_Weaponlist(id, weaponlist[], int, int2, int3, int4, int5, int6) {
	static msg_WeaponList; if(!msg_WeaponList) msg_WeaponList = get_user_msgid("WeaponList");
	message_begin(MSG_ONE, msg_WeaponList, _, id);
	write_string(weaponlist);
	write_byte(int);
	write_byte(int2);
	write_byte(-1);
	write_byte(-1);
	write_byte(int3);
	write_byte(int4);
	write_byte(int5);
	write_byte(int6);
	message_end();
}
stock UTIL_AmmoPickup(id, AmmoID, Amount) {
	static msg_AmmoPickup; if(!msg_AmmoPickup) msg_AmmoPickup = get_user_msgid("AmmoPickup");
	message_begin(MSG_ONE_UNRELIABLE, msg_AmmoPickup, _, id);
	write_byte(AmmoID);
	write_byte(Amount);
	message_end();
}
stock AmmoPickup_Icon(id, AmmoID, Clip, Amount) {
	static i, count; count = floatround(Amount*1.0/Clip, floatround_floor);
	static AmountAmmo; AmountAmmo = 0;
	for(i=0;i<count;i++) {
		UTIL_AmmoPickup(id, AmmoID, Clip);
		AmountAmmo+=Clip;
	}
	static RestAmmo; RestAmmo = Amount-AmountAmmo;
	if(RestAmmo) UTIL_AmmoPickup(id, AmmoID, RestAmmo);
}
stock GetAmmoDifference(id, csw, amount) {
	static ammo; ammo = cs_get_user_bpammo(id, csw);
	if(ammo >= amount) return 0;
	return amount-ammo;
}
public event_round_start()     if (get_pcvar_num(cvar_show_tip))     set_task(5.0,"wellcome",201707281354)
public wellcome()
{
	color_saytext(0,"^x04[weapon_rpg7]^x01 The plugin author by PlaneShfit1231 / Batcon!")
	if (task_exists(201707281354)) remove_task(201707281354)
	set_task(60.0, "wellcome", 201707281354)
}
color_saytext(player, const message[], any:...)
{
	new text[301],dest 
	format(text, 300, "%s", message)

	if (player) dest = MSG_ONE
	else dest = MSG_ALL
	
	message_begin(dest, get_user_msgid("SayText"), {0,0,0}, player)
	write_byte(1)
	write_string(check_text(text))
	return message_end()
}
check_text(text1[])
{
	new text[301]
	format(text, 300, "%s", text1)
	replace(text, 300, ">x04", "^x04")
	replace(text, 300, ">x03", "^x03")
	replace(text, 300, ">x01", "^x01")
	return text
}

/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ ansicpg936\\ deff0{\\ fonttbl{\\ f0\\ fnil\\ fcharset134 Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang2052\\ f0\\ fs16 \n\\ par }
*/