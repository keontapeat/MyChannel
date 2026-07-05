'use client';

// Mini Player - Floating Picture-in-Picture Video Player

import { useState, useRef, useEffect } from 'react';
import { X, Maximize2, Volume2, VolumeX, Play, Pause } from 'lucide-react';

// Props will come from a global video player state system; none for now.
type MiniPlayerProps = Record<string, never>;

const MiniPlayer = ({}: MiniPlayerProps) => {
  const [isVisible, setIsVisible] = useState(false); // Would be controlled by global state
  const [isPlaying, setIsPlaying] = useState(false);
  const [isMuted, setIsMuted] = useState(false);
  const [isDragging, setIsDragging] = useState(false);
  const [position, setPosition] = useState({ x: 20, y: 20 }); // Bottom-right by default
  const playerRef = useRef<HTMLDivElement>(null);
  const dragStartPos = useRef({ x: 0, y: 0 });

  // Mock video data - replace with actual state
  const currentVideo = {
    id: '1',
    title: 'Sample Video Title',
    creator: 'Creator Name',
    thumbnailURL: 'https://picsum.photos/320/180',
  };

  // Drag handlers
  const handleMouseDown = (e: React.MouseEvent) => {
    if (e.target === playerRef.current || (e.target as HTMLElement).closest('.drag-handle')) {
      setIsDragging(true);
      dragStartPos.current = {
        x: e.clientX - position.x,
        y: e.clientY - position.y,
      };
    }
  };

  useEffect(() => {
    const handleMouseMove = (e: MouseEvent) => {
      if (isDragging) {
        const newX = e.clientX - dragStartPos.current.x;
        const newY = e.clientY - dragStartPos.current.y;

        // Constrain to viewport
        const maxX = window.innerWidth - 320;
        const maxY = window.innerHeight - 200;

        setPosition({
          x: Math.max(0, Math.min(newX, maxX)),
          y: Math.max(0, Math.min(newY, maxY)),
        });
      }
    };

    const handleMouseUp = () => {
      setIsDragging(false);
    };

    if (isDragging) {
      document.addEventListener('mousemove', handleMouseMove);
      document.addEventListener('mouseup', handleMouseUp);
    }

    return () => {
      document.removeEventListener('mousemove', handleMouseMove);
      document.removeEventListener('mouseup', handleMouseUp);
    };
  }, [isDragging]);

  // Don't render if not visible
  if (!isVisible) return null;

  return (
    <div
      ref={playerRef}
      onMouseDown={handleMouseDown}
      style={{
        left: `${position.x}px`,
        bottom: `${position.y}px`,
      }}
      className={`
        fixed w-80 bg-[rgb(var(--color-surface))] rounded-lg shadow-2xl overflow-hidden
        border border-[rgb(var(--color-border))] z-[10000]
        ${isDragging ? 'cursor-grabbing' : 'cursor-grab'}
      `}
    >
      {/* Drag Handle / Video */}
      <div className="drag-handle relative aspect-video bg-black group">
        {/* Video Thumbnail (would be actual video player) */}
        <img
          src={currentVideo.thumbnailURL}
          alt={currentVideo.title}
          className="w-full h-full object-cover"
        />

        {/* Play/Pause Overlay */}
        <div className="absolute inset-0 bg-black/30 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
          <button
            onClick={() => setIsPlaying(!isPlaying)}
            className="w-12 h-12 rounded-full bg-white/20 backdrop-blur-sm flex items-center justify-center hover:bg-white/30 transition-colors"
          >
            {isPlaying ? (
              <Pause size={20} className="text-white" />
            ) : (
              <Play size={20} className="text-white ml-0.5" />
            )}
          </button>
        </div>

        {/* Top Controls */}
        <div className="absolute top-0 left-0 right-0 p-2 flex items-center justify-between opacity-0 group-hover:opacity-100 transition-opacity">
          <button
            onClick={() => {/* Expand to full view */}}
            className="p-1.5 rounded-full bg-black/50 backdrop-blur-sm hover:bg-black/70 transition-colors"
            title="Expand"
          >
            <Maximize2 size={16} className="text-white" />
          </button>

          <button
            onClick={() => setIsVisible(false)}
            className="p-1.5 rounded-full bg-black/50 backdrop-blur-sm hover:bg-black/70 transition-colors"
            title="Close"
          >
            <X size={16} className="text-white" />
          </button>
        </div>

        {/* Bottom Controls */}
        <div className="absolute bottom-0 left-0 right-0 p-2 opacity-0 group-hover:opacity-100 transition-opacity">
          <div className="flex items-center gap-2">
            {/* Volume Control */}
            <button
              onClick={() => setIsMuted(!isMuted)}
              className="p-1.5 rounded-full bg-black/50 backdrop-blur-sm hover:bg-black/70 transition-colors"
            >
              {isMuted ? (
                <VolumeX size={16} className="text-white" />
              ) : (
                <Volume2 size={16} className="text-white" />
              )}
            </button>

            {/* Progress Bar */}
            <div className="flex-1 h-1 bg-white/20 rounded-full overflow-hidden">
              <div className="h-full w-1/3 bg-[rgb(var(--color-primary))]" />
            </div>
          </div>
        </div>
      </div>

      {/* Video Info */}
      <div className="p-3 bg-[rgb(var(--color-surface))]">
        <h4 className="text-sm font-medium text-[rgb(var(--color-text-primary))] line-clamp-2 mb-1">
          {currentVideo.title}
        </h4>
        <p className="text-xs text-[rgb(var(--color-text-secondary))]">
          {currentVideo.creator}
        </p>
      </div>
    </div>
  );
};

export default MiniPlayer;

