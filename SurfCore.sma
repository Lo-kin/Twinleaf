#include <amxmodx>
#include <fakemeta>
#include <reapi>

#define PLUGIN_NAME "SurfCore"
#define PLUGIN_VERSION "1.0"
#define SURF_STEP_WALL_Z_MAX 0.05
#define SURF_STEP_MIN_INTO_SPEED 20.0
#define SURF_SEAM_MIN_SPEED 50.0
#define AUTO_STEP_MIN 0.125
#define AUTO_STEP_HARD_MAX 18.0
#define AUTO_STEP_BINARY_ITERS 5
#define GROUND_WALKABLE_Z 0.70
#define GROUND_TRACE_UP_EPSILON 0.25

#define SURF_PLANE_Z_EPSILON       0.001
#define SURF_PLANE_HORIZ_SQ_MIN    0.000001

#define RAMP_TANGENT_MIN_HORIZ_SQ    0.0025
#define RAMP_TANGENT_Z_MAX           0.9995
#define RAMP_TANGENT_TRACE_FRAC_MAX  0.001
#define RAMP_TANGENT_MAX_INTO        8.0
#define RAMP_TANGENT_MAX_RATIO       0.01

#define SURF_STALL_POST_SPEED      2.0
#define SURF_STALL_MAX_MOVE        0.02
#define SURF_STALL_TRACE_FRAC_MAX  0.00010
#define SURF_RECOVERY_MIN_NUDGE    0.001
#define SURF_RECOVERY_MAX_NUDGE    0.125
#define SURF_CLIP_STOP_EPSILON     0.10

#define SURF_MICRO_STEP_TIME       0.001
#define SURF_MICRO_MAX_STEPS       64
#define SURF_MICRO_BUMPS           4
#define SURF_MICRO_MIN_SPEED       30.0
#define SURF_MICRO_HARD_STALL_RATIO 0.35
#define SURF_MICRO_CONTACT_FRAC_MAX  0.010
#define SURF_MICRO_MIN_EXPECTED    0.05
#define SURF_MICRO_MIN_PROGRESS    0.0005
#define SURF_MICRO_NUDGE_MIN       0.001
#define SURF_MICRO_NUDGE_MAX       0.250
#define SURF_MICRO_SAME_PLANE_DOT  0.95

#define SURF_NATIVE_MIN_SPEED       20.0

new g_pEnabled, g_pStepSizeFix, g_pStepSizeValue, g_pBoost, g_pBoostAccel, g_pBoostMax;
new g_pFlyMoveMethod;

#define SURF_SMOOTH_RATIO 0.98

new bool:g_bAirMoveSaved[33], bool:g_bAirTraceLift[33];
new Float:g_vecAirStartOrigin[33][3], Float:g_vecAirInputVelocity[33][3], Float:g_vecAirBaseVelocity[33][3];
new Float:g_flAirFrameTime[33], g_iAirHull[33];
new Float:g_flAirTraceLift[33], Float:g_vecAirExpectedEnd[33][3], Float:g_vecAirExpectedVelocity[33][3];
new Float:g_sideMove[33];

new bool:g_bNativeM1Active[33];
new g_iNativeM1SavedValue[33];

new Float:g_vecSurfRawFlyInput[33][3];

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, "Rem");

    g_pEnabled = register_cvar("surf_fix_enabled", "1");

    g_pStepSizeFix = register_cvar("surf_fix_stepsize", "1");
    g_pStepSizeValue = register_cvar("surf_fix_stepsize_value", "18.0");
    g_pBoost = register_cvar("surf_boost", "0");
    g_pBoostAccel = register_cvar("surf_boost_accel", "200.0");
    g_pBoostMax = register_cvar("surf_boost_maxspeed", "2000.0");

    g_pFlyMoveMethod = get_cvar_pointer("mp_flymove_method");

    register_forward(FM_CmdStart, "CmdStart");

    RegisterHookChain(RG_PM_AirMove, "PM_AirMove_Pre", false);
    RegisterHookChain(RG_PM_AirAccelerate, "PM_AirAccelerate_Post", true);
    RegisterHookChain(RG_PM_AirMove, "PM_AirMove_Post", true);
}

public plugin_end()
{
    for (new id = 1; id <= 32; id++)
    {
        if (g_bNativeM1Active[id] && g_pFlyMoveMethod)
        {
            set_pcvar_num(g_pFlyMoveMethod, g_iNativeM1SavedValue[id]);
            g_bNativeM1Active[id] = false;
        }
    }

}

public client_putinserver(id)
{
    reset_state(id);
}

public client_disconnected(id)
{
    if (g_bNativeM1Active[id] && g_pFlyMoveMethod)
    {
        set_pcvar_num(g_pFlyMoveMethod, g_iNativeM1SavedValue[id]);
        g_bNativeM1Active[id] = false;
    }

    reset_state(id);
}

stock reset_state(id)
{
    g_bAirMoveSaved[id] = false;
    g_bAirTraceLift[id] = false;
    g_bNativeM1Active[id] = false;
    g_iNativeM1SavedValue[id] = 0;

    g_sideMove[id] = 0.0;
    g_flAirFrameTime[id] = 0.0;
    g_flAirTraceLift[id] = 0.0;

    for (new i = 0; i < 3; i++)
    {
        g_vecAirStartOrigin[id][i] = 0.0;
        g_vecAirInputVelocity[id][i] = 0.0;
        g_vecAirBaseVelocity[id][i] = 0.0;
        g_vecAirExpectedEnd[id][i] = 0.0;
        g_vecAirExpectedVelocity[id][i] = 0.0;

        g_vecSurfRawFlyInput[id][i] = 0.0;
    }
}

public CmdStart(id, uc, seed)
{
    get_uc(uc, UC_SideMove, g_sideMove[id]);
    return FMRES_IGNORED;
}

