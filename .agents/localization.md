# Localization & W3Strings Guide for The Witcher 3

This guide details how strings work in *The Witcher 3: Wild Hunt* (Next-Gen v4.04+), how to avoid menu collisions, and how to encode/decode `.w3strings` binaries.

---

## 1. Architecture of In-Game Strings

Strings in The Witcher 3 are identified by:
1. **String ID** (32-bit integer, e.g. `2117592000`). Modders usually use a high unique prefix like `211759xxxx`.
2. **Key Hash** (32-bit unsigned hex integer, e.g. `0xbfd5030e`). This is calculated from a string key using a custom 31-multiplier hash algorithm (case-insensitive).
3. **Key String** (text name, e.g. `CutscenePT`, `option_ModEnabled`).
4. **Text Content** (localized UTF-8 text).

### How REDengine Calculates Hashes:
```python
def hash_key(key: str) -> int:
    h = 0
    for c in key.lower():
        h = ((h * 31) + ord(c)) & 0xffffffff
    return h
```

---

## 2. In-Game Menu Navigation & Group Resolution

When a group is defined in `modCutscenePT.xml`:
```xml
<Group id="CutscenePTMain" displayName="Mods.CutscenePT.CutscenePT_General">
```
The game engine (`igmOptions.ws` -> `IngameMenu_FetchAndGenerateGroupMenuObject`) parses `displayName` by splitting on dots (`.`):
1. Element 1: `Mods` -> Looks up key `panel_Mods` (`0x4d5f8b0c`) -> "Модификации" / "Mods".
2. Element 2: `CutscenePT` -> Looks up key `panel_CutscenePT` (`0x2297a429`) -> "КАТ-СЦЕНЫ: ТРАССИРОВКА ПУТИ" / "Cutscene Path Tracing".
3. Element 3: `CutscenePT_General` -> Looks up key `panel_CutscenePT_General` (`0xb9721ad2`) -> "Общие настройки" / "General".

### ⚠️ The `panel_` Collision Trap (CRITICAL)
- The game automatically prepends `panel_` to the last token of the dot-separated string to get the sidebar tab label:
  `GetLocStringByKeyExt("panel_" + currentSubMenuName)`
- **DO NOT** name the group token `General` (e.g. `Mods.CutscenePT.General`):
  - It results in the lookup key `panel_General` (hash `0xb38875ad`).
  - **`0xb38875ad` is the vanilla game's internal key for the "Graphics" ("Графика") tab in `Settings > Video`!**
  - Defining `panel_General` in any mod will overwrite the vanilla "Graphics" button in the main game settings.
- **Rule:** Always prefix or uniquely namespace the subcategory token, e.g. `Mods.CutscenePT.CutscenePT_General` (`panel_CutscenePT_General`).

---

## 3. Supported Languages (18 total)

The mod includes full translations for all 18 supported Witcher 3 locales:
- `ar` — Arabic
- `br` — Brazilian Portuguese
- `cn` — Simplified Chinese
- `cz` — Czech
- `de` — German
- `en` — English
- `es` — Spanish (Castilian)
- `esmx` — Spanish (Latin America)
- `fr` — French
- `hu` — Hungarian
- `it` — Italian
- `jp` — Japanese
- `kr` — Korean
- `pl` — Polish
- `ru` — Russian
- `tr` — Turkish
- `ua` — Ukrainian
- `zh` — Traditional Chinese

---

## 4. Encoding `.w3strings` Files

We use `localization/w3strings_nextgen.py` (Next-Gen Version 164 compatible encoder).

### Command to Encode a Single File:
```bash
python localization/w3strings_nextgen.py -e localization/en.csv -o content/en.w3strings
```

### Python Script to Batch Encode All 18 Languages:
```python
import glob, os, subprocess

csv_files = glob.glob('localization/*.csv')
for f in csv_files:
    if 'en.csv.w3strings' in f or 'w3strings.csv' in f:
        continue
    lang = os.path.splitext(os.path.basename(f))[0]
    out_file = f'content/{lang}.w3strings'
    subprocess.run(['python', 'localization/w3strings_nextgen.py', '-e', f, '-o', out_file], check=True)
```

### Decoding for Verification:
```bash
python localization/w3strings_nextgen.py -d content/en.w3strings
```
