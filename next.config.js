/** @type {import('next').NextConfig} */
const nextConfig = {
  // 开启 standalone 模式，大幅缩小 Docker 镜像体积
  output: 'standalone',
}
module.exports = nextConfig