stock apply_surf_boost(id, const Float:wish[3], Float:wishSpeed)
{
    if (!get_pcvar_num(g_pBoost) || floatabs(g_sideMove[id]) < 1.0
        || wishSpeed <= 0.0 || get_pmove(pm_onground) != -1) return;
    new Float:base[3]; get_pmove(pm_basevelocity, base);
    if (vec_length_sq(base) > 0.0001) return;
    new Float:origin[3], Float:end[3], Float:normal[3], Float:v[3];
    get_pmove(pm_origin, origin); vec_copy(origin,end); end[2] -= 2.0;
    new hull = g_iAirHull[id] == 1 ? HULL_HEAD : HULL_HUMAN;
    new tr = create_tr2();
    engfunc(EngFunc_TraceHull, origin, end, IGNORE_MONSTERS, hull, id, tr);
    new Float:f; get_tr2(tr,TR_flFraction,f);
    get_tr2(tr,TR_vecPlaneNormal,normal);
    new bool:ramp = !get_tr2(tr,TR_StartSolid) && !get_tr2(tr,TR_AllSolid)
        && f < 1.0 && is_static_surf_brush(get_tr2(tr,TR_pHit))
        && normal[2] > 0.05 && normal[2] < 0.9995;
    free_tr2(tr);
    if (!ramp) return;
    get_pmove(pm_velocity,v);
    new Float:speed = floatsqroot(vec_length_2d_sq(v));
    new Float:limit = floatmin(floatclamp(get_pcvar_float(g_pBoostMax),50.0,4000.0),
        Float:get_movevar(mv_maxvelocity));
    if (speed < SURF_SEAM_MIN_SPEED || speed >= limit) return;
    new Float:projection = v[0]*wish[0]+v[1]*wish[1];

    new Float:room = floatmin(60.0,wishSpeed)-projection;
    if (projection < 0.0 || room <= 0.0) return;
    new Float:add = floatmin(room,floatclamp(get_pcvar_float(g_pBoostAccel),0.0,1000.0)
        * floatmin(g_flAirFrameTime[id],0.05));
    if (add <= 0.0) return;

    new Float:wishSq = wish[0]*wish[0]+wish[1]*wish[1];
    if (wishSq < 0.0001) return;
    new Float:maxAdd = (floatsqroot(projection*projection
        + wishSq*(limit*limit-speed*speed))-projection)/wishSq;
    add = floatmin(add,floatmax(0.0,maxAdd));
    v[0] += wish[0]*add; v[1] += wish[1]*add;
    set_pmove(pm_velocity,v);
}

public PM_AirMove_Post(id)
{

    if (g_bNativeM1Active[id])
    {

        if (vec_length_sq(g_vecAirBaseVelocity[id]) <= 0.0001)
        {
            new Float:nativeVelocity[3];
            get_pmove(pm_velocity, nativeVelocity);
            clamp_vector_length(nativeVelocity, g_vecSurfRawFlyInput[id]);
            set_pmove(pm_velocity, nativeVelocity);
        }
        if (g_pFlyMoveMethod)
        {
            set_pcvar_num(g_pFlyMoveMethod, g_iNativeM1SavedValue[id]);
        }

        g_bNativeM1Active[id] = false;
    }

    if (!g_bAirMoveSaved[id])
    {
        return HC_CONTINUE;
    }

    g_bAirMoveSaved[id] = false;

    if (!g_bAirTraceLift[id])
    {
        if (!RecoverSurfMicrostep(id))
        {
            RecoverConfirmedSurfStall(id);
        }
        return HC_CONTINUE;
    }

    g_bAirTraceLift[id] = false;

    new Float:result[3], Float:velocity[3], Float:delta[3];
    get_pmove(pm_origin, result);
    get_pmove(pm_velocity, velocity);

    new hull = g_iAirHull[id] == 1 ? HULL_HEAD : HULL_HUMAN;

    for (new a = 0; a < 2; a++)
    {
        delta[a] = result[a] - g_vecAirExpectedEnd[id][a];
    }

    if (get_pmove(pm_usehull) != g_iAirHull[id]
        || vec_length_2d_sq(delta) > 0.0001
        || !clear_hull_segment(id, hull, result, g_vecAirExpectedEnd[id])
        || !is_hull_vacant(id, hull, g_vecAirExpectedEnd[id]))
    {
        set_pmove(pm_origin, g_vecAirStartOrigin[id]);

        new Float:stop[3];
        set_pmove(pm_velocity, stop);

        if (!RecoverSurfMicrostep(id))
        {
            RecoverConfirmedSurfStall(id);
        }
        return HC_CONTINUE;
    }

    new Float:rise = floatmax(
        0.0,
        g_vecAirExpectedEnd[id][2] - (result[2] - g_flAirTraceLift[id])
    );

    new Float:gravity = Float:get_pmove(pm_gravity);

    if (gravity == 0.0)
    {
        gravity = 1.0;
    }

    gravity *= Float:get_movevar(mv_gravity);

    new Float:sq = vec_length_sq(velocity);
    new Float:budget = floatmax(
        0.0,
        sq - 2.0 * floatmax(0.0, gravity) * rise
    );

    budget = floatmin(budget, vec_length_sq(g_vecAirExpectedVelocity[id]));

    if (sq > 0.0)
    {
        new Float:scale = floatsqroot(budget / sq);

        for (new a = 0; a < 3; a++)
        {
            velocity[a] *= scale;
        }
    }

    set_pmove(pm_origin, g_vecAirExpectedEnd[id]);
    set_pmove(pm_velocity, velocity);
    return HC_CONTINUE;
}

