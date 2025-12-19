# Onlook Production Dockerfile - Fixed for Coolify
# Handles monorepo workspace dependencies properly

FROM oven/bun:1.3-alpine AS builder

WORKDIR /app

# Copy root package files
COPY package.json bun.lockb* ./

# Copy workspace package files for better caching
COPY apps/web/client/package.json ./apps/web/client/
COPY apps/web/template/package.json ./apps/web/template/ 2>/dev/null || true

# Install root dependencies
RUN bun install --frozen-lockfile

# Copy all source code
COPY . .

# CRITICAL: Install workspace dependencies explicitly
# This fixes the framer-motion and lodash missing errors
RUN cd /app/apps/web/client && bun install

# Build arguments - Coolify passes these automatically
ARG SUPABASE_DATABASE_URL
ARG ANTHROPIC_API_KEY
ARG NEXT_PUBLIC_SUPABASE_URL
ARG NEXT_PUBLIC_SUPABASE_ANON_KEY
ARG CSB_API_KEY
ARG NEXT_PUBLIC_APP_URL
ARG NODE_ENV=production
ARG SESSION_SECRET
ARG JWT_SECRET

# Set environment variables for build time
ENV SUPABASE_DATABASE_URL=$SUPABASE_DATABASE_URL \
    ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY \
    NEXT_PUBLIC_SUPABASE_URL=$NEXT_PUBLIC_SUPABASE_URL \
    NEXT_PUBLIC_SUPABASE_ANON_KEY=$NEXT_PUBLIC_SUPABASE_ANON_KEY \
    CSB_API_KEY=$CSB_API_KEY \
    NEXT_PUBLIC_APP_URL=$NEXT_PUBLIC_APP_URL \
    NODE_ENV=$NODE_ENV \
    SESSION_SECRET=$SESSION_SECRET \
    JWT_SECRET=$JWT_SECRET \
    NEXT_TELEMETRY_DISABLED=1

# Build the application using the standard build command
RUN bun run build

# Production stage
FROM oven/bun:1.3-alpine AS runner

WORKDIR /app

# Copy built application from builder
COPY --from=builder /app ./

# Set runtime environment
ENV NODE_ENV=production \
    PORT=3000 \
    HOSTNAME="0.0.0.0" \
    NEXT_TELEMETRY_DISABLED=1

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD bun -e "fetch('http://localhost:3000/api/health').catch(() => fetch('http://localhost:3000')).then(r => r.ok ? process.exit(0) : process.exit(1)).catch(() => process.exit(1))"

# Start the application
CMD ["bun", "run", "start"]
