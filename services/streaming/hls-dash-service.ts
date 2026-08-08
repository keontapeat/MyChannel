import ffmpeg from 'fluent-ffmpeg';
import {Storage} from '@google-cloud/storage';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';

const storage = new Storage();
const BUCKET_NAME = process.env.GCS_BUCKET || 'mychannel-ca26d-media';
const CDN_BASE_URL = (process.env.CDN_BASE_URL || '').replace(/\/$/, '');

interface StreamingQuality {
  name: string;
  width: number;
  height: number;
  bitrate: string;
  audioBitrate: string;
}

interface SourceMetadata {
  width: number;
  height: number;
  duration: number;
}

const QUALITIES: StreamingQuality[] = [
  {name: '2160p', width: 3840, height: 2160, bitrate: '20000k', audioBitrate: '192k'},
  {name: '1440p', width: 2560, height: 1440, bitrate: '10000k', audioBitrate: '192k'},
  {name: '1080p', width: 1920, height: 1080, bitrate: '5000k', audioBitrate: '128k'},
  {name: '720p', width: 1280, height: 720, bitrate: '2500k', audioBitrate: '128k'},
  {name: '480p', width: 854, height: 480, bitrate: '1000k', audioBitrate: '96k'},
  {name: '360p', width: 640, height: 360, bitrate: '500k', audioBitrate: '96k'},
  {name: '240p', width: 426, height: 240, bitrate: '300k', audioBitrate: '64k'},
];

function cleanVideoId(value: string): string {
  const videoId = String(value || '').trim();
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(videoId)) throw new Error('Invalid video ID');
  return videoId;
}

function mediaUrl(objectName: string): string {
  const encoded = objectName.split('/').map(encodeURIComponent).join('/');
  return CDN_BASE_URL
    ? `${CDN_BASE_URL}/${encoded}`
    : `https://storage.googleapis.com/${BUCKET_NAME}/${encoded}`;
}

function probeSource(inputPath: string): Promise<SourceMetadata> {
  return new Promise((resolve, reject) => {
    ffmpeg.ffprobe(inputPath, (error, metadata) => {
      if (error) return reject(error);
      const video = metadata.streams.find(stream => stream.codec_type === 'video');
      const width = Number(video?.width);
      const height = Number(video?.height);
      const duration = Number(metadata.format.duration);
      if (!video || !Number.isFinite(width) || width <= 0 ||
          !Number.isFinite(height) || height <= 0 ||
          !Number.isFinite(duration) || duration <= 0) {
        return reject(new Error('Invalid source video metadata'));
      }
      resolve({width, height, duration});
    });
  });
}

function sourceAwareQualities(source: SourceMetadata): StreamingQuality[] {
  const compatible = QUALITIES.filter(quality =>
    quality.width <= source.width && quality.height <= source.height
  );
  if (compatible.length > 0) return compatible;
  const width = Math.max(2, Math.floor(source.width / 2) * 2);
  const height = Math.max(2, Math.floor(source.height / 2) * 2);
  return [{name: 'source', width, height, bitrate: '300k', audioBitrate: '64k'}];
}

async function collectFiles(directory: string): Promise<string[]> {
  const entries = await fs.readdir(directory, {withFileTypes: true});
  const nested = await Promise.all(entries.map(async entry => {
    const fullPath = path.join(directory, entry.name);
    return entry.isDirectory() ? collectFiles(fullPath) : [fullPath];
  }));
  return nested.flat();
}

async function mapWithConcurrency<T>(
  values: T[],
  concurrency: number,
  operation: (value: T) => Promise<void>,
): Promise<void> {
  let cursor = 0;
  const workers = Array.from({length: Math.min(concurrency, values.length)}, async () => {
    while (cursor < values.length) {
      const index = cursor++;
      await operation(values[index]);
    }
  });
  await Promise.all(workers);
}

function runCommand(command: ffmpeg.FfmpegCommand): Promise<void> {
  return new Promise((resolve, reject) => {
    command.on('end', () => resolve()).on('error', reject).run();
  });
}

