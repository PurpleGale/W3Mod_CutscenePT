// -------------------------------------------------------------------------
// Cutscene Path Tracing - WitcherScript Annotations (Next-Gen v4.04+)
// Eliminates conflicts with vanilla files and other mods without Script Merger.
// -------------------------------------------------------------------------

@addField(CR4Game)
public var cutscenePTOptions : CutscenePTOptions;

@addField(CR4Game)
public var cutscenePTManager : CutscenePTManager;

@wrapMethod(CR4Game)
function OnGameStarting( restored : bool )
{
	wrappedMethod( restored );

	cutscenePTOptions = new CutscenePTOptions in this;
	cutscenePTOptions.Init();
	cutscenePTManager = new CutscenePTManager in this;
	cutscenePTManager.Init( cutscenePTOptions );
}

@wrapMethod(CR4Game)
function OnGameStarted( restored : bool )
{
	wrappedMethod( restored );

	if ( cutscenePTOptions )
	{
		cutscenePTOptions.Init();
	}
	if ( cutscenePTManager )
	{
		cutscenePTManager.OnGameStarted();
	}
}

@wrapMethod(CR4Game)
function SetIsDialogOrCutscenePlaying( b : bool )
{
	wrappedMethod( b );

	if ( cutscenePTManager )
	{
		cutscenePTManager.OnDialogStateChanged( b );
	}
}

@wrapMethod(CR4Game)
function SetIsCutscenePlaying( b : bool )
{
	wrappedMethod( b );

	if ( cutscenePTManager )
	{
		cutscenePTManager.OnCutsceneStateChanged( b );
	}
}

@addMethod(CR4Game)
function CutscenePTOptions() : CutscenePTOptions
{
	return cutscenePTOptions;
}

@addMethod(CR4Game)
function CutscenePTManager() : CutscenePTManager
{
	return cutscenePTManager;
}

@wrapMethod(CStoryScenePlayer)
function OnCameraBlendToGameplay()
{
	wrappedMethod();

	if ( theGame.cutscenePTManager )
	{
		theGame.cutscenePTManager.OnCameraBlendToGameplay();
	}
}

@wrapMethod(CR4IngameMenu)
function SaveChangedSettings()
{
	wrappedMethod();

	if ( theGame.cutscenePTOptions )
	{
		theGame.cutscenePTOptions.ReadValues();
	}
	if ( theGame.cutscenePTManager )
	{
		theGame.cutscenePTManager.OnSettingsChanged();
	}
}

// -------------------------------------------------------------------------
// Dynamic UI State Updates for CutscenePT Groups (Dialogues & Cutscenes)
// Exactly replicates vanilla graphics.xml UI logic:
// - Disables RT GI, Reflections, Shadows, AO when RT is OFF or Path Tracing is ON
// - Disables/enables DLSS / FSR / XeSS Quality / DLSS RR based on chosen AAMode
// - Disables/enables PT Hair based on HairWorks and RT state
// -------------------------------------------------------------------------

@wrapMethod(CR4IngameMenu)
function showOptionsPanel() : void
{
	wrappedMethod();

	RefreshDialogGroupUI();
	RefreshCutsceneGroupUI();
}

@wrapMethod(CR4IngameMenu)
function OnItemActivated( actionType : int, menuTag : int ) : void
{
	wrappedMethod( actionType, menuTag );

	RefreshDialogGroupUI();
	RefreshCutsceneGroupUI();
}

@wrapMethod(CR4IngameMenu)
function OnOptionPanelNavigateBack()
{
	wrappedMethod();

	RefreshDialogGroupUI();
	RefreshCutsceneGroupUI();
}

@wrapMethod(CR4IngameMenu)
function OnShowOptionSubmenu( actionType : int, menuTag : int, id : string ) : void
{
	wrappedMethod( actionType, menuTag, id );

	RefreshDialogGroupUI();
	RefreshCutsceneGroupUI();
}

@wrapMethod(CR4IngameMenu)
function OnPresetApplied( groupId : name, targetPresetIndex : int ) : void
{
	wrappedMethod( groupId, targetPresetIndex );

	if ( groupId == 'CutscenePTDialogs' )
	{
		RefreshDialogGroupUI();
	}
	else if ( groupId == 'CutscenePTCutscenes' )
	{
		RefreshCutsceneGroupUI();
	}
}

@wrapMethod(CR4IngameMenu)
function OnOptionValueChanged( groupId : int, optionName : name, optionValue : string ) : void
{
	wrappedMethod( groupId, optionName, optionValue );

	if ( optionName == 'Dialog_EnableRT' || optionName == 'Dialog_PTEnable' || optionName == 'Dialog_HairWorksLevel' )
	{
		RefreshDialogGroupUI();
	}
	else if ( optionName == 'Cutscene_EnableRT' || optionName == 'Cutscene_PTEnable' || optionName == 'Cutscene_HairWorksLevel' )
	{
		RefreshCutsceneGroupUI();
	}
}

