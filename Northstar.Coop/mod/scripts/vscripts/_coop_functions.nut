untyped

global function InitCoopFuncs
global function FullyHidePlayers
global function FullyShowPlayers
global function IsPlayingSolo
global function IsPlayingCoop

#if SERVER
global function GetPreferredTitanForPlayer
global function Coop_LoadMapFromStartPoint
global function Coop_ReloadCurrentMapFromLatestStartPoint
global function Coop_SyncCutsceneToProtagonist
global function Coop_ClearCutsceneFromProtagonist
global function Coop_CheckIfIsCutscenePlaying
#endif

struct
{
	table<entity, string> coopPreferredTitan
	bool isPlayingCutscene
	FirstPersonSequenceStruct& currentCutscene
	entity cutsceneRef
	float cutsceneTime
} file

void function InitCoopFuncs()
{
    #if SERVER
    AddClientCommandCallback( "tpall", TeleportAll )
    AddClientCommandCallback( "tpto", TeleportTo )
	AddClientCommandCallback( "coop_titanset", ClientCommand_CoopSetPreferredTitan )
	AddCallback_OnClientDisconnected( OnClientDisconnected )
	#else
	AddCallback_OnClientScriptInit( OnClientScriptInit )
	#endif
}

bool function TeleportAll( entity player, array<string> args )
{
    if ( !GetConVarBool( "sv_cheats" ) )
		return true

    vector origin = player.GetOrigin()

    foreach ( player in GetPlayerArray() )
    {
        player.SetOrigin( origin )
    }

    return true
}

bool function TeleportTo( entity player, array<string> args )
{
    if ( !args.len() )
        return true

    entity target

    foreach( entity p in GetPlayerArray() )
    {
        if ( p.GetPlayerName().tolower().find( args[0].tolower() ) != null )
        {
            target = p
            break
        }
    }

    if ( IsValid( target ) )
        player.SetOrigin( target.GetOrigin() )

    return true
}

void function FullyHidePlayers()
{
    foreach( entity player in GetPlayerArray() )
    {
        player.MakeInvisible()
    }
}

void function FullyShowPlayers()
{
    foreach( entity player in GetPlayerArray() )
    {
        player.MakeVisible()
    }
}

bool function IsPlayingSolo()
{
    return GetPlayerArray().len() <= 1
}

bool function IsPlayingCoop()
{
    return GetPlayerArray().len() > 1
}

void function OnClientDisconnected( entity player )
{
	entity petTitan = player.GetPetTitan()
	if ( IsValid( petTitan ) )
	{
		if( GetTitanCharacterName( petTitan ) == "bt" )
		{
			petTitan.ClearBossPlayer()
			petTitan.GetTitanSoul().ClearBossPlayer()
		}
	}
	if ( player in file.coopPreferredTitan )
		delete file.coopPreferredTitan[player]
}

#if CLIENT
void function OnClientScriptInit( entity player )
{
	GetLocalClientPlayer().ClientCommand( "coop_titanset " + GetConVarString( "coop_preferredtitan" ) )
}
#endif

#if SERVER
bool function ClientCommand_CoopSetPreferredTitan( entity player, array<string> args )
{
	if ( !args.len() )
		return false
	
	if ( player in file.coopPreferredTitan )
		file.coopPreferredTitan[player] = args[0]
	else
		file.coopPreferredTitan[player] <- args[0]
	
	Coop_TitanSpawnRequestedForExtraPlayer( player )
	return true
}

void function Coop_LoadMapFromStartPoint( string mapName, string startPoint, LevelTransitionStruct ornull trans = null )
{
	thread ChangeLevelAfterFadeout( mapName, startPoint, trans )
}

