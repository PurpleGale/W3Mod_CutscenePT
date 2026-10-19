// -------------------------------------------------------------------------
// Cutscene Path Tracing (Next-Gen Remastered)
// Central Manager handling state detection, safe caching, and transitions
// -------------------------------------------------------------------------

class CutscenePTManager
{
	private var m_options            : CutscenePTOptions;
	private var m_isCutsceneActive   : bool;
	private var m_isDialogActive     : bool;
	private var m_isPTApplied        : bool;
	private var m_activeProfileType  : int; // 0: None, 1: Cutscene, 2: Dialogue
	private var m_hasCachedValues    : bool;

	// Cached gameplay rendering settings
	private var m_cachedPTEnable         : string;
	private var m_cachedEnableRT         : string;
	private var m_cachedRTGIPreset       : string;
	private var m_cachedEnableRtRadiance : string;
	private var m_cachedRTAOEnabled      : string;
	private var m_cachedShadows          : string;

	// Cached AA, Upscaling and DRS settings
	private var m_cachedAAMode           : string;
	private var m_cachedDLSSQuality      : string;
	private var m_cachedEnableDLSSRR     : string;
	private var m_cachedFSR2Quality      : string;
	private var m_cachedXESSQuality      : string;
	private var m_cachedDRSEnable        : string;

	// Cached HairWorks settings
	private var m_cachedHairWorksLevel     : string;
	private var m_cachedPTHairQuality      : string;
	private var m_cachedHairWorksAALevel   : string;
	private var m_cachedHWStrandSmoothness : string;
	private var m_cachedHWDensityLimit     : string;
	private var m_cachedHWDensityQuality   : string;
	private var m_cachedHWDetailLODFactor  : string;
	private var m_cachedHWWidthLimit       : string;

	public function Init( options : CutscenePTOptions ) : void
	{
		m_options = options;
		m_isCutsceneActive = false;
		m_isDialogActive = false;
		m_isPTApplied = false;
		m_activeProfileType = 0;
		m_hasCachedValues = false;
	}

	public function OnGameStarted() : void
	{
		m_isCutsceneActive = false;
		m_isDialogActive = false;
		m_isPTApplied = false;
		m_activeProfileType = 0;
		m_hasCachedValues = false;

		LogChannel( 'CutscenePT', "Initialized v" + GetCutscenePTVersion() + " | RTSupport: " + theGame.GetRTSupported() + " | DLSSEnabled: " + theGame.GetDLSSEnabled() + " | FSREnabled: " + theGame.GetFSREnabled() + " | XESSEnabled: " + theGame.GetXESSEnabled() );

		// If loaded directly into an active dialogue or cutscene
		if ( theGame.IsDialogOrCutscenePlaying() || theGame.isCutscenePlaying )
		{
			m_isDialogActive = theGame.IsDialogOrCutscenePlaying();
			m_isCutsceneActive = theGame.isCutscenePlaying;
			EvaluateSceneState();
		}
	}

	// ---------------------------------------------------------------------
	// Scene Event Handlers
	// ---------------------------------------------------------------------

	public function OnDialogStateChanged( isPlaying : bool ) : void
	{
		m_isDialogActive = isPlaying;
		EvaluateSceneState();
	}

	public function OnCutsceneStateChanged( isPlaying : bool ) : void
	{
		m_isCutsceneActive = isPlaying;
		EvaluateSceneState();
	}

	public function OnCameraBlendToGameplay() : void
	{
		// Camera started blending back to player; restore immediately for seamless gameplay combat
		if ( m_isPTApplied )
		{
			if ( !theGame.IsDialogOrCutscenePlaying() && !theGame.isCutscenePlaying )
			{
				RestoreGameplayLighting();
			}
		}
	}

	// ---------------------------------------------------------------------
	// Core State Evaluation
	// ---------------------------------------------------------------------