@wrapMethod(CR4IngameMenu)
function OnOptionSelectionChanged( optionName : name, value : bool ) : void
{
	wrappedMethod( optionName, value );

	if ( optionName == 'Dialog_EnableRT' || optionName == 'Dialog_HairWorksLevel' || optionName == 'Dialog_PTEnable' )
	{
		RefreshDialogGroupUI();
	}
	else if ( optionName == 'Cutscene_EnableRT' || optionName == 'Cutscene_HairWorksLevel' || optionName == 'Cutscene_PTEnable' )
	{
		RefreshCutsceneGroupUI();
	}
}

@addMethod(CR4IngameMenu)
public function RefreshDialogGroupUI() : void
{
	RefreshDialogGroupUI_WithAA( "" );
}

@addMethod(CR4IngameMenu)
public function RefreshDialogGroupUI_WithAA( explicitAAMode : string ) : void
{
	var dataObject : CScriptedFlashObject;
	var dataArray  : CScriptedFlashArray;
	var isRTOn     : bool;
	var isPTOn     : bool;
	var hwVal      : string;
	var isHW       : bool;

	if ( !m_flashValueStorage )
	{
		return;
	}

	dataArray = m_flashValueStorage.CreateTempFlashArray();

	isRTOn = ( mInGameConfigWrapper.GetVarValue( 'CutscenePTDialogs', 'Dialog_EnableRT' ) == "true" );
	isPTOn = ( mInGameConfigWrapper.GetVarValue( 'CutscenePTDialogs', 'Dialog_PTEnable' ) == "true" );
	hwVal  = mInGameConfigWrapper.GetVarValue( 'CutscenePTDialogs', 'Dialog_HairWorksLevel' );
	isHW   = ( hwVal != "" && hwVal != "0" );

	// 1. Path Tracer toggle disabled if RT is off
	dataObject = m_flashValueStorage.CreateTempFlashObject();
	dataObject.SetMemberFlashUInt( "tag", NameToFlashUInt( 'Dialog_PTEnable' ) );
	dataObject.SetMemberFlashBool( "disabled", !isRTOn );
	dataArray.PushBackFlashObject( dataObject );

	// 2. RT Sub-options disabled if RT is off OR Path Tracing is ON (disableIfPT)
	dataObject = m_flashValueStorage.CreateTempFlashObject();
	dataObject.SetMemberFlashUInt( "tag", NameToFlashUInt( 'Dialog_RTGIPreset' ) );
	dataObject.SetMemberFlashBool( "disabled", !isRTOn || isPTOn );
	dataArray.PushBackFlashObject( dataObject );

	dataObject = m_flashValueStorage.CreateTempFlashObject();
	dataObject.SetMemberFlashUInt( "tag", NameToFlashUInt( 'Dialog_EnableRtRadiance' ) );
	dataObject.SetMemberFlashBool( "disabled", !isRTOn || isPTOn );
	dataArray.PushBackFlashObject( dataObject );

	dataObject = m_flashValueStorage.CreateTempFlashObject();
	dataObject.SetMemberFlashUInt( "tag", NameToFlashUInt( 'Dialog_Shadows' ) );
	dataObject.SetMemberFlashBool( "disabled", !isRTOn || isPTOn );
	dataArray.PushBackFlashObject( dataObject );

	dataObject = m_flashValueStorage.CreateTempFlashObject();
	dataObject.SetMemberFlashUInt( "tag", NameToFlashUInt( 'Dialog_RTAOEnabled' ) );
	dataObject.SetMemberFlashBool( "disabled", !isRTOn || isPTOn );
	dataArray.PushBackFlashObject( dataObject );

	// 3. PT Hair disabled if HairWorks is off OR PT is off OR HW linear swept spheres unsupported
	dataObject = m_flashValueStorage.CreateTempFlashObject();
	dataObject.SetMemberFlashUInt( "tag", NameToFlashUInt( 'Dialog_PTHairQualityMode' ) );
	dataObject.SetMemberFlashBool( "disabled", !isHW || !isPTOn || !theGame.GetHardwareLinearSweptSpheresSupport() );
	dataArray.PushBackFlashObject( dataObject );

	// 4. HairWorks AA and Quality preset disabled if HairWorks is off
	dataObject = m_flashValueStorage.CreateTempFlashObject();
	dataObject.SetMemberFlashUInt( "tag", NameToFlashUInt( 'Dialog_HairWorksAALevel' ) );
	dataObject.SetMemberFlashBool( "disabled", !isHW );
	dataArray.PushBackFlashObject( dataObject );

	dataObject = m_flashValueStorage.CreateTempFlashObject();
	dataObject.SetMemberFlashUInt( "tag", NameToFlashUInt( 'Dialog_HairWorksQualityPreset' ) );
	dataObject.SetMemberFlashBool( "disabled", !isHW );
	dataArray.PushBackFlashObject( dataObject );

	m_flashValueStorage.SetFlashArray( "options.update_disabled", dataArray );
	theGame.GetGuiManager().ForceProcessFlashStorage();
}

