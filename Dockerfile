# Use Ubuntu minimal base image
FROM ubuntu:22.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Install Chrome via .deb file and Bun in a single layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    curl \
    unzip \
    && wget -q -O chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get install -y ./chrome.deb \
    && rm chrome.deb \
    && curl -fsSL https://bun.sh/install | bash \
    && apt-get purge -y wget \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Add Bun to PATH
ENV PATH="/root/.bun/bin:$PATH"

# Set working directory
WORKDIR /app

# Copy and install dependencies
COPY package.json tsconfig.json ./
RUN bun install --production

# Copy source code
COPY src/ ./src/

# Create non-root user for Chrome
RUN groupadd -r chrome && useradd -r -g chrome -G audio,video chrome \
    && mkdir -p /home/chrome/.cache /app/data \
    && chown -R chrome:chrome /home/chrome /app/data

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

# Switch to non-root user
USER chrome

# Start command
CMD ["bun", "run", "src/index.ts"]