'use client';

// 🔥 MINI PLAYER CONTEXT - Global State Management 🔥

import { createContext, useContext, useState, ReactNode } from 'react';
import MiniPlayer from '@/components/video/MiniPlayer';

interface Video {
  id: string;
  title: string;
  channel: string;
  thumbnailURL: string;
}

interface MiniPlayerContextType {
  isOpen: boolean;
  currentVideo: Video | null;
  openMiniPlayer: (video: Video) => void;
  closeMiniPlayer: () => void;
}

const MiniPlayerContext = createContext<MiniPlayerContextType | undefined>(undefined);

export const useMiniPlayer = () => {
  const context = useContext(MiniPlayerContext);
  if (!context) {
    throw new Error('useMiniPlayer must be used within MiniPlayerProvider');
  }
  return context;
};

export const MiniPlayerProvider = ({ children }: { children: ReactNode }) => {
  const [isOpen, setIsOpen] = useState(false);
  const [currentVideo, setCurrentVideo] = useState<Video | null>(null);

  const openMiniPlayer = (video: Video) => {
    setCurrentVideo(video);
    setIsOpen(true);
  };

  const closeMiniPlayer = () => {
    setIsOpen(false);
    setCurrentVideo(null);
  };

  return (
    <MiniPlayerContext.Provider
      value={{
        isOpen,
        currentVideo,
        openMiniPlayer,
        closeMiniPlayer,
      }}
    >
      {children}
      {isOpen && currentVideo && (
        <MiniPlayer
          video={currentVideo}
          onClose={closeMiniPlayer}
        />
      )}
    </MiniPlayerContext.Provider>
  );
};






