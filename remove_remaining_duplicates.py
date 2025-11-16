#!/usr/bin/env python3
"""
Remove remaining duplicate type definitions
"""

import re
import os

def remove_lines_between(content, start_pattern, end_pattern):
    """Remove lines from start pattern to end pattern (inclusive)"""
    lines = content.split('\n')
    new_lines = []
    skip = False
    brace_count = 0
    
    for line in lines:
        if re.search(start_pattern, line) and not skip:
            skip = True
            brace_count = line.count('{') - line.count('}')
            continue
        
        if skip:
            brace_count += line.count('{') - line.count('}')
            if brace_count <= 0:
                skip = False
            continue
        
        new_lines.append(line)
    
    return '\n'.join(new_lines)

files = {
    "MyChannel/Features/LiveStreaming/Components/AwardsComponents.swift": [
        r"struct ShimmerModifier",
        r"func shimmer\(\)"
    ],
    "MyChannel/Features/University/Components/ShimmerLoadingViews.swift": [
        r"struct ShimmerModifier",
        r"func shimmer\(\)"
    ],
    "MyChannel/Features/Gaming/MatchResultSubmissionView.swift": [
        r"struct ImagePicker"
    ],
    "MyChannel/Features/Search/SearchView.swift": [
        r"struct ImagePicker"
    ],
    "MyChannel/Features/Upload/UploadView.swift": [
        r"struct ImagePicker"
    ],
    "MyChannel/Features/Stories/FacebookParityStoryEngine.swift": [
        r"enum StoryError"
    ],
    "MyChannel/Features/Stories/UltimateStoryViewModel.swift": [
        r"enum StoryError"
    ],
    "MyChannel/Features/Stories/MultiClipEngine.swift": [
        r"struct VideoClip"
    ],
    "MyChannel/Features/Upload/ProVideoEditor.swift": [
        r"struct VideoClip"
    ],
    "MyChannel/Core/Components/FlowLayout.swift": [
        # Keep this one, it's the main definition
    ],
    "MyChannel/Core/Models/Video.swift": [
        r"    var isTrending:"  # Remove duplicate property
    ],
    "MyChannel/Core/AI/VertexAI/PlacementOptimizationAgent.swift": [
        r"    var isTrending:"  # Remove duplicate property
    ]
}

print("🔥 Removing remaining duplicate type definitions...")
fixed_count = 0

for file_path, patterns in files.items():
    if not patterns:
        continue
    
    if not os.path.exists(file_path):
        print(f"⚠️  File not found: {file_path}")
        continue
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    original_len = len(content)
    
    for pattern in patterns:
        content = remove_lines_between(content, pattern, r"^}")
    
    # Clean up extra newlines
    content = re.sub(r'\n{3,}', '\n\n', content)
    
    if len(content) < original_len:
        with open(file_path, 'w') as f:
            f.write(content)
        print(f"✅ Fixed {file_path} (removed {original_len - len(content)} chars)")
        fixed_count += 1

print(f"\n✅ Fixed {fixed_count} files")
