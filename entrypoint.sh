#!/bin/sh

# Function to start 3proxy
start_3proxy() {
    echo "Starting 3proxy..."
    
    # Generate 3proxy config from template using mustpl
    /bin/mustpl \
        -f /etc/3proxy/3proxy.cfg.json \
        -o /etc/3proxy/3proxy.cfg \
        /etc/3proxy/3proxy.cfg.mustach
    
    # Start 3proxy in background
    /bin/dumb-init /bin/3proxy /etc/3proxy/3proxy.cfg &
    
    echo "3proxy started with PID $!"
}

# Function to start Chromium
start_chromium() {
    echo "Starting Chromium with CDP..."
    
    # Set Chrome flags based on environment variables  
    CHROME_FLAGS="--no-sandbox \
                  --disable-gpu \
                  --disable-dev-shm-usage \
                  --disable-setuid-sandbox \
                  --no-first-run \
                  --disable-extensions \
                  --disable-plugins \
                  --disable-default-apps \
                  --disable-background-networking \
                  --disable-sync \
                  --no-default-browser-check \
                  --disable-web-security \
                  --disable-features=VizDisplayCompositor \
                  --disable-features=TranslateUI \
                  --disable-background-timer-throttling \
                  --disable-backgrounding-occluded-windows \
                  --disable-renderer-backgrounding \
                  --disable-component-extensions-with-background-pages \
                  --user-data-dir=${USER_DATA_DIR} \
                  --remote-debugging-address=0.0.0.0 \
                  --remote-debugging-port=${CHROME_PORT}"
    
    # Add headless flag if HEADLESS is true
    if [ "$HEADLESS" = "true" ]; then
        CHROME_FLAGS="$CHROME_FLAGS --headless=new"
    fi
    
    # Ensure chrome user owns the data directory
    chown -R chrome:chrome ${USER_DATA_DIR}
    
    # Start Chromium as chrome user
    echo "Starting Chromium with flags: $CHROME_FLAGS"
    su -s /bin/sh chrome -c "chromium-browser $CHROME_FLAGS" &
    
    echo "Chromium started with PID $!"
}

# Function to handle shutdown
shutdown_handler() {
    echo "Received shutdown signal, stopping services..."
    
    # Kill all background processes
    pkill -f "3proxy"
    pkill -f "chromium-browser"
    
    echo "All services stopped."
    exit 0
}

# Set up signal handlers
trap shutdown_handler SIGTERM SIGINT

# Start services
echo "=== Starting Remote CDP Browser with 3proxy ==="
echo "Proxy port: ${PROXY_PORT:-3128}"
echo "Chrome CDP port: ${CHROME_PORT}"
echo "Headless mode: ${HEADLESS}"
echo "User data directory: ${USER_DATA_DIR}"

# Create user data directory if it doesn't exist
mkdir -p ${USER_DATA_DIR}

# Start 3proxy first
start_3proxy

# Wait a moment for 3proxy to initialize
sleep 2

# Start Chromium
start_chromium

# Wait a moment for Chromium to start
sleep 3

echo "=== Services started successfully ==="
echo "3proxy is running on port ${PROXY_PORT:-3128}"
echo "Chromium CDP is available on port ${CHROME_PORT}"
echo "Health check: curl http://localhost:${CHROME_PORT}/json/version"

# Keep the container running and wait for any child process to exit
wait