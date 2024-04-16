#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = {
    name        = "[L4D2] Survivor Death Animations",
    author      = "caoqt, Shadowsyn",
    description = "Port to sourcemod of Shadowsyn's addon. Common Infected death animations for survivors.",
    version     = "1.1.5",
    url         = ""
};

static bool g_bIncapTable[MAXPLAYERS + 1];

public void OnPluginStart()
{
	// Make sure to precache the common models.
	if (!IsModelPrecached("models/infected/common_male01.mdl"))
		PrecacheModel("models/infected/common_male01.mdl", true);
	
	HookEvent("player_death", player_death, EventHookMode_Pre);
	HookEvent("player_incapacitated", player_incapacitated, EventHookMode_Pre);
	HookEvent("revive_success", revive_success, EventHookMode_Pre);
}

public void OnEntityCreated(int iEntity, const char[] sClassname)
{
	if(sClassname[0] != 's')
		return;
	
	if(StrEqual(sClassname, "survivor_death_model", false))
		SDKHook(iEntity, SDKHook_SpawnPost, SpawnPostDeathModel);
}

public void SpawnPostDeathModel(int iEntity)
{
	SDKUnhook(iEntity, SDKHook_SpawnPost, SpawnPostDeathModel);
	if(!IsValidEntity(iEntity))
		return;
	
	// Hide the death model
	RequestFrame(HideDeathModel, iEntity);
}

// Hides the death model to retain defib functionality.
void HideDeathModel(int iEntity)
{
	SetEntityRenderMode(iEntity, RENDER_NONE);
}

// Check to see if player is getting attacked by any SI.
bool IsPlayerHeld(int iClient)
{
	if (!iClient || GetClientTeam(iClient) != 2)
		return false;
	
	int m_pummelAttacker = GetEntPropEnt(iClient, Prop_Send, "m_pummelAttacker");
	int m_carryAttacker = GetEntPropEnt(iClient, Prop_Send, "m_carryAttacker");
	int m_pounceAttacker = GetEntPropEnt(iClient, Prop_Send, "m_pounceAttacker");
	int m_tongueOwner = GetEntPropEnt(iClient, Prop_Send, "m_tongueOwner");
	
	if (m_pummelAttacker > 0 || m_carryAttacker > 0 || m_pounceAttacker > 0 || m_tongueOwner > 0)
		return true;
	return false;
}

public void player_death(Event event, const char[] name, bool dontbroadcast)
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	
	if (!iClient || GetClientTeam(iClient) != 2)
		return;
	
	int m_hRagdoll = GetEntPropEnt(iClient, Prop_Send, "m_hRagdoll");
	if (m_hRagdoll && IsValidEntity(m_hRagdoll))
		return;
	
	// Check to see if we are able to do the death animation.
	char sWeapon[128];
	event.GetString("weapon", sWeapon, sizeof(sWeapon));
	
	PrintToServer(sWeapon);
	bool isAbleToDeathAnim = true;
	
	if (StrEqual(sWeapon, "tank_claw", false))
		isAbleToDeathAnim = false;
	else if (StrEqual(sWeapon, "tank_rock", false))
		isAbleToDeathAnim = false;
	else if (event.GetInt("type") & (1 << 5))
		isAbleToDeathAnim = false;
	else if (g_bIncapTable[iClient])
	{ g_bIncapTable[iClient] = false; isAbleToDeathAnim = false; }
	
	if (isAbleToDeathAnim)
		CreateCorpse(iClient);
	else CreateRagdoll(iClient);
}

public void player_incapacitated(Event event, const char[] name, bool dontbroadcast)
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	
	if (!iClient || GetClientTeam(iClient) != 2 || !IsPlayerAlive(iClient))
		return;
	
	if (IsPlayerHeld(iClient) || GetEntProp(iClient, Prop_Send, "m_isIncapacitated", 1))	
	{
		g_bIncapTable[iClient] = true;
	}
}

