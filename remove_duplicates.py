#!/usr/bin/env python3
"""
Remove duplicate type definitions from Swift files
"""

import re
import os

# Files and their duplicate types to remove
FIXES = {
    "MyChannel/Core/AI/AdTargetingAGI.swift": [
        r"struct ScoredAd \{[^}]*\}",
        r"struct EngagementData \{[^}]*\}"
    ],
    "MyChannel/Core/Services/AITargetingEngine.swift": [
        r"struct AdCreative: Identifiable, Codable \{[^}]*\}",
        r"struct ScoredAd \{[^}]*\}",
        r"struct EngagementData \{[^}]*\}"
    ],
    "MyChannel/Core/AI/FraudDetectionAGI.swift": [
        r"struct FraudAnalysis \{[^}]*\}",
        r"enum FraudLevel \{[^}]*\}"
    ],
    "MyChannel/Core/Services/EnterpriseAITeam.swift": [
        r"struct FraudAnalysis \{[^}]*\}"
    ],
    "MyChannel/Core/AI/VertexAI/CreativePerformanceAgent.swift": [
        r"struct AdCreative \{[^}]*\}"
    ],
    "MyChannel/Core/AI/VertexAI/FraudDetectionMLAgent.swift": [
        r"struct AdRequest \{[^}]*\}"
    ]
}

def remove_duplicates(file_path, patterns):
    """Remove duplicate type definitions from file"""
    if not os.path.exists(file_path):
        print(f"⚠️  File not found: {file_path}")
        return False
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    original_len = len(content)
    
    for pattern in patterns:
        content = re.sub(pattern, "", content, flags=re.DOTALL)
    
    # Clean up extra newlines
    content = re.sub(r'\n{3,}', '\n\n', content)
    
    if len(content) < original_len:
        with open(file_path, 'w') as f:
            f.write(content)
        print(f"✅ Fixed {file_path} (removed {original_len - len(content)} chars)")
        return True
    else:
        print(f"⏭️  No changes needed in {file_path}")
        return False

def main():
    print("🔥 Removing duplicate type definitions...")
    fixed_count = 0
    
    for file_path, patterns in FIXES.items():
        if remove_duplicates(file_path, patterns):
            fixed_count += 1
    
    print(f"\n✅ Fixed {fixed_count}/{len(FIXES)} files")

if __name__ == "__main__":
    main()