stock bool:RecoverSurfMicrostep(id)
{
    if (!get_pcvar_num(g_pEnabled)
        || g_flAirFrameTime[id] <= 0.0
        || get_pmove(pm_usehull) != g_iAirHull[id]
        || vec_length_sq(g_vecAirBaseVelocity[id]) > 0.0001)
    {
        return false;
    }

    new Float:flRawSpeedSq = vec_length_sq(g_vecSurfRawFlyInput[id]);

    if (flRawSpeedSq < (SURF_MICRO_MIN_SPEED * SURF_MICRO_MIN_SPEED))
    {
        return false;
    }

    new Float:flRawSpeed = floatsqroot(flRawSpeedSq);
    new Float:flExpectedDist = flRawSpeed * g_flAirFrameTime[id];

    if (flExpectedDist < SURF_MICRO_MIN_EXPECTED)
    {
        return false;
    }

    new Float:vecEngineOrigin[3];
    get_pmove(pm_origin, vecEngineOrigin);

    new Float:vecEngineDelta[3];
    vecEngineDelta[0] = vecEngineOrigin[0] - g_vecAirStartOrigin[id][0];
    vecEngineDelta[1] = vecEngineOrigin[1] - g_vecAirStartOrigin[id][1];
    vecEngineDelta[2] = vecEngineOrigin[2] - g_vecAirStartOrigin[id][2];

    new Float:flEngineDist = floatsqroot(vec_length_sq(vecEngineDelta));
    new Float:flProgressRatio = flEngineDist / flExpectedDist;

    new Float:flSmoothRatio = SURF_SMOOTH_RATIO;

    if (flSmoothRatio < 0.50)
    {
        flSmoothRatio = 0.50;
    }
    else if (flSmoothRatio > 0.999)
    {
        flSmoothRatio = 0.999;
    }

    if (flProgressRatio > flSmoothRatio)
    {
        return false;
    }

    new iHull = (g_iAirHull[id] == 1) ? HULL_HEAD : HULL_HUMAN;

    new Float:vecRawEnd[3];
    vecRawEnd[0] = g_vecAirStartOrigin[id][0] + g_vecSurfRawFlyInput[id][0] * g_flAirFrameTime[id];
    vecRawEnd[1] = g_vecAirStartOrigin[id][1] + g_vecSurfRawFlyInput[id][1] * g_flAirFrameTime[id];
    vecRawEnd[2] = g_vecAirStartOrigin[id][2] + g_vecSurfRawFlyInput[id][2] * g_flAirFrameTime[id];

    new tr = create_tr2();
    engfunc(
        EngFunc_TraceHull,
        g_vecAirStartOrigin[id],
        vecRawEnd,
        0,
        iHull,
        id,
        tr
    );

    new bStartSolid = get_tr2(tr, TR_StartSolid);
    new bAllSolid = get_tr2(tr, TR_AllSolid);
    new iHit = get_tr2(tr, TR_pHit);
    new Float:flFraction;
    new Float:vecNormal[3];
    get_tr2(tr, TR_flFraction, flFraction);
    get_tr2(tr, TR_vecPlaneNormal, vecNormal);
    free_tr2(tr);

    if (bStartSolid
        || bAllSolid
        || !is_static_surf_brush(iHit)
        || flFraction >= 1.0
        || !is_method1_surf_normal(vecNormal))
    {
        return false;
    }

    new bool:bHardStall =
        flProgressRatio <= SURF_MICRO_HARD_STALL_RATIO;

    new bool:bSmoothContactHitch =
        flFraction <= SURF_MICRO_CONTACT_FRAC_MAX
        && flProgressRatio < flSmoothRatio;

    if (!bHardStall && !bSmoothContactHitch)
    {
        return false;
    }

    new Float:vecRecoveredOrigin[3], Float:vecRecoveredVelocity[3];
    new iSteps, iCollisions, iNudges;
    new Float:flMaxNudge;

    if (!simulate_surf_microsteps(
        id,
        iHull,
        g_vecAirStartOrigin[id],
        g_vecSurfRawFlyInput[id],
        g_flAirFrameTime[id],
        vecRecoveredOrigin,
        vecRecoveredVelocity,
        iSteps,
        iCollisions,
        iNudges,
        flMaxNudge
    ))
    {
        return false;
    }

    new Float:vecRecoveredDelta[3];
    vecRecoveredDelta[0] = vecRecoveredOrigin[0] - g_vecAirStartOrigin[id][0];
    vecRecoveredDelta[1] = vecRecoveredOrigin[1] - g_vecAirStartOrigin[id][1];
    vecRecoveredDelta[2] = vecRecoveredOrigin[2] - g_vecAirStartOrigin[id][2];

    new Float:flRecoveredDist = floatsqroot(vec_length_sq(vecRecoveredDelta));

    if (flRecoveredDist <= flEngineDist + 0.01
        || flRecoveredDist < SURF_MICRO_MIN_PROGRESS)
    {
        return false;
    }

    clamp_vector_length(vecRecoveredVelocity, g_vecSurfRawFlyInput[id]);

    set_pmove(pm_origin, vecRecoveredOrigin);
    set_pmove(pm_velocity, vecRecoveredVelocity);

    return true;
}

stock bool:simulate_surf_microsteps(
    id,
    iHull,
    const Float:vecStart[3],
    const Float:vecInputVelocity[3],
    Float:flTotalTime,
    Float:vecOutOrigin[3],
    Float:vecOutVelocity[3],
    &iSteps,
    &iCollisions,
    &iNudges,
    &Float:flMaxNudge
)
{
    vec_copy(vecStart, vecOutOrigin);
    vec_copy(vecInputVelocity, vecOutVelocity);

    iSteps = floatround(flTotalTime / SURF_MICRO_STEP_TIME, floatround_ceil);

    if (iSteps < 1)
    {
        iSteps = 1;
    }
    else if (iSteps > SURF_MICRO_MAX_STEPS)
    {
        iSteps = SURF_MICRO_MAX_STEPS;
    }

    new Float:flStepTime = flTotalTime / float(iSteps);
    iCollisions = 0;
    iNudges = 0;
    flMaxNudge = 0.0;

    for (new iStep = 0; iStep < iSteps; iStep++)
    {
        new Float:flTimeLeft = flStepTime;
        new bool:bFinishedStep = false;

        for (new iBump = 0; iBump < SURF_MICRO_BUMPS; iBump++)
        {
            if (flTimeLeft <= 0.000001
                || vec_length_sq(vecOutVelocity) < 0.000001)
            {
                bFinishedStep = true;
                break;
            }

            new Float:vecEnd[3];
            vecEnd[0] = vecOutOrigin[0] + vecOutVelocity[0] * flTimeLeft;
            vecEnd[1] = vecOutOrigin[1] + vecOutVelocity[1] * flTimeLeft;
            vecEnd[2] = vecOutOrigin[2] + vecOutVelocity[2] * flTimeLeft;

            new tr = create_tr2();
            engfunc(EngFunc_TraceHull, vecOutOrigin, vecEnd, 0, iHull, id, tr);

            new bStartSolid = get_tr2(tr, TR_StartSolid);
            new bAllSolid = get_tr2(tr, TR_AllSolid);
            new iHit = get_tr2(tr, TR_pHit);
            new Float:flFraction;
            new Float:vecEndPos[3], Float:vecNormal[3];
            get_tr2(tr, TR_flFraction, flFraction);
            get_tr2(tr, TR_vecEndPos, vecEndPos);
            get_tr2(tr, TR_vecPlaneNormal, vecNormal);
            free_tr2(tr);

            if (bStartSolid || bAllSolid || !is_static_surf_brush(iHit))
            {
                return false;
            }

            if (flFraction > 0.0)
            {
                vec_copy(vecEndPos, vecOutOrigin);
            }

            if (flFraction >= 1.0)
            {
                bFinishedStep = true;
                break;
            }

            if (!is_method1_surf_normal(vecNormal))
            {
                return false;
            }

            iCollisions++;
            flTimeLeft -= flTimeLeft * flFraction;

            new Float:vecBeforeClip[3];
            vec_copy(vecOutVelocity, vecBeforeClip);
            surf_clip_velocity(vecOutVelocity, vecNormal, vecOutVelocity);

            new Float:flInto = vec_dot(vecOutVelocity, vecNormal);

            if (flInto < 0.0)
            {
                vecOutVelocity[0] -= vecNormal[0] * flInto;
                vecOutVelocity[1] -= vecNormal[1] * flInto;
                vecOutVelocity[2] -= vecNormal[2] * flInto;
            }

            clamp_vector_length(vecOutVelocity, vecBeforeClip);

            if (vec_length_sq(vecOutVelocity) < 1.0)
            {
                return false;
            }

            if (flFraction <= SURF_STALL_TRACE_FRAC_MAX)
            {
                new Float:flUsedNudge = 0.0;

                if (!micro_nudge_out_of_surf(
                    id,
                    iHull,
                    vecOutOrigin,
                    vecOutVelocity,
                    vecNormal,
                    flTimeLeft,
                    flUsedNudge
                ))
                {
                    return false;
                }

                iNudges++;

                if (flUsedNudge > flMaxNudge)
                {
                    flMaxNudge = flUsedNudge;
                }
            }
        }

        if (!bFinishedStep && flTimeLeft > 0.000001)
        {
            return false;
        }
    }

    return true;
}