	public function EvaluateSceneState() : void
	{
		var desiredProfile : int;

		if ( !m_options || !m_options.IsModEnabled() )
		{
			if ( m_isPTApplied )
			{
				RestoreGameplayLighting();
			}
			return;
		}

		if ( !IsRTSupported() )
		{
			return;
		}

		desiredProfile = GetDesiredProfileType();

		if ( desiredProfile != 0 )
		{
			if ( !m_isPTApplied || m_activeProfileType != desiredProfile )
			{
				ApplySceneProfile( desiredProfile );
			}
		}
		else if ( m_isPTApplied )
		{
			RestoreGameplayLighting();
		}
	}

	public function OnSettingsChanged() : void
	{
		var desiredProfile : int;

		LogChannel( 'CutscenePT', "OnSettingsChanged | Mod settings updated in-game" );

		if ( !m_options || !m_options.IsModEnabled() )
		{
			if ( m_isPTApplied )
			{
				RestoreGameplayLighting();
			}
			return;
		}

		if ( !IsRTSupported() )
		{
			return;
		}

		desiredProfile = GetDesiredProfileType();
		if ( desiredProfile != 0 )
		{
			ApplySceneProfile( desiredProfile );
		}
		else if ( m_isPTApplied )
		{
			RestoreGameplayLighting();
		}
	}

	private function GetDesiredProfileType() : int
	{
		var isCutscene : bool;
		var isDialog   : bool;
		var cutsceneProf : SCutscenePTProfile;
		var dialogProf   : SCutscenePTProfile;

		isCutscene = ( m_isCutsceneActive || theGame.isCutscenePlaying );
		isDialog   = ( m_isDialogActive || theGame.IsDialogOrCutscenePlaying() );

		cutsceneProf = m_options.GetCutsceneProfile();
		dialogProf   = m_options.GetDialogProfile();

		// Priority 1: Cutscenes
		if ( isCutscene && cutsceneProf.enabled )
		{
			return 1; // Cutscene Profile
		}

		// Priority 2: Dialogues
		if ( isDialog && dialogProf.enabled )
		{
			return 2; // Dialogue Profile
		}

		return 0; // None / Restore
	}

	// ---------------------------------------------------------------------
	// Lighting Transitions
	// ---------------------------------------------------------------------

