import os, re
root = 'd:/Proyectos_Flutter/Aplicativo_Personal'

packages = ['core', 'data', 'domain']

files_fixed = 0

for sub_dir in ['apps', 'packages']:
    for dirpath, _, filenames in os.walk(os.path.join(root, sub_dir)):
        if '.git' in dirpath or '.dart_tool' in dirpath or 'build' in dirpath or 'android' in dirpath or 'ios' in dirpath or 'windows' in dirpath or 'linux' in dirpath or 'macos' in dirpath: continue
        for filename in filenames:
            if filename.endswith('.dart'):
                filepath = os.path.join(dirpath, filename)
                try:
                    with open(filepath, 'r', encoding='utf-8') as f:
                        content = f.read()
                except:
                    continue

                orig_content = content
                for pkg in packages:
                    # we must use single quotes typically used in imports
                    pattern = r"package:" + pkg + r"/src/[^\']+\.dart"
                    replacement = "package:" + pkg + "/" + pkg + ".dart"
                    content = re.sub(pattern, replacement, content)
                
                if content != orig_content:
                    with open(filepath, 'w', encoding='utf-8') as f:
                        f.write(content)
                    files_fixed += 1

print(f'Fixed {files_fixed} files.')