stock bool:micro_nudge_out_of_surf(
    id,
    iHull,
    Float:vecOrigin[3],
    Float:vecVelocity[3],
    const Float:vecPrimaryNormal[3],
    Float:flTimeLeft,
    &Float:flUsedNudge
)
{
    new Float:vecNudgeDir[3];
    vec_copy(vecPrimaryNormal, vecNudgeDir);

    new Float:vecProbeEnd[3];
    vecProbeEnd[0] = vecOrigin[0] + vecVelocity[0] * flTimeLeft;
    vecProbeEnd[1] = vecOrigin[1] + vecVelocity[1] * flTimeLeft;
    vecProbeEnd[2] = vecOrigin[2] + vecVelocity[2] * flTimeLeft;

    new trProbe = create_tr2();
    engfunc(EngFunc_TraceHull, vecOrigin, vecProbeEnd, 0, iHull, id, trProbe);

    new Float:flProbeFraction;
    new Float:vecSecondNormal[3];
    get_tr2(trProbe, TR_flFraction, flProbeFraction);
    get_tr2(trProbe, TR_vecPlaneNormal, vecSecondNormal);
    new bProbeStartSolid = get_tr2(trProbe, TR_StartSolid);
    new bProbeAllSolid = get_tr2(trProbe, TR_AllSolid);
    new iProbeHit = get_tr2(trProbe, TR_pHit);
    free_tr2(trProbe);

    if (!bProbeStartSolid
        && !bProbeAllSolid
        && is_static_surf_brush(iProbeHit)
        && flProbeFraction <= SURF_STALL_TRACE_FRAC_MAX
        && is_method1_surf_normal(vecSecondNormal)
        && vec_dot(vecPrimaryNormal, vecSecondNormal) >= SURF_MICRO_SAME_PLANE_DOT)
    {
        new Float:vecBeforeSecond[3];
        vec_copy(vecVelocity, vecBeforeSecond);
        surf_clip_velocity(vecVelocity, vecSecondNormal, vecVelocity);
        clamp_vector_length(vecVelocity, vecBeforeSecond);

        vecNudgeDir[0] += vecSecondNormal[0];
        vecNudgeDir[1] += vecSecondNormal[1];
        vecNudgeDir[2] += vecSecondNormal[2];
        normalize_vector3(vecNudgeDir);
    }

    new Float:flNudge = SURF_MICRO_NUDGE_MIN;

    for (new i = 0; i < 9; i++)
    {
        if (flNudge > SURF_MICRO_NUDGE_MAX)
        {
            flNudge = SURF_MICRO_NUDGE_MAX;
        }

        new Float:vecCandidateStart[3];
        vecCandidateStart[0] = vecOrigin[0] + vecNudgeDir[0] * flNudge;
        vecCandidateStart[1] = vecOrigin[1] + vecNudgeDir[1] * flNudge;
        vecCandidateStart[2] = vecOrigin[2] + vecNudgeDir[2] * flNudge;

        new Float:vecCandidateEnd[3];
        vecCandidateEnd[0] = vecCandidateStart[0] + vecVelocity[0] * flTimeLeft;
        vecCandidateEnd[1] = vecCandidateStart[1] + vecVelocity[1] * flTimeLeft;
        vecCandidateEnd[2] = vecCandidateStart[2] + vecVelocity[2] * flTimeLeft;

        new tr = create_tr2();
        engfunc(EngFunc_TraceHull, vecCandidateStart, vecCandidateEnd, 0, iHull, id, tr);

        new bStartSolid = get_tr2(tr, TR_StartSolid);
        new bAllSolid = get_tr2(tr, TR_AllSolid);
        new iHit = get_tr2(tr, TR_pHit);
        new Float:flFraction;
        new Float:vecHitNormal[3];
        get_tr2(tr, TR_flFraction, flFraction);
        get_tr2(tr, TR_vecPlaneNormal, vecHitNormal);
        free_tr2(tr);

        if (!bStartSolid && !bAllSolid && is_static_surf_brush(iHit))
        {
            if (flFraction >= SURF_MICRO_MIN_PROGRESS)
            {
                vec_copy(vecCandidateStart, vecOrigin);
                flUsedNudge = flNudge;
                return true;
            }

            if (!(flFraction <= SURF_STALL_TRACE_FRAC_MAX
                && is_method1_surf_normal(vecHitNormal)
                && vec_dot(vecNudgeDir, vecHitNormal) >= SURF_MICRO_SAME_PLANE_DOT))
            {
                return false;
            }
        }

        if (flNudge >= SURF_MICRO_NUDGE_MAX)
        {
            break;
        }

        flNudge *= 2.0;
    }

    return false;
}

stock Float:normalize_vector3(Float:vec[3])
{
    new Float:flLength = floatsqroot(vec_length_sq(vec));

    if (flLength <= 0.000001)
    {
        return 0.0;
    }

    vec[0] /= flLength;
    vec[1] /= flLength;
    vec[2] /= flLength;
    return flLength;
}

