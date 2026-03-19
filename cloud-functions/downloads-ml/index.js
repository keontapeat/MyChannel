const functions = require('firebase-functions');
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

exports.trackDownload = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { videoId, quality, action } = data;
  const userId = context.auth.uid;

  try {
    const downloadEvent = {
      userId,
      videoId,
      quality,
      action,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      platform: 'ios'
    };

    await db.collection('ml_events').doc('downloads').collection('events').add(downloadEvent);

    await db.collection('users').doc(userId).collection('downloads_history').add({
      videoId,
      quality,
      action,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    const mlEndpoints = [
      'https://watch-time-predictor-fkri6ifojq-uc.a.run.app/track-download',
      'https://recommendations-fkri6ifojq-uc.a.run.app/update-download-preference',
      'https://feed-personalization-fkri6ifojq-uc.a.run.app/track-offline-behavior'
    ];

    const mlPromises = mlEndpoints.map(endpoint =>
      fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(downloadEvent)
      }).catch(err => console.error(`ML endpoint error: ${endpoint}`, err))
    );

    await Promise.allSettled(mlPromises);

    return { success: true, message: 'Download tracked successfully' };
  } catch (error) {
    console.error('Error tracking download:', error);
    throw new functions.https.HttpsError('internal', 'Failed to track download');
  }
});

exports.getRecommendedDownloads = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const userId = context.auth.uid;
  const { limit = 10 } = data;

  try {
    const userDoc = await db.collection('users').doc(userId).get();
    const isPlusSubscriber = userDoc.data()?.isPlusSubscriber || false;

    if (!isPlusSubscriber) {
      return { recommendations: [], requiresPlus: true };
    }

    const mlEndpoint = 'https://recommendations-fkri6ifojq-uc.a.run.app/recommend-downloads';
    
    const response = await fetch(mlEndpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        user_id: userId,
        limit,
        context: 'downloads',
        include_offline_suitable: true
      })
    });

    if (!response.ok) {
      throw new Error('ML service error');
    }

    const mlData = await response.json();

    const watchTimeEndpoint = 'https://watch-time-predictor-fkri6ifojq-uc.a.run.app/predict-download-value';
    const watchTimeResponse = await fetch(watchTimeEndpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        user_id: userId,
        video_ids: mlData.recommendations.map(r => r.video_id),
        context: 'download_prediction'
      })
    });

    let watchTimeScores = {};
    if (watchTimeResponse.ok) {
      const watchTimeData = await watchTimeResponse.json();
      watchTimeScores = watchTimeData.predictions || {};
    }

    const enrichedRecommendations = mlData.recommendations.map(rec => ({
      ...rec,
      watch_time_score: watchTimeScores[rec.video_id] || 0.5,
      ml_confidence: rec.score
    }));

    return {
      recommendations: enrichedRecommendations,
      requiresPlus: false,
      mlVersion: '2.0'
    };
  } catch (error) {
    console.error('Error getting recommended downloads:', error);
    throw new functions.https.HttpsError('internal', 'Failed to get recommendations');
  }
});

exports.onDownloadComplete = functions.firestore
  .document('users/{userId}/downloads/{downloadId}')
  .onCreate(async (snap, context) => {
    const download = snap.data();
    const userId = context.params.userId;

    try {
      const analyticsEvent = {
        userId,
        videoId: download.videoId,
        quality: download.quality,
        fileSize: download.fileSize,
        downloadDate: download.downloadDate,
        eventType: 'download_complete',
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      };

      await db.collection('analytics').doc('downloads').collection('events').add(analyticsEvent);

      const mlEndpoint = 'https://churn-predictor-fkri6ifojq-uc.a.run.app/track-engagement';
      await fetch(mlEndpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          user_id: userId,
          event_type: 'download',
          video_id: download.videoId,
          engagement_score: 0.9,
          timestamp: new Date().toISOString()
        })
      }).catch(err => console.error('Churn predictor error:', err));

      const userRef = db.collection('users').doc(userId);
      await userRef.update({
        totalDownloads: admin.firestore.FieldValue.increment(1),
        lastDownloadDate: admin.firestore.FieldValue.serverTimestamp()
      });

      console.log(`Download completed for user ${userId}: ${download.videoId}`);
    } catch (error) {
      console.error('Error processing download completion:', error);
    }
  });

exports.onDownloadDelete = functions.firestore
  .document('users/{userId}/downloads/{downloadId}')
  .onDelete(async (snap, context) => {
    const download = snap.data();
    const userId = context.params.userId;

    try {
      await db.collection('analytics').doc('downloads').collection('events').add({
        userId,
        videoId: download.videoId,
        eventType: 'download_delete',
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });

      const userRef = db.collection('users').doc(userId);
      await userRef.update({
        totalDownloads: admin.firestore.FieldValue.increment(-1)
      });

      console.log(`Download deleted for user ${userId}: ${download.videoId}`);
    } catch (error) {
      console.error('Error processing download deletion:', error);
    }
  });

exports.cleanupExpiredDownloads = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    try {
      const usersSnapshot = await db.collection('users').get();
      
      for (const userDoc of usersSnapshot.docs) {
        const userId = userDoc.id;
        const isPlusSubscriber = userDoc.data().isPlusSubscriber || false;

        if (!isPlusSubscriber) {
          const downloadsSnapshot = await db.collection('users').doc(userId)
            .collection('downloads').get();
          
          const batch = db.batch();
          downloadsSnapshot.docs.forEach(doc => {
            batch.delete(doc.ref);
          });
          
          if (downloadsSnapshot.size > 0) {
            await batch.commit();
            console.log(`Cleaned up ${downloadsSnapshot.size} downloads for non-Plus user ${userId}`);
          }
        }
      }

      console.log('Expired downloads cleanup completed');
      return null;
    } catch (error) {
      console.error('Error cleaning up expired downloads:', error);
      throw error;
    }
  });
