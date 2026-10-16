# Build & Localization Tooling

This directory contains standalone Python development utilities used to generate localizations and package release archives for **Dynamic Path Tracing For Cutscenes**.

---

## Tool Overview

### 1. `build_localization.py` — Localization Builder
- **Purpose:** Manages translations across 18 supported languages, updates CSV sources in `localization/`, and compiles binary `.w3strings` into `content/`.
- **Usage:**
  ```powershell
  python tools/build_localization.py
  ```

---

### 2. `w3strings_nextgen.py` — Binary W3Strings Engine
- **Purpose:** Low-level encoder and decoder for The Witcher 3 Next-Gen binary string files (`.w3strings`, version 164).
- **Usage:**
  ```powershell
  # Encode a CSV into binary w3strings
  python tools/w3strings_nextgen.py --encode localization/en.csv -l en -o content/en.w3strings

  # Decode binary w3strings back to CSV
  python tools/w3strings_nextgen.py --decode content/en.w3strings -l en -o localization/en.csv
  ```

---

### 3. `package.py` — Release Packager
- **Purpose:** Builds a distribution-ready `.zip` archive formatted for direct drag-and-drop installation into The Witcher 3 root directory.
- **How it works:**
  - Reads the mod version directly from `GetCutscenePTVersion()` in `content/scripts/local/CutscenePTOptions.ws`.
  - Packages `bin/` and `mods/modCutscenePT/content/`.
  - Filters out development files, source CSVs, and python caches.
  - Generates `DynamicPathTracingForCutscenes_v<VERSION>.zip` in the parent directory.
- **Usage:**
  ```powershell
  python tools/package.py
  ```
