#!/usr/bin/env node

/**
 * Fix Thumbnail URLs - Remove :443 Port from Firebase Storage URLs
 * 
 * This script finds and fixes Firebase Storage URLs that incorrectly include :443 port.
 * 
 * Problem URLs: https://firebasestorage.googleapis.com:443/v0/b/...
 * Fixed URLs:   https://firebasestorage.googleapis.com/v0/b/...
 * 
 * Usage:
 *   node scripts/fix-thumbnail-urls.js --dry-run    # Preview changes without applying
 *   node scripts/fix-thumbnail-urls.js              # Apply fixes to database
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
const serviceAccountPath = path.join(__dirname, '../firebase-service-account.json');

try {
  const serviceAccount = require(serviceAccountPath);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    storageBucket: 'mychannel-ca26d.appspot.com'
  });
  console.log('✅ Firebase Admin initialized');
} catch (error) {
  console.error('❌ Failed to initialize Firebase Admin');
  console.error('   Make sure firebase-service-account.json exists in the project root');
  console.error('   Download it from: https://console.firebase.google.com/project/mychannel-ca26d/settings/serviceaccounts/adminsdk');
  process.exit(1);
}

const db = admin.firestore();
const isDryRun = process.argv.includes('--dry-run');

// Collections and fields to check
const COLLECTIONS_TO_FIX = [
  { name: 'videos', fields: ['thumbnailURL', 'videoURL'] },
  { name: 'stories', fields: ['thumbnailURL', 'videoURL', 'mediaURL'] },
  { name: 'users', fields: ['profilePictureURL', 'bannerURL'] },
  { name: 'featured', fields: ['thumbnailURL', 'videoURL'] },
];

/**
 * Check if URL has the :443 port issue
 */
function hasPortIssue(url) {
  if (!url || typeof url !== 'string') return false;
  return url.includes('firebasestorage.googleapis.com:443');
}

/**
 * Fix URL by removing :443 port
 */
function fixURL(url) {
  if (!url || typeof url !== 'string') return url;
  return url.replace('firebasestorage.googleapis.com:443', 'firebasestorage.googleapis.com');
}

/**
 * Process a single collection
 */
async function processCollection(collectionName, fields) {
  console.log(`\n🔍 Checking collection: ${collectionName}`);
  
  const snapshot = await db.collection(collectionName).get();
  console.log(`   Found ${snapshot.size} documents`);
  
  let fixedCount = 0;
  const batch = db.batch();
  let batchCount = 0;
  
  for (const doc of snapshot.docs) {
    const data = doc.data();
    const updates = {};
    let needsUpdate = false;
    
    // Check each field
    for (const field of fields) {
      const value = data[field];
      if (hasPortIssue(value)) {
        const fixed = fixURL(value);
        updates[field] = fixed;
        needsUpdate = true;
        
        console.log(`   📝 ${doc.id}.${field}:`);
        console.log(`      Before: ${value.substring(0, 80)}...`);
        console.log(`      After:  ${fixed.substring(0, 80)}...`);
      }
    }
    
    // Apply updates
    if (needsUpdate) {
      fixedCount++;
      
      if (!isDryRun) {
        batch.update(doc.ref, updates);
        batchCount++;
        
        // Commit batch every 500 operations (Firestore limit)
        if (batchCount >= 500) {
          await batch.commit();
          console.log(`   💾 Committed batch of ${batchCount} updates`);
          batchCount = 0;
        }
      }
    }
  }
  
  // Commit remaining updates
  if (!isDryRun && batchCount > 0) {
    await batch.commit();
    console.log(`   💾 Committed final batch of ${batchCount} updates`);
  }
  
  if (fixedCount > 0) {
    console.log(`   ✅ Fixed ${fixedCount} documents in ${collectionName}`);
  } else {
    console.log(`   ✨ No issues found in ${collectionName}`);
  }
  
  return fixedCount;
}

/**
 * Main execution
 */
async function main() {
  console.log('🔧 Firebase Storage URL Fixer');
  console.log('================================\n');
  
  if (isDryRun) {
    console.log('🔍 DRY RUN MODE - No changes will be applied\n');
  } else {
    console.log('⚠️  LIVE MODE - Changes will be applied to database\n');
  }
  
  let totalFixed = 0;
  
  for (const collection of COLLECTIONS_TO_FIX) {
    try {
      const fixed = await processCollection(collection.name, collection.fields);
      totalFixed += fixed;
    } catch (error) {
      console.error(`❌ Error processing ${collection.name}:`, error.message);
    }
  }
  
  console.log('\n================================');
  console.log(`📊 Summary: Fixed ${totalFixed} documents total`);
  
  if (isDryRun) {
    console.log('\n💡 Run without --dry-run to apply these fixes');
  } else {
    console.log('\n✅ All fixes applied successfully!');
  }
}

// Run the script
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('\n❌ Fatal error:', error);
    process.exit(1);
  });
