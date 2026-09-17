import type { NextConfig } from 'next';

const backendUrl = process.env.KORKEM_BACKEND_URL || 'https://api.korkem.asia';

const nextConfig: NextConfig = {
  reactStrictMode: true,
  output: 'standalone',
  async rewrites() {
    return [
      {
        source: '/api/method/:path*',
        destination: `${backendUrl}/api/method/:path*`,
      },
      {
        source: '/files/:path*',
        destination: `${backendUrl}/files/:path*`,
      },
    ];
  },
};

export default nextConfig;