public void revive_success(Event event, const char[] name, bool dontbroadcast)
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	
	if (!iClient || GetClientTeam(iClient) != 2 || !IsPlayerAlive(iClient))
		return;
	
	if (!IsPlayerHeld(iClient))
	{
		PrintToServer("removing player from incap table.");
		g_bIncapTable[iClient] = false;
	}
}

// Creates a ragdoll.
int CreateRagdoll(int iClient)
{
	int iRagdoll = CreateEntityByName("cs_ragdoll");
	float m_vecPos[3], m_vecAng[3];
	GetClientAbsOrigin(iClient, m_vecPos); 
	GetClientAbsAngles(iClient, m_vecAng);
	
	TeleportEntity(iRagdoll, m_vecPos, m_vecAng, NULL_VECTOR);
	
	SetEntPropVector(iRagdoll, Prop_Send, "m_vecRagdollOrigin", m_vecPos);
	SetEntProp(iRagdoll, Prop_Send, "m_nModelIndex", GetEntProp(iClient, Prop_Send, "m_nModelIndex"));
	SetEntProp(iRagdoll, Prop_Send, "m_iTeamNum", GetClientTeam(iClient));
	SetEntPropEnt(iRagdoll, Prop_Send, "m_hPlayer", iClient);
	SetEntProp(iRagdoll, Prop_Send, "m_iDeathPose", GetEntProp(iClient, Prop_Send, "m_nSequence"));
	SetEntProp(iRagdoll, Prop_Send, "m_iDeathFrame", GetEntProp(iClient, Prop_Send, "m_flAnimTime"));
	SetEntProp(iRagdoll, Prop_Send, "m_nForceBone", GetEntProp(iClient, Prop_Send, "m_nForceBone"));
	
	float m_vecForce[3];
	GetEntPropVector(iClient, Prop_Send, "m_vecForce", m_vecForce);
	
	SetEntPropVector(iRagdoll, Prop_Send, "m_vecForce", m_vecForce);
	SetEntProp(iRagdoll, Prop_Send, "m_ragdollType", 4);
	SetEntProp(iRagdoll, Prop_Send, "m_survivorCharacter", GetEntProp(iClient, Prop_Send, "m_survivorCharacter"));
	
	int m_hRagdoll = GetEntPropEnt(iClient, Prop_Send, "m_hRagdoll");
	if (!IsPlayerAlive(iClient) && m_hRagdoll == -1)
		SetEntPropEnt(iClient, Prop_Send, "m_hRagdoll", iRagdoll);
	else {
		SetVariantString("OnUser1 !self:Kill::1.0:-1");
		AcceptEntityInput(iRagdoll, "AddOutput");
		AcceptEntityInput(iRagdoll, "FireUser1");
	}
	
	DispatchSpawn(iRagdoll);
	ActivateEntity(iRagdoll);
	
	return iRagdoll;
}

int ApplyDeathAnimFunctionality(int corpse, float anim_time, int common)
{
	if (common > 0)
	{
		SetEntProp(common, Prop_Send, "movetype", 3); // MOVETYPE_STEP
		SetEntProp(common, Prop_Send, "m_CollisionGroup", 1);
	}
	CreateTimer(anim_time, DoDeathRagdoll, corpse);
}

// This might be an *awful* way at doing this, but it gets the job done.
void GetCommonDeathAnim(char deathAnim[PLATFORM_MAX_PATH])
{
	int RandomInt = GetRandomInt(1, 10);
	switch(RandomInt)
	{
		case 1:
			strcopy(deathAnim, sizeof(deathAnim), "Death_10ab");
		case 2:
			strcopy(deathAnim, sizeof(deathAnim), "Death_10b");
		case 3:
			strcopy(deathAnim, sizeof(deathAnim), "Death_09");
		case 4:
			strcopy(deathAnim, sizeof(deathAnim), "Death_07");
		case 5:
			strcopy(deathAnim, sizeof(deathAnim), "Death_06");
		case 6:
			strcopy(deathAnim, sizeof(deathAnim), "Death_05");
		case 7:
			strcopy(deathAnim, sizeof(deathAnim), "Death_03");
		case 8:
			strcopy(deathAnim, sizeof(deathAnim), "Death_02c");
		case 9:
			strcopy(deathAnim, sizeof(deathAnim), "Death_02a");
		case 10:
			strcopy(deathAnim, sizeof(deathAnim), "Death_01");
	}
}

