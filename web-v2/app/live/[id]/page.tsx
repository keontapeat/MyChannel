// Live Stream Watch Page

import LivePlayer from '@/components/live/LivePlayer';
import LiveChat from '@/components/live/LiveChat';
import LiveInfo from '@/components/live/LiveInfo';
import type { Metadata } from 'next';

// Generate static params for export
export const dynamic = 'force-static';

export async function generateStaticParams(): Promise<{ id: string }[]> {
  return [];
}

interface LiveStreamPageProps {
  params: { id: string };
}

// Mock function - replace with actual data fetching
async function getLiveStreamData(id: string) {
  return {
    id,
    title: 'Epic Gaming Session - Come Join! 🎮',
    description: 'Playing the latest game with viewers! Drop your suggestions in chat!',
    thumbnailURL: 'https://picsum.photos/1920/1080',
    hlsURL: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8', // Test HLS stream
    isLive: true,
    startedAt: new Date(Date.now() - 2 * 60 * 60 * 1000), // 2 hours ago
    viewerCount: 12543,
    peakViewerCount: 15234,
    likeCount: 8567,
    streamer: {
      id: 'streamer-1',
      username: 'epicgamer',
      displayName: 'Epic Gamer',
      profileImageURL: 'https://i.pravatar.cc/150?img=1',
      isVerified: true,
      subscriberCount: 250000,
    },
    category: 'Gaming',
    tags: ['gaming', 'fps', 'multiplayer'],
    chatEnabled: true,
    donationsEnabled: true,
    status: 'live' as const,
  };
}

export async function generateMetadata({ params }: LiveStreamPageProps): Promise<Metadata> {
  const stream = await getLiveStreamData(params.id);

  return {
    title: `${stream.title} - Live on MyChannel`,
    description: stream.description,
    openGraph: {
      title: stream.title,
      description: stream.description,
      images: [stream.thumbnailURL],
      type: 'video.other',
    },
  };
}

export default async function LiveStreamPage({ params }: LiveStreamPageProps) {
  const stream = await getLiveStreamData(params.id);

  return (
    <div className="min-h-screen bg-[rgb(var(--color-background))]">
      <div className="max-w-[1920px] mx-auto">
        <div className="grid grid-cols-1 lg:grid-cols-[1fr_400px]">
          {/* Left Column - Video Player and Info */}
          <div>
            {/* Live Player */}
            <div className="relative">
              <LivePlayer stream={stream} />
            </div>

            {/* Stream Info */}
            <div className="p-6">
              <LiveInfo stream={stream} />
            </div>
          </div>

          {/* Right Column - Live Chat */}
          <div className="h-screen sticky top-0">
            <LiveChat streamId={stream.id} chatEnabled={stream.chatEnabled} />
          </div>
        </div>
      </div>
    </div>
  );
}

