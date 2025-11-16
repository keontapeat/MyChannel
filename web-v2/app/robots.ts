import { MetadataRoute } from 'next';

/**
 * robots.txt for SEO
 * Controls search engine crawling
 */

export const dynamic = 'force-static';

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: '*',
        allow: '/',
        disallow: ['/api/', '/admin/', '/studio/'],
      },
    ],
    sitemap: 'https://www.mychannel.live/sitemap.xml',
  };
}

