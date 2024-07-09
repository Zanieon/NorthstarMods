untyped
global function NewSaveLocation
global function TeleportAllExceptOne
global function TriggerManualCheckPoint
global function TriggerSilentCheckPoint
global function Init_triggers
global function GetSaveLocation
global function GetCheckPointInfo
global function SetProtagonist
global function GetProtagonist
global function ClearPlayerHint

global struct CheckPointInfo
{
	vector pos
	bool RsPilot = true
	entity protagonist
}

struct
{
	bool lastCheckpointWasAsPilot = true
	vector lastSave = <0,0,0>

	entity protagonist
} save

/*
██╗███╗   ██╗██╗████████╗
██║████╗  ██║██║╚══██╔══╝
██║██╔██╗ ██║██║   ██║   
██║██║╚██╗██║██║   ██║   
██║██║ ╚████║██║   ██║   
╚═╝╚═╝  ╚═══╝╚═╝   ╚═╝
*/

void function Init_triggers()
{
	thread Init_triggersThreaded()
}

void function Init_triggersThreaded()
{
	switch ( GetMapName() )
	{
		case "sp_sewers1":
			CreateCoopTeleporter( < 10656, 6796, 784 >, 128, 64, 0, true, true, < 10619, 6793, 1023 > )
			CreateCoopTeleporter( < -913, 1434, 289 >, 128, 64, 0, true, true, < -913, 1694, 289 > )
			CreateCoopTeleporter( < -7693, 2040, 1935 >, 128, 64, 0, true, true, < -5987, 925, 1734 > )
			break
		
		case "sp_boomtown_start":
			break
		
		case "sp_boomtown":
			break
		
		case "sp_boomtown_end":
			break
		
		case "sp_hub_timeshift":
			break
		
		case "sp_timeshift_spoke02":
			CreateCoopTeleporter( < 3206, -3394, 10976 >, 200, 250, 0, true, true, < 2998, -3385, 10976 > )
			break
		
		case "sp_beacon":
			break
		
		case "sp_beacon_spoke0":
			CreateCoopTeleporter( < 2686, 10285, 416 >, 200, 250, 0, true, true, < 2695, 10497, 416 > )
			CreateCoopTeleporter( < 1834, 9679, -1644 >, 200, 250, 0, true, true, < 2050, 9684, -1632 > )
			CreateCoopTeleporter( < -2191, 10293, 800 >, 200, 250, 0, true, true, < -2024, 10291, 798 > )
			break
		
		case "sp_tday":
			break
		
		case "sp_skyway_v1":
			break
	}
}


/*
████████╗██████╗ ██╗ ██████╗  ██████╗ ███████╗██████╗ ███████╗
╚══██╔══╝██╔══██╗██║██╔════╝ ██╔════╝ ██╔════╝██╔══██╗██╔════╝
   ██║   ██████╔╝██║██║  ███╗██║  ███╗█████╗  ██████╔╝███████╗
   ██║   ██╔══██╗██║██║   ██║██║   ██║██╔══╝  ██╔══██╗╚════██║
   ██║   ██║  ██║██║╚██████╔╝╚██████╔╝███████╗██║  ██║███████║
   ╚═╝   ╚═╝  ╚═╝╚═╝ ╚═════╝  ╚═════╝ ╚══════╝╚═╝  ╚═╝╚══════╝
*/

void function CreateCoopTeleporter( vector origin, float radius, float top, float bottom, bool TpAsPilot, bool hasTrailTrigger = false, vector trailDestination = < 0, 0, 0 > )
{
	array<entity> ents = []
	entity trigger = _CreateScriptCylinderTriggerInternal( origin, radius, TRIG_FLAG_PLAYERONLY | TRIG_FLAG_ONCE, ents, top, bottom )
	
	trigger.s.haveAntiSoftlockTrigger <- hasTrailTrigger
	trigger.s.trailDestination <- trailDestination
	if ( TpAsPilot )
		AddCallback_ScriptTriggerEnter( trigger, OnTeleportPilotTriggered )
	else
		AddCallback_ScriptTriggerEnter( trigger, OnTeleportTitanTriggered )
}

void function CreateTrailTeleporter( vector origin, vector originalTriggerPos )
{
	array<entity> ents = []
	entity trigger = _CreateScriptCylinderTriggerInternal( origin, 128.0, TRIG_FLAG_PLAYERONLY , ents, 64.0, 0.0 )
	trigger.s.endTeleport <- originalTriggerPos
	AddCallback_ScriptTriggerEnter( trigger, OnTeleportTrailTriggered )
}

void function OnTeleportTrailTriggered( entity trigger, entity player )
{
	thread OnTeleportTrailTriggeredThreaded( trigger, player )
}

void function OnTeleportTrailTriggeredThreaded( entity trigger, entity player )
{
	vector destination = expect vector( trigger.s.endTeleport )
	
	PhaseShift( player, 0.0, 0.2 )
	wait 0.2
	player.SetOrigin( destination )
}

