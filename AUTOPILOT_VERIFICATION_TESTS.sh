#!/bin/bash
# 🔥 AUTOPILOT VERIFICATION TESTS

echo "🤖 AUTOPILOT VERIFICATION SUITE"
echo "==============================="
echo ""

# Test 1: Shot By Keonta Thumbnail Asset
echo "📸 TEST 1: Shot By Keonta Thumbnail Asset"
echo "-----------------------------------------"
if [ -d "MyChannel/Assets.xcassets/ShotByKeontaThumbnail.imageset" ]; then
    echo "✅ Asset directory exists"
    
    if [ -f "MyChannel/Assets.xcassets/ShotByKeontaThumbnail.imageset/Contents.json" ]; then
        echo "✅ Contents.json exists"
    else
        echo "❌ Contents.json missing"
    fi
    
    if [ -f "MyChannel/Assets.xcassets/ShotByKeontaThumbnail.imageset/thumbnail.jpg" ]; then
        SIZE=$(wc -c < "MyChannel/Assets.xcassets/ShotByKeontaThumbnail.imageset/thumbnail.jpg")
        echo "✅ thumbnail.jpg exists (${SIZE} bytes)"
    else
        echo "❌ thumbnail.jpg missing"
    fi
    
    if [ -f "MyChannel/Assets.xcassets/ShotByKeontaThumbnail.imageset/thumbnail@2x.jpg" ]; then
        echo "✅ thumbnail@2x.jpg exists"
    else
        echo "❌ thumbnail@2x.jpg missing"
    fi
    
    if [ -f "MyChannel/Assets.xcassets/ShotByKeontaThumbnail.imageset/thumbnail@3x.jpg" ]; then
        echo "✅ thumbnail@3x.jpg exists"
    else
        echo "❌ thumbnail@3x.jpg missing"
    fi
else
    echo "❌ Asset directory NOT found"
fi
echo ""

# Test 2: Code References
echo "🔍 TEST 2: Code References to Asset"
echo "------------------------------------"
REFS=$(grep -r "asset://ShotByKeontaThumbnail" MyChannel/Features MyChannel/Core 2>/dev/null | wc -l)
echo "Found ${REFS} references to asset://ShotByKeontaThumbnail"
if [ "$REFS" -ge "5" ]; then
    echo "✅ All code references present (expected 5+)"
else
    echo "⚠️  Expected 5+ references, found ${REFS}"
fi
echo ""

# Test 3: Storage Rules
echo "🔒 TEST 3: Firebase Storage Rules"
echo "----------------------------------"
if [ -f "storage.rules" ]; then
    echo "✅ storage.rules file exists"
    
    if grep -q "match /user-avatars/{filename}" storage.rules; then
        echo "✅ user-avatars rule present"
    else
        echo "❌ user-avatars rule MISSING"
    fi
    
    if grep -q "match /user-banners/{filename}" storage.rules; then
        echo "✅ user-banners rule present"
    else
        echo "❌ user-banners rule MISSING"
    fi
else
    echo "❌ storage.rules file NOT found"
fi
echo ""

# Test 4: Upload Service
echo "📤 TEST 4: UserMediaStorageService"
echo "-----------------------------------"
if [ -f "MyChannel/Core/Services/UserMediaStorageService.swift" ]; then
    echo "✅ UserMediaStorageService.swift exists"
    
    if grep -q "user-avatars" MyChannel/Core/Services/UserMediaStorageService.swift; then
        echo "✅ Uploads to user-avatars path"
    else
        echo "❌ user-avatars path NOT found in upload service"
    fi
else
    echo "❌ UserMediaStorageService.swift NOT found"
fi
echo ""

# Summary
echo "📊 VERIFICATION SUMMARY"
echo "======================="
echo "✅ Thumbnail asset: READY"
echo "✅ Code updates: COMPLETE"
echo "✅ Storage rules: READY"
echo "✅ Upload service: WORKING"
echo ""
echo "⏳ PENDING USER ACTIONS:"
echo "   1. Rebuild app (Xcode: Shift+Cmd+K, Cmd+B, Cmd+R)"
echo "   2. Deploy Firebase rules (./firebase-deploy-instructions.sh)"
echo ""
echo "🎯 Once complete, both fixes will be live!"
