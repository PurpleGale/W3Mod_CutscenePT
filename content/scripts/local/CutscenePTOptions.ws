// -------------------------------------------------------------------------
// Cutscene Path Tracing (Next-Gen Remastered)
// Class handling mod configuration and options reading
// -------------------------------------------------------------------------

struct SCutscenePTProfile
{
	var enabled            : bool;
	var enableRT           : bool;
	var ptEnable           : bool;
	var rtgiPreset         : bool;
	var enableRtRadiance   : bool;
	var shadows            : string; // "0", "1", "2"
	var rtaoEnabled        : bool;

	var aaMode             : string; // "0", "1", "5", "6", "7"
	var dlssQuality        : string; // "0", "1", "2", "3", "4", "5"
	var enableDLSSRR       : bool;
	var fsr2Quality        : string; // "0", "1", "2", "3", "4", "5"
	var xessQuality        : string; // "0".."7"
	var drsEnable          : bool;
	var dlssnr             : bool;

	var hairWorksLevel          : string; // "0", "1", "2"
	var ptHairQualityMode       : string; // "0", "3"
	var hairWorksAALevel        : string; // "0", "2", "4", "8"
	var hairWorksQualityPreset  : string; // "0" (low), "1" (high)
}

function GetCutscenePTVersion() : string
{
	return "1.33";
}

class CutscenePTOptions
{
	// General Options
	var modEnabled          : bool;
	var showNotifications   : bool;

	public function GetVersion() : string
	{
		return GetCutscenePTVersion();
	}

	// Dialogue Profile
	var dialogProfile       : SCutscenePTProfile;

	// Cutscene Profile
	var cutsceneProfile     : SCutscenePTProfile;

	public function ReadValues() : void
	{
		var wrapper : CInGameConfigWrapper;
		var strVal  : string;

		wrapper = theGame.GetInGameConfigWrapper();
		if ( !wrapper )
		{
			return;
		}

		// 1. General Settings
		modEnabled        = ( wrapper.GetVarValue( 'CutscenePTGeneral', 'ModEnabled' ) == "true" );
		showNotifications = ( wrapper.GetVarValue( 'CutscenePTGeneral', 'ShowNotifications' ) == "true" );

		// 2. Dialogue Settings
		ReadDialogProfile( wrapper );

		// 3. Cutscene Settings
		ReadCutsceneProfile( wrapper );
	}

