FROM node:22-slim

RUN apt-get update && apt-get install -y git curl procps python3 make g++ cron tini unzip && rm -rf /var/lib/apt/lists/*

# Install Bun (required by gbrain — Node.js not supported as primary runtime)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:$PATH"

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev --prefer-online && npm cache clean --force

RUN npm install -g @anthropic-ai/claude-code@2.1.133 \
 && claude --version
ENV CLAUDE_CONFIG_DIR=/data/.claude

ENV PATH="/app/node_modules/.bin:/root/.bun/bin:$PATH"
ENV ALPHACLAW_ROOT_DIR=/data

# Clone and link gbrain — binary baked into image, brain data goes to /data/gbrain at runtime
RUN git clone https://github.com/garrytan/gbrain.git /app/gbrain \
 && cd /app/gbrain \
 && bun install \
 && bun link

ENV GBRAIN_DATA_DIR=/data/gbrain

RUN mkdir -p /data

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3000

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/entrypoint.sh"]
