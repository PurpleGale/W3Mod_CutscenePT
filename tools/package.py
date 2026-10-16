import zipfile, os, re

tools_dir = os.path.dirname(os.path.abspath(__file__))
base_dir = os.path.dirname(tools_dir)

# 1. Automatically extract version from single source of truth (CutscenePTOptions.ws)
options_path = os.path.join(base_dir, 'content', 'scripts', 'local', 'CutscenePTOptions.ws')
with open(options_path, 'r', encoding='utf-8') as f:
    content = f.read()

match = re.search(r'function\s+GetCutscenePTVersion\s*\(\)\s*:\s*string\s*\{\s*return\s*"([^"]+)";', content)
if not match:
    raise RuntimeError("Failed to extract version from CutscenePTOptions.ws (GetCutscenePTVersion)!")

version = match.group(1)
print(f"Detected mod version from CutscenePTOptions.ws: v{version}")

output_dir = os.path.dirname(base_dir)
archive_path = os.path.join(output_dir, f"DynamicPathTracingForCutscenes_v{version}.zip")

if os.path.exists(archive_path):
    os.remove(archive_path)

with zipfile.ZipFile(archive_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
    # 1. bin folder
    bin_dir = os.path.join(base_dir, 'bin')
    for root, dirs, files in os.walk(bin_dir):
        for f in files:
            full_path = os.path.join(root, f)
            rel_path = os.path.relpath(full_path, base_dir)
            zipf.write(full_path, rel_path)
            
    # 2. mods/modCutscenePT/content folder
    content_dir = os.path.join(base_dir, 'content')
    for root, dirs, files in os.walk(content_dir):
        for f in files:
            if f.endswith('.csv'):
                continue
            full_path = os.path.join(root, f)
            rel_in_content = os.path.relpath(full_path, content_dir)
            arcname = os.path.join('mods', 'modCutscenePT', 'content', rel_in_content)
            zipf.write(full_path, arcname)

print(f"Archive successfully created: {archive_path}")
