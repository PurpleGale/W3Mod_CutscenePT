# Release Packaging & Deployment Guide

This guide defines the packaging standards, archive directory hierarchy, and naming conventions for releases of **Dynamic Path Tracing For Cutscenes**.

---

## 1. Archive Naming Convention

The release zip must be saved in the parent directory and strictly named:
```
DynamicPathTracingForCutscenes_v<VERSION>.zip
```
Example: `DynamicPathTracingForCutscenes_v1.22.1.zip`

---

## 2. Archive Directory Structure

The archive must unpack cleanly into the root of the user's *The Witcher 3* installation directory (`The Witcher 3\`).

```
DynamicPathTracingForCutscenes_v<VERSION>.zip
├── bin/
│   ├── config/
│   │   └── r4game/
│   │       └── user_config_matrix/
│   │           └── pc/
│   │               └── modCutscenePT.xml
│   └── x64_dx12/
│       └── OptiScaler/
│           └── plugins/
│               └── CutsceneNR.asi
└── mods/
    └── modCutscenePT/
        └── content/
            ├── scripts/
            │   └── local/
            │       ├── CutscenePTHooks.ws
            │       ├── CutscenePTManager.ws
            │       └── CutscenePTOptions.ws
            ├── ar.w3strings
            ├── br.w3strings
            ├── cn.w3strings
            ├── cz.w3strings
            ├── de.w3strings
            ├── en.w3strings
            ├── es.w3strings
            ├── esmx.w3strings
            ├── fr.w3strings
            ├── hu.w3strings
            ├── it.w3strings
            ├── jp.w3strings
            ├── kr.w3strings
            ├── pl.w3strings
            ├── ru.w3strings
            ├── tr.w3strings
            ├── ua.w3strings
            └── zh.w3strings
```

> **Note on Exclusions:**
> - Do NOT include source CSV files (`localization/*.csv`) in the release zip.
> - Do NOT include decoder artifacts (`*.w3strings.csv`).
> - Do NOT include temporary scratch files or `.agents` guides in the release zip.

---

## 3. Automated Packaging Script (Python)

The mod version is defined in **one single place**: `GetCutscenePTVersion()` inside `content/scripts/local/CutscenePTOptions.ws`.
The packaging script `tools/package.py` automatically extracts this version and builds the release zip.

To package a release, simply run:
```powershell
python tools/package.py
```

The script extracts the version from `CutscenePTOptions.ws` and creates `DynamicPathTracingForCutscenes_v<VERSION>.zip` containing `bin/` and `mods/modCutscenePT/content/`.

---

## 4. Release Process & Rules (CRITICAL)

When creating a release (on GitHub and Nexus Mods):

1. **Strict Version Consistency:**
   - The release tag (`v<VERSION>`), release title (`v<VERSION>`), archive name (`DynamicPathTracingForCutscenes_v<VERSION>.zip`), and the version inside `GetCutscenePTVersion()` in `CutscenePTOptions.ws` **must match identically**.
   - Before triggering a release, verify `GetCutscenePTVersion()` matches the intended version.

2. **Automated Release Notes Only (No Hand-Written Text):**
   - The release description on GitHub **must not contain manually written free-form text**.
   - It must exclusively use GitHub's [automatically generated release notes](https://docs.github.com/en/repositories/releasing-projects-on-github/automatically-generated-release-notes) comparing against the previous release / tag.
   - When drafting or generating releases via GitHub Web UI or API, use the "Generate release notes" feature (or `generate_release_notes: true`).

3. **Automated CI/CD Pipeline & Git Release Commands:**
   - Any git tag matching `v*` pushed to GitHub triggers `.github/workflows/release.yml`.
   - The workflow automatically creates the GitHub Release, generates release notes from commit history, attaches the packaged `.zip`, and uploads the release to Nexus Mods.
   - **Step-by-step Git release workflow:**
     ```bash
     # 1. Verify and ensure working tree is clean and synced
     git status
     git pull origin main

     # 2. Verify that GetCutscenePTVersion() in CutscenePTOptions.ws matches <VERSION>

     # 3. Create annotated git tag
     git tag -a v<VERSION> -m "Release v<VERSION>"

     # 4. Push tag to GitHub (triggers CI/CD workflow automatically)
     git push origin v<VERSION>
     ```
   - The pipeline:
     1. Builds the release archive using `python tools/package.py .`.
     2. Generates release notes automatically and creates the GitHub Release with the zip asset attached.
     3. Uploads the new version archive directly to Nexus Mods using `Nexus-Mods/upload-action` (File ID `8072358`).