stock bool:RecoverConfirmedSurfStall(id)
{
    if (!get_pcvar_num(g_pEnabled)
        || g_flAirFrameTime[id] <= 0.0
        || get_pmove(pm_usehull) != g_iAirHull[id]
        || vec_length_sq(g_vecAirBaseVelocity[id]) > 0.0001)
    {
        return false;
    }

    new Float:flRaw2DSq = vec_length_2d_sq(g_vecSurfRawFlyInput[id]);

    if (flRaw2DSq < (SURF_SEAM_MIN_SPEED * SURF_SEAM_MIN_SPEED))
    {
        return false;
    }

    new Float:vecPostOrigin[3], Float:vecPostVelocity[3];
    get_pmove(pm_origin, vecPostOrigin);
    get_pmove(pm_velocity, vecPostVelocity);

    new Float:flPost2D = floatsqroot(vec_length_2d_sq(vecPostVelocity));

    if (flPost2D > SURF_STALL_POST_SPEED)
    {
        return false;
    }

    new Float:vecMoved[3];
    vecMoved[0] = vecPostOrigin[0] - g_vecAirStartOrigin[id][0];
    vecMoved[1] = vecPostOrigin[1] - g_vecAirStartOrigin[id][1];
    vecMoved[2] = vecPostOrigin[2] - g_vecAirStartOrigin[id][2];

    if (vec_length_sq(vecMoved) > (SURF_STALL_MAX_MOVE * SURF_STALL_MAX_MOVE))
    {
        return false;
    }

    new iHull = (g_iAirHull[id] == 1) ? HULL_HEAD : HULL_HUMAN;

    new Float:vecRawEnd[3];
    vecRawEnd[0] = g_vecAirStartOrigin[id][0] + g_vecSurfRawFlyInput[id][0] * g_flAirFrameTime[id];
    vecRawEnd[1] = g_vecAirStartOrigin[id][1] + g_vecSurfRawFlyInput[id][1] * g_flAirFrameTime[id];
    vecRawEnd[2] = g_vecAirStartOrigin[id][2] + g_vecSurfRawFlyInput[id][2] * g_flAirFrameTime[id];

    new tr = create_tr2();
    engfunc(
        EngFunc_TraceHull,
        g_vecAirStartOrigin[id],
        vecRawEnd,
        0,
        iHull,
        id,
        tr
    );

    if (get_tr2(tr, TR_StartSolid)
        || get_tr2(tr, TR_AllSolid)
        || !is_static_surf_brush(get_tr2(tr, TR_pHit)))
    {
        free_tr2(tr);
        return false;
    }

    new Float:flFraction;
    get_tr2(tr, TR_flFraction, flFraction);

    new Float:vecNormal[3];
    get_tr2(tr, TR_vecPlaneNormal, vecNormal);
    free_tr2(tr);

    if (flFraction > SURF_STALL_TRACE_FRAC_MAX
        || !is_recoverable_slide_plane(
            vecNormal,
            g_vecSurfRawFlyInput[id],
            flFraction
        ))
    {
        return false;
    }

    new Float:flInto = vec_dot(g_vecSurfRawFlyInput[id], vecNormal);

    if (flInto >= 0.0)
    {
        return false;
    }

    new Float:vecProjected[3];
    surf_clip_velocity(
        g_vecSurfRawFlyInput[id],
        vecNormal,
        vecProjected
    );

    if (vec_length_sq(vecProjected) < 1.0
        || vec_dot(vecProjected, g_vecSurfRawFlyInput[id]) <= 0.0)
    {
        return false;
    }

    new Float:flProjectedDot = vec_dot(vecProjected, vecNormal);

    if (flProjectedDot < 0.0)
    {
        vecProjected[0] -= vecNormal[0] * flProjectedDot;
        vecProjected[1] -= vecNormal[1] * flProjectedDot;
        vecProjected[2] -= vecNormal[2] * flProjectedDot;
        flProjectedDot = vec_dot(vecProjected, vecNormal);
    }

    clamp_vector_length(vecProjected, g_vecSurfRawFlyInput[id]);
    new Float:flNudge = 0.0;
    new Float:flBaseNudge = floatclamp(
        g_flAirFrameTime[id],
        SURF_RECOVERY_MIN_NUDGE,
        0.03125
    );

    for (new attempt = 0; attempt < 9; attempt++)
    {
        if (attempt == 0)
        {
            flNudge = 0.0;
        }
        else if (attempt == 1)
        {
            flNudge = flBaseNudge;
        }
        else
        {
            flNudge *= 2.0;

            if (flNudge > SURF_RECOVERY_MAX_NUDGE)
            {
                flNudge = SURF_RECOVERY_MAX_NUDGE;
            }
        }

        new Float:vecCandidateStart[3];
        vecCandidateStart[0] = g_vecAirStartOrigin[id][0] + vecNormal[0] * flNudge;
        vecCandidateStart[1] = g_vecAirStartOrigin[id][1] + vecNormal[1] * flNudge;
        vecCandidateStart[2] = g_vecAirStartOrigin[id][2] + vecNormal[2] * flNudge;

        new Float:vecCandidateEnd[3];
        vecCandidateEnd[0] = vecCandidateStart[0] + vecProjected[0] * g_flAirFrameTime[id];
        vecCandidateEnd[1] = vecCandidateStart[1] + vecProjected[1] * g_flAirFrameTime[id];
        vecCandidateEnd[2] = vecCandidateStart[2] + vecProjected[2] * g_flAirFrameTime[id];

        new trPath = create_tr2();
        engfunc(
            EngFunc_TraceHull,
            vecCandidateStart,
            vecCandidateEnd,
            0,
            iHull,
            id,
            trPath
        );

        new bStartSolid = get_tr2(trPath, TR_StartSolid);
        new bAllSolid = get_tr2(trPath, TR_AllSolid);
        new Float:flPathFraction;
        get_tr2(trPath, TR_flFraction, flPathFraction);

        new Float:vecPathNormal[3];
        get_tr2(trPath, TR_vecPlaneNormal, vecPathNormal);

        new iPathHit = get_tr2(trPath, TR_pHit);
        free_tr2(trPath);

        if (!bStartSolid
            && !bAllSolid
            && is_static_surf_brush(iPathHit)
            && flPathFraction >= 1.0)
        {
            set_pmove(pm_origin, vecCandidateEnd);
            set_pmove(pm_velocity, vecProjected);

            return true;
        }

        if (flPathFraction < 1.0
            && (vec_length_sq(vecPathNormal) > 0.0001)
            && vec_dot(vecPathNormal, vecNormal) < 0.99)
        {
            break;
        }

        if (flNudge >= SURF_RECOVERY_MAX_NUDGE)
        {
            break;
        }
    }

    return false;
}

stock surf_clip_velocity(
    const Float:vecIn[3],
    const Float:vecNormal[3],
    Float:vecOut[3]
)
{
    new Float:flBackoff = vec_dot(vecIn, vecNormal);

    for (new i = 0; i < 3; i++)
    {
        vecOut[i] = vecIn[i] - vecNormal[i] * flBackoff;

        if (vecOut[i] > -SURF_CLIP_STOP_EPSILON
            && vecOut[i] < SURF_CLIP_STOP_EPSILON)
        {
            vecOut[i] = 0.0;
        }
    }
}

stock clamp_vector_length(
    Float:vecVelocity[3],
    const Float:vecReference[3]
)
{
    new Float:flVelocitySq = vec_length_sq(vecVelocity);
    new Float:flReferenceSq = vec_length_sq(vecReference);

    if (flVelocitySq <= flReferenceSq || flVelocitySq <= 0.0)
    {
        return;
    }

    new Float:flScale = floatsqroot(flReferenceSq / flVelocitySq);

    vecVelocity[0] *= flScale;
    vecVelocity[1] *= flScale;
    vecVelocity[2] *= flScale;
}

public PM_AirMove_Pre(id)
{
    g_bAirMoveSaved[id] = false;
    g_bAirTraceLift[id] = false;
    g_bNativeM1Active[id] = false;
    g_iNativeM1SavedValue[id] = 0;
    g_flAirTraceLift[id] = 0.0;

    if (!get_pcvar_num(g_pEnabled)
        || !is_user_alive(id)
        || get_pmove(pm_movetype) != MOVETYPE_WALK
        || get_pmove(pm_waterlevel) > 0
        || (get_pmove(pm_usehull) != 0 && get_pmove(pm_usehull) != 1))
    {
        return HC_CONTINUE;
    }

    g_flAirFrameTime[id] = Float:get_pmove(pm_frametime);

    if (g_flAirFrameTime[id] <= 0.0)
    {
        return HC_CONTINUE;
    }

    get_pmove(pm_origin, g_vecAirStartOrigin[id]);
    g_iAirHull[id] = get_pmove(pm_usehull);

    g_bAirMoveSaved[id] = true;
    return HC_CONTINUE;
}

