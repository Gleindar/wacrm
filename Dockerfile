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

# Next.js production build
ENV NODE_ENV=production
RUN npm run build

# --------- Runtime ---------
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production

# Non-root user
RUN addgroup -S nextjs && adduser -S nextjs -G nextjs

# Copy only what Next.js needs at runtime
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/package.json ./package.json

# If you have custom server code, copy it here (this project uses Next start)

USER nextjs

EXPOSE 3000

# Next.js default port
CMD ["npm", "start"]

