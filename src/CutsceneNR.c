#include <windows.h>
#include <stdio.h>
#include <stdint.h>

static void** g_ppConfig = NULL;
static uint32_t g_enabledOffset = 0; // Master switch: "Enable Neural Rendering" (0x13A)
static uint32_t g_modelOffset = 0;   // Model switch:  "Apply the model" (0x11B8)
static BOOL g_initialized = FALSE;

static void LogToFile(const char* fmt, ...) {
    char buf[1024];
    va_list args;
    va_start(args, fmt);
    wvsprintfA(buf, fmt, args);
    va_end(args);

    OutputDebugStringA(buf);

    char logPath[MAX_PATH];
    if (GetModuleFileNameA(NULL, logPath, MAX_PATH)) {
        char* lastSlash = strrchr(logPath, '\\');
        if (lastSlash) *(lastSlash + 1) = '\0';
        lstrcatA(logPath, "CutsceneNR.log");
        FILE* f = fopen(logPath, "a");
        if (f) {
            SYSTEMTIME st;
            GetLocalTime(&st);
            fprintf(f, "[%02d:%02d:%02d.%03d] %s\n", st.wHour, st.wMinute, st.wSecond, st.wMilliseconds, buf);
            fclose(f);
        }
    }
}

__declspec(dllexport) void InitializeASI(void) {
    LogToFile("[CutsceneNR] ASI Plugin loaded into process");
}

static void LogEnvironmentDiagnostics(void) {
    // 1. Hardware GPU Name (Non-personal)
    DISPLAY_DEVICEA dd;
    ZeroMemory(&dd, sizeof(dd));
    dd.cb = sizeof(dd);
    char gpuName[128] = "Unknown GPU";
    if (EnumDisplayDevicesA(NULL, 0, &dd, 0)) {
        lstrcpynA(gpuName, dd.DeviceString, sizeof(gpuName));
    }
    LogToFile("[CutsceneNR] Hardware GPU: %s", gpuName);

    // 2. Scan active proxy/hook DLLs in process (Non-personal)
    static const char* hookModules[] = {
        "dxgi.dll",
        "d3d12.dll",
        "version.dll",
        "winmm.dll",
        "dbghelp.dll",
        "wininet.dll",
        "winhttp.dll",
        "dinput8.dll",
        "OptiScaler.dll"
    };

    for (int i = 0; i < sizeof(hookModules) / sizeof(hookModules[0]); i++) {
        HMODULE h = GetModuleHandleA(hookModules[i]);
        if (!h) continue;

        const char* tag = "System";
        uint8_t* base = (uint8_t*)h;
        IMAGE_DOS_HEADER* dos = (IMAGE_DOS_HEADER*)base;
        if (dos->e_magic == IMAGE_DOS_SIGNATURE) {
            IMAGE_NT_HEADERS* nt = (IMAGE_NT_HEADERS*)(base + dos->e_lfanew);
            if (nt->Signature == IMAGE_NT_SIGNATURE) {
                uint32_t modSize = nt->OptionalHeader.SizeOfImage;
                for (uint32_t j = 0; j + 11 < modSize && j < 0x2000000; j++) {
                    if (memcmp(base + j, "OptiScaler\0", 11) == 0) {
                        tag = "OptiScaler";
                        break;
                    }
                    if (memcmp(base + j, "ReShade\0", 8) == 0) {
                        tag = "ReShade";
                        break;
                    }
                }
            }
        }
        LogToFile("[CutsceneNR] Active Hook DLL: %s (%s, Base=%p)", hookModules[i], tag, h);
    }

    // 3. Game Folder Assets Check (Non-personal)
    char exePath[MAX_PATH];
    if (GetModuleFileNameA(NULL, exePath, MAX_PATH)) {
        char* lastSlash = strrchr(exePath, '\\');
        if (lastSlash) *(lastSlash + 1) = '\0';

        char dlssnrFile[MAX_PATH];
        lstrcpyA(dlssnrFile, exePath);
        lstrcatA(dlssnrFile, "nvngx_dlssnr.dll");
        BOOL hasDlssnr = (GetFileAttributesA(dlssnrFile) != INVALID_FILE_ATTRIBUTES);
        LogToFile("[CutsceneNR] DLSS-NR Model File (nvngx_dlssnr.dll): %s", hasDlssnr ? "Present" : "Missing");

        char iniFile[MAX_PATH];
        lstrcpyA(iniFile, exePath);
        lstrcatA(iniFile, "OptiScaler.ini");
        if (GetFileAttributesA(iniFile) != INVALID_FILE_ATTRIBUTES) {
            char valEnabled[32] = {0};
            char valPrecision[32] = {0};
            char valRunBefore[32] = {0};
            char valResidual[32] = {0};

            GetPrivateProfileStringA("DlssNr", "Enabled", "N/A", valEnabled, sizeof(valEnabled), iniFile);
            GetPrivateProfileStringA("DlssNr", "Precision", "N/A", valPrecision, sizeof(valPrecision), iniFile);
            GetPrivateProfileStringA("DlssNr", "RunBeforeSR", "N/A", valRunBefore, sizeof(valRunBefore), iniFile);
            GetPrivateProfileStringA("DlssNr", "ResidualAcrossRR", "N/A", valResidual, sizeof(valResidual), iniFile);

            LogToFile("[CutsceneNR] OptiScaler.ini [DlssNr]: Enabled=%s, Precision=%s, RunBeforeSR=%s, ResidualAcrossRR=%s",
                      valEnabled, valPrecision, valRunBefore, valResidual);

            if (lstrcmpA(valPrecision, "4") == 0 && strstr(gpuName, "50") == NULL) {
                LogToFile("[CutsceneNR] [DIAGNOSTIC NOTE] Precision=4 (NVFP4) requires RTX 50 GPU. If cutscenes freeze, set Precision=0 in OptiScaler.ini!");
            }
        } else {
            LogToFile("[CutsceneNR] OptiScaler.ini: Not found in executable directory");
        }
    }
}

