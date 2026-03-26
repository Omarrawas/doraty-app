import os
import re
from collections import Counter

lib_dir = r"c:\Users\omarr\OneDrive\Desktop\doraty-app\lib"
screens = []

# match builder: (context) => ScreenName(
# or builder: (_) => ScreenName(
pattern = re.compile(r'builder:\s*\([^)]*\)\s*=>\s*([A-Za-z0-9_]+)\s*\(')

for root, dirs, files in os.walk(lib_dir):
    for filename in files:
        if filename.endswith(".dart"):
            with open(os.path.join(root, filename), 'r', encoding='utf-8') as f:
                content = f.read()
                matches = pattern.findall(content)
                screens.extend(matches)

counter = Counter(screens)
for screen, count in counter.most_common():
    print(f"{screen}: {count}")