	public function ApplySceneProfile( profileType : int ) : void
	{
		var prof     : SCutscenePTProfile;
		var rtStr    : string;
		var ptStr    : string;
		var giStr    : string;
		var radStr   : string;
		var rtaoStr  : string;
		var rrStr    : string;
		var drsStr   : string;

		var aaMode   : string;

		// 1. Snapshot gameplay settings before touching anything
		if ( !m_hasCachedValues )
		{
			m_cachedPTEnable         = ReadConfigVar( "Rendering/RT/PathTracer", 'PTEnable' );
			m_cachedEnableRT         = ReadConfigVar( "Rendering/RT", 'EnableRT' );
			m_cachedRTGIPreset       = ReadConfigVar( "Rendering/RT", 'RTGIPreset' );
			m_cachedEnableRtRadiance = ReadConfigVar( "Rendering/RT", 'EnableRtRadiance' );
			m_cachedRTAOEnabled      = ReadConfigVar( "Rendering/RT", 'RTAOEnabled' );
			m_cachedShadows          = ReadConfigVar( "Rendering/RT", 'Shadows' );

			m_cachedAAMode           = ReadConfigVar( "PostProcess", 'AAMode' );
			m_cachedDLSSQuality      = ReadConfigVar( "PostProcess", 'DLSSQuality' );
			m_cachedEnableDLSSRR     = ReadConfigVar( "PostProcess", 'EnableDLSSRR' );
			m_cachedFSR2Quality      = ReadConfigVar( "PostProcess", 'FSR2Quality' );
			m_cachedXESSQuality      = ReadConfigVar( "PostProcess", 'XESSQuality' );
			m_cachedDRSEnable        = ReadConfigVar( "Rendering/DRS", 'Enable' );

			m_cachedHairWorksLevel     = ReadConfigVar( "Rendering", 'HairWorksLevel' );
			m_cachedPTHairQuality      = ReadConfigVar( "Rendering/RT/PathTracer", 'PTHairQualityMode' );
			m_cachedHairWorksAALevel   = ReadConfigVar( "Rendering", 'HairWorksAALevel' );
			m_cachedHWStrandSmoothness = ReadConfigVar( "Rendering", 'HairWorksGlobalStrandSmoothness' );
			m_cachedHWDensityLimit     = ReadConfigVar( "Rendering", 'HairWorkstGlobalDensityLimit' );
			m_cachedHWDensityQuality   = ReadConfigVar( "Rendering", 'HairWorksGlobalDensityQuality' );
			m_cachedHWDetailLODFactor  = ReadConfigVar( "Rendering", 'HairWorksGlobalDetailLODFactor' );
			m_cachedHWWidthLimit       = ReadConfigVar( "Rendering", 'HairWorksGlobalWidthLimit' );

			m_hasCachedValues        = true;
		}

		if ( profileType == 1 )
		{
			prof = m_options.GetCutsceneProfile();
		}
		else
		{
			prof = m_options.GetDialogProfile();
		}

		// Convert booleans to strings - PT strictly requires RT to be active
		if ( prof.enableRT || prof.ptEnable ) rtStr = "true";   else rtStr = "false";
		if ( prof.ptEnable )                  ptStr = "true";   else ptStr = "false";
		if ( prof.rtgiPreset )       giStr = "true";   else giStr = "false";
		if ( prof.enableRtRadiance ) radStr = "true";  else radStr = "false";
		if ( prof.rtaoEnabled )      rtaoStr = "true"; else rtaoStr = "false";
		if ( prof.enableDLSSRR )     rrStr = "true";   else rrStr = "false";
		if ( prof.drsEnable )        drsStr = "true";  else drsStr = "false";

		// 2. Apply Ray Tracing Settings
		if ( prof.enableRT )
		{
			if ( prof.ptEnable )         ptStr = "true";   else ptStr = "false";
			if ( prof.rtgiPreset )       giStr = "true";   else giStr = "false";
			if ( prof.enableRtRadiance ) radStr = "true";  else radStr = "false";
			if ( prof.rtaoEnabled )      rtaoStr = "true"; else rtaoStr = "false";

			ApplyConfigVar( "Rendering/RT", 'EnableRT', "true" );
			ApplyConfigVar( "Rendering/RT/PathTracer", 'PTEnable', ptStr );
			ApplyConfigVar( "Rendering/RT", 'RTGIPreset', giStr );
			ApplyConfigVar( "Rendering/RT", 'EnableRtRadiance', radStr );
			ApplyConfigVar( "Rendering/RT", 'Shadows', prof.shadows );
			ApplyConfigVar( "Rendering/RT", 'RTAOEnabled', rtaoStr );
		}
		else
		{
			// User set Ray Tracing to OFF: disable base RT and all RT/PT passes completely!
			ApplyConfigVar( "Rendering/RT", 'EnableRT', "false" );
			ApplyConfigVar( "Rendering/RT/PathTracer", 'PTEnable', "false" );
			ApplyConfigVar( "Rendering/RT", 'RTGIPreset', "false" );
			ApplyConfigVar( "Rendering/RT", 'EnableRtRadiance', "false" );
			ApplyConfigVar( "Rendering/RT", 'Shadows', "0" );
			ApplyConfigVar( "Rendering/RT", 'RTAOEnabled', "false" );
		}

		// 3. Apply Anti-Aliasing and Upscaling Settings
		ApplyAAConfig( prof.aaMode, prof.dlssQuality, prof.enableDLSSRR, prof.fsr2Quality, prof.xessQuality );
		ApplyConfigVar( "Rendering/DRS", 'Enable', drsStr );

		if ( prof.dlssnr )
		{
			ApplyConfigVar( "PostProcess", 'CutsceneNR_Active', "force_on" );
		}
		else
		{
			ApplyConfigVar( "PostProcess", 'CutsceneNR_Active', "force_off" );
		}

		// 4. Apply HairWorks, PT Hair, and HairWorks AA / Preset
		ApplyConfigVar( "Rendering", 'HairWorksLevel', prof.hairWorksLevel );
		if ( prof.ptEnable && CanEnablePTHair() )
		{
			ApplyConfigVar( "Rendering/RT/PathTracer", 'PTHairQualityMode', prof.ptHairQualityMode );
		}
		else
		{
			ApplyConfigVar( "Rendering/RT/PathTracer", 'PTHairQualityMode', "0" );
		}

		if ( prof.hairWorksLevel != "" && prof.hairWorksLevel != "0" )
		{
			ApplyConfigVar( "Rendering", 'HairWorksAALevel', prof.hairWorksAALevel );

			if ( prof.hairWorksQualityPreset == "1" ) // high
			{
				ApplyConfigVar( "Rendering", 'HairWorksGlobalStrandSmoothness', "3" );
				ApplyConfigVar( "Rendering", 'HairWorkstGlobalDensityLimit', "2.0" );
				ApplyConfigVar( "Rendering", 'HairWorksGlobalDensityQuality', "1.0" );
				ApplyConfigVar( "Rendering", 'HairWorksGlobalDetailLODFactor', "1.0" );
				ApplyConfigVar( "Rendering", 'HairWorksGlobalWidthLimit', "5.0" );
			}
			else // low
			{
				ApplyConfigVar( "Rendering", 'HairWorksGlobalStrandSmoothness', "2" );
				ApplyConfigVar( "Rendering", 'HairWorkstGlobalDensityLimit', "0.35" );
				ApplyConfigVar( "Rendering", 'HairWorksGlobalDensityQuality', "0.75" );
				ApplyConfigVar( "Rendering", 'HairWorksGlobalDetailLODFactor', "0.65" );
				ApplyConfigVar( "Rendering", 'HairWorksGlobalWidthLimit', "2.25" );
			}
		}

		theGame.SaveUserSettings();
		m_isPTApplied = true;
		m_activeProfileType = profileType;

		// 5. User feedback notification if enabled
		SendNotification( "Msg_PTActive", "[Cutscene PT] Path Tracing Active" );

		LogChannel( 'CutscenePT', "Profile " + profileType + " applied | RT: " + prof.enableRT + ", PT: " + prof.ptEnable + ", AA: " + prof.aaMode + ", DLSSQuality: " + prof.dlssQuality + ", DLSS-NR: " + prof.dlssnr + ", HW: " + prof.hairWorksLevel );
	}

