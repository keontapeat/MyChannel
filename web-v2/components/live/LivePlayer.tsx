'use client';

// Live Player Component - HLS Live Stream Player

import { useEffect, useRef, useState } from 'react';
import videojs from 'video.js';
import 'video.js/dist/video-js.css';
import type Player from 'video.js/dist/types/player';
import type { LiveStream } from '@/types/live';
import { Radio } from 'lucide-react';

interface LivePlayerProps {
  stream: LiveStream;
}

const LivePlayer = ({ stream }: LivePlayerProps) => {
  const videoRef = useRef<HTMLDivElement>(null);
  const playerRef = useRef<Player | null>(null);
  const [isReady, setIsReady] = useState(false);
  const [latency, setLatency] = useState(0);

  useEffect(() => {
    // Initialize Video.js player with HLS
    if (!playerRef.current && videoRef.current) {
      const videoElement = document.createElement('video-js');
      videoElement.classList.add('vjs-big-play-centered');
      videoRef.current.appendChild(videoElement);

      const player = playerRef.current = videojs(videoElement, {
        autoplay: true,
        controls: true,
        responsive: true,
        fluid: true,
        liveui: true,
        preload: 'auto',
        html5: {
          vhs: {
            overrideNative: true,
          },
          nativeAudioTracks: false,
          nativeVideoTracks: false,
        },
        sources: [{
          src: stream.hlsURL,
          type: 'application/x-mpegURL',
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
            'customControlSpacer',
            'playbackRateMenuButton',
            'qualitySelector',
            'fullscreenToggle',
            'pictureInPictureToggle',
          ],
        },
      });

      player.on('ready', () => {
        setIsReady(true);
        console.log('🔴 [Live Player] Ready');
      });

      player.on('error', (error: any) => {
        console.error('🚨 [Live Player] Error:', error);
      });

      // Track latency
      player.on('timeupdate', () => {
        if ((player as any).liveTracker) {
          const currentTime = player.currentTime();
          if (currentTime !== undefined) {
            const liveLatency = (player as any).liveTracker.liveCurrentTime() - currentTime;
            setLatency(Math.round(liveLatency));
          }
        }
      });
    }
  }, []);

  // Update source when stream URL changes
  useEffect(() => {
    if (playerRef.current && isReady) {
      playerRef.current.src({
        src: stream.hlsURL,
        type: 'application/x-mpegURL',
      });
    }
  }, [stream.hlsURL, isReady]);

  // Dispose player on unmount
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
    <div className="relative bg-black">
      {/* Live Badge */}
      {stream.isLive && (
        <div className="absolute top-4 left-4 z-20 flex items-center gap-2 px-3 py-1.5 bg-red-600 rounded-full">
          <Radio size={14} className="text-white animate-pulse" />
          <span className="text-white text-sm font-semibold uppercase">Live</span>
        </div>
      )}

      {/* Viewer Count */}
      {stream.isLive && (
        <div className="absolute top-4 right-4 z-20 px-3 py-1.5 bg-black/70 backdrop-blur rounded-full">
          <span className="text-white text-sm font-medium">
            {stream.viewerCount.toLocaleString()} watching
          </span>
        </div>
      )}

      {/* Latency Indicator */}
      {isReady && latency > 0 && (
        <div className="absolute top-16 right-4 z-20 px-2 py-1 bg-black/50 backdrop-blur rounded text-xs text-white/70">
          {latency}s latency
        </div>
      )}

      {/* Video Player */}
      <div data-vjs-player>
        <div ref={videoRef} />
      </div>
    </div>
  );
};

export default LivePlayer;

