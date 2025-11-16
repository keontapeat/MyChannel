#!/usr/bin/env python3
"""
Remove duplicate type definitions from View files
"""

import re
import os

def remove_section(content, start_pattern, end_pattern="^}"):
    """Remove a section from start pattern to first closing brace"""
    lines = content.split('\n')
    new_lines = []
    skip = False
    for line in lines:
        if re.match(start_pattern, line):
            skip = True
            continue
        if skip and re.match(end_pattern, line):
            skip = False
            continue
        if not skip:
            new_lines.append(line)
    return '\n'.join(new_lines)

files_to_fix = [
    ("MyChannel/Features/Ads/CampaignCreatorView.swift", [
        r"^enum CampaignStep",
        r"^enum CampaignObjective",
        r"^enum BidStrategy",
        r"^struct FlowLayout:"
    ]),
    ("MyChannel/Features/Ads/CreateCampaignView.swift", [
        r"^enum CampaignStep",
        r"^enum CampaignObjective",
        r"^enum BidStrategy"
    ]),
    ("MyChannel/Features/Monetization/CreatorMonetizationView.swift", [
        r"^enum TimePeriod",
        r"^struct EarningsDataPoint:"
    ]),
    ("MyChannel/Features/Monetization/CreatorRevenueDashboardView.swift", [
        r"^struct EarningsDataPoint:",
        r"^enum TimePeriod"
    ])
]

def fix_file(file_path, patterns):
    if not os.path.exists(file_path):
        print(f"⚠️  File not found: {file_path}")
        return False
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    original_len = len(content)
    
    for pattern in patterns:
        content = remove_section(content, pattern)
    
    # Clean up extra newlines
    content = re.sub(r'\n{3,}', '\n\n', content)
    
    if len(content) < original_len:
        with open(file_path, 'w') as f:
            f.write(content)
        print(f"✅ Fixed {file_path} (removed {original_len - len(content)} chars)")
        return True
    return False

print("🔥 Removing duplicate type definitions from View files...")
fixed_count = 0

for file_path, patterns in files_to_fix:
    if fix_file(file_path, patterns):
        fixed_count += 1

print(f"\n✅ Fixed {fixed_count}/{len(files_to_fix)} files")
