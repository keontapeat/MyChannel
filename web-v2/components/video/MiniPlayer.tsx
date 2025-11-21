'use client';

// 🔥 YOUTUBE-LEVEL PROFESSIONAL MINI PLAYER 🔥
// Floating mini player with drag, resize, and expand capabilities

import { useState, useRef, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { 
  X, Maximize2, Play, Pause, Volume2, VolumeX, SkipBack, SkipForward,
} from 'lucide-react';
import Link from 'next/link';

interface MiniPlayerProps {
  video: {
    id: string;
    title: string;
    channel: string;
    thumbnailURL: string;
  };
  onClose: () => void;
  onExpand?: () => void;
}

const MiniPlayer = ({ video, onClose, onExpand }: MiniPlayerProps) => {
  const router = useRouter();
  const [isPlaying, setIsPlaying] = useState(true);
  const [isMuted, setIsMuted] = useState(false);
  const [position, setPosition] = useState({ x: 20, y: window.innerHeight - 240 });
  const [size, setSize] = useState({ width: 400, height: 225 });
  const [isDragging, setIsDragging] = useState(false);
  const [isResizing, setIsResizing] = useState(false);
  const [dragStart, setDragStart] = useState({ x: 0, y: 0 });
  const [resizeStart, setResizeStart] = useState({ x: 0, y: 0, width: 0, height: 0 });
  const [isHovered, setIsHovered] = useState(false);
  
  const playerRef = useRef<HTMLDivElement>(null);
  const videoRef = useRef<HTMLVideoElement>(null);

  // Minimum and maximum sizes
  const MIN_WIDTH = 320;
  const MIN_HEIGHT = 180;
  const MAX_WIDTH = 800;
  const MAX_HEIGHT = 450;

  // Dragging logic
  const handleMouseDown = (e: React.MouseEvent) => {
    if (isResizing) return;
    setIsDragging(true);
    setDragStart({
      x: e.clientX - position.x,
      y: e.clientY - position.y,
    });
  };

  const handleMouseMove = (e: MouseEvent) => {
    if (isDragging) {
      const newX = e.clientX - dragStart.x;
      const newY = e.clientY - dragStart.y;

      // Keep within viewport bounds
      const maxX = window.innerWidth - size.width - 20;
      const maxY = window.innerHeight - size.height - 20;

      setPosition({
        x: Math.max(20, Math.min(newX, maxX)),
        y: Math.max(20, Math.min(newY, maxY)),
      });
    }

    if (isResizing) {
      const deltaX = e.clientX - resizeStart.x;
      const deltaY = deltaX * (9 / 16); // Maintain 16:9 aspect ratio

      const newWidth = Math.max(MIN_WIDTH, Math.min(MAX_WIDTH, resizeStart.width + deltaX));
      const newHeight = Math.max(MIN_HEIGHT, Math.min(MAX_HEIGHT, newWidth * (9 / 16)));

      setSize({ width: newWidth, height: newHeight });
    }
  };

  const handleMouseUp = () => {
    setIsDragging(false);
    setIsResizing(false);
  };

  useEffect(() => {
    if (isDragging || isResizing) {
      window.addEventListener('mousemove', handleMouseMove);
      window.addEventListener('mouseup', handleMouseUp);

      return () => {
        window.removeEventListener('mousemove', handleMouseMove);
        window.removeEventListener('mouseup', handleMouseUp);
      };
    }
  }, [isDragging, isResizing, dragStart, resizeStart]);

  // Resize corner handler
  const handleResizeMouseDown = (e: React.MouseEvent) => {
    e.stopPropagation();
    setIsResizing(true);
    setResizeStart({
      x: e.clientX,
      y: e.clientY,
      width: size.width,
      height: size.height,
    });
  };

  // Play/pause toggle
  const togglePlayPause = () => {
    if (videoRef.current) {
      if (isPlaying) {
        videoRef.current.pause();
      } else {
        videoRef.current.play();
      }
      setIsPlaying(!isPlaying);
    }
  };

  // Mute toggle
  const toggleMute = () => {
    if (videoRef.current) {
      videoRef.current.muted = !isMuted;
      setIsMuted(!isMuted);
    }
  };

  // Expand to full watch page
  const handleExpand = () => {
    if (onExpand) {
      onExpand();
    } else {
      router.push(`/watch/${video.id}`);
    }
    onClose();
  };

  return (
    <div
      ref={playerRef}
      className={`
        fixed z-[999] bg-black rounded-lg overflow-hidden shadow-xl-yt
        transition-shadow duration-200
        ${isDragging ? 'cursor-grabbing shadow-2xl' : 'cursor-grab'}
        ${isHovered ? 'shadow-2xl' : 'shadow-xl-yt'}
      `}
      style={{
        left: `${position.x}px`,
        top: `${position.y}px`,
        width: `${size.width}px`,
        height: `${size.height}px`,
      }}
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
    >
      {/* Video Player */}
      <div
        className="relative w-full h-full bg-black group"
        onMouseDown={handleMouseDown}
      >
        <video
          ref={videoRef}
          src="https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
          className="w-full h-full object-cover"
          autoPlay
          loop
          muted={isMuted}
          poster={video.thumbnailURL}
        />

        {/* Controls Overlay */}
        <div
          className={`
            absolute inset-0 bg-gradient-to-t from-black/60 via-transparent to-black/40
            transition-opacity duration-200
            ${isHovered ? 'opacity-100' : 'opacity-0'}
          `}
        >
          {/* Top Bar - Title and Close */}
          <div className="absolute top-0 left-0 right-0 p-3 flex items-start justify-between">
            <div className="flex-1 min-w-0 pr-2">
              <Link
                href={`/watch/${video.id}`}
                className="block hover:text-white transition-colors"
              >
                <h3 className="text-sm font-semibold text-white line-clamp-1 leading-tight mb-0.5">
                  {video.title}
                </h3>
                <p className="text-xs text-white/80">
                  {video.channel}
                </p>
              </Link>
            </div>
            <div className="flex items-center gap-1 flex-shrink-0">
              <button
                onClick={handleExpand}
                className="p-2 rounded-full hover:bg-white/20 transition-colors"
                aria-label="Expand to full screen"
              >
                <Maximize2 size={16} className="text-white" />
              </button>
              <button
                onClick={onClose}
                className="p-2 rounded-full hover:bg-white/20 transition-colors"
                aria-label="Close mini player"
              >
                <X size={16} className="text-white" />
              </button>
            </div>
          </div>

          {/* Center Play/Pause Button */}
          <div className="absolute inset-0 flex items-center justify-center">
            <button
              onClick={togglePlayPause}
              className="w-16 h-16 rounded-full bg-white/90 hover:bg-white flex items-center justify-center transition-all hover:scale-110 btn-press"
              aria-label={isPlaying ? 'Pause' : 'Play'}
            >
              {isPlaying ? (
                <Pause size={28} className="text-black" fill="currentColor" />
              ) : (
                <Play size={28} className="text-black ml-1" fill="currentColor" />
              )}
            </button>
          </div>

          {/* Bottom Controls */}
          <div className="absolute bottom-0 left-0 right-0 p-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <button
                  onClick={togglePlayPause}
                  className="p-2 rounded-full hover:bg-white/20 transition-colors"
                  aria-label={isPlaying ? 'Pause' : 'Play'}
                >
                  {isPlaying ? (
                    <Pause size={18} className="text-white" />
                  ) : (
                    <Play size={18} className="text-white" />
                  )}
                </button>
                <button
                  onClick={toggleMute}
                  className="p-2 rounded-full hover:bg-white/20 transition-colors"
                  aria-label={isMuted ? 'Unmute' : 'Mute'}
                >
                  {isMuted ? (
                    <VolumeX size={18} className="text-white" />
                  ) : (
                    <Volume2 size={18} className="text-white" />
                  )}
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Resize Handle - Bottom Right Corner */}
      <div
        className={`
          absolute bottom-0 right-0 w-4 h-4 cursor-nwse-resize
          transition-opacity duration-200
          ${isHovered ? 'opacity-100' : 'opacity-0'}
        `}
        onMouseDown={handleResizeMouseDown}
      >
        <div className="absolute bottom-1 right-1 w-3 h-3 border-r-2 border-b-2 border-white/60"></div>
      </div>

      {/* Dragging Indicator */}
      {isDragging && (
        <div className="absolute inset-0 bg-white/10 pointer-events-none"></div>
      )}
    </div>
  );
};

export default MiniPlayer;






