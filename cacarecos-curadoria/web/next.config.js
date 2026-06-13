/** @type {import('next').NextConfig} */
const nextConfig = {
  images: {
    remotePatterns: [
      { protocol: "https", hostname: "**.cloudfront.net" },
      { protocol: "https", hostname: "d1o6h00a1h5k7q.cloudfront.net" },
      { protocol: "https", hostname: "**.mitiendanube.com" },
    ],
  },
};
module.exports = nextConfig;