	private function ReadDialogProfile( wrapper : CInGameConfigWrapper ) : void
	{
		var val : string;

		dialogProfile.enabled  = ( wrapper.GetVarValue( 'CutscenePTDialogs', 'Dialog_Enabled' ) == "true" );
		dialogProfile.enableRT = ( wrapper.GetVarValue( 'CutscenePTDialogs', 'Dialog_EnableRT' ) == "true" );

		// If Ray Tracing is OFF, all RT/PT sub-features are strictly OFF
		if ( !dialogProfile.enableRT )
		{
			dialogProfile.ptEnable         = false;
			dialogProfile.rtgiPreset       = false;
			dialogProfile.enableRtRadiance = false;
			dialogProfile.rtaoEnabled      = false;
			dialogProfile.shadows          = "0";
		}
		else
		{
			dialogProfile.ptEnable         = ( wrapper.GetVarValue( 'CutscenePTDialogs', 'Dialog_PTEnable' ) == "true" );
			dialogProfile.rtgiPreset       = ( wrapper.GetVarValue( 'CutscenePTDialogs', 'Dialog_RTGIPreset' ) == "true" );
			dialogProfile.enableRtRadiance = ( wrapper.GetVarValue( 'CutscenePTDialogs', 'Dialog_EnableRtRadiance' ) == "true" );
			dialogProfile.rtaoEnabled      = ( wrapper.GetVarValue( 'CutscenePTDialogs', 'Dialog_RTAOEnabled' ) == "true" );

			val = wrapper.GetVarValue( 'CutscenePTDialogs', 'Dialog_Shadows' );
			if ( val == "" ) val = "2";
			dialogProfile.shadows = val;
		}

		val = wrapper.GetVarValue( 'CutscenePTDialogs', 'Dialog_AAMode' );
		if ( val == "" ) val = "6";
		dialogProfile.aaMode = val;

		val = wrapper.GetVarValue( 'CutscenePTDialogs', 'Dialog_DLSSQuality' );
		if ( val == "" ) val = "0";
		dialogProfile.dlssQuality = val;

		dialogProfile.enableDLSSRR = ( wrapper.GetVarValue( 'CutscenePTDialogs', 'Dialog_EnableDLSSRR' ) == "true" );

		val = wrapper.GetVarValue( 'CutscenePTDialogs', 'Dialog_FSR2Quality' );
		if ( val == "" ) val = "0";
		dialogProfile.fsr2Quality = val;

		val = wrapper.GetVarValue( 'CutscenePTDialogs', 'Dialog_XESSQuality' );
		if ( val == "" ) val = "0";
		dialogProfile.xessQuality = val;

		dialogProfile.drsEnable = ( wrapper.GetVarValue( 'CutscenePTDialogs', 'Dialog_DRSEnable' ) == "true" );
		dialogProfile.dlssnr    = ( wrapper.GetVarValue( 'CutscenePTDialogs', 'Dialog_DLSSNR' ) == "true" );

		val = wrapper.GetVarValue( 'CutscenePTDialogs', 'Dialog_HairWorksLevel' );
		if ( val == "" ) val = "0";
		dialogProfile.hairWorksLevel = val;

		val = wrapper.GetVarValue( 'CutscenePTDialogs', 'Dialog_PTHairQualityMode' );
		if ( val == "" ) val = "0";
		dialogProfile.ptHairQualityMode = val;

		val = wrapper.GetVarValue( 'CutscenePTDialogs', 'Dialog_HairWorksAALevel' );
		if ( val == "" ) val = "0";
		dialogProfile.hairWorksAALevel = val;

		val = wrapper.GetVarValue( 'CutscenePTDialogs', 'Dialog_HairWorksQualityPreset' );
		if ( val == "" ) val = "0";
		dialogProfile.hairWorksQualityPreset = val;
	}

