export interface MusicTrack {
  id: string;
  title: string;
  artistName: string;
  artistId?: string;
  albumName?: string;
  genre?: string;
  audioUrl: string;
  artworkUrl?: string;
  isExplicit: boolean;
  durationSeconds?: number;
  publishedAtMs?: number;
}
