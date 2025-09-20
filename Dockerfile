# Use linuxserver/chrome base image (already has Chrome installed)
FROM linuxserver/chrome:latest

# Install Bun globally
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    unzip \
    && curl -fsSL https://bun.sh/install | bash -s "bun-v1.1.29" \
    && mv ~/.bun/bin/bun /usr/local/bin/bun \
    && chmod +x /usr/local/bin/bun \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /root/.bun

# Set working directory
WORKDIR /app

# Copy and install dependencies
COPY package.json tsconfig.json ./
RUN bun install --production

# Copy source code
COPY src/ ./src/

# Create data directory and set permissions
RUN mkdir -p /app/data \
    && chown -R abc:abc /app/data

# Environment variables
ENV CHROME_PORT=9222 \
    PROXY_PORT=8080 \
    HEADLESS=true \
    USER_DATA_DIR=/app/data

# Expose ports
EXPOSE 8080 9222

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:8080/json/version || exit 1

# Switch to non-root user (abc is the default user in linuxserver/chrome)
USER abc

# Start command
CMD ["bun", "run", "src/index.ts"]