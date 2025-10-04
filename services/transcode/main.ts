import express from 'express';
import cors from 'cors';
import { Storage } from '@google-cloud/storage';
import { PubSub } from '@google-cloud/pubsub';
import { createClient } from '@supabase/supabase-js';
import ffmpeg from 'fluent-ffmpeg';
import path from 'path';
import fs from 'fs/promises';

const app = express();
const storage = new Storage();
const pubsub = new PubSub();
const supabase = createClient(
  process.env.SUPABASE_URL || 'your-supabase-url',
  process.env.SUPABASE_SERVICE_KEY || 'your-supabase-service-key'
);

const INGEST_BUCKET = process.env.INGEST_BUCKET || 'mychannel-ingest';
const OUTPUT_BUCKET = process.env.OUTPUT_BUCKET || 'mychannel-videos';
const THUMBNAIL_BUCKET = process.env.THUMBNAIL_BUCKET || 'mychannel-thumbnails';

app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
  methods: ['POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(express.json());

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'transcode', timestamp: new Date().toISOString() });
});

// Video quality configurations
const QUALITY_PRESETS = {
  '144p': { width: 256, height: 144, bitrate: '100k', audioBitrate: '64k' },
  '240p': { width: 426, height: 240, bitrate: '300k', audioBitrate: '64k' },
  '360p': { width: 640, height: 360, bitrate: '600k', audioBitrate: '96k' },
  '480p': { width: 854, height: 480, bitrate: '1000k', audioBitrate: '128k' },
  '720p': { width: 1280, height: 720, bitrate: '2500k', audioBitrate: '192k' },
  '1080p': { width: 1920, height: 1080, bitrate: '5000k', audioBitrate: '256k' },
  '1440p': { width: 2560, height: 1440, bitrate: '10000k', audioBitrate: '320k' },
  '2160p': { width: 3840, height: 2160, bitrate: '20000k', audioBitrate: '320k' }
};

// Pub/Sub push endpoint (for tests) or manual trigger
app.post('/v1/transcode/ingest', async (req, res) => {
  try {
    const { videoId, inputPath, qualities = ['360p', '720p', '1080p'] } = req.body;

    if (!videoId || !inputPath) {
      return res.status(400).json({ error: 'videoId and inputPath are required' });
    }

    // Update video status to processing
    await supabase
      .from('videos')
      .update({ 
        status: 'processing',
        updated_at: new Date().toISOString()
      })
      .eq('id', videoId);

    // Start transcoding process in background
    processVideo(videoId, inputPath, qualities).catch(error => {
      console.error('Transcoding error:', error);
      // Update video status to failed
      supabase
        .from('videos')
        .update({ 
          status: 'failed',
          updated_at: new Date().toISOString()
        })
        .eq('id', videoId)
        .then(() => {
          // Publish failure event
          pubsub.topic('video-events').publishMessage({
            json: {
              type: 'transcode_failed',
              videoId,
              error: error.message,
              timestamp: new Date().toISOString()
            }
          });
        });
    });

    res.json({ 
      message: 'Transcoding started',
      videoId,
      qualities,
      status: 'processing'
    });
  } catch (error) {
    console.error('Transcode start error:', error);
    res.status(500).json({ error: 'Failed to start transcoding' });
  }
});

