import express from 'express';
import admin from 'firebase-admin';
import { Storage } from '@google-cloud/storage';
import { randomUUID } from 'crypto';

const app = express();
app.use(express.json({ limit: '50mb' }));

// Firebase Admin SDK initialization
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: 'mychannel-ca26d'
  });
}

const db = admin.firestore();
const storage = new Storage();
const bucket = storage.bucket('mychannel-ca26d.appspot.com');

// Helper function to verify Firebase Auth token
async function requireUser(req: any, res: any) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      res.status(401).json({ error: 'Unauthorized' });
      return null;
    }

    const token = authHeader.split('Bearer ')[1];
    const decoded = await admin.auth().verifyIdToken(token);
    return { userId: decoded.uid, email: decoded.email };
  } catch (error) {
    res.status(401).json({ error: 'Invalid token' });
    return null;
  }
}

// Helper function to generate track ID
function generateTrackId(): string {
  return randomUUID();
}

// ─────────────────────────────────────────────────────────────────────────────
// Phase 1: Enhanced Music Upload & Processing Service
// ─────────────────────────────────────────────────────────────────────────────

// POST /v1/music/tracks/upload - Initiate upload with metadata
app.post('/v1/music/tracks/upload', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { title, artistName, albumName, genre, isExplicit, duration } = req.body || {};

    if (!title || typeof title !== 'string') {
      return res.status(400).json({ error: 'title is required' });
    }

    if (!artistName || typeof artistName !== 'string') {
      return res.status(400).json({ error: 'artistName is required' });
    }

    if (!genre || typeof genre !== 'string') {
      return res.status(400).json({ error: 'genre is required' });
    }

    const trackId = generateTrackId();
    const now = admin.firestore.Timestamp.now();

    // Create track document with initial metadata
    const trackRef = db.collection('music_tracks').doc(trackId);
    await trackRef.set({
      id: trackId,
      title: title.trim(),
      artistId: user.userId,
      artistName: artistName.trim(),
      albumName: albumName?.trim() || null,
      genre: genre.trim(),
      isExplicit: isExplicit || false,
      duration: duration || null,
      status: 'uploading',
      uploadStartedAt: now,
      createdAt: now,
      streamCount: 0,
      likeCount: 0,
      artworkURL: null,
      audioURL: null,
      transcodingStatus: 'pending',
      distributionStatus: 'not_submitted'
    });

    res.status(201).json({
      trackId,
      status: 'uploading',
      message: 'Upload initiated. Use chunked upload endpoint for large files.'
    });
  } catch (error) {
    console.error('Initiate upload error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/music/tracks/:trackId/chunk - Chunked audio upload
app.post('/v1/music/tracks/:trackId/chunk', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { trackId } = req.params;
    const { chunkIndex, totalChunks, chunkData } = req.body || {};

    if (!chunkData || typeof chunkData !== 'string') {
      return res.status(400).json({ error: 'chunkData is required' });
    }

    if (typeof chunkIndex !== 'number' || typeof totalChunks !== 'number') {
      return res.status(400).json({ error: 'chunkIndex and totalChunks are required' });
    }

    const trackRef = db.collection('music_tracks').doc(trackId);
    const trackSnap = await trackRef.get();

    if (!trackSnap.exists) {
      return res.status(404).json({ error: 'Track not found' });
    }

    const trackData = trackSnap.data()!;

    if (String(trackData.artistId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    // Store chunk in temporary storage
    const chunkRef = bucket.file(`music/temp/${user.userId}/${trackId}/chunk_${chunkIndex}`);
    const buffer = Buffer.from(chunkData, 'base64');
    await chunkRef.save(buffer);

    // Update track with chunk progress
    await trackRef.update({
      totalChunks,
      uploadedChunks: admin.firestore.FieldValue.increment(1),
      lastChunkUploadedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    res.json({
      trackId,
      chunkIndex,
      status: 'chunk_uploaded',
      message: `Chunk ${chunkIndex + 1} of ${totalChunks} uploaded`
    });
  } catch (error) {
    console.error('Chunk upload error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/music/tracks/:trackId/complete - Finalize upload and trigger processing
app.post('/v1/music/tracks/:trackId/complete', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { trackId } = req.params;
    const { fileName, mimeType } = req.body || {};

    const trackRef = db.collection('music_tracks').doc(trackId);
    const trackSnap = await trackRef.get();

    if (!trackSnap.exists) {
      return res.status(404).json({ error: 'Track not found' });
    }

    const trackData = trackSnap.data()!;

    if (String(trackData.artistId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    // Combine chunks into final audio file
    const tempDir = `music/temp/${user.userId}/${trackId}`;
    const [chunks] = await bucket.getFiles({ prefix: tempDir });

    if (chunks.length === 0) {
      return res.status(400).json({ error: 'No chunks found' });
    }

    // Sort chunks by index
    chunks.sort((a, b) => {
      const indexA = parseInt(a.name.split('_').pop() || '0');
      const indexB = parseInt(b.name.split('_').pop() || '0');
      return indexA - indexB;
    });

    // Combine chunks (simplified - in production, use a proper audio processing service)
    const finalAudioPath = `music/${user.userId}/tracks/${trackId}.${fileName?.split('.').pop() || 'mp3'}`;
    const finalAudioRef = bucket.file(finalAudioPath);

    // For now, just move the first chunk (in production, combine all chunks)
    const firstChunk = chunks[0];
    const [chunkData] = await firstChunk.download();
    await finalAudioRef.save(chunkData, {
      contentType: mimeType || 'audio/mpeg'
    });

    const audioURL = `https://storage.googleapis.com/${bucket.name}/${finalAudioPath}`;

    // Update track status
    await trackRef.update({
      audioURL,
      status: 'processing',
      processingStartedAt: admin.firestore.FieldValue.serverTimestamp(),
      transcodingStatus: 'in_progress'
    });

    // Clean up temp chunks
    for (const chunk of chunks) {
      await chunk.delete();
    }

    res.json({
      trackId,
      audioURL,
      status: 'processing',
      message: 'Upload complete. Transcoding in progress.'
    });
  } catch (error) {
    console.error('Complete upload error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// POST /v1/music/tracks/:trackId/artwork - Upload artwork
app.post('/v1/music/tracks/:trackId/artwork', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { trackId } = req.params;
    const { artworkData, mimeType } = req.body || {};

    if (!artworkData || typeof artworkData !== 'string') {
      return res.status(400).json({ error: 'artworkData is required' });
    }

    const trackRef = db.collection('music_tracks').doc(trackId);
    const trackSnap = await trackRef.get();

    if (!trackSnap.exists) {
      return res.status(404).json({ error: 'Track not found' });
    }

    const trackData = trackSnap.data()!;

    if (String(trackData.artistId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    // Upload artwork
    const artworkPath = `music/${user.userId}/artwork/${trackId}.jpg`;
    const artworkRef = bucket.file(artworkPath);
    const buffer = Buffer.from(artworkData, 'base64');
    
    await artworkRef.save(buffer, {
      contentType: mimeType || 'image/jpeg'
    });

    const artworkURL = `https://storage.googleapis.com/${bucket.name}/${artworkPath}`;

    // Update track with artwork URL
    await trackRef.update({
      artworkURL,
      artworkUploadedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    res.json({
      trackId,
      artworkURL,
      message: 'Artwork uploaded successfully'
    });
  } catch (error) {
    console.error('Artwork upload error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/music/tracks/:trackId/status - Check upload/processing status
app.get('/v1/music/tracks/:trackId/status', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { trackId } = req.params;

    const trackRef = db.collection('music_tracks').doc(trackId);
    const trackSnap = await trackRef.get();

    if (!trackSnap.exists) {
      return res.status(404).json({ error: 'Track not found' });
    }

    const trackData = trackSnap.data()!;

    if (String(trackData.artistId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    res.json({
      trackId,
      status: trackData.status,
      transcodingStatus: trackData.transcodingStatus,
      audioURL: trackData.audioURL,
      artworkURL: trackData.artworkURL,
      streamCount: trackData.streamCount || 0,
      likeCount: trackData.likeCount || 0,
      createdAt: trackData.createdAt?.toDate().toISOString()
    });
  } catch (error) {
    console.error('Get status error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// GET /v1/music/tracks - List artist's tracks
app.get('/v1/music/tracks', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { limit, status } = req.query || {};

    let query = db.collection('music_tracks')
      .where('artistId', '==', user.userId)
      .orderBy('createdAt', 'desc')
      .limit(parseInt(limit as string) || 50);

    if (status) {
      query = query.where('status', '==', status);
    }

    const tracksSnap = await query.get();

    const tracks = tracksSnap.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        title: data.title,
        artistName: data.artistName,
        albumName: data.albumName,
        genre: data.genre,
        isExplicit: data.isExplicit,
        artworkURL: data.artworkURL,
        audioURL: data.audioURL,
        status: data.status,
        transcodingStatus: data.transcodingStatus,
        streamCount: data.streamCount || 0,
        likeCount: data.likeCount || 0,
        createdAt: data.createdAt?.toDate().toISOString()
      };
    });

    res.json({
      tracks,
      total: tracksSnap.size
    });
  } catch (error) {
    console.error('List tracks error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PUT /v1/music/tracks/:trackId/publish - Publish track (make it live)
app.put('/v1/music/tracks/:trackId/publish', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { trackId } = req.params;

    const trackRef = db.collection('music_tracks').doc(trackId);
    const trackSnap = await trackRef.get();

    if (!trackSnap.exists) {
      return res.status(404).json({ error: 'Track not found' });
    }

    const trackData = trackSnap.data()!;

    if (String(trackData.artistId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    if (!trackData.audioURL) {
      return res.status(400).json({ error: 'Audio must be uploaded before publishing' });
    }

    await trackRef.update({
      status: 'published',
      publishedAt: admin.firestore.FieldValue.serverTimestamp(),
      isPublished: true
    });

    res.json({
      trackId,
      status: 'published',
      message: 'Track published successfully'
    });
  } catch (error) {
    console.error('Publish track error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// PUT /v1/music/tracks/:trackId - Edit track metadata
app.put('/v1/music/tracks/:trackId', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { trackId } = req.params;
    const { title, artistName, albumName, genre, isExplicit } = req.body || {};

    const trackRef = db.collection('music_tracks').doc(trackId);
    const trackSnap = await trackRef.get();

    if (!trackSnap.exists) {
      return res.status(404).json({ error: 'Track not found' });
    }

    const trackData = trackSnap.data()!;

    if (String(trackData.artistId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const updates: any = {};
    if (title !== undefined) updates.title = title.trim();
    if (artistName !== undefined) updates.artistName = artistName.trim();
    if (albumName !== undefined) updates.albumName = albumName.trim();
    if (genre !== undefined) updates.genre = genre.trim();
    if (isExplicit !== undefined) updates.isExplicit = isExplicit;
    updates.updatedAt = admin.firestore.FieldValue.serverTimestamp();

    await trackRef.update(updates);

    res.json({
      trackId,
      message: 'Track updated successfully'
    });
  } catch (error) {
    console.error('Edit track error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE /v1/music/tracks/:trackId - Delete track
app.delete('/v1/music/tracks/:trackId', async (req, res) => {
  try {
    const user = await requireUser(req, res);
    if (!user) return;

    const { trackId } = req.params;

    const trackRef = db.collection('music_tracks').doc(trackId);
    const trackSnap = await trackRef.get();

    if (!trackSnap.exists) {
      return res.status(404).json({ error: 'Track not found' });
    }

    const trackData = trackSnap.data()!;

    if (String(trackData.artistId || '') !== user.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    // Delete audio file from storage
    if (trackData.audioURL) {
      const audioFileName = trackData.audioURL.split('/').pop();
      if (audioFileName) {
        const audioFile = bucket.file(`music/${user.userId}/tracks/${audioFileName}`);
        await audioFile.delete().catch(() => {});
      }
    }

    // Delete artwork from storage
    if (trackData.artworkURL) {
      const artworkFileName = trackData.artworkURL.split('/').pop();
      if (artworkFileName) {
        const artworkFile = bucket.file(`music/${user.userId}/artwork/${artworkFileName}`);
        await artworkFile.delete().catch(() => {});
      }
    }

    // Delete Firestore document
    await trackRef.delete();

    res.json({
      trackId,
      message: 'Track deleted successfully'
    });
  } catch (error) {
    console.error('Delete track error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
  console.log(`🎵 Music service listening on port ${PORT}`);
});
