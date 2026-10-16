# WitcherScript & Engine Implementation Guide

This guide covers the technical details of WitcherScript hooks, engine settings wrappers, and compile workflows for **Dynamic Path Tracing For Cutscenes**.

---

## 1. Script Architecture & Responsibilities

### 1. `local/CutscenePTManager.ws`
- Singleton manager attached to `CR4Game` (`theGame.cutscenePTManager`).
- Monitors dialogue and cutscene states:
  - `OnCutsceneOrDialogueStart(isDialogue: bool)`
  - `OnCutsceneOrDialogueEnd(isDialogue: bool)`
- Implements debounce delay timer to prevent rapid graphics switching when players skip dialogue lines with the Spacebar.
- Interacts with `CInGameConfigWrapper` to toggle graphics options on the fly.
- Handles user notifications (`thePlayer.DisplayCustomOrientationFeedback(...)` or `theGame.GetGuiManager().ShowNotification(...)`).

### 2. `local/CutscenePTOptions.ws`
- Attached to `CR4Game` (`theGame.cutscenePTOptions`).
- Reads user settings from the `[CutscenePTMain]` config section in `user.settings`:
  - `ModEnabled` (bool)
  - `CutsceneLightingMode` (int: 0 = Full PT, 1 = Minimal PT / GI, 2 = Cinematic RT)
  - `TargetScenes` (int: 0 = All Scenes, 1 = Cinematics Only, 2 = Dialogues Only)
  - `AutoAAQuality` (int: 0 = Unchanged, 1 = Auto, 2 = Max DLAA)
  - `AutoHairWorks` (bool)
  - `StandbyRT` (bool)
  - `DebounceDelay` (float)
  - `ShowNotifications` (bool)

### 3. Hooks in Vanilla Files
- **`game/r4Game.ws`:**
  - Instantiates `CutscenePTManager` and `CutscenePTOptions` on game launch (`Init`).
  - Calls `cutscenePTManager.OnTick(timeDelta)` inside `OnTick`.
- **`game/scenes/scenePlayer.ws`:**
  - Calls `theGame.cutscenePTManager.OnCutsceneOrDialogueStart(...)` in `OnPlay` / `OnSceneStarted`.
  - Calls `theGame.cutscenePTManager.OnCutsceneOrDialogueEnd(...)` in `OnStop` / `OnSceneEnded`.
- **`game/gui/main_menu/ingamemenu/ingameMenu.ws`:**
  - Calls `theGame.cutscenePTOptions.ReadValues()` inside `SaveChangedSettings()` so option changes apply immediately without restarting.

### 4. Native Engine Annotations (Patch v4.04+ / REDkit)
Since June 2024, the REDengine supports annotations to reduce script merging conflicts:
- `@wrapMethod(ClassName)`: Wraps an existing method; must call `wrappedMethod(...)`. Chaining multiple wrappers is supported.
- `@addMethod(ClassName)`: Injects a new method into an existing class.
- `@replaceMethod(ClassName)`: Replaces a class method (or global function if class omitted).
- `@addField(ClassName)`: Injects a new member field into an existing class.

---

## 2. In-Game Config Wrapper & Graphics Switching

WitcherScript uses `CInGameConfigWrapper` to read and write runtime settings:
```ws
var configWrapper : CInGameConfigWrapper;
configWrapper = (CInGameConfigWrapper)theGame.GetInGameConfigWrapper();

// Read setting
var rtEnabled : bool;
rtEnabled = configWrapper.GetVarValue('Rendering/RT', 'RayTracingEnabled') == "true";

// Set setting temporarily or permanently
configWrapper.SetVarValue('Rendering/RT', 'RayTracingEnabled', "true");
theGame.ApplySettings(); // or theGame.SaveUserSettings();
```

---

## 3. Compiling and Validating Scripts

To verify that all scripts compile cleanly without syntax errors, run the game in batch compile mode:

```powershell
& "<Witcher3-Root>/bin/x64_dx12/witcher3.exe" -compileScripts
```

If compilation succeeds, the process exits cleanly (return code 0).
If there is an error, a modal error dialog will be written to `bin/x64_dx12/crash_*.log` or stderr.

Make sure to terminate any lingering processes afterward:
```powershell
Get-Process -Name "witcher3*" -ErrorAction SilentlyContinue | Stop-Process -Force
```
