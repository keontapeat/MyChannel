/**
 * MyChannel Cloud Functions
 * 🔥 Auto-Delete Expired Stories + Orphaned Media Cleanup
 */

import {onSchedule} from 'firebase-functions/v2/scheduler';
import {onDocumentCreated} from 'firebase-functions/v2/firestore';
import * as admin from 'firebase-admin';

admin.initializeApp();

// ============================================
// 🔥 DELETE EXPIRED STORIES - Runs Every Hour
// ============================================

export const deleteExpiredStories = onSchedule('every 1 hours', async () => {
    const db = admin.firestore();
    const storage = admin.storage();
    const now = admin.firestore.Timestamp.now();
    
    console.log('⏰ [deleteExpiredStories] Running cleanup...');
    
    try {
      // Find expired stories (expiresAt < now)
      const expiredStories = await db.collection('stories')
        .where('expiresAt', '<', now)
        .limit(100) // Process 100 at a time
        .get();
      
      if (expiredStories.empty) {
        console.log('✅ [deleteExpiredStories] No expired stories found');
        return;
      }
      
      const batch = db.batch();
      let deletedCount = 0;
      
      // Delete each expired story
      for (const doc of expiredStories.docs) {
        const data = doc.data();
        
        // 1. Delete story document
        batch.delete(doc.ref);
        deletedCount++;
        
        // 2. Delete main media from Storage
        if (data.mediaURL && data.mediaURL.includes('firebase')) {
          try {
            const url = new URL(data.mediaURL);
            const pathMatch = url.pathname.match(/\/o\/(.+?)(\?|$)/);
            if (pathMatch) {
              const path = decodeURIComponent(pathMatch[1]);
              await storage.bucket().file(path).delete();
              console.log(`🗑️ [deleteExpiredStories] Deleted media: ${path}`);
            }
          } catch (error) {
            console.error('Failed to delete media:', error);
          }
        }
        
        // 3. Delete content items from Storage
        if (data.content && Array.isArray(data.content)) {
          for (const item of data.content) {
            if (item.url && item.url.includes('firebase')) {
              try {
                const url = new URL(item.url);
                const pathMatch = url.pathname.match(/\/o\/(.+?)(\?|$)/);
                if (pathMatch) {
                  const path = decodeURIComponent(pathMatch[1]);
                  await storage.bucket().file(path).delete();
                  console.log(`🗑️ [deleteExpiredStories] Deleted content: ${path}`);
                }
              } catch (error) {
                console.error('Failed to delete content:', error);
              }
            }
          }
        }
        
        // 4. Delete story views
        const viewsRef = db.collection('story_views').doc(doc.id);
        batch.delete(viewsRef);
        
        const expiresAt = data.expiresAt?.toDate() || new Date();
        console.log(`✅ [deleteExpiredStories] Deleted story: ${doc.id} (expired ${expiresAt.toISOString()})`);
      }
      
      // Commit batch delete
      await batch.commit();
      console.log(`🎉 [deleteExpiredStories] Deleted ${deletedCount} expired stories`);
      
    } catch (error) {
      console.error('🚨 [deleteExpiredStories] Error:', error);
    }
  });

// ============================================
// 🧹 CLEANUP ORPHANED MEDIA - Runs Daily
// ============================================

export const cleanupOrphanedMedia = onSchedule('every 24 hours', async () => {
    const storage = admin.storage();
    const db = admin.firestore();
    
    console.log('🧹 [cleanupOrphanedMedia] Running orphaned media cleanup...');
    
    try {
      // Get all story media files
      const [files] = await storage.bucket().getFiles({
        prefix: 'stories/',
        maxResults: 1000
      });
      
      let cleanedCount = 0;
      
      for (const file of files) {
        const fileName = file.name.split('/').pop();
        
        // Build public URL for the file
        const publicUrl = `https://storage.googleapis.com/${file.bucket.name}/${file.name}`;
        
        // Check if file is referenced in any story
        const storyQuery = await db.collection('stories')
          .where('mediaURL', '==', publicUrl)
          .limit(1)
          .get();
        
        // Also check in content arrays
        let foundInContent = false;
        if (storyQuery.empty) {
          const allStories = await db.collection('stories')
            .limit(1000)
            .get();
          
          for (const storyDoc of allStories.docs) {
            const data = storyDoc.data();
            if (data.content && Array.isArray(data.content)) {
              for (const item of data.content) {
                if (item.url === publicUrl) {
                  foundInContent = true;
                  break;
                }
              }
            }
            if (foundInContent) break;
          }
        }
        
        if (storyQuery.empty && !foundInContent) {
          // File not referenced - delete it
          await file.delete();
          cleanedCount++;
          console.log(`🗑️ [cleanupOrphanedMedia] Deleted orphaned file: ${fileName}`);
        }
      }
      
      console.log(`🎉 [cleanupOrphanedMedia] Cleaned up ${cleanedCount} orphaned files`);
    } catch (error) {
      console.error('🚨 [cleanupOrphanedMedia] Error:', error);
    }
  });

// ============================================
// 🔔 STORY NOTIFICATIONS - New Story Alert
// ============================================

export const notifyFollowersOnStoryCreated = onDocumentCreated('stories/{storyId}', async (event) => {
    const snap = event.data;
    if (!snap) {
      console.log('No data in snapshot');
      return;
    }
    
    const data = snap.data();
    const creatorId = data.creatorId;
    
    console.log(`📢 [notifyFollowers] New story from ${creatorId}`);
    
    // Get creator's followers
    const followersSnapshot = await admin.firestore()
      .collection('subscriptions')
      .where('creatorId', '==', creatorId)
      .get();
    
    if (followersSnapshot.empty) {
      console.log('No followers to notify');
      return;
    }
    
    // Send notifications to followers (batch)
    const batch = admin.firestore().batch();
    let notificationCount = 0;
    
    for (const followerDoc of followersSnapshot.docs) {
      const followerId = followerDoc.data().userId;
      
      // Create notification document
      const notificationRef = admin.firestore()
        .collection('notifications')
        .doc(followerId)
        .collection('items')
        .doc();
      
      batch.set(notificationRef, {
        type: 'new_story',
        creatorId: creatorId,
        storyId: snap.id,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        read: false
      });
      
      notificationCount++;
    }
    
    await batch.commit();
    console.log(`✅ [notifyFollowers] Sent ${notificationCount} notifications`);
  });
