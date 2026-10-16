# Modern REDkit & The Witcher 3 Modding Guide

This document captures architecture, tools, mechanisms, and best practices documented in the official CD PROJEKT RED REDkit Modding Guide (`https://cdprojektred.atlassian.net/wiki/spaces/W3REDkit/pages/6328234/Modding+Guide`).

---

## 1. Mod Architecture: Regular Mods vs. DLC Mods

Witcher 3 distinguishes between two primary forms of content additions:

### Regular Mods (`mods/mod<Name>/`)
- Modify or override existing vanilla assets and scripts (`content/scripts/`, `content/blob0.bundle`, etc.).
- Loaded alphabetically by folder name from `<Game>/mods/`.
  - Prefix convention: Folder **MUST** start with `mod` (e.g. `modCutscenePT`, `mod0000_MergedFiles`). Folders without the `mod` prefix are completely ignored by the engine.
  - Load order: Files loaded later alphabetically can override files loaded earlier (unless mod priority is configured via `mods.settings`).
- Script conflicts between different regular mods editing the same `.ws` files require Script Merger or WitcherScript annotations.

### DLC Mods (`dlc/dlc<Name>/`)
- Contain strictly **new** content, independent assets, and isolated additions.
- Require a `.reddlc` definition file in the root of the DLC folder.
- Separate and isolate packages so they do not conflict with base game bundles.
- Use **DLC Mounters** (`.reddlc`) to register new resources into engine systems without modifying vanilla files.

#### Key DLC Mounters:
| DLC Mounter | Purpose | Key Parameters |
|---|---|---|
| `CGameplayDLCMounter` | Basic scriptable DLC mounter (ideal for script-only standalone systems) | Script hooks |
| `CR4DefinitionsDLCMounter` | Loads definition XML files (items, abilities, recipes) | `definitionXmlFilePath` |
| `CR4DefinitionsEntitieTemplatesDLCMounter` | Loads entity templates referenced in definition XMLs | `entitieTemplatesDirectoryPath` |
| `CR4EntityExternalAppearanceDLCMounter` | Registers entity appearances & mesh replacements | `entityTemplatePaths`, `entityExternalAppearances` |
| `CR4EntityTemplateParamDLCMounter` | Adds template parameters to existing entities | `entityTemplatePaths`, `entityTemplateParams` |
| `CR4EntityTemplateSlotDLCMounter` | Adds attachment/bone slots to entities | `baseEntityTemplatePath`, `entityTemplatePaths`, `entityTemplateSlots` |
| `CR4JournalDLCMounter` / `CR4JournalEntriesDLCMounter` | Registers journal and quest entries | `journalDirectoryPath`, `journalEntriesFilePath` |
| `CR4MappinsDLCMounter` | Registers map pins and quest markers | `worldFilePath`, `mappinsFilePath`, `questMappinsFilePath` |
| `CR4QuestDLCMounter` | Starts a quest on game boot | `quest` |
| `CR4WorldDLCMounter` | Registers a brand-new game world/level | `worlds` |
| `CR4SceneAnimationsDLCMounter` | Registers custom scene body/mimic animations | `sceneAnimationsBodyFilePath`, `sceneAnimationsMimicsFilePath` |
| `CR4ScaleformContentDLCMounter` | Registers custom UI / flash SWF resources | `scaleformDirectoryPath` |
| `CR4AttitudesDLCMounter` | Registers faction/attitude tables | `attitudeGroupsTableFilePath`, `attitudesXMLFilePath` |

---

## 2. WitcherScript Overrides & Annotations (Engine v4.04+)

Since the June 6, 2024 update alongside REDkit, the engine natively supports **method and field annotations**. This eliminates the need to replace entire vanilla `.ws` files or rely on Script Merger for simple hooks.

### Available Annotations:

1. `@wrapMethod(ClassName)`
   - Wraps an existing method in `ClassName`.
   - Must match the original method's signature exactly.
   - **Must** call `wrappedMethod(...)` inside to pass execution to the original (or downstream wrapped) method.
   - Multiple mods wrapping the same method chain together cleanly based on load order.
   - Example:
     ```ws
     @wrapMethod(CR4Game)
     function OnTick(timeDelta : float)
     {
         wrappedMethod(timeDelta);
         theGame.cutscenePTManager.OnTick(timeDelta);
     }
     ```

2. `@addMethod(ClassName)`
   - Injects a brand-new method into an existing class.
   - Example:
     ```ws
     @addMethod(CR4Game)
     function GetCutscenePTManager() : CCutscenePTManager
     {
         return cutscenePTManager;
     }
     ```

3. `@replaceMethod(ClassName)` / `@replaceMethod`
   - Completely replaces an existing method in `ClassName`.
   - Without `ClassName`, replaces a global function.
   - Use sparingly, as only one mod can replace a given method without conflict.

4. `@addField(ClassName)`
   - Injects a new field/variable into an existing class.
   - Example:
     ```ws
     @addField(CR4Game)
     var cutscenePTManager : CCutscenePTManager;
     ```

---

## 3. Virtual Depot & Directory Hierarchy

REDkit virtualizes files by merging three physical directories into a single unified asset browser view:
1. **Workspace** (`<project>/workspace/`): User-created and modified files (highest priority).
2. **Uncooked data** (`<uncook>/`): Meshes, textures, and assets extracted from base game packages.
3. **r4data** (`<redkit>/r4data/`): Base engine assets and templates shipped with REDkit.

Resolution priority: **`workspace > uncook > r4data`**.

### Level-Only Assets Trap (Missing Meshes/Materials in Custom Worlds)
- Some base game meshes (`.w2mesh`) use Material Instances (`.w2mi`) bundled only with specific world levels (e.g. Skellige or Toussaint).
- Checking out an entity into a custom mod project copies the entity and mesh, but does **not** automatically pull referenced `.w2mi` files if they are level-bound.
- In-game result: Objects appear with missing textures, invisible walls, or see-through buildings.
- Fix: Inspect the entity's materials via the REDkit Scene panel (`Show resources` -> locate `.w2mesh` -> `Materials` tab) and explicitly check out referenced `.w2mi` files into the mod workspace.

---

## 4. String ID Spaces & Localization Collaboration

When collaborating on mods or adding new localized strings:
- String IDs in REDkit must be allocated within safe ID spaces to prevent collisions.
- Safe ID space range: **`10,000,000` to `0x7FFFFFFF - 1000`** (`10,000,000` to `2,147,482,647`).
- Mod Project Settings: Configure **Project ID space** start in `View > Settings > Mod Project Settings`.
- Collaboration convention: Split ID ranges among authors (e.g., Author A: `15000000–15004999`, Author B: `15005000–15009999`).
- Syncing strings: Use Localized Strings Editor to Export/Import `LocalEditorStringDataBaseW3_UTF8_mod_export.csv`.

---

## 5. Mod Distribution & Management

### Steam Workshop vs. Nexus Mods
- **Nexus Mods / Manual Install**: Placed into `<Game>/mods/mod<ModName>/` and `<Game>/dlc/dlc<ModName>/`.
- **Steam Workshop**:
  - Downloaded to Steam workshop cache directories (`steamapps/workshop/content/292030/<PublishedFileId>`).
  - Do **not** reside in `<Game>/mods/`.
  - When mixing manual mods and workshop subscriptions, watch out for load order and configuration precedence.
- **Publishing via REDkit**:
  - Requires connection to Steam Workshop client.
  - Packs mod/DLC bundles automatically based on folder layout.
  - Generates preview metadata and thumbnail.