// Start transcoding job
app.post('/v1/transcode/start', async (req, res) => {
  try {
    const { videoId, inputPath, qualities = ['360p', '720p', '1080p'] } = req.body;

    if (!videoId || !inputPath) {
      return res.status(400).json({ error: 'videoId and inputPath are required' });
    }

    // Update video status to processing
    await supabase
      .from('videos')
      .update({ 
        status: 'processing',
        updated_at: new Date().toISOString()
      })
      .eq('id', videoId);

    // Start transcoding process in background
    processVideo(videoId, inputPath, qualities).catch(error => {
      console.error('Transcoding error:', error);
      // Update video status to failed
      supabase
        .from('videos')
        .update({ 
          status: 'failed',
          updated_at: new Date().toISOString()
        })
        .eq('id', videoId)
        .then(() => {
          // Publish failure event
          pubsub.topic('video-events').publishMessage({
            json: {
              type: 'transcode_failed',
              videoId,
              error: error.message,
              timestamp: new Date().toISOString()
            }
          });
        });
    });

    res.json({ 
      message: 'Transcoding started',
      videoId,
      qualities,
      status: 'processing'
    });
  } catch (error) {
    console.error('Transcode start error:', error);
    res.status(500).json({ error: 'Failed to start transcoding' });
  }
});

// Get transcoding status
app.get('/v1/transcode/status/:videoId', async (req, res) => {
  try {
    const { videoId } = req.params;

    const { data: video, error } = await supabase
      .from('videos')
      .select('id, status, quality_variants, duration, file_size')
      .eq('id', videoId)
      .single();

    if (error || !video) {
      return res.status(404).json({ error: 'Video not found' });
    }

    res.json({
      videoId: video.id,
      status: video.status,
      qualityVariants: video.quality_variants || [],
      duration: video.duration,
      fileSize: video.file_size
    });
  } catch (error) {
    console.error('Status check error:', error);
    res.status(500).json({ error: 'Failed to get status' });
  }
});

// Main video processing function
async function processVideo(videoId: string, inputPath: string, qualities: string[]) {
  const tempDir = `/tmp/${videoId}`;
  
  try {
    // Create temp directory
    await fs.mkdir(tempDir, { recursive: true });

    // Download input file
    const inputFile = path.join(tempDir, 'input.mp4');
    await downloadFile(inputPath, inputFile);

    // Get video metadata
    const metadata = await getVideoMetadata(inputFile);
    console.log('Video metadata:', metadata);

    // Update video with metadata
    await supabase
      .from('videos')
      .update({
        duration: Math.round(metadata.duration),
        file_size: metadata.size,
        updated_at: new Date().toISOString()
      })
      .eq('id', videoId);

    // Generate thumbnail
    const thumbnailPath = await generateThumbnail(inputFile, tempDir);
    const thumbnailUrl = await uploadThumbnail(videoId, thumbnailPath);

    // Transcode to different qualities
    const qualityVariants = [];
    for (const quality of qualities) {
      if (QUALITY_PRESETS[quality]) {
        console.log(`Transcoding to ${quality}...`);
        const outputPath = await transcodeVideo(inputFile, tempDir, quality, QUALITY_PRESETS[quality]);
        const videoUrl = await uploadVideo(videoId, outputPath, quality);
        
        qualityVariants.push({
          quality,
          url: videoUrl,
          width: QUALITY_PRESETS[quality].width,
          height: QUALITY_PRESETS[quality].height,
          bitrate: QUALITY_PRESETS[quality].bitrate
        });
      }
    }

    // Update video with results
    await supabase
      .from('videos')
      .update({
        status: 'ready',
        thumbnail_url: thumbnailUrl,
        quality_variants: qualityVariants,
        updated_at: new Date().toISOString(),
        published_at: new Date().toISOString()
      })
      .eq('id', videoId);

    // Publish completion event
    await pubsub.topic('video-events').publishMessage({
      json: {
        type: 'transcode_completed',
        videoId,
        qualityVariants,
        thumbnailUrl,
        duration: metadata.duration,
        timestamp: new Date().toISOString()
      }
    });

    console.log(`✅ Video ${videoId} transcoded successfully`);

  } catch (error) {
    console.error(`❌ Transcoding failed for video ${videoId}:`, error);
    throw error;
  } finally {
    // Cleanup temp files
    try {
      await fs.rm(tempDir, { recursive: true, force: true });
    } catch (err) {
      console.error('Cleanup error:', err);
    }
  }
}

