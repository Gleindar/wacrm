# syntax=docker/dockerfile:1

# --------- Base ---------
FROM node:20-alpine AS base
WORKDIR /app

# --------- Dependencies ---------
FROM base AS deps
# Install libc6-compat for some native deps (safe on alpine)
RUN apk add --no-cache libc6-compat
COPY package.json package-lock.json ./
RUN npm ci

# --------- Build ---------
FROM base AS builder
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# NEXT_PUBLIC_* vars get inlined into the client bundle at build time,
# so they must exist as real env vars during `npm run build` — a
# --build-arg alone is NOT visible to the build unless re-declared
# with ARG and promoted to ENV here.
ARG NEXT_PUBLIC_SUPABASE_URL
ARG NEXT_PUBLIC_SUPABASE_ANON_KEY
ARG NEXT_PUBLIC_SITE_URL
ARG NEXT_PUBLIC_APP_LOCALE
ENV NEXT_PUBLIC_SUPABASE_URL=$NEXT_PUBLIC_SUPABASE_URL
ENV NEXT_PUBLIC_SUPABASE_ANON_KEY=$NEXT_PUBLIC_SUPABASE_ANON_KEY
ENV NEXT_PUBLIC_SITE_URL=$NEXT_PUBLIC_SITE_URL
ENV NEXT_PUBLIC_APP_LOCALE=$NEXT_PUBLIC_APP_LOCALE

# Next.js production build
ENV NODE_ENV=production
RUN npm run build

# --------- Runtime ---------
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production

# Non-root user
RUN addgroup -S nextjs && adduser -S nextjs -G nextjs

# `output: "standalone"` in next.config.ts produces a self-contained
# server bundle (server.js + only the node_modules actually needed at
# runtime) under .next/standalone. Static assets are NOT included in
# that folder and must be copied in separately.
COPY --from=builder --chown=nextjs:nextjs /app/public ./public
COPY --from=builder --chown=nextjs:nextjs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nextjs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

# Standalone output ships its own minimal server — no need for
# `npm start` (which just wraps `next start`, unavailable here since
# node_modules/.bin/next isn't copied into this image).
CMD ["node", "server.js"]