void function ChangeLevelAfterFadeout( string mapName, string startPoint, LevelTransitionStruct ornull trans = null )
{
	foreach ( player in GetPlayerArray() )
		ScreenFadeToBlackForever( player, SP_LEVEL_TRANSITION_FADETIME )
	
	AllPlayersMuteAll( 4 )
	wait SP_LEVEL_TRANSITION_HOLDTIME
	ExecuteLoadingClientCommands_SetStartPoint( mapName, GetStartPointIndexFromName( mapName, startPoint ) )
	GameRules_ChangeMap( mapName, GAMETYPE )
}

void function Coop_ReloadCurrentMapFromLatestStartPoint()
{
	string mapName = GetMapName()
	LevelTransitionStruct ornull trans = GetLevelTransitionStruct()
	ExecuteLoadingClientCommands_SetStartPoint( mapName, GetCurrentStartPointIndex() )
	GameRules_ChangeMap( mapName, GAMETYPE )
}

//Coop_SyncCutsceneToProtagonist( player, cutsceneSequence, animRef )
void function Coop_SyncCutsceneToProtagonist( entity protagonist, FirstPersonSequenceStruct cutsceneSequence, entity animRef = null )
{
	file.isPlayingCutscene = true
	file.currentCutscene = cutsceneSequence
	file.cutsceneRef = animRef
	file.cutsceneTime = Time()
	foreach ( player in GetPlayerArray() )
	{
		if( !IsAlive( player ) )
		{
			DoRespawnPlayer( player, null )
			ScreenFadeFromBlack( player, 0.1, 0.1 )
		}
		player.MakeInvisible()
		player.SetInvulnerable()
		player.SetNoTarget( true )
		player.MovementDisable()
		player.ForceStand()
		HideName( player )
		player.HolsterWeapon()
		player.Server_TurnOffhandWeaponsDisabledOn()
		if( player != protagonist )
			thread FirstPersonSequence( cutsceneSequence, player, animRef )
	}
	FirstPersonSequence( cutsceneSequence, protagonist, animRef )
}

void function Coop_ClearCutsceneFromProtagonist( entity protagonist )
{
	file.isPlayingCutscene = false
	foreach ( player in GetPlayerArray() )
	{
		if( player != protagonist )
		{
			player.MakeVisible()
			player.ClearInvulnerable()
			player.SetNoTarget( false )
			ShowName( player )
			player.DeployWeapon()
			player.Server_TurnOffhandWeaponsDisabledOff()
			player.SetOrigin( protagonist.GetOrigin() )
			player.SetAngles( protagonist.GetAngles() )
			player.MovementEnable()
			player.ClearAnimNearZ()
			player.ClearParent()
			player.UnforceStand()
			ClearPlayerAnimViewEntity( player )
		}
	}
	
	protagonist.MakeVisible()
	protagonist.ClearInvulnerable()
	protagonist.SetNoTarget( false )
	ShowName( protagonist )
	protagonist.DeployWeapon()
	protagonist.Server_TurnOffhandWeaponsDisabledOff()
	protagonist.MovementEnable()
	protagonist.ClearAnimNearZ()
	protagonist.ClearParent()
	protagonist.UnforceStand()
	ClearPlayerAnimViewEntity( protagonist )
}

bool function Coop_CheckIfIsCutscenePlaying( entity player )
{
	if( file.isPlayingCutscene )
	{
		FirstPersonSequenceStruct cutsceneSequence = file.currentCutscene
		cutsceneSequence.setInitialTime = Time() - file.cutsceneTime
		ScreenFadeFromBlack( player, 0.1, 0.1 )
		player.MakeInvisible()
		player.SetInvulnerable()
		player.SetNoTarget( true )
		player.MovementDisable()
		player.ForceStand()
		HideName( player )
		player.HolsterWeapon()
		player.Server_TurnOffhandWeaponsDisabledOn()
		thread FirstPersonSequence( cutsceneSequence, player, file.cutsceneRef )
		return true
	}
	
	return false
}

string function GetPreferredTitanForPlayer( entity player )
{
	if ( player in file.coopPreferredTitan )
		return file.coopPreferredTitan[player]
	
	return "none"
}
#endif