// Download file from Google Cloud Storage
async function downloadFile(gsPath: string, localPath: string): Promise<void> {
  const [bucket, ...pathParts] = gsPath.replace('gs://', '').split('/');
  const objectPath = pathParts.join('/');
  
  await storage.bucket(bucket).file(objectPath).download({ destination: localPath });
}

// Upload video to storage
async function uploadVideo(videoId: string, localPath: string, quality: string): Promise<string> {
  const fileName = `${videoId}/${quality}.mp4`;
  const file = storage.bucket(OUTPUT_BUCKET).file(fileName);
  
  await file.save(await fs.readFile(localPath), {
    metadata: {
      contentType: 'video/mp4',
      cacheControl: 'public, max-age=3600'
    }
  });

  // Make file publicly readable
  await file.makePublic();
  
  return `https://storage.googleapis.com/${OUTPUT_BUCKET}/${fileName}`;
}

// Upload thumbnail to storage
async function uploadThumbnail(videoId: string, localPath: string): Promise<string> {
  const fileName = `${videoId}/thumbnail.jpg`;
  const file = storage.bucket(THUMBNAIL_BUCKET).file(fileName);
  
  await file.save(await fs.readFile(localPath), {
    metadata: {
      contentType: 'image/jpeg',
      cacheControl: 'public, max-age=86400'
    }
  });

  // Make file publicly readable
  await file.makePublic();
  
  return `https://storage.googleapis.com/${THUMBNAIL_BUCKET}/${fileName}`;
}

// Get video metadata using ffprobe
function getVideoMetadata(inputPath: string): Promise<any> {
  return new Promise((resolve, reject) => {
    ffmpeg.ffprobe(inputPath, (err, metadata) => {
      if (err) {
        reject(err);
        return;
      }

      const videoStream = metadata.streams.find(stream => stream.codec_type === 'video');
      const audioStream = metadata.streams.find(stream => stream.codec_type === 'audio');

      resolve({
        duration: metadata.format.duration,
        size: metadata.format.size,
        bitrate: metadata.format.bit_rate,
        video: videoStream ? {
          codec: videoStream.codec_name,
          width: videoStream.width,
          height: videoStream.height,
          fps: eval(videoStream.r_frame_rate)
        } : null,
        audio: audioStream ? {
          codec: audioStream.codec_name,
          channels: audioStream.channels,
          sampleRate: audioStream.sample_rate
        } : null
      });
    });
  });
}

// Generate thumbnail from video
function generateThumbnail(inputPath: string, outputDir: string): Promise<string> {
  return new Promise((resolve, reject) => {
    const outputPath = path.join(outputDir, 'thumbnail.jpg');
    
    ffmpeg(inputPath)
      .seekInput(10) // Seek to 10 seconds
      .frames(1)
      .size('1280x720')
      .output(outputPath)
      .on('end', () => resolve(outputPath))
      .on('error', reject)
      .run();
  });
}

// Transcode video to specific quality
function transcodeVideo(inputPath: string, outputDir: string, quality: string, preset: any): Promise<string> {
  return new Promise((resolve, reject) => {
    const outputPath = path.join(outputDir, `${quality}.mp4`);
    
    ffmpeg(inputPath)
      .videoCodec('libx264')
      .audioCodec('aac')
      .size(`${preset.width}x${preset.height}`)
      .videoBitrate(preset.bitrate)
      .audioBitrate(preset.audioBitrate)
      .outputOptions([
        '-preset medium',
        '-crf 23',
        '-movflags +faststart', // Enable progressive download
        '-pix_fmt yuv420p'
      ])
      .output(outputPath)
      .on('progress', (progress) => {
        console.log(`${quality}: ${Math.round(progress.percent || 0)}% complete`);
      })
      .on('end', () => resolve(outputPath))
      .on('error', reject)
      .run();
  });
}

const port = process.env.PORT || 8080;
app.listen(port, () => {
  console.log(`🎬 Transcode service listening on port ${port}`);
});