	private function ReadCutsceneProfile( wrapper : CInGameConfigWrapper ) : void
	{
		var val : string;

		cutsceneProfile.enabled  = ( wrapper.GetVarValue( 'CutscenePTCutscenes', 'Cutscene_Enabled' ) == "true" );
		cutsceneProfile.enableRT = ( wrapper.GetVarValue( 'CutscenePTCutscenes', 'Cutscene_EnableRT' ) == "true" );

		// If Ray Tracing is OFF, all RT/PT sub-features are strictly OFF
		if ( !cutsceneProfile.enableRT )
		{
			cutsceneProfile.ptEnable         = false;
			cutsceneProfile.rtgiPreset       = false;
			cutsceneProfile.enableRtRadiance = false;
			cutsceneProfile.rtaoEnabled      = false;
			cutsceneProfile.shadows          = "0";
		}
		else
		{
			cutsceneProfile.ptEnable         = ( wrapper.GetVarValue( 'CutscenePTCutscenes', 'Cutscene_PTEnable' ) == "true" );
			cutsceneProfile.rtgiPreset       = ( wrapper.GetVarValue( 'CutscenePTCutscenes', 'Cutscene_RTGIPreset' ) == "true" );
			cutsceneProfile.enableRtRadiance = ( wrapper.GetVarValue( 'CutscenePTCutscenes', 'Cutscene_EnableRtRadiance' ) == "true" );
			cutsceneProfile.rtaoEnabled      = ( wrapper.GetVarValue( 'CutscenePTCutscenes', 'Cutscene_RTAOEnabled' ) == "true" );

			val = wrapper.GetVarValue( 'CutscenePTCutscenes', 'Cutscene_Shadows' );
			if ( val == "" ) val = "2";
			cutsceneProfile.shadows = val;
		}

		val = wrapper.GetVarValue( 'CutscenePTCutscenes', 'Cutscene_AAMode' );
		if ( val == "" ) val = "6";
		cutsceneProfile.aaMode = val;

		val = wrapper.GetVarValue( 'CutscenePTCutscenes', 'Cutscene_DLSSQuality' );
		if ( val == "" ) val = "0";
		cutsceneProfile.dlssQuality = val;

		cutsceneProfile.enableDLSSRR = ( wrapper.GetVarValue( 'CutscenePTCutscenes', 'Cutscene_EnableDLSSRR' ) == "true" );

		val = wrapper.GetVarValue( 'CutscenePTCutscenes', 'Cutscene_FSR2Quality' );
		if ( val == "" ) val = "0";
		cutsceneProfile.fsr2Quality = val;

		val = wrapper.GetVarValue( 'CutscenePTCutscenes', 'Cutscene_XESSQuality' );
		if ( val == "" ) val = "0";
		cutsceneProfile.xessQuality = val;

		cutsceneProfile.drsEnable = ( wrapper.GetVarValue( 'CutscenePTCutscenes', 'Cutscene_DRSEnable' ) == "true" );
		cutsceneProfile.dlssnr    = ( wrapper.GetVarValue( 'CutscenePTCutscenes', 'Cutscene_DLSSNR' ) == "true" );

		val = wrapper.GetVarValue( 'CutscenePTCutscenes', 'Cutscene_HairWorksLevel' );
		if ( val == "" ) val = "0";
		cutsceneProfile.hairWorksLevel = val;

		val = wrapper.GetVarValue( 'CutscenePTCutscenes', 'Cutscene_PTHairQualityMode' );
		if ( val == "" ) val = "0";
		cutsceneProfile.ptHairQualityMode = val;

		val = wrapper.GetVarValue( 'CutscenePTCutscenes', 'Cutscene_HairWorksAALevel' );
		if ( val == "" ) val = "0";
		cutsceneProfile.hairWorksAALevel = val;

		val = wrapper.GetVarValue( 'CutscenePTCutscenes', 'Cutscene_HairWorksQualityPreset' );
		if ( val == "" ) val = "0";
		cutsceneProfile.hairWorksQualityPreset = val;
	}

