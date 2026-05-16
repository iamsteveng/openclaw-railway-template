FROM node:22-slim

RUN apt-get update && apt-get install -y git curl procps python3 make g++ cron tini jq && rm -rf /var/lib/apt/lists/*

# Install Bun via official image (pinned, avoids curl|bash supply-chain risk)
COPY --from=oven/bun:1.3.14 /usr/local/bin/bun /usr/local/bin/bun
ENV BUN_INSTALL=/usr/local

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev --prefer-online && npm cache clean --force

RUN npm install -g @anthropic-ai/claude-code@2.1.133 \
 && claude --version
ENV CLAUDE_CONFIG_DIR=/data/.claude

ENV PATH="/app/node_modules/.bin:$PATH"
ENV ALPHACLAW_ROOT_DIR=/data

# Clone and link gbrain — pinned to commit SHA for reproducible builds
RUN git clone https://github.com/garrytan/gbrain.git /app/gbrain \
 && cd /app/gbrain \
 && git checkout baf1a47798cb145d00bfce4fa94f85a94c8d7e07 \
 && bun install \
 && bun link

ENV GBRAIN_DATA_DIR=/data/gbrain

RUN mkdir -p /data

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3000

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/entrypoint.sh"]