// Same goes for this, haha.
float GetCommonDeathTimer(char[] deathAnim)
{
	float deathTimer = 1.0;
	
	if (StrEqual(deathAnim, "Death_10ab", false))
		deathTimer = 2.8;
	else if (StrEqual(deathAnim, "Death_10b", false))
		deathTimer = 2.4;
	else if (StrEqual(deathAnim, "Death_09", false))
		deathTimer = 2.5;
	else if (StrEqual(deathAnim, "Death_07", false))
		deathTimer = 2.25;
	else if (StrEqual(deathAnim, "Death_06", false))
		deathTimer = 3.8;
	else if (StrEqual(deathAnim, "Death_05", false))
		deathTimer = 0.7;
	else if (StrEqual(deathAnim, "Death_03", false))
		deathTimer = 3.05;
	else if (StrEqual(deathAnim, "Death_02c", false))
		deathTimer = 2.1;
	else if (StrEqual(deathAnim, "Death_02a", false))
		deathTimer = 0.65;
	else if (StrEqual(deathAnim, "Death_01", false))
		deathTimer = 2.0;
	
	return deathTimer;
}

int CreateCorpse(int iClient)
{
	char keyValue_model[PLATFORM_MAX_PATH] = "models/infected/common_male01.mdl";
	
	float m_vecPos[3], m_vecAng[3];
	GetClientAbsOrigin(iClient, m_vecPos);
	GetClientEyeAngles(iClient, m_vecAng);
	m_vecAng[0] = 0.0; m_vecAng[2] = 0.0;
	
	char sModel[128];
	GetClientModel(iClient, sModel, sizeof(sModel));
	
	// Create the corpse, this will be the visual for the survivor.
	int corpse = CreateEntityByName("commentary_dummy");
	DispatchKeyValue(corpse, "model", sModel);
	DispatchSpawn(corpse);
	ActivateEntity(corpse);
	TeleportEntity(corpse, m_vecPos, m_vecAng, NULL_VECTOR);
	SetEntPropEnt(corpse, Prop_Send, "m_hOwnerEntity", iClient);
	
	// Create an invisible common infected, will be used to play the animation.
	int common = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(common, "spawnflags", "128");
	DispatchKeyValue(common, "model", keyValue_model);
	DispatchKeyValue(common, "solid", "0");
	SetEntProp(common, Prop_Send, "m_nRenderMode", 10);
	SetEntPropEnt(corpse, Prop_Send, "moveparent", common);
	SetEntProp(corpse, Prop_Send, "m_fEffects", 1|128|512);
	
	DispatchSpawn(common);
	ActivateEntity(common);
	TeleportEntity(common, m_vecPos, m_vecAng, NULL_VECTOR);
	
	// Get animation name and timer.
	char animName[PLATFORM_MAX_PATH];
	GetCommonDeathAnim(animName);
	float animTimer = GetCommonDeathTimer(animName);
	
	SetVariantString("Idle");
	AcceptEntityInput(common, "SetAnimation");
	SetVariantString(animName);
	AcceptEntityInput(common, "SetAnimation");
	
	ApplyDeathAnimFunctionality(corpse, animTimer, common);
	CreateTimer(animTimer + 1.0, KillObject, common);
}

// Kills an object.
public Action KillObject(Handle iTimer, int iObject)
{
	if (IsValidEntity(iObject))
		AcceptEntityInput(iObject, "Kill");
}

// Turns the corpse into a ragdoll.
public Action DoDeathRagdoll(Handle iTimer, int iCorpse)
{
	if (IsValidEntity(iCorpse))
		AcceptEntityInput(iCorpse, "BecomeRagdoll"); // BOO! BecomeRagdoll!1
}