static void FindOptiScalerOffsets(HMODULE hOpti) {
    if (!hOpti) return;

    uint8_t* base = (uint8_t*)hOpti;
    IMAGE_DOS_HEADER* dos = (IMAGE_DOS_HEADER*)base;
    if (dos->e_magic != IMAGE_DOS_SIGNATURE) return;

    IMAGE_NT_HEADERS* nt = (IMAGE_NT_HEADERS*)(base + dos->e_lfanew);
    if (nt->Signature != IMAGE_NT_SIGNATURE) return;

    IMAGE_SECTION_HEADER* sec = IMAGE_FIRST_SECTION(nt);
    uint8_t* textStart = NULL;
    uint32_t textSize = 0;

    for (WORD i = 0; i < nt->FileHeader.NumberOfSections; i++) {
        if (memcmp(sec[i].Name, ".text", 5) == 0) {
            textStart = base + sec[i].VirtualAddress;
            textSize = sec[i].Misc.VirtualSize;
            break;
        }
    }

    if (!textStart || !textSize) return;

    // 1. Dynamic Discovery of Config* singleton pointer
    for (uint32_t i = 0; i + 18 < textSize; i++) {
        if (textStart[i] == 0x48 && textStart[i+1] == 0x8B && textStart[i+2] == 0x05 &&
            textStart[i+7] == 0x48 && textStart[i+8] == 0x85 && textStart[i+9] == 0xC0 && textStart[i+10] == 0x75) {
            if (textStart[i+12] == 0xB9) {
                uint32_t allocSize = *(uint32_t*)(textStart + i + 13);
                if (allocSize > 0x1000) { // sizeof(Config) is ~0x2DD0
                    int32_t disp = *(int32_t*)(textStart + i + 3);
                    uint8_t* rip = textStart + i + 7;
                    g_ppConfig = (void**)(rip + disp);
                    break;
                }
            }
        }
    }

    // 2. Dynamic Discovery of "Enable Neural Rendering" (DlssNr.Enabled, offset ~0x13A)
    uint8_t* strEnabled = NULL;
    uint32_t modSize = nt->OptionalHeader.SizeOfImage;
    for (uint32_t i = 0; i + 24 < modSize; i++) {
        if (memcmp(base + i, "Enable Neural Rendering\0", 24) == 0) {
            strEnabled = base + i;
            break;
        }
    }
    if (strEnabled) {
        for (uint32_t i = 3; i + 7 < textSize; i++) {
            if (textStart[i-3] == 0x48 && textStart[i-2] == 0x8D && (textStart[i-1] == 0x0D || textStart[i-1] == 0x15)) {
                int32_t disp = *(int32_t*)(textStart + i);
                uint8_t* rip = textStart + i + 4;
                if (rip + disp == strEnabled) {
                    for (uint32_t j = i; j < i + 80 && j + 7 < textSize; j++) {
                        if (textStart[j] == 0x66 && textStart[j+1] == 0x89) {
                            uint8_t modrm = textStart[j+2];
                            if ((modrm & 0xC0) == 0x80) {
                                uint32_t off = *(uint32_t*)(textStart + j + 3);
                                if (off >= 0x40 && off <= 0x4000) {
                                    g_enabledOffset = off;
                                    break;
                                }
                            }
                        }
                    }
                    if (g_enabledOffset) break;
                }
            }
        }
    }

    // 3. Dynamic Discovery of "Apply the model" (DlssNr.Model, offset ~0x11B8)
    uint8_t* strModel = NULL;
    for (uint32_t i = 0; i + 16 < modSize; i++) {
        if (memcmp(base + i, "Apply the model\0", 16) == 0) {
            strModel = base + i;
            break;
        }
    }
    if (strModel) {
        for (uint32_t i = 3; i + 7 < textSize; i++) {
            if (textStart[i-3] == 0x48 && textStart[i-2] == 0x8D && (textStart[i-1] == 0x0D || textStart[i-1] == 0x15)) {
                int32_t disp = *(int32_t*)(textStart + i);
                uint8_t* rip = textStart + i + 4;
                if (rip + disp == strModel) {
                    for (uint32_t j = i; j < i + 80 && j + 7 < textSize; j++) {
                        if (textStart[j] == 0x66 && textStart[j+1] == 0x89) {
                            uint8_t modrm = textStart[j+2];
                            if ((modrm & 0xC0) == 0x80) {
                                uint32_t off = *(uint32_t*)(textStart + j + 3);
                                if (off >= 0x40 && off <= 0x4000) {
                                    g_modelOffset = off;
                                    break;
                                }
                            }
                        }
                    }
                    if (g_modelOffset) break;
                }
            }
        }
    }

    // Safety validation and Fallbacks
    if (!g_ppConfig)                                      g_ppConfig = (void**)((uintptr_t)hOpti + 0x18c0d80);
    if (!g_enabledOffset || g_enabledOffset > 0x4000)     g_enabledOffset = 0x13A;
    if (!g_modelOffset   || g_modelOffset   > 0x4000)     g_modelOffset = 0x11B8;

    LogToFile("[CutsceneNR] Scanner ready: Config*=%p, EnabledOffset=0x%X, ModelOffset=0x%X",
              g_ppConfig, g_enabledOffset, g_modelOffset);
    g_initialized = TRUE;
}

