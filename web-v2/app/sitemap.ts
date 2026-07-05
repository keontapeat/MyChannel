import { MetadataRoute } from 'next';
import { collection, getDocs, orderBy, query, limit } from 'firebase/firestore';
import { firestore } from '@/lib/firebase/config';

/**
 * Sitemap for SEO
 * Generates XML sitemap for search engines.
 *
 * Static export runs this once at build time, so video/channel routes are
 * pulled from Firestore at build time rather than hardcoded. Both `videos`
 * and `users` allow public read in firestore.rules, so no admin credentials
 * are needed — this uses the same client SDK the rest of the app uses.
 */

export const dynamic = 'force-static';

const BASE_URL = 'https://www.mychannel.live';

// Caps keep the build-time Firestore read bounded and the sitemap a
// reasonable size. Raise these (or paginate into a sitemap index) once the
// catalog grows well beyond a few thousand videos.
const MAX_VIDEOS = 2000;
const MAX_CHANNELS = 500;

async function fetchVideoRoutes(): Promise<MetadataRoute.Sitemap> {
  try {
    const snap = await getDocs(
      query(collection(firestore, 'videos'), orderBy('createdAt', 'desc'), limit(MAX_VIDEOS))
    );
    const routes: MetadataRoute.Sitemap = [];
    for (const d of snap.docs) {
      const data = d.data();
      if (data.isPublic === false) continue;
      const updatedAt = data.updatedAt?.toDate?.() ?? data.createdAt?.toDate?.() ?? new Date();
      routes.push({
        url: `${BASE_URL}/watch/${d.id}`,
        lastModified: updatedAt,
        changeFrequency: 'weekly',
        priority: 0.8,
      });
    }
    return routes;
  } catch (error) {
    console.error('🚨 Sitemap: failed to fetch video routes:', error);
    return [];
  }
}

async function fetchChannelRoutes(): Promise<MetadataRoute.Sitemap> {
  try {
    const snap = await getDocs(
      query(collection(firestore, 'users'), orderBy('subscriberCount', 'desc'), limit(MAX_CHANNELS))
    );
    const routes: MetadataRoute.Sitemap = [];
    for (const d of snap.docs) {
      const data = d.data();
      if (!data.username) continue;
      routes.push({
        url: `${BASE_URL}/profile/${data.username}`,
        lastModified: data.updatedAt?.toDate?.() ?? new Date(),
        changeFrequency: 'daily',
        priority: 0.6,
      });
    }
    return routes;
  } catch (error) {
    console.error('🚨 Sitemap: failed to fetch channel routes:', error);
    return [];
  }
}

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const staticRoutes: MetadataRoute.Sitemap = [
    {
      url: BASE_URL,
      lastModified: new Date(),
      changeFrequency: 'daily',
      priority: 1,
    },
    {
      url: `${BASE_URL}/flicks`,
      lastModified: new Date(),
      changeFrequency: 'hourly',
      priority: 0.9,
    },
    {
      url: `${BASE_URL}/live`,
      lastModified: new Date(),
      changeFrequency: 'hourly',
      priority: 0.9,
    },
    {
      url: `${BASE_URL}/medals`,
      lastModified: new Date(),
      changeFrequency: 'daily',
      priority: 0.8,
    },
    {
      url: `${BASE_URL}/channels`,
      lastModified: new Date(),
      changeFrequency: 'daily',
      priority: 0.7,
    },
    {
      url: `${BASE_URL}/trending`,
      lastModified: new Date(),
      changeFrequency: 'hourly',
      priority: 0.8,
    },
    {
      url: `${BASE_URL}/premieres`,
      lastModified: new Date(),
      changeFrequency: 'hourly',
      priority: 0.6,
    },
  ];

  const [videoRoutes, channelRoutes] = await Promise.all([
    fetchVideoRoutes(),
    fetchChannelRoutes(),
  ]);

  return [...staticRoutes, ...channelRoutes, ...videoRoutes];
}

