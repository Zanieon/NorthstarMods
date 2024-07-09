untyped
global function StartSpawn
global function AddMapSpecifcRespawnsInit
global function AddMapSpecifcRespawns
global function CodeCallback_OnPlayerKilled
global function RestartMapWithDelay
global function MakePlayerPilot
global function MakePlayerTitan
global function AddFunctionForMapRespawn
global function DisableOnePlayerRestart
global function EnableOnePlayerRestart


struct {
    table< string, void functionref( entity ) > CustomMapRespawns
	table< string, void functionref( entity ) > CustomMapRespawnsFunction
	bool RestartMap = true
} file


void function AddMapSpecifcRespawnsInit()
{
    AddMapSpecifcRespawns("sp_s2s", s2sRespawn )
}

void function AddMapSpecifcRespawns( string map, void functionref( entity ) func )
{
	file.CustomMapRespawns[map] <- func
}


void function StartSpawn( entity player )
{
    // Player was already positioned at info_player_start in SpPlayerConnecting.
	// Don't reposition him, in case movers have already pushed him.
	// No, I will

	// log their UID
	printt( format( "%s : %s", player.GetPlayerName(), player.GetUID() ) )
	
	CheckPointInfo info = GetCheckPointInfo()

	// for events
	thread RunMiddleFunc( player )

	if ( GetMapName() in file.CustomMapRespawns )
	{
		thread file.CustomMapRespawns[ GetMapName() ]( player )
		return
	}

	else if ( info.pos != <0,0,0> )
	{
		player.SetOrigin( info.pos )
		
		if ( !info.RsPilot )
			thread MakePlayerTitan( player, info.pos )
	}

	DoRespawnPlayer( player, null )
	// do we need this?
	// AddPlayerMovementEventCallback( player, ePlayerMovementEvents.BEGIN_WALLRUN, Callback_WallrunBegin )
	
	// give them map specific items
	OnTimeShiftGiveGlove( player )
	if ( ( GetMapName() == "sp_beacon" || GetMapName() == "sp_beacon_spoke0" ) && Flag( "HasChargeTool" ) )
		GiveBatteryChargeToolSingle( player )

	RemoveCinematicFlag( player, CE_FLAG_HIDE_MAIN_HUD )
}

void function RestartMapWithDelay()
{
    wait 1
    Coop_ReloadCurrentMapFromLatestStartPoint()
}

void function s2sRespawn( entity player )
{
	EndSignal( player, "InternalPlayerRespawned" )
	EndSignal( player, "OnDestroy" )

	wait 1
	if ( "sp_s2s" in file.CustomMapRespawnsFunction && IsPlayingCoop() )
		thread file.CustomMapRespawnsFunction["sp_s2s"]( player )

	wait 1
	
	if ( !IsAlive( player ) && IsValid( player ) )
		DoRespawnPlayer( player, null )
}

void function CodeCallback_OnPlayerKilled( entity player, var damageInfo )
{
	thread PostDeathThread_SP( player, damageInfo )
}

