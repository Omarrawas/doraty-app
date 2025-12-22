
import os

file_path = r'c:\Users\omarr\Downloads\D\doraty\lib\screens\lesson\lesson_screen.dart'

try:
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find the last closing brace
    last_brace_index = content.rfind('}')

    if last_brace_index != -1:
        # Keep everything up to the last brace
        new_content = content[:last_brace_index+1] + '\n'
        
        # Verify it looks reasonable (not empty)
        if len(new_content) > 100:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print("Successfully truncated file after last closing brace.")
        else:
            print("Content too short, something is wrong.")
    else:
        print("No closing brace found.")

except Exception as e:
    print(f"Error: {e}")