@addMethod(CR4IngameMenu)
public function RefreshCutsceneGroupUI() : void
{
	RefreshCutsceneGroupUI_WithAA( "" );
}

@addMethod(CR4IngameMenu)
public function RefreshCutsceneGroupUI_WithAA( explicitAAMode : string ) : void
{
	var dataObject : CScriptedFlashObject;
	var dataArray  : CScriptedFlashArray;
	var isRTOn     : bool;
	var isPTOn     : bool;
	var hwVal      : string;
	var isHW       : bool;

	if ( !m_flashValueStorage )
	{
		return;
	}

	dataArray = m_flashValueStorage.CreateTempFlashArray();

	isRTOn = ( mInGameConfigWrapper.GetVarValue( 'CutscenePTCutscenes', 'Cutscene_EnableRT' ) == "true" );
	isPTOn = ( mInGameConfigWrapper.GetVarValue( 'CutscenePTCutscenes', 'Cutscene_PTEnable' ) == "true" );
	hwVal  = mInGameConfigWrapper.GetVarValue( 'CutscenePTCutscenes', 'Cutscene_HairWorksLevel' );
	isHW   = ( hwVal != "" && hwVal != "0" );

	// 1. Path Tracer toggle disabled if RT is off
	dataObject = m_flashValueStorage.CreateTempFlashObject();
	dataObject.SetMemberFlashUInt( "tag", NameToFlashUInt( 'Cutscene_PTEnable' ) );
	dataObject.SetMemberFlashBool( "disabled", !isRTOn );
	dataArray.PushBackFlashObject( dataObject );

	// 2. RT Sub-options disabled if RT is off OR Path Tracing is ON (disableIfPT)
	dataObject = m_flashValueStorage.CreateTempFlashObject();
	dataObject.SetMemberFlashUInt( "tag", NameToFlashUInt( 'Cutscene_RTGIPreset' ) );
	dataObject.SetMemberFlashBool( "disabled", !isRTOn || isPTOn );
	dataArray.PushBackFlashObject( dataObject );

	dataObject = m_flashValueStorage.CreateTempFlashObject();
	dataObject.SetMemberFlashUInt( "tag", NameToFlashUInt( 'Cutscene_EnableRtRadiance' ) );
	dataObject.SetMemberFlashBool( "disabled", !isRTOn || isPTOn );
	dataArray.PushBackFlashObject( dataObject );

	dataObject = m_flashValueStorage.CreateTempFlashObject();
	dataObject.SetMemberFlashUInt( "tag", NameToFlashUInt( 'Cutscene_Shadows' ) );
	dataObject.SetMemberFlashBool( "disabled", !isRTOn || isPTOn );
	dataArray.PushBackFlashObject( dataObject );

	dataObject = m_flashValueStorage.CreateTempFlashObject();
	dataObject.SetMemberFlashUInt( "tag", NameToFlashUInt( 'Cutscene_RTAOEnabled' ) );
	dataObject.SetMemberFlashBool( "disabled", !isRTOn || isPTOn );
	dataArray.PushBackFlashObject( dataObject );

	// 3. PT Hair disabled if HairWorks is off OR PT is off OR HW linear swept spheres unsupported
	dataObject = m_flashValueStorage.CreateTempFlashObject();
	dataObject.SetMemberFlashUInt( "tag", NameToFlashUInt( 'Cutscene_PTHairQualityMode' ) );
	dataObject.SetMemberFlashBool( "disabled", !isHW || !isPTOn || !theGame.GetHardwareLinearSweptSpheresSupport() );
	dataArray.PushBackFlashObject( dataObject );

	// 4. HairWorks AA and Quality preset disabled if HairWorks is off
	dataObject = m_flashValueStorage.CreateTempFlashObject();
	dataObject.SetMemberFlashUInt( "tag", NameToFlashUInt( 'Cutscene_HairWorksAALevel' ) );
	dataObject.SetMemberFlashBool( "disabled", !isHW );
	dataArray.PushBackFlashObject( dataObject );

	dataObject = m_flashValueStorage.CreateTempFlashObject();
	dataObject.SetMemberFlashUInt( "tag", NameToFlashUInt( 'Cutscene_HairWorksQualityPreset' ) );
	dataObject.SetMemberFlashBool( "disabled", !isHW );
	dataArray.PushBackFlashObject( dataObject );

	m_flashValueStorage.SetFlashArray( "options.update_disabled", dataArray );
	theGame.GetGuiManager().ForceProcessFlashStorage();
}
