FROM oven/bun:1 AS base
WORKDIR /app

# Install dependencies
COPY package.json bun.lock* ./
COPY packages/core/package.json packages/core/
COPY packages/mcp/package.json packages/mcp/
COPY packages/vue/package.json packages/vue/
COPY packages/cli/package.json packages/cli/
COPY packages/docs/package.json packages/docs/
RUN bun install --frozen-lockfile || bun install

# Copy source
COPY . .

# Build web app (static files)
RUN bun run build || (echo "Trying vite directly..." && bunx vite build)

# Build MCP server
RUN cd packages/mcp && bun run build

# --- Production stage ---
FROM oven/bun:1-slim
WORKDIR /app

COPY --from=base /app/packages/mcp/dist ./packages/mcp/dist
COPY --from=base /app/packages/mcp/package.json ./packages/mcp/
COPY --from=base /app/packages/core/dist ./packages/core/dist
COPY --from=base /app/packages/core/package.json ./packages/core/
COPY --from=base /app/dist ./web
COPY --from=base /app/node_modules ./node_modules
COPY --from=base /app/package.json ./

ENV HOST=0.0.0.0
ENV PORT=7600
ENV WS_PORT=7601
ENV OPENPENCIL_MCP_CORS_ORIGIN=*

EXPOSE 7600

CMD ["bun", "run", "packages/mcp/dist/index.js"]