static HMODULE FindOptiScalerModule(void) {
    // Supports all proxy DLL names used by OptiScaler / DLSS 5 Manager
    static const char* candidateNames[] = {
        "dxgi.dll",
        "d3d12.dll",
        "version.dll",
        "winmm.dll",
        "dbghelp.dll",
        "wininet.dll",
        "winhttp.dll",
        "dinput8.dll",
        "OptiScaler.dll"
    };

    for (int i = 0; i < sizeof(candidateNames) / sizeof(candidateNames[0]); i++) {
        HMODULE hMod = GetModuleHandleA(candidateNames[i]);
        if (!hMod) continue;

        uint8_t* base = (uint8_t*)hMod;
        IMAGE_DOS_HEADER* dos = (IMAGE_DOS_HEADER*)base;
        if (dos->e_magic != IMAGE_DOS_SIGNATURE) continue;

        IMAGE_NT_HEADERS* nt = (IMAGE_NT_HEADERS*)(base + dos->e_lfanew);
        if (nt->Signature != IMAGE_NT_SIGNATURE) continue;

        uint32_t modSize = nt->OptionalHeader.SizeOfImage;
        for (uint32_t j = 0; j + 11 < modSize && j < 0x2000000; j++) {
            if (memcmp(base + j, "OptiScaler\0", 11) == 0) {
                LogToFile("[CutsceneNR] Identified OptiScaler in module: %s (%p)", candidateNames[i], hMod);
                return hMod;
            }
        }
    }
    return NULL;
}

