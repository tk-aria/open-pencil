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

# Build core library (needed by MCP at runtime)
RUN cd packages/core && bun run build

# Build web app (static files)
RUN bunx vite build

# Build MCP server
RUN cd packages/mcp && bun run build

# --- Production stage ---
FROM oven/bun:1-slim
WORKDIR /app

# Copy workspace metadata
COPY --from=base /app/package.json ./
COPY --from=base /app/bun.lock* ./
COPY --from=base /app/packages/vue/package.json ./packages/vue/
COPY --from=base /app/packages/cli/package.json ./packages/cli/
COPY --from=base /app/packages/docs/package.json ./packages/docs/

# Copy core and mcp entirely (bun resolves src/ via "bun" condition in package.json)
COPY --from=base /app/packages/core ./packages/core
COPY --from=base /app/packages/mcp ./packages/mcp

# Create stub dirs for unused workspaces
RUN mkdir -p packages/vue/src packages/cli/src packages/docs/src

# Install all dependencies (workspace-aware)
RUN bun install --frozen-lockfile || bun install

# Copy web app static files
COPY --from=base /app/dist ./web

ENV HOST=0.0.0.0
ENV PORT=7600
ENV WS_PORT=7601
ENV OPENPENCIL_MCP_CORS_ORIGIN=*

EXPOSE 7600

CMD ["bun", "run", "packages/mcp/src/index.ts"]
