import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  /* Static export for Firebase Hosting */
  output: 'export',
  
  /* Fix for Next.js 15 dynamic routes */
  trailingSlash: true,
  
  /* Fail the build on type errors so broken code can't ship silently. */
  typescript: {
    ignoreBuildErrors: false,
  },
  
  /* Fail the build on ESLint errors (warnings are allowed). */
  eslint: {
    ignoreDuringBuilds: false,
  },
  
  /* Video streaming & media optimization */
  images: {
    unoptimized: true, // Required for static export
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'firebasestorage.googleapis.com',
      },
      {
        protocol: 'https',
        hostname: 'storage.googleapis.com',
      },
      {
        protocol: 'https',
        hostname: 'picsum.photos',
      },
      {
        protocol: 'https',
        hostname: 'i.pravatar.cc',
      },
      {
        protocol: 'https',
        hostname: 'commondatastorage.googleapis.com',
      },
    ],
    formats: ['image/avif', 'image/webp'],
  },
  
  /* Performance optimizations */
  experimental: {
    optimizeCss: true,
  },
  
  /* Turbopack config */
  turbopack: {
    root: '/Users/keonta/Documents/MyChannel/web-v2',
  },
};

export default nextConfig;
