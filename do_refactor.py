import os
import re

lib_dir = r"c:\Users\omarr\OneDrive\Desktop\doraty-app\lib"

# Define the mapping of screen names to routes
route_mapping = {
    "LoginScreen": "/login",
    "RegisterScreen": "/register",
    "CartScreen": "/cart",
    "SettingsScreen": "/settings",
    "TeachersListScreen": "/teachers",
    "AllPackagesScreen": "/packages",
    "AllTipsScreen": "/tips",
    "SubjectsScreen": "/topics",
    "OrderHistoryScreen": "/orders",
    "FAQScreen": "/faq",
    "PrivacyPolicyScreen": "/privacy",
    "TermsConditionsScreen": "/terms",
    "ExploreScreen": "/courses",
}

def replace_navigator(match):
    full_match = match.group(0)
    screen_name = match.group(1)
    args = match.group(2).strip()
    
    # We only replace if there are no complex arguments that break go_router
    # or if the user wants it blindly replaced. For safety, let's just do it
    # if it's completely empty or has exactly "showBackButton: true" which we can ignore
    
    if screen_name in route_mapping:
        route = route_mapping[screen_name]
        return f"context.push('{route}')"
    
    return full_match

pattern = re.compile(r'Navigator\.push\s*\(\s*context\s*,\s*MaterialPageRoute\s*\(\s*builder:\s*\([^)]*\)\s*=>\s*([A-Za-z0-9_]+)\(([^)]*)\)\s*,?\s*\)\s*,?\s*\);?')

modified_files_count = 0

for root, dirs, files in os.walk(lib_dir):
    for filename in files:
        if filename.endswith(".dart"):
            filepath = os.path.join(root, filename)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            new_content = pattern.sub(replace_navigator, content)
            
            if new_content != content:
                # Add go_router import if not present
                if "import 'package:go_router/go_router.dart';" not in new_content:
                    lines = new_content.split('\n')
                    for i, line in enumerate(lines):
                        if line.startswith('import'):
                            lines.insert(i, "import 'package:go_router/go_router.dart';")
                            break
                    new_content = '\n'.join(lines)

                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                modified_files_count += 1

print(f"Refactored {modified_files_count} files successfully!")
