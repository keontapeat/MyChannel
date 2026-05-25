/**
 * HLS/DASH Adaptive Streaming Service
 * Multi-quality video streaming with CDN integration
 */

import ffmpeg from 'fluent-ffmpeg';
import { Storage } from '@google-cloud/storage';
import path from 'path';

const storage = new Storage();
const BUCKET_NAME = process.env.GCS_BUCKET || 'mychannel-ca26d-media';

interface StreamingQuality {
  name: string;
  width: number;
  height: number;
  bitrate: string;
  audioBitrate: string;
}

const QUALITIES: StreamingQuality[] = [
  { name: '2160p', width: 3840, height: 2160, bitrate: '20000k', audioBitrate: '192k' },
  { name: '1440p', width: 2560, height: 1440, bitrate: '10000k', audioBitrate: '192k' },
  { name: '1080p', width: 1920, height: 1080, bitrate: '5000k', audioBitrate: '128k' },
  { name: '720p', width: 1280, height: 720, bitrate: '2500k', audioBitrate: '128k' },
  { name: '480p', width: 854, height: 480, bitrate: '1000k', audioBitrate: '96k' },
  { name: '360p', width: 640, height: 360, bitrate: '500k', audioBitrate: '96k' },
  { name: '240p', width: 426, height: 240, bitrate: '300k', audioBitrate: '64k' },
];

export class AdaptiveStreamingService {
  /**
   * Generate HLS playlist and segments
   */
  async generateHLS(videoId: string, inputPath: string): Promise<string> {
    const outputDir = `/tmp/hls/${videoId}`;
    const masterPlaylist = `${outputDir}/master.m3u8`;

    console.log(`🎬 [HLS] Generating adaptive stream for ${videoId}`);

    // Create variant playlists for each quality
    const variantPromises = QUALITIES.map((quality) =>
      this.createHLSVariant(inputPath, outputDir, quality)
    );

    await Promise.all(variantPromises);

    // Generate master playlist
    await this.createMasterPlaylist(outputDir, QUALITIES);

    // Upload to GCS
    await this.uploadToGCS(outputDir, videoId);

    console.log(`✅ [HLS] Stream ready: ${videoId}`);
    return `https://storage.googleapis.com/${BUCKET_NAME}/streams/${videoId}/master.m3u8`;
  }

  /**
   * Generate DASH manifest and segments
   */
  async generateDASH(videoId: string, inputPath: string): Promise<string> {
    const outputDir = `/tmp/dash/${videoId}`;
    const manifestPath = `${outputDir}/manifest.mpd`;

    console.log(`🎬 [DASH] Generating adaptive stream for ${videoId}`);

    return new Promise((resolve, reject) => {
      ffmpeg(inputPath)
        .outputOptions([
          '-f dash',
          '-seg_duration 4',
          '-use_template 1',
          '-use_timeline 1',
          '-init_seg_name init-$RepresentationID$.m4s',
          '-media_seg_name chunk-$RepresentationID$-$Number%05d$.m4s',
          '-adaptation_sets "id=0,streams=v id=1,streams=a"',
        ])
        .output(manifestPath)
        .on('end', async () => {
          await this.uploadToGCS(outputDir, videoId, 'dash');
          const url = `https://storage.googleapis.com/${BUCKET_NAME}/streams/${videoId}/manifest.mpd`;
          console.log(`✅ [DASH] Stream ready: ${videoId}`);
          resolve(url);
        })
        .on('error', reject)
        .run();
    });
  }

  private async createHLSVariant(
    inputPath: string,
    outputDir: string,
    quality: StreamingQuality
  ): Promise<void> {
    const variantDir = `${outputDir}/${quality.name}`;
    const playlistPath = `${variantDir}/playlist.m3u8`;

    return new Promise((resolve, reject) => {
      ffmpeg(inputPath)
        .outputOptions([
          `-vf scale=${quality.width}:${quality.height}`,
          `-b:v ${quality.bitrate}`,
          `-b:a ${quality.audioBitrate}`,
          '-c:v libx264',
          '-c:a aac',
          '-preset fast',
          '-g 48',
          '-sc_threshold 0',
          '-f hls',
          '-hls_time 4',
          '-hls_playlist_type vod',
          `-hls_segment_filename ${variantDir}/segment%03d.ts`,
        ])
        .output(playlistPath)
        .on('end', () => {
          console.log(`✅ [HLS] ${quality.name} variant created`);
          resolve();
        })
        .on('error', reject)
        .run();
    });
  }

  private async createMasterPlaylist(outputDir: string, qualities: StreamingQuality[]): Promise<void> {
    const fs = require('fs').promises;
    const masterPath = `${outputDir}/master.m3u8`;

    let content = '#EXTM3U\n#EXT-X-VERSION:3\n\n';

    for (const quality of qualities) {
      const bandwidth = parseInt(quality.bitrate) * 1000;
      content += `#EXT-X-STREAM-INF:BANDWIDTH=${bandwidth},RESOLUTION=${quality.width}x${quality.height}\n`;
      content += `${quality.name}/playlist.m3u8\n\n`;
    }

    await fs.writeFile(masterPath, content);
    console.log('✅ [HLS] Master playlist created');
  }

  private async uploadToGCS(localDir: string, videoId: string, format: string = 'hls'): Promise<void> {
    const bucket = storage.bucket(BUCKET_NAME);
    const fs = require('fs').promises;
    const { promisify } = require('util');
    const glob = promisify(require('glob'));

    const files = await glob(`${localDir}/**/*`, { nodir: true });

    const uploadPromises = files.map(async (filePath: string) => {
      const relativePath = path.relative(localDir, filePath);
      const destination = `streams/${videoId}/${relativePath}`;

      await bucket.upload(filePath, {
        destination,
        metadata: {
          cacheControl: 'public, max-age=31536000',
          contentType: this.getContentType(filePath),
        },
      });
    });

    await Promise.all(uploadPromises);
    console.log(`✅ [${format.toUpperCase()}] Uploaded ${files.length} files to GCS`);
  }

  private getContentType(filePath: string): string {
    const ext = path.extname(filePath).toLowerCase();
    const types: Record<string, string> = {
      '.m3u8': 'application/vnd.apple.mpegurl',
      '.mpd': 'application/dash+xml',
      '.ts': 'video/mp2t',
      '.m4s': 'video/iso.segment',
    };
    return types[ext] || 'application/octet-stream';
  }

  /**
   * Generate thumbnail sprite for seeking
   */
  async generateThumbnailSprite(videoId: string, inputPath: string): Promise<string> {
    const outputPath = `/tmp/sprites/${videoId}-sprite.jpg`;
    const vttPath = `/tmp/sprites/${videoId}-sprite.vtt`;

    return new Promise((resolve, reject) => {
      ffmpeg(inputPath)
        .outputOptions([
          '-vf fps=1/10,scale=160:90,tile=10x10',
          '-frames:v 1',
        ])
        .output(outputPath)
        .on('end', async () => {
          await this.uploadToGCS(`/tmp/sprites`, videoId, 'sprites');
          console.log(`✅ [Sprites] Thumbnail sprite created`);
          resolve(`https://storage.googleapis.com/${BUCKET_NAME}/streams/${videoId}/sprite.jpg`);
        })
        .on('error', reject)
        .run();
    });
  }
}

export const streamingService = new AdaptiveStreamingService();
export default streamingService;