	public function RestoreGameplayLighting() : void
	{
		if ( !m_isPTApplied || !m_hasCachedValues )
		{
			m_isPTApplied = false;
			m_activeProfileType = 0;
			return;
		}

		// 1. Restore exact gameplay graphics settings
		if ( m_cachedPTEnable != "" )
		{
			ApplyConfigVar( "Rendering/RT/PathTracer", 'PTEnable', m_cachedPTEnable );
		}
		if ( m_cachedEnableRtRadiance != "" )
		{
			ApplyConfigVar( "Rendering/RT", 'EnableRtRadiance', m_cachedEnableRtRadiance );
		}
		if ( m_cachedRTAOEnabled != "" )
		{
			ApplyConfigVar( "Rendering/RT", 'RTAOEnabled', m_cachedRTAOEnabled );
		}
		if ( m_cachedShadows != "" )
		{
			ApplyConfigVar( "Rendering/RT", 'Shadows', m_cachedShadows );
		}
		if ( m_cachedRTGIPreset != "" )
		{
			ApplyConfigVar( "Rendering/RT", 'RTGIPreset', m_cachedRTGIPreset );
		}

		if ( m_cachedEnableRT != "" )
		{
			ApplyConfigVar( "Rendering/RT", 'EnableRT', m_cachedEnableRT );
		}

		// 2. Restore AA / Upscaling quality and DRS
		if ( theGame.GetDLSSEnabled() || m_cachedAAMode == "6" )
		{
			if ( m_cachedDLSSQuality != "" )
			{
				ApplyConfigVar( "PostProcess", 'DLSSQuality', m_cachedDLSSQuality );
			}
		}
		else if ( theGame.GetFSREnabled() || m_cachedAAMode == "5" )
		{
			if ( m_cachedFSR2Quality != "" )
			{
				ApplyConfigVar( "PostProcess", 'FSR2Quality', m_cachedFSR2Quality );
			}
		}
		else if ( theGame.GetXESSEnabled() || m_cachedAAMode == "7" )
		{
			if ( m_cachedXESSQuality != "" )
			{
				ApplyConfigVar( "PostProcess", 'XESSQuality', m_cachedXESSQuality );
			}
		}

		if ( m_cachedDRSEnable != "" )
		{
			ApplyConfigVar( "Rendering/DRS", 'Enable', m_cachedDRSEnable );
		}
		if ( m_cachedEnableDLSSRR != "" )
		{
			ApplyConfigVar( "PostProcess", 'EnableDLSSRR', m_cachedEnableDLSSRR );
		}
		ApplyConfigVar( "PostProcess", 'CutsceneNR_Active', "gameplay" );

		// 3. Restore HairWorks, PT Hair mode, AA level and Preset
		if ( m_cachedHairWorksLevel != "" )
		{
			ApplyConfigVar( "Rendering", 'HairWorksLevel', m_cachedHairWorksLevel );
		}
		if ( m_cachedPTHairQuality != "" )
		{
			ApplyConfigVar( "Rendering/RT/PathTracer", 'PTHairQualityMode', m_cachedPTHairQuality );
		}
		if ( m_cachedHairWorksAALevel != "" )
		{
			ApplyConfigVar( "Rendering", 'HairWorksAALevel', m_cachedHairWorksAALevel );
		}
		if ( m_cachedHWStrandSmoothness != "" )
		{
			ApplyConfigVar( "Rendering", 'HairWorksGlobalStrandSmoothness', m_cachedHWStrandSmoothness );
		}
		if ( m_cachedHWDensityLimit != "" )
		{
			ApplyConfigVar( "Rendering", 'HairWorkstGlobalDensityLimit', m_cachedHWDensityLimit );
		}
		if ( m_cachedHWDensityQuality != "" )
		{
			ApplyConfigVar( "Rendering", 'HairWorksGlobalDensityQuality', m_cachedHWDensityQuality );
		}
		if ( m_cachedHWDetailLODFactor != "" )
		{
			ApplyConfigVar( "Rendering", 'HairWorksGlobalDetailLODFactor', m_cachedHWDetailLODFactor );
		}
		if ( m_cachedHWWidthLimit != "" )
		{
			ApplyConfigVar( "Rendering", 'HairWorksGlobalWidthLimit', m_cachedHWWidthLimit );
		}

		theGame.SaveUserSettings();
		m_isPTApplied = false;
		m_activeProfileType = 0;
		m_hasCachedValues = false;

		// 4. User feedback notification if enabled
		SendNotification( "Msg_PTRestored", "[Cutscene PT] Gameplay Lighting Restored" );

		LogChannel( 'CutscenePT', "Gameplay settings restored | RT: " + m_cachedEnableRT + ", PT: " + m_cachedPTEnable + ", AA: " + m_cachedAAMode + ", DLSSQuality: " + m_cachedDLSSQuality + ", HW: " + m_cachedHairWorksLevel );
	}

