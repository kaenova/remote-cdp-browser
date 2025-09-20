#!/bin/bash

# Docker build and run scripts for Remote CDP Browser

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Function to build Docker image
build_image() {
    print_status "Building Remote CDP Browser Docker image..."
    docker build -t remote-cdp-browser:latest .
    print_status "Docker image built successfully!"
}

# Function to run container
run_container() {
    local headless=${1:-true}
    local proxy_port=${2:-8080}
    local chrome_port=${3:-9222}
    
    print_status "Starting Remote CDP Browser container..."
    print_info "Proxy Port: $proxy_port"
    print_info "Chrome CDP Port: $chrome_port"
    print_info "Headless Mode: $headless"
    
    docker run -d \
        --name remote-cdp-browser \
        -p "$proxy_port:8080" \
        -p "$chrome_port:9222" \
        -e HEADLESS="$headless" \
        -e CHROME_PORT=9222 \
        -e PROXY_PORT=8080 \
        -e DOCKER_CONTAINER=true \
        --shm-size=2gb \
        remote-cdp-browser:latest
    
    print_status "Container started! Access the proxy at http://localhost:$proxy_port"
    print_info "Chrome CDP available at http://localhost:$chrome_port"
}

# Function to stop and remove container
stop_container() {
    print_status "Stopping and removing Remote CDP Browser container..."
    docker stop remote-cdp-browser 2>/dev/null || true
    docker rm remote-cdp-browser 2>/dev/null || true
    print_status "Container stopped and removed."
}

# Function to show logs
show_logs() {
    print_status "Showing container logs..."
    docker logs -f remote-cdp-browser
}

# Function to run with Docker Compose
compose_up() {
    print_status "Starting services with Docker Compose..."
    docker-compose up -d
    print_status "Services started! Access the proxy at http://localhost:8080"
}

# Function to stop Docker Compose services
compose_down() {
    print_status "Stopping Docker Compose services..."
    docker-compose down
    print_status "Services stopped."
}

# Main script logic
case "${1:-help}" in
    build)
        build_image
        ;;
    run)
        stop_container
        build_image
        run_container "${2:-true}" "${3:-8080}" "${4:-9222}"
        ;;
    stop)
        stop_container
        ;;
    logs)
        show_logs
        ;;
    restart)
        stop_container
        build_image
        run_container "${2:-true}" "${3:-8080}" "${4:-9222}"
        ;;
    compose-up)
        compose_up
        ;;
    compose-down)
        compose_down
        ;;
    help|*)
        echo "Remote CDP Browser Docker Management Script"
        echo ""
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  build                     Build the Docker image"
        echo "  run [headless] [proxy_port] [chrome_port]"
        echo "                           Build and run container (default: true 8080 9222)"
        echo "  stop                     Stop and remove container"
        echo "  logs                     Show container logs"
        echo "  restart [headless] [proxy_port] [chrome_port]"
        echo "                           Stop, rebuild, and start container"
        echo "  compose-up               Start services with Docker Compose"
        echo "  compose-down             Stop Docker Compose services"
        echo "  help                     Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0 build"
        echo "  $0 run true 8080 9222"
        echo "  $0 run false 3000 9223"
        echo "  $0 compose-up"
        echo ""
        ;;
esac