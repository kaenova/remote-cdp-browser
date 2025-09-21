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

# Environment variables for linuxserver/chrome
ENV PUID=911 \
    PGID=1000 \
    TZ=Etc/UTC \
    CHROME_CLI="--remote-debugging-port=9222 --remote-debugging-address=0.0.0.0 --no-sandbox --disable-setuid-sandbox --disable-dev-shm-usage --headless --disable-gpu"

# Environment variables for our app
ENV CHROME_PORT=9222 \
    PROXY_PORT=8080 \
    HEADLESS=true

# Expose ports
EXPOSE 8080 9222 3000

# Create startup script
COPY <<EOF /app/start.sh
#!/bin/bash
# Start the linuxserver chrome service in the background
/init &

# Wait for Chrome to be ready
echo "Waiting for Chrome to start..."
sleep 10

# Start our proxy server
echo "Starting proxy server..."
cd /app
exec bun run src/index.ts
EOF

RUN chmod +x /app/start.sh

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:8080/json/version || curl -f http://localhost:9222/json/version || exit 1

# Start command - use the startup script
CMD ["/app/start.sh"]