// Live Streaming Type Definitions

export interface LiveStream {
  id: string;
  title: string;
  description: string;
  thumbnailURL: string;
  hlsURL: string; // HLS manifest URL for live playback
  rtmpURL?: string; // RTMP ingest URL for streaming
  streamKey?: string; // Stream key for OBS/streaming software
  isLive: boolean;
  startedAt: Date;
  endedAt?: Date;
  viewerCount: number;
  peakViewerCount: number;
  likeCount: number;
  streamer: {
    id: string;
    username: string;
    displayName: string;
    profileImageURL: string;
    isVerified: boolean;
    subscriberCount: number;
  };
  category: string;
  tags: string[];
  chatEnabled: boolean;
  donationsEnabled: boolean;
  status: 'scheduled' | 'live' | 'ended';
  scheduledFor?: Date;
}

export interface ChatMessage {
  id: string;
  streamId: string;
  userId: string;
  username: string;
  displayName: string;
  userProfileImage: string;
  isVerified: boolean;
  isModerator: boolean;
  isStreamer: boolean;
  message: string;
  timestamp: Date;
  badges?: string[]; // subscriber, moderator, vip, etc.
}

export interface StreamerAward {
  id: string;
  category: string;
  tier: 'Silver' | 'Gold' | 'Platinum' | 'Diamond' | 'Master' | 'Legendary';
  pointsRequired: number;
  pointsEarned: number;
  achievedAt?: Date;
  icon: string;
  description: string;
}

export interface StreamerAwardsProfile {
  userId: string;
  totalPoints: number;
  totalHoursStreamed: number;
  totalViewers: number;
  averageViewers: number;
  peakViewers: number;
  totalSubscribers: number;
  totalDonations: number;
  awards: StreamerAward[];
  rank: number;
  tier: 'Silver' | 'Gold' | 'Platinum' | 'Diamond' | 'Master' | 'Legendary';
}