public PM_AirAccelerate_Post(const Float:vecWishDir[3], Float:flWishSpeed, Float:flAccel, id)
{
    if (!g_bAirMoveSaved[id]
        || !get_pcvar_num(g_pEnabled)
        || !is_user_alive(id))
    {
        return HC_CONTINUE;
    }

    apply_surf_boost(id, vecWishDir, flWishSpeed);

    get_pmove(pm_velocity, g_vecAirInputVelocity[id]);
    get_pmove(pm_basevelocity, g_vecAirBaseVelocity[id]);

    g_vecSurfRawFlyInput[id][0] = g_vecAirInputVelocity[id][0] + g_vecAirBaseVelocity[id][0];
    g_vecSurfRawFlyInput[id][1] = g_vecAirInputVelocity[id][1] + g_vecAirBaseVelocity[id][1];
    g_vecSurfRawFlyInput[id][2] = g_vecAirInputVelocity[id][2] + g_vecAirBaseVelocity[id][2];

    force_native_method1_for_surf(
        id,
        g_iAirHull[id],
        g_vecAirStartOrigin[id],
        g_vecSurfRawFlyInput[id],
        g_flAirFrameTime[id]
    );

    get_pmove(pm_velocity, g_vecAirInputVelocity[id]);
    get_pmove(pm_basevelocity, g_vecAirBaseVelocity[id]);

    new Float:vecFlyInput[3];
    vecFlyInput[0] = g_vecAirInputVelocity[id][0] + g_vecAirBaseVelocity[id][0];
    vecFlyInput[1] = g_vecAirInputVelocity[id][1] + g_vecAirBaseVelocity[id][1];
    vecFlyInput[2] = g_vecAirInputVelocity[id][2] + g_vecAirBaseVelocity[id][2];

    prepare_surf_trace_lift(
        id,
        g_iAirHull[id],
        g_vecAirStartOrigin[id],
        vecFlyInput,
        g_flAirFrameTime[id]
    );

    return HC_CONTINUE;
}

stock bool:force_native_method1_for_surf(
    id,
    iUseHull,
    const Float:vecStart[3],
    const Float:vecFlyInput[3],
    Float:flFrameTime
)
{
    if (!g_pFlyMoveMethod
        || get_pcvar_num(g_pFlyMoveMethod) != 0
        || vec_length_sq(g_vecAirBaseVelocity[id]) > 0.0001
        || flFrameTime <= 0.0
        || vec_length_sq(vecFlyInput) < (SURF_NATIVE_MIN_SPEED * SURF_NATIVE_MIN_SPEED))
    {
        return false;
    }

    new iHull = (iUseHull == 1) ? HULL_HEAD : HULL_HUMAN;

    new Float:vecEnd[3];
    vecEnd[0] = vecStart[0] + vecFlyInput[0] * flFrameTime;
    vecEnd[1] = vecStart[1] + vecFlyInput[1] * flFrameTime;
    vecEnd[2] = vecStart[2] + vecFlyInput[2] * flFrameTime;

    new tr = create_tr2();
    engfunc(
        EngFunc_TraceHull,
        vecStart,
        vecEnd,
        IGNORE_MONSTERS,
        iHull,
        id,
        tr
    );

    if (get_tr2(tr, TR_StartSolid)
        || get_tr2(tr, TR_AllSolid)
        || !is_static_surf_brush(get_tr2(tr, TR_pHit)))
    {
        free_tr2(tr);
        return false;
    }

    new Float:flFraction;
    get_tr2(tr, TR_flFraction, flFraction);

    if (flFraction >= 1.0)
    {
        free_tr2(tr);
        return false;
    }

    new Float:vecNormal[3];
    get_tr2(tr, TR_vecPlaneNormal, vecNormal);
    free_tr2(tr);

    if (!is_recoverable_slide_plane(
        vecNormal,
        vecFlyInput,
        flFraction
    ))
    {
        return false;
    }

    g_iNativeM1SavedValue[id] = get_pcvar_num(g_pFlyMoveMethod);
    set_pcvar_num(g_pFlyMoveMethod, 1);

    g_bNativeM1Active[id] = true;

    return true;
}

stock bool:is_recoverable_slide_plane(
    const Float:vecNormal[3],
    const Float:vecVelocity[3],
    Float:flTraceFraction
)
{
    if (is_method1_surf_normal(vecNormal))
    {
        return true;
    }

    if (flTraceFraction > RAMP_TANGENT_TRACE_FRAC_MAX
        || vecNormal[2] < GROUND_WALKABLE_Z
        || vecNormal[2] >= RAMP_TANGENT_Z_MAX)
    {
        return false;
    }

    new Float:flHorizontalSq =
        vecNormal[0] * vecNormal[0]
        + vecNormal[1] * vecNormal[1];

    if (flHorizontalSq < RAMP_TANGENT_MIN_HORIZ_SQ)
    {

        return false;
    }

    new Float:flSpeedSq = vec_length_sq(vecVelocity);

    if (flSpeedSq < (SURF_SEAM_MIN_SPEED * SURF_SEAM_MIN_SPEED))
    {
        return false;
    }

    new Float:flInto = vec_dot(vecVelocity, vecNormal);

    if (flInto >= 0.0)
    {
        return false;
    }

    new Float:flIntoAbs = -flInto;
    new Float:flSpeed = floatsqroot(flSpeedSq);

    if (flIntoAbs > RAMP_TANGENT_MAX_INTO
        || (flIntoAbs / flSpeed) > RAMP_TANGENT_MAX_RATIO)
    {

        return false;
    }

    return true;
}

stock bool:is_method1_surf_normal(const Float:vecNormal[3])
{
    new Float:flHorizontalSq =
        vecNormal[0] * vecNormal[0]
        + vecNormal[1] * vecNormal[1];

    if (flHorizontalSq < SURF_PLANE_HORIZ_SQ_MIN)
    {
        return false;
    }

    if (floatabs(vecNormal[2]) <= SURF_PLANE_Z_EPSILON)
    {
        return false;
    }

    if (vecNormal[2] > 0.0 && vecNormal[2] >= GROUND_WALKABLE_Z)
    {
        return false;
    }

    return true;
}

