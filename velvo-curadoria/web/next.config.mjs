/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // imagens vêm do cloudfront das casas de leilão; usamos <img> simples,
  // então não precisa de remotePatterns do next/image.
};

export default nextConfig;
