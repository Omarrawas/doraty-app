import os
import re

lib_dir = 'g:/تطبيقات برمجة/D/doraty-app/lib'
import_statement = "import '../utils/safe_parser.dart';\n"
import_statement_models = "import '../core/utils/safe_parser.dart';\n"

count = 0
for root, _, files in os.walk(lib_dir):
    for file in files:
        if file.endswith('.dart'):
            path = os.path.join(root, file)
            with open(path, 'r', encoding='utf-8') as f:
                content = f.read()

            new_content = re.sub(r'List\s*<\s*Map\s*<\s*String\s*,\s*dynamic\s*>\s*>\s*\.\s*from\s*\(', 'SafeParser.safeMapList(', content)

            if new_content != content:
                print(f'Patching {path}')
                if 'safe_parser.dart' not in new_content:
                    lines = new_content.split('\n')
                    last_import_idx = -1
                    for i, line in enumerate(lines):
                        if line.startswith('import '):
                            last_import_idx = i
                    
                    imp = import_statement if 'services' in path or 'screens' in path else import_statement_models
                    if 'database_service.dart' in path: imp = "import '../utils/safe_parser.dart';\n"
                    
                    if last_import_idx != -1:
                        lines.insert(last_import_idx + 1, imp.strip())
                    else:
                        lines.insert(0, imp.strip())
                    new_content = '\n'.join(lines)
                
                with open(path, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                count += 1

print(f'Done patching {count} files.')