stock bool:prepare_surf_trace_lift(
    id,
    iUseHull,
    const Float:vecStart[3],
    const Float:vecFlyInput[3],
    const Float:flFrameTime
)
{

    if (!get_pcvar_num(g_pStepSizeFix) || flFrameTime <= 0.0)
    {
        return false;
    }

    if (vec_length_2d_sq(vecFlyInput) < (SURF_SEAM_MIN_SPEED * SURF_SEAM_MIN_SPEED))
    {
        return false;
    }

    new Float:flMaxLift = get_surf_step_limit();

    if (vec_length_sq(g_vecAirBaseVelocity[id]) > 0.0001) return false;

    if (flMaxLift < AUTO_STEP_MIN)
    {
        return false;
    }

    new iHull = (iUseHull == 1) ? HULL_HEAD : HULL_HUMAN;

    new Float:vecIdealEnd[3];
    vecIdealEnd[0] = vecStart[0] + vecFlyInput[0] * flFrameTime;
    vecIdealEnd[1] = vecStart[1] + vecFlyInput[1] * flFrameTime;
    vecIdealEnd[2] = vecStart[2] + vecFlyInput[2] * flFrameTime;

    new Float:vecWallNormal[3];
    new Float:flClearLift;

    if (!find_auto_clear_lift(
        id,
        iHull,
        vecStart,
        vecIdealEnd,
        vecFlyInput,
        flMaxLift,
        flClearLift,
        vecWallNormal
    ))
    {
        return false;
    }

    if (!center_path_allows_seam_bypass(id, vecStart, vecIdealEnd, vecFlyInput))
    {
        return false;
    }

    if (!find_ramp_destination(id, iHull, vecStart, vecIdealEnd, vecFlyInput, flClearLift)) return false;

    new Float:vecLiftedStart[3];
    vec_copy(vecStart, vecLiftedStart);
    vecLiftedStart[2] += flClearLift;

    if (!is_hull_vacant(id, iHull, vecLiftedStart))
    {
        return false;
    }

    g_bAirTraceLift[id] = true;
    g_flAirTraceLift[id] = flClearLift;

    vec_copy(vecIdealEnd, g_vecAirExpectedEnd[id]);
    vec_copy(vecFlyInput, g_vecAirExpectedVelocity[id]);

    set_pmove(pm_origin, vecLiftedStart);

    return true;
}

stock bool:clear_hull_segment(id, hull, const Float:a[3], const Float:b[3])
{
    new tr = create_tr2();
    engfunc(EngFunc_TraceHull, a, b, 0, hull, id, tr);
    new Float:f; get_tr2(tr, TR_flFraction, f);
    new bool:clear = !get_tr2(tr, TR_StartSolid) && !get_tr2(tr, TR_AllSolid) && f >= 1.0;
    free_tr2(tr);
    return clear;
}

stock bool:find_ramp_destination(id, hull, const Float:start[3], Float:end[3], const Float:velocity[3], Float:lift)
{
    new Float:normal[3];
    new Float:gravity = Float:get_pmove(pm_gravity);
    if (gravity == 0.0) gravity = 1.0;
    new Float:tolerance = floatmax(5.0, 1.5 * floatabs(gravity * Float:get_movevar(mv_gravity)) * g_flAirFrameTime[id]);
    if (!trace_walkable_ground_normal_near(id, hull, start, 2.5, normal)

        || normal[2] >= 0.9995 || vec_dot(normal, velocity) < -tolerance
        || !is_hull_vacant(id, hull, start)) return false;
    new Float:raisedStart[3], Float:raisedEnd[3];
    vec_copy(start, raisedStart); raisedStart[2] += lift;
    vec_copy(end, raisedEnd); raisedEnd[2] += lift;
    if (!clear_hull_segment(id, hull, start, raisedStart)
        || !clear_hull_segment(id, hull, raisedStart, raisedEnd)) return false;
    new tr = create_tr2();
    new Float:downEnd[3];vec_copy(end,downEnd);
    new bool:endClear=is_hull_vacant(id,hull,end);

    if(endClear)downEnd[2]-=floatmin(get_surf_step_limit(),
        2.5+floatmax(0.0,velocity[2]*g_flAirFrameTime[id]));
    engfunc(EngFunc_TraceHull, raisedEnd, downEnd, 0, hull, id, tr);
    new Float:f, Float:exitNormal[3], Float:landing[3];
    get_tr2(tr, TR_flFraction, f);
    get_tr2(tr, TR_vecPlaneNormal, exitNormal);
    get_tr2(tr, TR_vecEndPos, landing);
    new bool:valid = !get_tr2(tr, TR_StartSolid) && !get_tr2(tr, TR_AllSolid)
        && is_static_surf_brush(get_tr2(tr, TR_pHit)) && f < 1.0 && exitNormal[2] > 0.7
        && (vec_dot(normal, exitNormal) >= 0.995
            || (velocity[2] > 0.0 && is_flatter_ramp_exit(normal, exitNormal)));
    free_tr2(tr);
    if (!valid) return false;
    if(endClear)vec_copy(end,landing);
    else
    landing[2] += 0.001;
    if (landing[2] > raisedEnd[2] || !is_hull_vacant(id, hull, landing)
        || !clear_hull_segment(id, hull, raisedEnd, landing)) return false;
    vec_copy(landing, end);
    return true;
}

stock bool:is_flatter_ramp_exit(const Float:entry[3], const Float:exitPlane[3])
{
    if (exitPlane[2] < entry[2]) return false;
    if (vec_dot(entry, exitPlane) >= 0.93) return true;
    if (exitPlane[2] >= 0.9995) return true;
    new Float:entryXY = vec_length_2d_sq(entry);
    new Float:exitXY = vec_length_2d_sq(exitPlane);
    if (entryXY < 0.000001 || exitXY < 0.000001) return false;
    return entry[0]*exitPlane[0]+entry[1]*exitPlane[1]
        >= 0.995*floatsqroot(entryXY*exitXY);
}

stock Float:get_engine_step_limit()
{
    new Float:flStep = Float:get_movevar(mv_stepsize);

    if (flStep < AUTO_STEP_MIN)
    {
        return 0.0;
    }

    if (flStep > AUTO_STEP_HARD_MAX)
    {
        flStep = AUTO_STEP_HARD_MAX;
    }

    return flStep;
}

stock Float:get_surf_step_limit()
{
    new Float:flStep = get_pcvar_float(g_pStepSizeValue);

    if (flStep < 0.0)
    {
        flStep = 0.0;
    }
    else if (flStep > AUTO_STEP_HARD_MAX)
    {
        flStep = AUTO_STEP_HARD_MAX;
    }

    flStep = floatmin(flStep, get_engine_step_limit());

    if (flStep < AUTO_STEP_MIN)
    {
        return 0.0;
    }

    return flStep;
}

stock bool:trace_walkable_ground_normal_near(
    id,
    iHull,
    const Float:vecOrigin[3],
    const Float:flDown,
    Float:vecNormal[3]
)
{
    new Float:vecStart[3];
    new Float:vecEnd[3];

    vec_copy(vecOrigin, vecStart);
    vec_copy(vecOrigin, vecEnd);

    vecStart[2] += GROUND_TRACE_UP_EPSILON;
    vecEnd[2] -= flDown;

    new tr = create_tr2();
    engfunc(EngFunc_TraceHull, vecStart, vecEnd, IGNORE_MONSTERS, iHull, id, tr);

    if (get_tr2(tr, TR_StartSolid) || get_tr2(tr, TR_AllSolid))
    {
        free_tr2(tr);
        return false;
    }

    new Float:flFraction;
    get_tr2(tr, TR_flFraction, flFraction);

    if (flFraction >= 1.0)
    {
        free_tr2(tr);
        return false;
    }

    get_tr2(tr, TR_vecPlaneNormal, vecNormal);

    if (vecNormal[2] < GROUND_WALKABLE_Z || !is_static_surf_brush(get_tr2(tr, TR_pHit)))
    {
        free_tr2(tr);
        return false;
    }

    free_tr2(tr);
    return true;
}

