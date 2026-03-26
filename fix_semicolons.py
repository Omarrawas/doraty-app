import os
import re

lib_dir = r"c:\Users\omarr\OneDrive\Desktop\doraty-app\lib"

# Matches `context.push('/some_route')` that lacks a semicolon
pattern = re.compile(r"context\.push\('[^']+'\)(?!\s*;)")

def fix_semicolon(match):
    return match.group(0) + ";"

modified_files_count = 0

for root, dirs, files in os.walk(lib_dir):
    for filename in files:
        if filename.endswith(".dart"):
            filepath = os.path.join(root, filename)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            new_content = pattern.sub(fix_semicolon, content)
            
            if new_content != content:
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                modified_files_count += 1

print(f"Fixed semicolons in {modified_files_count} files!")
