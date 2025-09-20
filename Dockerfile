# Use Ubuntu as base image for better Chrome compatibility
FROM ubuntu:22.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    # Chrome dependencies
    wget \
    gnupg \
    ca-certificates \
    apt-transport-https \
    software-properties-common \
    # Additional Chrome runtime dependencies
    fonts-liberation \
    libappindicator3-1 \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libx11-xcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    xdg-utils \
    libxss1 \
    libgconf-2-4 \
    # System utilities
    curl \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install Google Chrome
RUN wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

# Install Bun
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:$PATH"

# Create app directory
WORKDIR /app

# Copy package files
COPY package.json ./
COPY tsconfig.json ./

# Install dependencies
RUN bun install

# Copy source code
COPY src/ ./src/
COPY start.sh ./

# Make start script executable
RUN chmod +x start.sh

# Create a non-root user for running Chrome (security best practice)
RUN groupadd -r chromeuser && useradd -r -g chromeuser -G audio,video chromeuser \
    && mkdir -p /home/chromeuser/Downloads /app/chrome-data \
    && chown -R chromeuser:chromeuser /home/chromeuser /app/chrome-data

# Set environment variables
ENV CHROME_PORT=9222
ENV PROXY_PORT=8080
ENV HEADLESS=true
ENV USER_DATA_DIR=/app/chrome-data

# Expose ports
EXPOSE 8080 9222

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/json/version || exit 1

# Create startup script that switches to non-root user for Chrome
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# Function to cleanup on exit\n\
cleanup() {\n\
    echo "Cleaning up..."\n\
    pkill -f chrome || true\n\
    exit 0\n\
}\n\
\n\
# Set up signal handlers\n\
trap cleanup SIGTERM SIGINT\n\
\n\
# Start the application\n\
echo "Starting Remote CDP Browser in Docker..."\n\
echo "Chrome CDP Port: $CHROME_PORT"\n\
echo "Proxy Server Port: $PROXY_PORT"\n\
echo "Headless Mode: $HEADLESS"\n\
\n\
# Run as root but Chrome will be launched by the chromeuser\n\
exec bun run src/index.ts --chrome-port "$CHROME_PORT" --proxy-port "$PROXY_PORT" --headless "$HEADLESS"\n\
' > /app/docker-entrypoint.sh && chmod +x /app/docker-entrypoint.sh

# Switch to non-root user for final operations
USER chromeuser

# Default command
CMD ["/app/docker-entrypoint.sh"]