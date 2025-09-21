# syntax=docker/dockerfile:1

# Build stage: Create a custom image with Chromium and 3proxy files
FROM alpine:latest AS builder

# Install Chromium and dependencies
RUN apk add --no-cache \
    chromium \
    chromium-chromedriver \
    font-noto-emoji \
    ttf-dejavu \
    ttf-droid \
    ttf-freefont \
    ttf-liberation \
    wget \
    && rm -rf /var/cache/apk/*

# Create users and groups
RUN addgroup -g 10001 3proxy \
    && adduser -D -G 3proxy -u 10001 3proxy \
    && addgroup -g 10002 chrome \
    && adduser -D -G chrome -u 10002 chrome

# Create necessary directories
RUN mkdir -p /tmp/chrome-data /etc/3proxy /usr/local/3proxy/libexec /bin \
    && chown -R chrome:chrome /tmp/chrome-data \
    && chmod 755 /tmp/chrome-data

# Copy 3proxy files from the official image
FROM tarampampam/3proxy:latest AS proxy-source

# Final stage: Combine everything
FROM alpine:latest

# Install runtime dependencies
RUN apk add --no-cache \
    chromium \
    font-noto-emoji \
    ttf-dejavu \
    ttf-droid \
    ttf-freefont \
    ttf-liberation \
    wget \
    && rm -rf /var/cache/apk/*

# Create users and groups
RUN addgroup -g 10001 3proxy \
    && adduser -D -G 3proxy -u 10001 3proxy \
    && addgroup -g 10002 chrome \
    && adduser -D -G chrome -u 10002 chrome

# Create directories
RUN mkdir -p /tmp/chrome-data /etc/3proxy /usr/local/3proxy/libexec /bin \
    && chown -R chrome:chrome /tmp/chrome-data \
    && chmod 755 /tmp/chrome-data \
    && chown -R 3proxy:3proxy /etc/3proxy

# Copy 3proxy binaries and configurations from the source image
COPY --from=proxy-source /bin/3proxy /bin/3proxy
COPY --from=proxy-source /bin/mustpl /bin/mustpl
COPY --from=proxy-source /bin/dumb-init /bin/dumb-init
COPY --from=proxy-source /usr/local/3proxy/libexec/ /usr/local/3proxy/libexec/
COPY --from=proxy-source /etc/3proxy/ /etc/3proxy/
COPY --from=proxy-source /lib/ /lib/

# Copy startup script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose proxy port (default: 3128) and Chrome CDP port
EXPOSE 3128 9222

# Set environment variables
ENV CHROME_PORT=9222
ENV PROXY_PORT=3128
ENV HEADLESS=true
ENV USER_DATA_DIR=/tmp/chrome-data

# Use custom entrypoint that starts both services
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]