	// ---------------------------------------------------------------------
	// Notifications
	// ---------------------------------------------------------------------

	private function SendNotification( msgKey : string, defaultFallback : string ) : void
	{
		var msg        : string;
		var guiManager : CR4GuiManager;
		var hud        : CR4ScriptedHud;

		if ( !m_options || !m_options.IsShowNotifications() )
		{
			return;
		}

		msg = GetLocStringByKeyExt( msgKey );
		if ( msg == "" )
		{
			msg = defaultFallback;
		}

		guiManager = theGame.GetGuiManager();
		if ( guiManager )
		{
			guiManager.ShowNotification( msg );
		}

		hud = (CR4ScriptedHud)theGame.GetHud();
		if ( hud )
		{
			hud.HudConsoleMsg( msg );
		}

		if ( thePlayer )
		{
			thePlayer.DisplayHudMessage( msg );
		}
	}

	// ---------------------------------------------------------------------
	// Config Helpers
	// ---------------------------------------------------------------------

	private function ApplyAAConfig( aaModeVal : string, dlssQualityVal : string, dlssRRVal : bool, fsrQualityVal : string, xessQualityVal : string ) : void
	{
		// Apply quality to active upscaler in [PostProcess] (exact v1.22 safe behavior)
		if ( theGame.GetDLSSEnabled() || aaModeVal == "6" )
		{
			if ( dlssQualityVal != "" )
			{
				ApplyConfigVar( "PostProcess", 'DLSSQuality', dlssQualityVal );
			}
		}
		else if ( theGame.GetFSREnabled() || aaModeVal == "5" )
		{
			if ( fsrQualityVal != "" )
			{
				ApplyConfigVar( "PostProcess", 'FSR2Quality', fsrQualityVal );
			}
		}
		else if ( theGame.GetXESSEnabled() || aaModeVal == "7" )
		{
			if ( xessQualityVal != "" )
			{
				ApplyConfigVar( "PostProcess", 'XESSQuality', xessQualityVal );
			}
		}
	}

