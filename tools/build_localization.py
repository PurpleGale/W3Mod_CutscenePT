import os, glob, subprocess

def hash_key(key: str) -> str:
    h = 0
    for c in key.lower():
        h = ((h * 31) + ord(c)) & 0xffffffff
    return f"{h:08x}"

# String definitions: (id_offset, key_str, ru_text, en_text, pl_text, de_text)
DEFINITIONS = [
    (0, "CutscenePT", "Кат-сцены: трассировка пути", "Cutscene Path Tracing", "Przerywniki filmowe: Path Tracing", "Zwischensequenzen: Path Tracing"),
    (1, "panel_CutscenePT", "Кат-сцены: трассировка пути", "Cutscene Path Tracing", "Przerywniki filmowe: Path Tracing", "Zwischensequenzen: Path Tracing"),
    (2, "CutscenePT_General", "Общие настройки", "General", "Ogólne", "Allgemein"),
    (3, "panel_CutscenePT_General", "Общие настройки", "General", "Ogólne", "Allgemein"),
    (4, "preset_CutscenePT_General", "Пресеты", "Presets", "Presety", "Voreinstellungen"),
    (5, "Mods.CutscenePT.CutscenePT_General", "Общие настройки", "General", "Ogólne", "Allgemein"),
    (6, "panel_Mods.CutscenePT.CutscenePT_General", "Общие настройки", "General", "Ogólne", "Allgemein"),
    (7, "CutscenePT_Dialogs", "Настройки диалогов", "Dialog Settings", "Ustawienia dialogów", "Dialogeinstellungen"),
    (8, "panel_CutscenePT_Dialogs", "Настройки диалогов", "Dialog Settings", "Ustawienia dialogów", "Dialogeinstellungen"),
    (9, "preset_CutscenePT_Dialogs", "Пресеты", "Presets", "Presety", "Voreinstellungen"),
    (10, "Mods.CutscenePT.CutscenePT_Dialogs", "Настройки диалогов", "Dialog Settings", "Ustawienia dialogów", "Dialogeinstellungen"),
    (11, "panel_Mods.CutscenePT.CutscenePT_Dialogs", "Настройки диалогов", "Dialog Settings", "Ustawienia dialogów", "Dialogeinstellungen"),
    (12, "CutscenePT_Cutscenes", "Настройки кат-сцен", "Cutscene Settings", "Ustawienia przerywników", "Zwischensequenzeinstellungen"),
    (13, "panel_CutscenePT_Cutscenes", "Настройки кат-сцен", "Cutscene Settings", "Ustawienia przerywników", "Zwischensequenzeinstellungen"),
    (14, "preset_CutscenePT_Cutscenes", "Пресеты", "Presets", "Presety", "Voreinstellungen"),
    (15, "Mods.CutscenePT.CutscenePT_Cutscenes", "Настройки кат-сцен", "Cutscene Settings", "Ustawienia przerywników", "Zwischensequenzeinstellungen"),
    (16, "panel_Mods.CutscenePT.CutscenePT_Cutscenes", "Настройки кат-сцен", "Cutscene Settings", "Ustawienia przerywników", "Zwischensequenzeinstellungen"),
    (17, "ModEnabled", "Включить модификацию", "Mod Enabled", "Włącz mod", "Mod aktivieren"),
    (18, "option_ModEnabled", "Включить модификацию", "Mod Enabled", "Włącz mod", "Mod aktivieren"),
    (19, "Dialog_Enabled", "Применять профиль диалогов", "Enable Dialog Profile", "Włącz profil dialogów", "Dialogprofil aktivieren"),
    (20, "option_Dialog_Enabled", "Применять профиль диалогов", "Enable Dialog Profile", "Włącz profil dialogów", "Dialogprofil aktivieren"),
    (21, "Cutscene_Enabled", "Применять профиль кат-сцен", "Enable Cutscene Profile", "Włącz profil przerywników", "Zwischensequenzprofil aktivieren"),
    (22, "option_Cutscene_Enabled", "Применять профиль кат-сцен", "Enable Cutscene Profile", "Włącz profil przerywników", "Zwischensequenzprofil aktivieren"),
    (27, "ShowNotifications", "Уведомления на экране", "Show HUD Notifications", "Powiadomienia na ekranie", "HUD-Benachrichtigungen anzeigen"),
    (28, "option_ShowNotifications", "Уведомления на экране", "Show HUD Notifications", "Powiadomienia na ekranie", "HUD-Benachrichtigungen anzeigen"),

    (31, "DLSS5_OptiScaler", "DLSS5 (OptiScaler)", "DLSS5 (OptiScaler)", "DLSS5 (OptiScaler)", "DLSS5 (OptiScaler)"),
    (32, "option_DLSS5_OptiScaler", "DLSS5 (OptiScaler)", "DLSS5 (OptiScaler)", "DLSS5 (OptiScaler)", "DLSS5 (OptiScaler)"),
    (39, "Msg_PTActive", "[Cutscene PT] Трассировка пути активна", "[Cutscene PT] Path Tracing Active", "[Cutscene PT] Path Tracing aktywny", "[Cutscene PT] Path Tracing aktiv"),
    (40, "Msg_PTRestored", "[Cutscene PT] Освещение геймплея восстановлено", "[Cutscene PT] Gameplay Lighting Restored", "[Cutscene PT] Przywrócono oświetlenie rozgrywki", "[Cutscene PT] Gameplay-Beleuchtung wiederhergestellt"),
    (41, "preset_Mods_CutscenePT_CutscenePT", "Пресеты", "Presets", "Presety", "Voreinstellungen"),
    (42, "preset_Mods_CutscenePT_CutscenePT_Dialogs", "Пресеты", "Presets", "Presety", "Voreinstellungen"),
    (43, "preset_Mods_CutscenePT_CutscenePT_Cutscenes", "Пресеты", "Presets", "Presety", "Voreinstellungen"),
    (44, "preset_Mods.CutscenePT.CutscenePT_Dialogs", "Пресеты", "Presets", "Presety", "Voreinstellungen"),
    (45, "preset_Mods.CutscenePT.CutscenePT_Cutscenes", "Пресеты", "Presets", "Presety", "Voreinstellungen"),
    (46, "PRESET_VALUE_0", "Полная трассировка пути", "Full Path Tracing", "Pełny Path Tracing", "Vollständiges Path Tracing"),
    (47, "PRESET_VALUE_1", "Минимальная трассировка пути", "Minimal Path Tracing", "Minimalny Path Tracing", "Minimales Path Tracing"),
    (48, "PRESET_VALUE_2", "Полная трассировка лучей", "Full Ray Tracing", "Pełny Ray Tracing", "Vollständiges Ray Tracing"),
    (49, "PRESET_VALUE_PresetFullPT", "Полная трассировка пути", "Full Path Tracing", "Pełny Path Tracing", "Vollständiges Path Tracing"),
    (50, "PRESET_VALUE_PresetPTGI", "Минимальная трассировка пути", "Minimal Path Tracing", "Minimalny Path Tracing", "Minimales Path Tracing"),
    (51, "PRESET_VALUE_PresetFullRT", "Полная трассировка лучей", "Full Ray Tracing", "Pełny Ray Tracing", "Vollständiges Ray Tracing"),
    (52, "preset_value_PresetFullPT", "Полная трассировка пути", "Full Path Tracing", "Pełny Path Tracing", "Vollständiges Path Tracing"),
    (53, "preset_value_PresetPTGI", "Минимальная трассировка пути", "Minimal Path Tracing", "Minimalny Path Tracing", "Minimales Path Tracing"),
    (54, "preset_value_PresetFullRT", "Полная трассировка лучей", "Full Ray Tracing", "Pełny Ray Tracing", "Vollständiges Ray Tracing"),
]

