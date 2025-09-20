#!/usr/bin/env bash

# Remote CDP Browser Startup Script
# This script starts the Remote CDP Browser with proper error handling

set -e

# Default values
CHROME_PORT=9222
PROXY_PORT=8080
HEADLESS=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if Chrome is installed
check_chrome() {
    local chrome_paths=(
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
        "/Applications/Chromium.app/Contents/MacOS/Chromium"
        "/usr/bin/google-chrome"
        "/usr/bin/google-chrome-stable"
        "/usr/bin/chromium"
        "/usr/bin/chromium-browser"
    )
    
    for path in "${chrome_paths[@]}"; do
        if [[ -f "$path" ]]; then
            print_status "Found Chrome at: $path"
            return 0
        fi
    done
    
    print_error "Chrome not found. Please install Chrome or Chromium."
    return 1
}

# Function to check if port is available
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null ; then
        print_error "Port $port is already in use"
        return 1
    fi
    return 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --chrome-port)
            CHROME_PORT="$2"
            shift 2
            ;;
        --proxy-port)
            PROXY_PORT="$2"
            shift 2
            ;;
        --headless)
            HEADLESS="$2"
            shift 2
            ;;
        -h|--help)
            echo "Remote CDP Browser Startup Script"
            echo ""
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --chrome-port <port>    Chrome CDP port (default: 9222)"
            echo "  --proxy-port <port>     Proxy server port (default: 8080)"
            echo "  --headless <boolean>    Run Chrome in headless mode (default: true)"
            echo "  -h, --help              Show this help message"
            echo ""
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

print_status "Starting Remote CDP Browser..."
print_status "Chrome CDP Port: $CHROME_PORT"
print_status "Proxy Server Port: $PROXY_PORT" 
print_status "Headless Mode: $HEADLESS"

# Check prerequisites
print_status "Checking prerequisites..."

# Check if Bun is installed
if ! command -v bun &> /dev/null; then
    print_error "Bun is not installed. Please install Bun from https://bun.sh/"
    exit 1
fi

# Check if Chrome is available
if ! check_chrome; then
    exit 1
fi

# Check if ports are available
if ! check_port $CHROME_PORT; then
    print_warning "Chrome CDP port $CHROME_PORT is in use. The application might fail to start."
fi

if ! check_port $PROXY_PORT; then
    print_warning "Proxy server port $PROXY_PORT is in use. The application might fail to start."
fi

# Start the application
print_status "Starting application..."
exec bun run src/index.ts --chrome-port "$CHROME_PORT" --proxy-port "$PROXY_PORT" --headless "$HEADLESS"