export class AdaptiveStreamingService {
  async generateHLS(videoIdValue: string, inputPath: string): Promise<string> {
    const videoId = cleanVideoId(videoIdValue);
    const tempRoot = await fs.mkdtemp(path.join(os.tmpdir(), 'mychannel-hls-'));
    const outputDir = path.join(tempRoot, 'output');
    try {
      await fs.mkdir(outputDir, {recursive: true});
      const source = await probeSource(inputPath);
      const qualities = sourceAwareQualities(source);
      await mapWithConcurrency(qualities, 2, quality =>
        this.createHLSVariant(inputPath, outputDir, quality)
      );
      await this.createMasterPlaylist(outputDir, qualities);
      await this.uploadToGCS(outputDir, videoId, 'hls');
      return mediaUrl(`streams/${videoId}/master.m3u8`);
    } finally {
      await fs.rm(tempRoot, {recursive: true, force: true});
    }
  }

  async generateDASH(videoIdValue: string, inputPath: string): Promise<string> {
    const videoId = cleanVideoId(videoIdValue);
    const tempRoot = await fs.mkdtemp(path.join(os.tmpdir(), 'mychannel-dash-'));
    const outputDir = path.join(tempRoot, 'output');
    const manifestPath = path.join(outputDir, 'manifest.mpd');
    try {
      await fs.mkdir(outputDir, {recursive: true});
      const source = await probeSource(inputPath);
      const qualities = sourceAwareQualities(source);
      const options: string[] = [];
      qualities.forEach((quality, index) => {
        options.push(
          '-map 0:v:0',
          `-filter:v:${index} scale=${quality.width}:${quality.height}:force_original_aspect_ratio=decrease,pad=${quality.width}:${quality.height}:(ow-iw)/2:(oh-ih)/2`,
          `-c:v:${index} libx264`,
          `-b:v:${index} ${quality.bitrate}`,
          `-maxrate:v:${index} ${quality.bitrate}`,
          `-bufsize:v:${index} ${quality.bitrate}`,
          `-g:v:${index} 120`,
          `-keyint_min:v:${index} 120`,
          `-sc_threshold:v:${index} 0`,
        );
      });
      options.push(
        '-map 0:a:0?',
        '-c:a:0 aac',
        '-b:a:0 128k',
        '-f dash',
        '-seg_duration 4',
        '-use_template 1',
        '-use_timeline 1',
        '-init_seg_name init-$RepresentationID$.m4s',
        '-media_seg_name chunk-$RepresentationID$-$Number%05d$.m4s',
        '-adaptation_sets id=0,streams=v id=1,streams=a',
      );
      await runCommand(ffmpeg(inputPath).outputOptions(options).output(manifestPath));
      await this.uploadToGCS(outputDir, videoId, 'dash');
      return mediaUrl(`streams/${videoId}/manifest.mpd`);
    } finally {
      await fs.rm(tempRoot, {recursive: true, force: true});
    }
  }

  private async createHLSVariant(
    inputPath: string,
    outputDir: string,
    quality: StreamingQuality,
  ): Promise<void> {
    const variantDir = path.join(outputDir, quality.name);
    const playlistPath = path.join(variantDir, 'playlist.m3u8');
    await fs.mkdir(variantDir, {recursive: true});
    await runCommand(
      ffmpeg(inputPath)
        .outputOptions([
          `-vf scale=${quality.width}:${quality.height}:force_original_aspect_ratio=decrease,pad=${quality.width}:${quality.height}:(ow-iw)/2:(oh-ih)/2`,
          `-b:v ${quality.bitrate}`,
          `-maxrate ${quality.bitrate}`,
          `-bufsize ${quality.bitrate}`,
          `-b:a ${quality.audioBitrate}`,
          '-c:v libx264',
          '-c:a aac',
          '-preset fast',
          '-g 120',
          '-keyint_min 120',
          '-sc_threshold 0',
          '-force_key_frames expr:gte(t,n_forced*4)',
          '-f hls',
          '-hls_time 4',
          '-hls_playlist_type vod',
          `-hls_segment_filename ${path.join(variantDir, 'segment%05d.ts')}`,
        ])
        .output(playlistPath),
    );
  }