	private function ApplyConfigVar( groupStr : string, varName : name, value : string ) : void
	{
		var wrapper : CInGameConfigWrapper;
		wrapper = theGame.GetInGameConfigWrapper();
		if ( wrapper && value != "" )
		{
			wrapper.SetVarValueByStr( groupStr, varName, value );
			wrapper.SetRawConfigValueByStr( groupStr, NameToString( varName ), value );
			theGame.OnConfigValueChanged( varName, value );
		}
	}

	private function ReadConfigVar( groupStr : string, varName : name ) : string
	{
		var wrapper : CInGameConfigWrapper;
		var val     : string;
		wrapper = theGame.GetInGameConfigWrapper();
		if ( wrapper )
		{
			val = wrapper.GetVarValueByStr( groupStr, varName );
			if ( val == "" )
			{
				val = wrapper.GetRawConfigValueByStr( groupStr, NameToString( varName ) );
			}
			return val;
		}
		return "";
	}

	public function IsRTSupported() : bool
	{
		if ( theGame.GetRTSupported() )
		{
			return true;
		}
		return ( theGame.GetPlatform() == Platform_PC && theGame.GetInGameConfigWrapper().GetVarValueByStr("Rendering/RT", 'EnableRT') != "" );
	}

	public function CanEnablePTHair() : bool
	{
		return theGame.GetRTSupported()
			&& theGame.GetHardwareLinearSweptSpheresSupport()
			&& theGame.GetDLSSRREnabled();
	}

	public function IsPTApplied() : bool
	{
		return m_isPTApplied;
	}
}

// -------------------------------------------------------------------------
// Debug and Manual Test Console Commands
// -------------------------------------------------------------------------
exec function CPT_On()
{
	if ( theGame.cutscenePTManager )
	{
		theGame.cutscenePTManager.ApplySceneProfile( 1 );
	}
}

exec function CPT_Off()
{
	if ( theGame.cutscenePTManager )
	{
		theGame.cutscenePTManager.RestoreGameplayLighting();
	}
}

exec function CPT_Status()
{
	var msg : string;
	if ( theGame.cutscenePTManager )
	{
		msg = "[Cutscene PT v" + GetCutscenePTVersion() + "] PTApplied: " + theGame.cutscenePTManager.IsPTApplied() + 
		      " | RTSupp: " + theGame.cutscenePTManager.IsRTSupported() + 
		      " | PTHairSupp: " + theGame.cutscenePTManager.CanEnablePTHair() + 
		      " | Scene: " + (theGame.IsDialogOrCutscenePlaying() || theGame.isCutscenePlaying);
		if ( thePlayer )
		{
			thePlayer.DisplayHudMessage( msg );
		}
		LogChannel( 'CutscenePT', msg );
	}
}