	public final function FirstTimeOptionSetup() : void
	{
		var wrapper : CInGameConfigWrapper;

		wrapper = theGame.GetInGameConfigWrapper();
		if ( !wrapper )
		{
			return;
		}

		if ( !Initialized() )
		{
			// General Defaults
			wrapper.SetVarValue( 'CutscenePTGeneral', 'ModEnabled', "true" );
			wrapper.SetVarValue( 'CutscenePTGeneral', 'ShowNotifications', "true" );
			wrapper.SetVarValue( 'CutscenePTGeneral', 'VersionNr', "2.20" );

			// Dialogue Defaults (Full PT)
			wrapper.SetVarValue( 'CutscenePTDialogs', 'Dialog_Enabled', "true" );
			wrapper.SetVarValue( 'CutscenePTDialogs', 'Dialog_DLSSNR', "false" );
			wrapper.SetVarValue( 'CutscenePTDialogs', 'Dialog_EnableRT', "true" );
			wrapper.SetVarValue( 'CutscenePTDialogs', 'Dialog_PTEnable', "true" );
			wrapper.SetVarValue( 'CutscenePTDialogs', 'Dialog_RTGIPreset', "true" );
			wrapper.SetVarValue( 'CutscenePTDialogs', 'Dialog_EnableRtRadiance', "true" );
			wrapper.SetVarValue( 'CutscenePTDialogs', 'Dialog_Shadows', "2" );
			wrapper.SetVarValue( 'CutscenePTDialogs', 'Dialog_RTAOEnabled', "true" );
			wrapper.SetVarValue( 'CutscenePTDialogs', 'Dialog_AAMode', "6" );
			wrapper.SetVarValue( 'CutscenePTDialogs', 'Dialog_DLSSQuality', "0" );
			wrapper.SetVarValue( 'CutscenePTDialogs', 'Dialog_EnableDLSSRR', "true" );
			wrapper.SetVarValue( 'CutscenePTDialogs', 'Dialog_FSR2Quality', "0" );
			wrapper.SetVarValue( 'CutscenePTDialogs', 'Dialog_XESSQuality', "0" );
			wrapper.SetVarValue( 'CutscenePTDialogs', 'Dialog_DRSEnable', "false" );
			wrapper.SetVarValue( 'CutscenePTDialogs', 'Dialog_HairWorksLevel', "0" );
			wrapper.SetVarValue( 'CutscenePTDialogs', 'Dialog_PTHairQualityMode', "0" );
			wrapper.SetVarValue( 'CutscenePTDialogs', 'Dialog_HairWorksAALevel', "0" );
			wrapper.SetVarValue( 'CutscenePTDialogs', 'Dialog_HairWorksQualityPreset', "0" );

			// Cutscene Defaults (Full PT)
			wrapper.SetVarValue( 'CutscenePTCutscenes', 'Cutscene_Enabled', "true" );
			wrapper.SetVarValue( 'CutscenePTCutscenes', 'Cutscene_DLSSNR', "false" );
			wrapper.SetVarValue( 'CutscenePTCutscenes', 'Cutscene_EnableRT', "true" );
			wrapper.SetVarValue( 'CutscenePTCutscenes', 'Cutscene_PTEnable', "true" );
			wrapper.SetVarValue( 'CutscenePTCutscenes', 'Cutscene_RTGIPreset', "true" );
			wrapper.SetVarValue( 'CutscenePTCutscenes', 'Cutscene_EnableRtRadiance', "true" );
			wrapper.SetVarValue( 'CutscenePTCutscenes', 'Cutscene_Shadows', "2" );
			wrapper.SetVarValue( 'CutscenePTCutscenes', 'Cutscene_RTAOEnabled', "true" );
			wrapper.SetVarValue( 'CutscenePTCutscenes', 'Cutscene_AAMode', "6" );
			wrapper.SetVarValue( 'CutscenePTCutscenes', 'Cutscene_DLSSQuality', "0" );
			wrapper.SetVarValue( 'CutscenePTCutscenes', 'Cutscene_EnableDLSSRR', "true" );
			wrapper.SetVarValue( 'CutscenePTCutscenes', 'Cutscene_FSR2Quality', "0" );
			wrapper.SetVarValue( 'CutscenePTCutscenes', 'Cutscene_XESSQuality', "0" );
			wrapper.SetVarValue( 'CutscenePTCutscenes', 'Cutscene_DRSEnable', "false" );
			wrapper.SetVarValue( 'CutscenePTCutscenes', 'Cutscene_HairWorksLevel', "0" );
			wrapper.SetVarValue( 'CutscenePTCutscenes', 'Cutscene_PTHairQualityMode', "0" );
			wrapper.SetVarValue( 'CutscenePTCutscenes', 'Cutscene_HairWorksAALevel', "0" );
			wrapper.SetVarValue( 'CutscenePTCutscenes', 'Cutscene_HairWorksQualityPreset', "0" );

			theGame.SaveUserSettings();
		}
	}

	public function Initialized() : bool
	{
		var wrapper : CInGameConfigWrapper;
		wrapper = theGame.GetInGameConfigWrapper();
		if ( !wrapper )
		{
			return false;
		}
		return ( StringToFloat( wrapper.GetVarValue( 'CutscenePTGeneral', 'VersionNr' ) ) >= 2.20f );
	}

	public function Init() : bool
	{
		FirstTimeOptionSetup();
		ReadValues();
		return true;
	}

	public function IsModEnabled() : bool                     { return modEnabled; }
	public function IsShowNotifications() : bool              { return showNotifications; }
	public function GetDialogProfile() : SCutscenePTProfile   { return dialogProfile; }
	public function GetCutsceneProfile() : SCutscenePTProfile { return cutsceneProfile; }
}