stock bool:find_auto_clear_lift(
    id,
    iHull,
    const Float:vecStart[3],
    const Float:vecEnd[3],
    const Float:vecIncoming[3],
    const Float:flMaxLift,
    &Float:flClearLift,
    Float:vecWallNormal[3]
)
{
    flClearLift = 0.0;

    new bool:bSawVerticalWall = false;
    new Float:flBlocked = 0.0;
    new Float:flTest = 0.0;
    new Float:flClear = 0.0;

    new Float:vecNormal[3];
    new iState = trace_lift_state(
        id,
        iHull,
        vecStart,
        vecEnd,
        0.0,
        vecIncoming,
        vecNormal
    );

    if (iState == 1)
    {
        vec_copy(vecNormal, vecWallNormal);
        bSawVerticalWall = true;
    }
    else if (iState == 2)
    {

        return false;
    }

    flTest = AUTO_STEP_MIN;

    while (flTest < flMaxLift + 0.0001)
    {
        if (flTest > flMaxLift)
        {
            flTest = flMaxLift;
        }

        iState = trace_lift_state(
            id,
            iHull,
            vecStart,
            vecEnd,
            flTest,
            vecIncoming,
            vecNormal
        );

        if (iState == 2)
        {
            if (!bSawVerticalWall)
            {
                return false;
            }

            flClear = flTest;
            break;
        }

        if (iState == 1)
        {
            vec_copy(vecNormal, vecWallNormal);
            bSawVerticalWall = true;
        }

        flBlocked = flTest;

        if (flTest >= flMaxLift)
        {
            break;
        }

        flTest *= 2.0;

        if (flTest > flMaxLift)
        {
            flTest = flMaxLift;
        }
    }

    if (!bSawVerticalWall || flClear <= 0.0)
    {
        return false;
    }

    new Float:flLow = flBlocked;
    new Float:flHigh = flClear;

    for (new i = 0; i < AUTO_STEP_BINARY_ITERS; i++)
    {
        new Float:flMid = (flLow + flHigh) * 0.5;

        iState = trace_lift_state(
            id,
            iHull,
            vecStart,
            vecEnd,
            flMid,
            vecIncoming,
            vecNormal
        );

        if (iState == 2)
        {
            flHigh = flMid;
        }
        else
        {
            if (iState == 1)
            {
                vec_copy(vecNormal, vecWallNormal);
            }

            flLow = flMid;
        }
    }

    flClearLift = flHigh;
    return true;
}

stock trace_lift_state(
    id,
    iHull,
    const Float:vecStart[3],
    const Float:vecEnd[3],
    const Float:flLift,
    const Float:vecIncoming[3],
    Float:vecNormal[3]
)
{
    new Float:vecA[3];
    new Float:vecB[3];

    vecA[0] = vecStart[0];
    vecA[1] = vecStart[1];
    vecA[2] = vecStart[2] + flLift;

    vecB[0] = vecEnd[0];
    vecB[1] = vecEnd[1];
    vecB[2] = vecEnd[2] + flLift;

    new tr = create_tr2();
    engfunc(EngFunc_TraceHull, vecA, vecB, IGNORE_MONSTERS, iHull, id, tr);

    if (get_tr2(tr, TR_StartSolid) || get_tr2(tr, TR_AllSolid))
    {
        free_tr2(tr);
        return 0;
    }

    new Float:flFraction;
    get_tr2(tr, TR_flFraction, flFraction);

    if (flFraction >= 1.0)
    {
        free_tr2(tr);
        return 2;
    }

    get_tr2(tr, TR_vecPlaneNormal, vecNormal);
    free_tr2(tr);

    if (floatabs(vecNormal[2]) <= SURF_STEP_WALL_Z_MAX
        && vec_dot(vecIncoming, vecNormal) <= -SURF_STEP_MIN_INTO_SPEED)
    {
        return 1;
    }

    return 0;
}

stock bool:center_path_allows_seam_bypass(
    id,
    const Float:vecStart[3],
    const Float:vecEnd[3],
    const Float:vecIncoming[3]
)
{
    new tr = create_tr2();
    engfunc(EngFunc_TraceLine, vecStart, vecEnd, IGNORE_MONSTERS, id, tr);

    if (get_tr2(tr, TR_StartSolid) || get_tr2(tr, TR_AllSolid))
    {
        free_tr2(tr);
        return false;
    }

    new Float:flFraction;
    get_tr2(tr, TR_flFraction, flFraction);

    if (flFraction >= 1.0)
    {
        free_tr2(tr);
        return true;
    }

    new Float:vecNormal[3];
    get_tr2(tr, TR_vecPlaneNormal, vecNormal);
    free_tr2(tr);

    if (floatabs(vecNormal[2]) <= SURF_STEP_WALL_Z_MAX
        && vec_dot(vecIncoming, vecNormal) <= -SURF_STEP_MIN_INTO_SPEED)
    {
        return false;
    }

    return true;
}

stock bool:is_hull_vacant(id, iHull, const Float:vecOrigin[3])
{
    new tr = create_tr2();
    engfunc(EngFunc_TraceHull, vecOrigin, vecOrigin, 0, iHull, id, tr);

    new bool:bVacant = !get_tr2(tr, TR_StartSolid) && !get_tr2(tr, TR_AllSolid);
    free_tr2(tr);

    return bVacant;
}

stock bool:is_static_surf_brush(ent)
{
    if (ent <= 0) return true;
    if (!pev_valid(ent) || pev(ent, pev_solid) != SOLID_BSP) return false;
    new classname[32], model[64];
    pev(ent, pev_classname, classname, charsmax(classname));
    pev(ent, pev_model, model, charsmax(model));
    if (model[0] != '*') return false;
    if (!equal(classname, "func_wall")
        && !(equal(classname, "func_button") && (pev(ent, pev_spawnflags) & SF_BUTTON_DONTMOVE))) return false;
    new move = pev(ent, pev_movetype);
    if (move != MOVETYPE_NONE && move != MOVETYPE_PUSH) return false;
    new Float:v[3];
    pev(ent, pev_velocity, v);
    if (vec_length_sq(v) > 0.000001) return false;
    pev(ent, pev_avelocity, v);
    return vec_length_sq(v) <= 0.000001;
}

stock vec_clear(Float:v[3])
{
    v[0] = 0.0;
    v[1] = 0.0;
    v[2] = 0.0;
}

stock Float:vec_dot(const Float:a[3], const Float:b[3])
{
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
}

stock Float:vec_length_sq(const Float:v[3])
{
    return v[0] * v[0] + v[1] * v[1] + v[2] * v[2];
}

stock Float:vec_length_2d_sq(const Float:v[3])
{
    return v[0] * v[0] + v[1] * v[1];
}

stock vec_copy(const Float:src[3], Float:dest[3])
{
    dest[0] = src[0];
    dest[1] = src[1];
    dest[2] = src[2];
}