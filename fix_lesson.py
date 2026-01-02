import os

file_path = r'c:\Users\omarr\Downloads\D\doraty\lib\screens\lesson\lesson_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

print(f"Original line count: {len(lines)}")

# Find the start of the last class
start_index = -1
for i, line in enumerate(lines):
    if 'class LessonSliverAppBarDelegate' in line:
        start_index = i
        break

if start_index == -1:
    print("Could not find LessonSliverAppBarDelegate class")
    exit(1)

# Find the end of the class (naive brace counting or just looking for the end)
# Since we know it's the last class, we can just look for the compilation unit end.
# But let's be precise.
# We will just take the lines up to the closing brace of this class
# and one empty line.

# Recalculate end index based on braces
brace_count = 0
end_index = -1
found_start = False

for i in range(start_index, len(lines)):
    line = lines[i]
    brace_count += line.count('{')
    brace_count -= line.count('}')
    
    if brace_count > 0:
        found_start = True
    
    if found_start and brace_count == 0:
        end_index = i
        break

if end_index != -1:
    print(f"Detected end of class at line {end_index + 1}")
    new_lines = lines[:end_index+1]
    new_lines.append('\n') # Ensure one newline at EOF
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
    print(f"Truncated file to {len(new_lines)} lines.")
else:
    print("Could not find end of class balance.")
