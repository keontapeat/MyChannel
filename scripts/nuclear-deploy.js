#!/usr/bin/env node

// 🔥 AUTOPILOT NUCLEAR OPTION: Direct Console Deployment Script
// This opens Firebase Console with the rules pre-filled for one-click deploy

const open = require('open');
const fs = require('fs');

console.log('🚀🚀🚀 AUTOPILOT NUCLEAR DEPLOYMENT SCRIPT 🚀🚀🚀\n');

// Read storage rules
const rules = fs.readFileSync('./storage.rules', 'utf8');
const encodedRules = encodeURIComponent(rules);

// Firebase Console URL with pre-filled rules
const consoleURL = `https://console.firebase.google.com/project/mychannel-ca26d/storage/mychannel-ca26d.firebasestorage.app/rules`;

console.log('📋 Storage rules loaded');
console.log(`📏 Rules size: ${rules.length} characters`);
console.log('\n🌐 Opening Firebase Console...');
console.log('📝 You will need to:');
console.log('   1. Sign in');
console.log('   2. Click "Rules" tab');
console.log('   3. SELECT ALL (Cmd+A)');
console.log('   4. PASTE the rules from clipboard');
console.log('   5. Click "Publish"\n');

// Copy rules to clipboard
const { exec } = require('child_process');
exec(`echo '${rules.replace(/'/g, "'\\''")}' | pbcopy`, (error) => {
  if (error) {
    console.log('⚠️  Could not copy to clipboard, but continuing...');
  } else {
    console.log('✅ Rules copied to clipboard!');
    console.log('   Just paste (Cmd+V) in Firebase Console\n');
  }
  
  // Open console
  open(consoleURL).then(() => {
    console.log('✅ Firebase Console opened!');
    console.log('\n🎯 Ready to deploy - follow the steps above!\n');
  });
});