BASE_ID = 2117592000

ALL_LANGS = [
    "ar", "br", "cn", "cz", "de", "en", "es", "esmx", "fr",
    "hu", "it", "jp", "kr", "pl", "ru", "tr", "ua", "zh"
]

def get_text_for_lang(item, lang):
    _, _, ru_text, en_text, pl_text, de_text = item
    if lang == "ru": return ru_text
    if lang == "pl": return pl_text
    if lang == "de": return de_text
    if lang == "ua":
        if "Кат-сцены" in ru_text: return ru_text.replace("Кат-сцены", "Кат-сцени").replace("трассировка пути", "трасування шляху")
        if "Настройки диалогов" in ru_text: return "Налаштування діалогів"
        if "Настройки кат-сцен" in ru_text: return "Налаштування кат-сцен"
        if "Общие настройки" in ru_text: return "Загальні налаштування"
        if "Включить модификацию" in ru_text: return "Увімкнути модифікацію"
        if "Применять профиль диалогов" in ru_text: return "Застосовувати профіль діалогів"
        if "Применять профиль кат-сцен" in ru_text: return "Застосовувати профіль кат-сцен"
        if "Генерация кадров" in ru_text: return "Генерація кадрів"
        if "Как в игре" in ru_text: return "Як у грі"
        if "Принудительно выкл." in ru_text: return "Примусово вимк."
        if "Принудительно вкл." in ru_text: return "Примусово увімк."
        if "Уведомления на экране" in ru_text: return "Сповіщення на екрані"
        if "Трассировка пути активна" in ru_text: return "[Cutscene PT] Трасування шляху активне"
        if "Освещение геймплея" in ru_text: return "[Cutscene PT] Освітлення геймплею відновлено"
        return ru_text
    return en_text

tools_dir = os.path.dirname(os.path.abspath(__file__))
mod_root = os.path.dirname(tools_dir)
loc_dir = os.path.join(mod_root, "localization")
content_dir = os.path.join(mod_root, "content")
os.makedirs(loc_dir, exist_ok=True)
os.makedirs(content_dir, exist_ok=True)

for lang in ALL_LANGS:
    csv_path = os.path.join(loc_dir, f"{lang}.csv")
    with open(csv_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(f";meta[language={lang}]\n")
        f.write("; id      |key(hex)|key(str)| text\n")
        for item in DEFINITIONS:
            idx = BASE_ID + item[0]
            kstr = item[1]
            khex = hash_key(kstr)
            txt = get_text_for_lang(item, lang)
            f.write(f"{idx}|{khex}|{kstr}|{txt}\n")

script_path = os.path.join(tools_dir, "w3strings_nextgen.py")
for lang in ALL_LANGS:
    csv_path = os.path.join(loc_dir, f"{lang}.csv")
    out_w3 = os.path.join(content_dir, f"{lang}.w3strings")
    cmd = ["python", script_path, "-e", csv_path, "-o", out_w3]
    subprocess.run(cmd, check=True)

print("All 18 languages compiled successfully!")