static BOOL GetConfigPtr(char** ppOutConfig) {
    HMODULE hOpti = FindOptiScalerModule();
    if (!hOpti) return FALSE;

    if (!g_initialized) {
        FindOptiScalerOffsets(hOpti);
    }

    if (!g_ppConfig || IsBadReadPtr(g_ppConfig, sizeof(void*)) || !*g_ppConfig) return FALSE;

    char* pConfig = (char*)*g_ppConfig;
    uint32_t maxOff = (g_modelOffset > g_enabledOffset ? g_modelOffset : g_enabledOffset) + 4;
    if (IsBadReadPtr(pConfig, maxOff)) return FALSE;

    *ppOutConfig = pConfig;
    return TRUE;
}

static DWORD WINAPI WorkerThread(LPVOID param) {
    wchar_t userProfile[MAX_PATH];
    wchar_t settingsPath[MAX_PATH];
    FILETIME lastWriteTime = {0};
    int inSceneMode = 0;
    int wasEnabledBefore = 0;
    int wasModelBefore = 0;
    char buffer[65536];
    BOOL isOneDrive = FALSE;

    Sleep(2000);
    LogToFile("[CutsceneNR] Background monitor initialized");
    LogEnvironmentDiagnostics();

    if (GetEnvironmentVariableW(L"USERPROFILE", userProfile, MAX_PATH) == 0) {
        LogToFile("[CutsceneNR] Error: Failed to get USERPROFILE");
        return 0;
    }

    wsprintfW(settingsPath, L"%s\\Documents\\The Witcher 3\\dx12user.settings", userProfile);
    if (GetFileAttributesW(settingsPath) == INVALID_FILE_ATTRIBUTES) {
        wchar_t oneDrivePath[MAX_PATH];
        wsprintfW(oneDrivePath, L"%s\\OneDrive\\Documents\\The Witcher 3\\dx12user.settings", userProfile);
        if (GetFileAttributesW(oneDrivePath) != INVALID_FILE_ATTRIBUTES) {
            lstrcpyW(settingsPath, oneDrivePath);
            isOneDrive = TRUE;
        }
    }

    // Anonymized logging (no username or personal information leaked)
    LogToFile("[CutsceneNR] Watching settings at: <USERPROFILE>%s",
              isOneDrive ? "\\OneDrive\\Documents\\The Witcher 3\\dx12user.settings" : "\\Documents\\The Witcher 3\\dx12user.settings");

    while (1) {
        Sleep(25);

        HANDLE hFile = CreateFileW(
            settingsPath,
            GENERIC_READ,
            FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
            NULL,
            OPEN_EXISTING,
            FILE_ATTRIBUTE_NORMAL,
            NULL
        );

        if (hFile != INVALID_HANDLE_VALUE) {
            FILETIME ftWrite;
            if (GetFileTime(hFile, NULL, NULL, &ftWrite)) {
                if (CompareFileTime(&ftWrite, &lastWriteTime) != 0) {
                    DWORD bytesRead = 0;
                    lastWriteTime = ftWrite;

                    if (ReadFile(hFile, buffer, sizeof(buffer) - 1, &bytesRead, NULL) && bytesRead > 0) {
                        buffer[bytesRead] = '\0';

                        char* pConfig = NULL;
                        BOOL hasConfig = GetConfigPtr(&pConfig);

                        // 1. Entering cutscene / dialogue with Force ON
                        if (strstr(buffer, "CutsceneNR_Active=force_on") != NULL) {
                            if (!inSceneMode) {
                                inSceneMode = 1;
                                if (hasConfig) {
                                    wasEnabledBefore = (pConfig[g_enabledOffset + 1] && pConfig[g_enabledOffset]);
                                    wasModelBefore   = (pConfig[g_modelOffset + 1] && pConfig[g_modelOffset]);

                                    // Turn ON both Enable Neural Rendering (0x13A) AND Apply the model (0x11B8)
                                    pConfig[g_enabledOffset]     = 1; // Enabled = true
                                    pConfig[g_enabledOffset + 1] = 1; // has_value = true
                                    pConfig[g_modelOffset]       = 1; // Model = true
                                    pConfig[g_modelOffset + 1]   = 1; // has_value = true

                                    LogToFile("[CutsceneNR] Scene Started: DLSS-NR Force ON (Enabled=1, Model=1). PreScene(Enabled=%d, Model=%d)",
                                              wasEnabledBefore, wasModelBefore);
                                } else {
                                    LogToFile("[CutsceneNR] Warning: Scene Started (Force ON) but OptiScaler Config pointer is not valid");
                                }
                            }
                        }
                        // 2. Entering cutscene / dialogue with Force OFF
                        else if (strstr(buffer, "CutsceneNR_Active=force_off") != NULL) {
                            if (!inSceneMode) {
                                inSceneMode = 1;
                                if (hasConfig) {
                                    wasEnabledBefore = (pConfig[g_enabledOffset + 1] && pConfig[g_enabledOffset]);
                                    wasModelBefore   = (pConfig[g_modelOffset + 1] && pConfig[g_modelOffset]);

                                    pConfig[g_modelOffset]       = 0; // Model = false
                                    pConfig[g_modelOffset + 1]   = 1; // has_value = true

                                    LogToFile("[CutsceneNR] Scene Started: DLSS-NR Force OFF (Model=0). PreScene(Enabled=%d, Model=%d)",
                                              wasEnabledBefore, wasModelBefore);
                                } else {
                                    LogToFile("[CutsceneNR] Warning: Scene Started (Force OFF) but OptiScaler Config pointer is not valid");
                                }
                            }
                        }
                        // 3. Entering cutscene / dialogue with Keep Gameplay
                        else if (strstr(buffer, "CutsceneNR_Active=keep") != NULL) {
                            if (!inSceneMode) {
                                inSceneMode = 1;
                                if (hasConfig) {
                                    wasEnabledBefore = (pConfig[g_enabledOffset + 1] && pConfig[g_enabledOffset]);
                                    wasModelBefore   = (pConfig[g_modelOffset + 1] && pConfig[g_modelOffset]);
                                    LogToFile("[CutsceneNR] Scene Started: DLSS-NR Keep Gameplay (Enabled=%d, Model=%d)",
                                              wasEnabledBefore, wasModelBefore);
                                } else {
                                    LogToFile("[CutsceneNR] Warning: Scene Started (Keep) but OptiScaler Config pointer is not valid");
                                }
                            }
                        }
                        // 4. Exiting cutscene / dialogue back to normal gameplay
                        else if (strstr(buffer, "CutsceneNR_Active=gameplay") != NULL || strstr(buffer, "CutsceneNR_Active=false") != NULL) {
                            if (inSceneMode) {
                                inSceneMode = 0;
                                if (hasConfig) {
                                    // Restore both flags to exactly how they were in gameplay
                                    pConfig[g_enabledOffset]     = wasEnabledBefore ? 1 : 0;
                                    pConfig[g_enabledOffset + 1] = 1;
                                    pConfig[g_modelOffset]       = wasModelBefore ? 1 : 0;
                                    pConfig[g_modelOffset + 1]   = 1;

                                    LogToFile("[CutsceneNR] Scene Ended: Restored Gameplay (Enabled=%d, Model=%d)",
                                              wasEnabledBefore, wasModelBefore);
                                } else {
                                    LogToFile("[CutsceneNR] Warning: Scene Ended but OptiScaler Config pointer is not valid");
                                }
                            }
                        }
                    }
                }
            }
            CloseHandle(hFile);
        }
    }
    return 0;
}

BOOL WINAPI DllMain(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpvReserved) {
    if (fdwReason == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(hinstDLL);
        CreateThread(NULL, 0, (LPTHREAD_START_ROUTINE)WorkerThread, NULL, 0, NULL);
    }
    return TRUE;
}
