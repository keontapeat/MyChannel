import { Metadata } from 'next';

/**
 * SEO Metadata for Watch Page
 * Generates Open Graph tags and JSON-LD structured data
 */

interface VideoMetadata {
  id: string;
  title: string;
  description: string;
  thumbnailURL: string;
  videoURL: string;
  duration: string;
  channel: {
    name: string;
    avatar: string;
  };
  views: number;
  publishedAt: string;
}

export async function generateMetadata({ params }: { params: { id: string } }): Promise<Metadata> {
  // In production, fetch video data from API/Firestore
  const video: VideoMetadata = {
    id: params.id,
    title: 'Amazing Video Title',
    description: 'Watch this amazing video on MyChannel',
    thumbnailURL: 'https://picsum.photos/1280/720',
    videoURL: `https://example.com/videos/${params.id}.mp4`,
    duration: 'PT10M30S',
    channel: {
      name: 'Creator Name',
      avatar: 'https://i.pravatar.cc/150',
    },
    views: 1234567,
    publishedAt: '2024-01-01T00:00:00Z',
  };

  return {
    title: `${video.title} - MyChannel`,
    description: video.description,
    openGraph: {
      title: video.title,
      description: video.description,
      type: 'video.other',
      url: `https://www.mychannel.live/watch/${video.id}`,
      siteName: 'MyChannel',
      images: [
        {
          url: video.thumbnailURL,
          width: 1280,
          height: 720,
          alt: video.title,
        },
      ],
      videos: [
        {
          url: video.videoURL,
          width: 1920,
          height: 1080,
          type: 'video/mp4',
        },
      ],
    },
    twitter: {
      card: 'player',
      title: video.title,
      description: video.description,
      images: [video.thumbnailURL],
      player: {
        url: `https://www.mychannel.live/watch/${video.id}`,
        width: 1280,
        height: 720,
      },
    },
    alternates: {
      canonical: `https://www.mychannel.live/watch/${video.id}`,
    },
  };
}

export function generateVideoObjectLD(video: VideoMetadata) {
  return {
    '@context': 'https://schema.org',
    '@type': 'VideoObject',
    name: video.title,
    description: video.description,
    thumbnailUrl: video.thumbnailURL,
    uploadDate: video.publishedAt,
    duration: video.duration,
    contentUrl: video.videoURL,
    embedUrl: `https://www.mychannel.live/watch/${video.id}`,
    publisher: {
      '@type': 'Organization',
      name: 'MyChannel',
      logo: {
        '@type': 'ImageObject',
        url: 'https://www.mychannel.live/logo.png',
      },
    },
    creator: {
      '@type': 'Person',
      name: video.channel.name,
      image: video.channel.avatar,
    },
    interactionStatistic: {
      '@type': 'InteractionCounter',
      interactionType: {
        '@type': 'WatchAction',
      },
      userInteractionCount: video.views,
    },
  };
}