void function OnTeleportPilotTriggered( entity trigger, entity player )
{
	bool hasTrailTrigger = expect bool( trigger.s.haveAntiSoftlockTrigger )
	if( hasTrailTrigger )
	{
		vector destination = expect vector( trigger.s.trailDestination )
		CreateTrailTeleporter( destination, trigger.GetOrigin() )
	}
	thread OnTeleportPilotTriggeredThreaded( trigger, player )
}

void function OnTeleportPilotTriggeredThreaded( entity trigger, entity player )
{
	vector destination = trigger.GetOrigin()
	waitthread TeleportAllExceptOne( destination, player )
	wait 0.1

	foreach( entity p in GetPlayerArray() )
	{
		if ( p != player )
			thread MakePlayerPilot( p, destination )
	}
}

void function OnTeleportTitanTriggered( entity trigger, entity player )
{
	bool hasTrailTrigger = expect bool( trigger.s.haveAntiSoftlockTrigger )
	if( hasTrailTrigger )
	{
		vector destination = expect vector( trigger.s.trailDestination )
		CreateTrailTeleporter( destination, trigger.GetOrigin() )
	}
	thread OnTeleportTitanTriggeredThreaded( trigger, player )
}

void function OnTeleportTitanTriggeredThreaded( entity trigger, entity player )
{
	vector destination = trigger.GetOrigin()
	waitthread TeleportAllExceptOne( destination, player )
	wait 0.1
	
	foreach( entity p in GetPlayerArray() )
	{
		if ( p != player )
			thread MakePlayerTitan( p, destination )
	}
}

/*
██╗   ██╗████████╗██╗██╗     ██╗████████╗██╗███████╗███████╗
██║   ██║╚══██╔══╝██║██║     ██║╚══██╔══╝██║██╔════╝██╔════╝
██║   ██║   ██║   ██║██║     ██║   ██║   ██║█████╗  ███████╗
██║   ██║   ██║   ██║██║     ██║   ██║   ██║██╔══╝  ╚════██║
╚██████╔╝   ██║   ██║███████╗██║   ██║   ██║███████╗███████║
 ╚═════╝    ╚═╝   ╚═╝╚══════╝╚═╝   ╚═╝   ╚═╝╚══════╝╚══════╝                                                                                              
*/

void function NewSaveLocation( vector origin )
{
	save.lastSave = origin
}

vector function GetSaveLocation()
{
	return save.lastSave
}

void function TeleportAllExceptOne( vector destination, entity ornull ThisPlayer, bool display_notification = true )
{
	entity triggerPlayer
	if ( IsValid( ThisPlayer ) && ThisPlayer != null )
	{
		expect entity( ThisPlayer )
		triggerPlayer = ThisPlayer
	}
	foreach( entity player in GetPlayerArray() )
	{
		if ( player != ThisPlayer )
			thread PlayerCheckpointTeleport( player, destination, display_notification, triggerPlayer )
	}
	wait 1.1
}

void function PlayerCheckpointTeleport( entity player, vector origin, bool notify, entity ornull triggerPlayer )
{
	if ( notify )
	{
		DisplayOnscreenHint( player, "coop_checkpoint" )
		thread ClearPlayerHint( player )
	}
	
	ScreenFadeToBlack( player, 1.0, 0.2 )
	wait 1.1
	if ( IsValid( triggerPlayer ) )
	{
		expect entity( triggerPlayer )
		if( IsAlive( triggerPlayer ) )
		{
			player.SetOrigin( triggerPlayer.GetOrigin() )
			player.SetVelocity( triggerPlayer.GetVelocity() )
		}
	}
	else
	{
		player.SetOrigin( origin )
		player.SetVelocity( < 0, 0, 0 > )
	}
	ScreenFadeFromBlack( player, 1.0, 0.1 )
}

void function TriggerManualCheckPoint( entity ornull player, vector origin, bool IsPilotSpawn )
{
	NewSaveLocation( origin )
	waitthread TeleportAllExceptOne( origin, player )
	wait 0.1
	
	foreach( entity p in GetPlayerArray() )
	{
		if ( p != player )
		{
			if ( !IsPilot( p ) && IsPilotSpawn )
				thread MakePlayerPilot( p, origin )
			else if ( IsPilot( p ) && !IsPilotSpawn )
				thread MakePlayerTitan( p, origin )
		}
	}
	save.lastCheckpointWasAsPilot = IsPilotSpawn
}

void function TriggerSilentCheckPoint( vector origin, bool IsPilotSpawn )
{
	NewSaveLocation( origin )
	save.lastCheckpointWasAsPilot = IsPilotSpawn
}

CheckPointInfo function GetCheckPointInfo()
{
	CheckPointInfo Info

	Info.RsPilot = save.lastCheckpointWasAsPilot
	
	Info.pos = save.lastSave
	Info.protagonist = save.protagonist
	return Info
}

void function SetProtagonist( entity player )
{
	if ( !IsValid( save.protagonist ) )
		save.protagonist = player
}

void function ClearPlayerHint( entity player )
{
	wait 5
	if ( IsValid( player ) )
		ClearOnscreenHint( player )
}

entity function GetProtagonist()
{
    return save.protagonist
}