function PostDeathThread_SP( entity player, var damageInfo )
{
	printl("PostDeathThread_SP Called!")
	
	if ( player.p.watchingPetTitanKillReplay )
		return

	float timeOfDeath = Time()
	player.p.postDeathThreadStartTime = Time()

	Assert( IsValid( player ), "Not a valid player" )
	player.EndSignal( "OnDestroy" )
	player.EndSignal( "OnRespawned" )

	player.p.deathOrigin = player.GetOrigin()
	player.p.deathAngles = player.GetAngles()

	player.s.inPostDeath = true
	player.s.respawnSelectionDone = false

	player.cloakedForever = false
	player.stimmedForever = false
	player.SetNoTarget( false )
	player.SetNoTargetSmartAmmo( false )
	player.ClearExtraWeaponMods()
	
	player.SetPredictionEnabled( false )
	
	EmitSoundOnEntityOnlyToPlayer( player, player, "Player_Death_Begin" )
	
	if ( player.IsTitan() )
		SoulDies( player.GetTitanSoul(), damageInfo ) // cleanup some titan stuff, no idea where else to put this

	entity attacker = DamageInfo_GetAttacker( damageInfo )
	int methodOfDeath = DamageInfo_GetDamageSourceIdentifier( damageInfo )

	player.p.rematchOrigin = player.p.deathOrigin
	if ( IsValid( attacker ) && methodOfDeath == eDamageSourceId.titan_execution )
	{
		// execution can throw you out of the map
		player.p.rematchOrigin = attacker.GetOrigin()
	}

	int attackerViewIndex = attacker.GetIndexForEntity()

	player.SetPredictionEnabled( false )
	player.Signal( "RodeoOver" )
	player.ClearParent()

	bool showedDeathHint = ShowDeathHintSP( player, damageInfo )
	
	thread RespawnPlayer( player )

	int damageSource = DamageInfo_GetDamageSourceIdentifier( damageInfo )
	if ( damageSource != eDamageSourceId.fall )
	{
		player.StartObserverMode( OBS_MODE_DEATHCAM )
		if ( ShouldSetObserverTarget( attacker ) )
			player.SetObserverTarget( attacker )
		else
			player.SetObserverTarget( null )
	}
}

void function RespawnPlayer( entity player )
{
	EndSignal( player, "OnDestroy" )
	WaitSignal( player, "RespawnNow" )

	if ( !IsAlive( player ) && IsValid( player ) )
    {
		UpdateSpDifficulty( player )

		if ( GetPlayerArray().len() == 1 && file.RestartMap )
            thread RestartMapWithDelay()
        else if ( GetMapName() in file.CustomMapRespawns )
            waitthread file.CustomMapRespawns[ GetMapName() ]( player )
        else
            waitthread GenericRespawn( player )
	}
}

void function GenericRespawn( entity player )
{        
	EndSignal( player, "OnDestroy" )
	EndSignal( player, "InternalPlayerRespawned" )

    wait 1

    player.s.inPostDeath = false
    player.s.respawnSelectionDone = true
	DoRespawnPlayer( player, null )
	CodeCallback_OnPlayerRespawned( player )
	player.Signal( "InternalPlayerRespawned" )
}

void function MakePlayerTitan( entity player, vector destination )
{
	EndSignal( player, "OnDeath" )
	EndSignal( player, "OnDestroy" )

	while( IsPlayerDisembarking( player ) || IsPlayerEmbarking( player ) )
	{
		WaitFrame()
	}

	entity titan = player.GetPetTitan()
	if ( !IsValid( titan ) )
	{
		CreatePetTitanAtOrigin( player, player.GetOrigin(), player.GetAngles() )
		titan = player.GetPetTitan()
		if ( titan != null )
			titan.kv.alwaysAlert = false
	}
	if ( !player.IsTitan() && IsValid( player.GetPetTitan() ) )
	{
		titan.SetOrigin( player.GetOrigin() )

		WaitFrame()
		waitthread PilotBecomesTitan( player, titan )
		WaitFrame()

		titan.Destroy()
		player.SetOrigin( destination )
	}
}

void function MakePlayerPilot( entity player, vector destination  )
{
	EndSignal( player, "OnDeath" )
	EndSignal( player, "OnDestroy" )

	while( IsPlayerDisembarking( player ) || IsPlayerEmbarking( player ) )
	{
		WaitFrame()
	}

	entity titan = GetTitanFromPlayer( player )
	if ( player.IsTitan() && IsValid( titan ) )
	{
		entity leftBehindTitan = CreateAutoTitanForPlayer_ForTitanBecomesPilot( player )
		
		TitanBecomesPilot( player, leftBehindTitan )
		
		player.SetOrigin( destination )
	}
}


void function AddFunctionForMapRespawn( string map, void functionref( entity ) func )
{
	if ( map in file.CustomMapRespawnsFunction )
		file.CustomMapRespawnsFunction[map] = func
	else
		file.CustomMapRespawnsFunction[map] <- func
}

void function EnableOnePlayerRestart()
{
	file.RestartMap = true
}

void function DisableOnePlayerRestart()
{
	file.RestartMap = false
}