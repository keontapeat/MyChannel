'use client';

// Video Player Component - Video.js with HLS Support

import { useEffect, useRef, useState } from 'react';
import videojs from 'video.js';
import 'video.js/dist/video-js.css';
import type Player from 'video.js/dist/types/player';

interface VideoPlayerProps {
  src: string;
  poster?: string;
  autoplay?: boolean;
  controls?: boolean;
  onTimeUpdate?: (currentTime: number) => void;
  onEnded?: () => void;
  onPlay?: () => void;
  onPause?: () => void;
}

const VideoPlayer = ({
  src,
  poster,
  autoplay = false,
  controls = true,
  onTimeUpdate,
  onEnded,
  onPlay,
  onPause,
}: VideoPlayerProps) => {
  const videoRef = useRef<HTMLDivElement>(null);
  const playerRef = useRef<Player | null>(null);
  const [isReady, setIsReady] = useState(false);

  useEffect(() => {
    // Make sure Video.js player is only initialized once
    if (!playerRef.current && videoRef.current) {
      const videoElement = document.createElement('video-js');
      videoElement.classList.add('vjs-big-play-centered');
      videoRef.current.appendChild(videoElement);

      const player = playerRef.current = videojs(videoElement, {
        autoplay,
        controls,
        responsive: true,
        fluid: true,
        preload: 'auto',
        poster,
        sources: [{
          src,
          type: src.includes('.m3u8') ? 'application/x-mpegURL' : 'video/mp4',
        }],
        controlBar: {
          children: [
            'playToggle',
            'volumePanel',
            'currentTimeDisplay',
            'timeDivider',
            'durationDisplay',
            'progressControl',
            'liveDisplay',
            'seekToLive',
            'remainingTimeDisplay',
            'customControlSpacer',
            'playbackRateMenuButton',
            'chaptersButton',
            'descriptionsButton',
            'subsCapsButton',
            'audioTrackButton',
            'qualitySelector',
            'fullscreenToggle',
            'pictureInPictureToggle',
          ],
        },
      });

      // Event listeners
      player.on('ready', () => {
        setIsReady(true);
        console.log('🎬 Video player ready');
      });

      player.on('timeupdate', () => {
        if (onTimeUpdate) {
          onTimeUpdate(player.currentTime() || 0);
        }
      });

      player.on('ended', () => {
        if (onEnded) {
          onEnded();
        }
      });

      player.on('play', () => {
        if (onPlay) {
          onPlay();
        }
      });

      player.on('pause', () => {
        if (onPause) {
          onPause();
        }
      });

      player.on('error', (error: any) => {
        console.error('🚨 Video player error:', error);
      });
    }
  }, []);

  // Update source when it changes
  useEffect(() => {
    if (playerRef.current && isReady) {
      playerRef.current.src({
        src,
        type: src.includes('.m3u8') ? 'application/x-mpegURL' : 'video/mp4',
      });
    }
  }, [src, isReady]);

  // Dispose the Video.js player when the component unmounts
  useEffect(() => {
    const player = playerRef.current;

    return () => {
      if (player && !player.isDisposed()) {
        player.dispose();
        playerRef.current = null;
      }
    };
  }, []);

  return (
    <div data-vjs-player>
      <div ref={videoRef} className="rounded-lg overflow-hidden" />
    </div>
  );
};

export default VideoPlayer;

