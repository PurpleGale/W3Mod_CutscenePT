# Dynamic Path Tracing For Cutscenes — AI Assistant Guide

This document is the central entry point and reference for AI coding assistants working on the **Dynamic Path Tracing For Cutscenes** mod for *The Witcher 3: Wild Hunt* (Next-Gen v5.00+).

---

## 1. Project Overview & Architecture

The mod dynamically switches ray tracing / path tracing settings in *The Witcher 3* during cutscenes and dialogue sequences, restoring normal gameplay settings when the scene concludes.

### Key Directories
- `bin/config/r4game/user_config_matrix/pc/modCutscenePT.xml` — Options menu configuration (groups, presets, sliders, toggles).
- `content/scripts/` — WitcherScript codebase:
  - `local/CutscenePTManager.ws` — Core runtime manager controlling transitions, debounce timers, RT toggling, and notifications.
  - `local/CutscenePTOptions.ws` — Reads and holds user menu settings from `user.settings`.
  - `local/CutscenePTHooks.ws` — Modern WitcherScript annotations (@addField, @wrapMethod) hooking into CR4Game, CStoryScenePlayer, and CR4IngameMenu without overriding vanilla files.
- `localization/` — Localization source CSVs (18 languages).
- `content/` — Compiled game package content:
  - `content/*.w3strings` — Binary localization strings.
  - `content/scripts/local/` — Scripts directory deployed to the game.
- `tools/` — Standalone development tooling:
  - `tools/build_localization.py` — Localization CSV and w3strings compiler.
  - `tools/w3strings_nextgen.py` — Low-level binary w3strings encoder/decoder engine.
  - `tools/package.py` — Release zip packaging script.
- `.agents/` — Assistant documentation and workflow guides:
  - `GEMINI.md` — This master guide.
  - `packaging.md` — Building release zips, folder structures, naming conventions.
  - `CONTRIBUTING.md` — Contribution guidelines and development standards.
  - `witcherscript.md` — WitcherScript engine guidelines and hooks.
  - `localization.md` — Working with w3strings, CSVs, hashing, avoiding collisions.

---

## 2. Core Workflow & Rules

1. **Working Environments & Paths:**
   - Workspace Repository: `<Repo-Root>`
   - Deployed Mod Directory: `<Witcher3-Root>/mods/modCutscenePT/`
   - Deployed Config Menu: `<Witcher3-Root>/bin/config/r4game/user_config_matrix/pc/modCutscenePT.xml`

2. **Always Keep Deployed & Repo Copies Synced:**
   - Whenever scripts or `.w3strings` are modified, make sure they are updated both in repository source and deployed to `<Witcher3-Root>/mods/modCutscenePT/`.
   - Update `modCutscenePT.xml` in both repository and the game's `bin/config/...` folder.

3. **Verify Script Compilation:**
   - Run compilation check using:
     ```powershell
     & "<Witcher3-Root>/bin/x64_dx12/witcher3.exe" -compileScripts
     ```
   - Ensure the process terminates or kill lingering compiler instances with `Stop-Process -Name "witcher3" -Force`.

4. **Localization Safety Rule (CRITICAL):**
   - **Never** use generic keys like `General`, `panel_General`, `Graphics`, or `Video`.
   - The REDengine hash `0xb38875ad` corresponds to vanilla `panel_general` (`Settings > Video > Graphics`). Colliding with it will break the native game menu.
   - Refer to [.agents/localization.md](localization.md) for hashing rules and namespace patterns.

5. **Packaging:**
   - Always archive releases following the exact structure and filename specified in [.agents/packaging.md](packaging.md).
   - Use `python tools/package.py` to create the release archive.
