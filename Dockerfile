FROM node:20-alpine AS base

# ==========================================
# 1. 依赖安装阶段
# ==========================================
FROM base AS deps
# 检查 libc6-compat 是否需要 (Alpine 中常用 C 库兼容)
RUN apk add --no-cache libc6-compat
WORKDIR /app

# 复制所有可能的 lockfile，增加对 bun 的支持
COPY package.json package-lock.json* yarn.lock* pnpm-lock.yaml* bun.lock* ./

# 动态识别包管理器并安装依赖 (支持 npm, yarn, pnpm 以及最新的 bun)
RUN if [ -f yarn.lock ]; then yarn --frozen-lockfile; \
    elif [ -f package-lock.json ]; then npm ci; \
    elif [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm i --frozen-lockfile; \
    elif [ -f bun.lock ] || [ -f bun.lockb ]; then npm install -g bun && bun install --frozen-lockfile; \
    else echo "Warning: Lockfile not found." && npm install; \
    fi

# ==========================================
# 2. 构建阶段
# ==========================================
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1

# 【修复处】：去掉 echo，并且根据对应的包管理器执行 build
RUN if [ -f yarn.lock ]; then yarn run build; \
    elif [ -f package-lock.json ]; then npm run build; \
    elif [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm run build; \
    elif [ -f bun.lock ] || [ -f bun.lockb ]; then npm install -g bun && bun run build; \
    else npm run build; \
    fi

# ==========================================
# 3. 运行阶段
# ==========================================
FROM base AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# 复制 public 静态目录
COPY --from=builder /app/public ./public

# 【优化处】：为 Next.js 图片优化和缓存预先创建目录并授予权限
RUN mkdir .next
RUN chown nextjs:nodejs .next

# 复制 standalone 产物 (核心代码与静态资源)
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

CMD ["node", "server.js"]