  private async createMasterPlaylist(
    outputDir: string,
    qualities: StreamingQuality[],
  ): Promise<void> {
    let content = '#EXTM3U\n#EXT-X-VERSION:3\n\n';
    for (const quality of qualities) {
      const bandwidth = Number.parseInt(quality.bitrate, 10) * 1000;
      content += `#EXT-X-STREAM-INF:BANDWIDTH=${bandwidth},RESOLUTION=${quality.width}x${quality.height}\n`;
      content += `${quality.name}/playlist.m3u8\n\n`;
    }
    await fs.writeFile(path.join(outputDir, 'master.m3u8'), content, 'utf8');
  }

  private async uploadToGCS(
    localDir: string,
    videoId: string,
    format: string,
  ): Promise<void> {
    const bucket = storage.bucket(BUCKET_NAME);
    const files = await collectFiles(localDir);
    await mapWithConcurrency(files, 8, async filePath => {
      const relativePath = path.relative(localDir, filePath).split(path.sep).join('/');
      const isManifest = ['.m3u8', '.mpd', '.vtt'].includes(path.extname(filePath).toLowerCase());
      await bucket.upload(filePath, {
        destination: `streams/${videoId}/${relativePath}`,
        resumable: !isManifest,
        validation: 'crc32c',
        metadata: {
          cacheControl: isManifest
            ? 'public, max-age=60, must-revalidate'
            : 'public, max-age=31536000, immutable',
          contentType: this.getContentType(filePath),
        },
      });
    });
    console.log(`[${format.toUpperCase()}] uploaded ${files.length} objects for ${videoId}`);
  }

  private getContentType(filePath: string): string {
    const types: Record<string, string> = {
      '.m3u8': 'application/vnd.apple.mpegurl',
      '.mpd': 'application/dash+xml',
      '.ts': 'video/mp2t',
      '.m4s': 'video/iso.segment',
      '.jpg': 'image/jpeg',
      '.vtt': 'text/vtt',
    };
    return types[path.extname(filePath).toLowerCase()] || 'application/octet-stream';
  }

  async generateThumbnailSprite(videoIdValue: string, inputPath: string): Promise<string> {
    const videoId = cleanVideoId(videoIdValue);
    const tempRoot = await fs.mkdtemp(path.join(os.tmpdir(), 'mychannel-sprite-'));
    try {
      const source = await probeSource(inputPath);
      const interval = Math.max(10, Math.ceil(source.duration / 100));
      const spritePath = path.join(tempRoot, 'sprite.jpg');
      const vttPath = path.join(tempRoot, 'sprite.vtt');
      await runCommand(
        ffmpeg(inputPath)
          .outputOptions([
            `-vf fps=1/${interval},scale=160:90,tile=10x10`,
            '-frames:v 1',
          ])
          .output(spritePath),
      );

      const cueCount = Math.min(100, Math.ceil(source.duration / interval));
      const cues = Array.from({length: cueCount}, (_, index) => {
        const start = index * interval;
        const end = Math.min(source.duration, (index + 1) * interval);
        const x = (index % 10) * 160;
        const y = Math.floor(index / 10) * 90;
        return `${this.vttTime(start)} --> ${this.vttTime(end)}\nsprite.jpg#xywh=${x},${y},160,90\n`;
      });
      await fs.writeFile(vttPath, `WEBVTT\n\n${cues.join('\n')}`, 'utf8');
      await this.uploadToGCS(tempRoot, videoId, 'sprites');
      return mediaUrl(`streams/${videoId}/sprite.vtt`);
    } finally {
      await fs.rm(tempRoot, {recursive: true, force: true});
    }
  }

  private vttTime(totalSeconds: number): string {
    const milliseconds = Math.max(0, Math.floor(totalSeconds * 1000));
    const hours = Math.floor(milliseconds / 3_600_000);
    const minutes = Math.floor((milliseconds % 3_600_000) / 60_000);
    const seconds = Math.floor((milliseconds % 60_000) / 1000);
    const millis = milliseconds % 1000;
    return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}.${String(millis).padStart(3, '0')}`;
  }
}

export const streamingService = new AdaptiveStreamingService();
export default streamingService;
