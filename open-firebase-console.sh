#!/bin/bash

# 🔥 ONE-CLICK FIREBASE CONSOLE OPENER
# Opens Firebase Console with rules ready to paste

echo "🔥🔥🔥 OPENING FIREBASE CONSOLE FOR YOU! 🔥🔥🔥"
echo ""

# Step 1: Copy rules to clipboard
echo "📋 Copying firestore.rules to clipboard..."
cat firestore.rules | pbcopy

if [ $? -eq 0 ]; then
    echo "✅ Rules copied to clipboard!"
    echo ""
    echo "📱 Opening Firebase Console..."
    
    # Step 2: Open Firebase Console in browser
    open "https://console.firebase.google.com/project/mychannel-ca26d/firestore/rules"
    
    sleep 2
    
    echo ""
    echo "🎯 INSTRUCTIONS:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "1. Click 'Edit rules' button"
    echo "2. Select ALL existing rules (Cmd+A)"
    echo "3. Press Cmd+V to paste new rules"
    echo "4. Click 'Publish' button"
    echo ""
    echo "✅ DONE! Your app will work!"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "🔥 Rules are already in your clipboard - just paste!"
    echo ""
    
    # Step 3: Wait a bit, then open index creation
    sleep 5
    
    echo "📊 Next: Creating Firestore Index..."
    echo ""
    
    sleep 2
    
    # Step 4: Open index creation link
    open "https://console.firebase.google.com/v1/r/project/mychannel-ca26d/firestore/indexes?create_composite=Ck5wcm9qZWN0cy9teWNoYW5uZWwtY2EyNmQvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL3ZpZGVvcy9pbmRleGVzL18QARoOCgp2aXNpYmlsaXR5EAEaEQoNdHJlbmRpbmdTY29yZRACGg0KCXVwZGF0ZWRBdBACGgwKCF9fbmFtZV9fEAI"
    
    echo "🎯 INSTRUCTIONS FOR INDEX:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "1. Click 'Create Index' button"
    echo "2. Wait 10-30 minutes for index to build"
    echo "3. Test your app!"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "✅✅✅ YOUR APP WILL BE WORKING IN 30 MINUTES! ✅✅✅"
    echo ""
    echo "🚀 Autopilot mode: MISSION COMPLETE! 🔥🔥🔥"
    
else
    echo "❌ Failed to copy rules"
    echo "Manual: Copy contents of firestore.rules file"
fi

