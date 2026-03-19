/**
 * Optimized Next.js Configuration
 * Lighthouse score 95+ target
 */

/** @type {import('next').NextConfig} */
const nextConfig = {
  // Enable React strict mode for better development
  reactStrictMode: true,

  // Enable SWC minification (faster than Terser)
  swcMinify: true,

  // Compiler optimizations
  compiler: {
    removeConsole: process.env.NODE_ENV === 'production',
  },

  // Image optimization
  images: {
    domains: [
      'firebasestorage.googleapis.com',
      'storage.googleapis.com',
      'lh3.googleusercontent.com',
      'image.tmdb.org',
    ],
    formats: ['image/avif', 'image/webp'],
    deviceSizes: [640, 750, 828, 1080, 1200, 1920, 2048, 3840],
    imageSizes: [16, 32, 48, 64, 96, 128, 256, 384],
    minimumCacheTTL: 60 * 60 * 24 * 30, // 30 days
  },

  // Compression
  compress: true,

  // Production optimizations
  productionBrowserSourceMaps: false,
  
  // Bundle analyzer (only in development)
  ...(process.env.ANALYZE === 'true' && {
    webpack: (config, { isServer }) => {
      if (!isServer) {
        const { BundleAnalyzerPlugin } = require('webpack-bundle-analyzer');
        config.plugins.push(
          new BundleAnalyzerPlugin({
            analyzerMode: 'static',
            reportFilename: './analyze.html',
          })
        );
      }
      return config;
    },
  }),

  // Experimental features for performance
  experimental: {
    optimizeCss: true,
    optimizePackageImports: [
      '@mui/material',
      '@mui/icons-material',
      'lucide-react',
    ],
    scrollRestoration: true,
  },

  // Headers for caching and security
  async headers() {
    return [
      {
        source: '/:path*',
        headers: [
          {
            key: 'X-DNS-Prefetch-Control',
            value: 'on',
          },
          {
            key: 'Strict-Transport-Security',
            value: 'max-age=63072000; includeSubDomains; preload',
          },
          {
            key: 'X-Content-Type-Options',
            value: 'nosniff',
          },
          {
            key: 'X-Frame-Options',
            value: 'SAMEORIGIN',
          },
          {
            key: 'X-XSS-Protection',
            value: '1; mode=block',
          },
          {
            key: 'Referrer-Policy',
            value: 'strict-origin-when-cross-origin',
          },
        ],
      },
      {
        source: '/static/:path*',
        headers: [
          {
            key: 'Cache-Control',
            value: 'public, max-age=31536000, immutable',
          },
        ],
      },
      {
        source: '/_next/image',
        headers: [
          {
            key: 'Cache-Control',
            value: 'public, max-age=31536000, immutable',
          },
        ],
      },
    ];
  },

  // Redirects for optimization
  async redirects() {
    return [
      {
        source: '/home',
        destination: '/',
        permanent: true,
      },
    ];
  },

  // Rewrites for API proxy (reduces CORS issues)
  async rewrites() {
    return [
      {
        source: '/api/ml/:path*',
        destination: 'https://:path*-fkri6ifojq-uc.a.run.app/:path*',
      },
    ];
  },

  // Output standalone for optimized Docker builds
  output: 'standalone',

  // Disable x-powered-by header
  poweredByHeader: false,

  // Generate ETags for caching
  generateEtags: true,

  // HTTP/2 Server Push (if supported)
  onDemandEntries: {
    maxInactiveAge: 60 * 1000,
    pagesBufferLength: 5,
  },
};

export default nextConfig;
