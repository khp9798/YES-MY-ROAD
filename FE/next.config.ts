import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  images: {
    remotePatterns: [
      { protocol: 'https', hostname: 'placehold.co' },
      { protocol: 'https', hostname: 'k12b201.p.ssafy.io' },
      // 테스트용
      { protocol: 'https', hostname: 'example.com' },
    ],
  },
  eslint: { dirs: ['src'], ignoreDuringBuilds: true },
}

export default nextConfig
