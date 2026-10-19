# Contributing Guidelines

This document outlines the workflow, coding standards, and architectural conventions for developers and AI coding assistants contributing to **Dynamic Path Tracing For Cutscenes**.

---

## 1. Environment & Path Standards

- **No Machine-Specific Paths:** Never commit hardcoded local filesystem paths (e.g., personal drive letters, user folder paths, or machine-specific steam directories).
- Always reference paths relatively or with clear portable placeholders:
  - Repository Root: `<Repo-Root>`
  - Game Directory: `<Witcher3-Root>`
  - Deployed Mod: `<Witcher3-Root>/mods/modCutscenePT/`
  - Deployed XML: `<Witcher3-Root>/bin/config/r4game/user_config_matrix/pc/modCutscenePT.xml`
- Run tools from repository root using relative paths:
  ```powershell
  python tools/build_localization.py
  python tools/package.py
  ```

---

## 2. WitcherScript Architecture & Rules

- **Native Annotations Only:**
  - Never replace or overwrite vanilla game `.ws` files.
  - Use REDengine annotations (`@addField`, `@wrapMethod`, `@addMethod`) to cleanly extend game classes (`CR4Game`, `CStoryScenePlayer`, `CR4IngameMenu`).
  - Always call `wrappedMethod(...)` inside `@wrapMethod`.
- **WitcherScript Instantiation Syntax:**
  - Dynamic allocations must use `new ClassName in parent;` without parentheses.
- **Debounce Protection:**
  - Ensure cutscene/dialogue transitions maintain a debounce timer to avoid rapid toggling when players skip dialogue lines with the Spacebar.

---

## 3. Localization Standards

- **Zero Hash Collision Policy:**
  - Never use generic string keys such as `General`, `panel_General`, `Graphics`, or `Video`.
  - Always prefix custom keys with `CutscenePT_` or `Msg_PT` to prevent collisions with vanilla REDengine string hashes.
- **18-Language Support:**
  - Localizations are defined in `tools/build_localization.py` and exported to `localization/*.csv`.
  - Binary `.w3strings` are compiled into `content/`.

---

## 4. Packaging & Releases

- **Version Management:**
  - The mod version is maintained in a single source of truth: `GetCutscenePTVersion()` inside `content/scripts/local/CutscenePTOptions.ws`.
  - The version strictly follows Semantic Versioning `a.b.c` (`Major.Minor.Patch`, e.g. `1.33.1`):
    - `Major` (`a`): Breaking changes or engine redesigns.
    - `Minor` (`b`): New features, menu options, or functional additions.
    - `Patch` (`c`): Bug fixes, logger improvements, debouncing fixes, or localization updates.
  - Release archives are created with:
    ```powershell
    python tools/package.py
    ```
- **Archive Cleanliness:**
  - Release archives must contain only `bin/` and `mods/modCutscenePT/content/`.
  - Source CSV files, development scripts, and temporary files must never be packaged into release distributions.

---

## 5. Pre-Commit Verification Checklist

Before committing changes:
1. Verify that scripts compile cleanly without errors:
   ```powershell
   & "<Witcher3-Root>/bin/x64_dx12/witcher3.exe" -compileScripts
   ```
2. Verify that lingering compiler processes are stopped.
3. Verify that `tools/build_localization.py` and `tools/package.py` execute cleanly.
4. Ensure no machine-specific absolute paths or temporary build artifacts are committed.

---

## 6. Git Commit Standards (Conventional Commits Only)

All git commit messages must strictly adhere to the **Conventional Commits** format:
```
<type>[optional scope]: <description>
```

- **Allowed Types:**
  - `feat`: A new feature or capability (e.g. `feat(plugin): support winmm, version, dbghelp proxy DLLs`)
  - `fix`: A bug fix (e.g. `fix(scanner): correct offset boundary check`)
  - `docs`: Documentation updates (e.g. `docs(agents): add conventional commits rule`)
  - `refactor`: Code changes that neither fix a bug nor add a feature
  - `perf`: Performance improvements
  - `chore`: Maintenance, version bumps, or tooling tasks (e.g. `chore(release): bump version to 1.33`)
  - `build`: Changes affecting build scripts or external dependencies
- Never commit with unstructured, generic, or non-conventional messages.

