// Flick (Short-Form Video) Type Definitions

export interface Flick {
  id: string;
  videoURL: string;
  thumbnailURL: string;
  title: string;
  description: string;
  duration: number; // in seconds (max 60s)
  viewCount: number;
  likeCount: number;
  commentCount: number;
  shareCount: number;
  createdAt: Date;
  creator: {
    id: string;
    username: string;
    displayName: string;
    profileImageURL: string;
    isVerified: boolean;
  };
  tags: string[];
  musicTrack?: {
    title: string;
    artist: string;
    albumArt: string;
  };
}

export interface FlickComment {
  id: string;
  flickId: string;
  userId: string;
  text: string;
  createdAt: Date;
  likeCount: number;
  userDisplayName: string;
  userProfileImage: string;
}

