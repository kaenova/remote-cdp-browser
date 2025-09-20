# Remote CDP Browser

A TypeScript Bun project that runs a Chrome process with Chrome DevTools Protocol (CDP) enabled and creates a proxy server to forward requests. This enables remote access to Chrome's debugging capa## 🐳 Docker Deployment

The application includes full Docker support with Chrome bundled in the container. This provides a completely self-contained solution that runs anywhere Docker is available.ities through a simple HTTP proxy.

## Features

- **Chrome DevTools Protocol (CDP) Proxy**: Forward HTTP and WebSocket requests to Chrome
- **WebSocket Support**: Full bidirectional WebSocket forwarding for real-time debugging
- **Headless and GUI Mode**: Configure Chrome to run in headless or visible mode
- **Docker Support**: Containerized deployment with Chrome included
- **Tab Management**: Visual interface to see and interact with Chrome tabs
- **Screenshot Capture**: Real-time screenshots of active browser tabs
- **Direct Browser Interaction**: Navigate, click, type, and inspect elements remotely
- **Interactive Test Interface**: Comprehensive HTML test page with all CDP features
- **Production Ready**: Health checks, graceful shutdown, and container optimization

## 📋 Prerequisites

- [Bun](https://bun.sh/) runtime installed
- Chrome or Chromium browser installed
- macOS, Linux, or Windows (with WSL)

## 🛠 Installation

```bash
# Clone the repository
git clone <your-repo-url>
cd remote-cdp-browser

# Install dependencies
bun install
```

## 🚦 Quick Start

### Development Mode

```bash
# Start with default settings (Chrome on 9222, Proxy on 8080)
bun run dev

# Start with custom ports
bun run dev -- --chrome-port 9223 --proxy-port 8081

# Start with headless mode (no GUI)
bun run dev -- --headless true
```

### Production Mode

```bash
# Build the project
bun run build

# Run the built version
bun run start

# Or use the startup script
./start.sh
```

### Docker Mode

```bash
# Quick start with Docker Compose
docker-compose up -d

# Or use the Docker management script
./docker.sh build
./docker.sh run

# Advanced Docker usage
./docker.sh run false 3000 9223  # GUI mode, custom ports
./docker.sh logs                 # View container logs
./docker.sh stop                 # Stop container

# Manual Docker commands
docker build -t remote-cdp-browser .
docker run -d -p 8080:8080 -p 9222:9222 \
  -e HEADLESS=true \
  --shm-size=2gb \
  remote-cdp-browser
```

## ⚙️ Configuration

### Environment Variables

Copy `.env.example` to `.env` and customize:

```bash
CHROME_PORT=9222
PROXY_PORT=8080
HEADLESS=false
USER_DATA_DIR=/tmp/remote-cdp-browser-chrome
```

### Command Line Options

```bash
bun run src/index.ts [options]

Options:
  --chrome-port <port>    Chrome CDP port (default: 9222)
  --proxy-port <port>     Proxy server port (default: 8080)
  --headless <boolean>    Run Chrome in headless mode (default: false)
  --help                  Show help message
```

### Startup Script Options

```bash
./start.sh [options]

Options:
  --chrome-port <port>    Chrome CDP port (default: 9222)
  --proxy-port <port>     Proxy server port (default: 8080)
  --headless <boolean>    Run Chrome in headless mode (default: false)
  -h, --help              Show help message
```

## 📖 Usage Examples

### Basic Usage

1. Start the application:
   ```bash
   bun run dev
   ```

2. The console will show:
   ```
   🚀 Starting Remote CDP Browser...
   Chrome CDP Port: 9222
   Proxy Server Port: 8080
   Headless: false

   ✅ Remote CDP Browser is ready!
   🌐 Proxy server: http://localhost:8080
   🔧 Chrome CDP: http://localhost:9222
   ```

3. Access Chrome DevTools through the proxy:
   ```bash
   curl http://localhost:8080/json/version
   ```

4. All requests to port 8080 will be forwarded to Chrome's CDP on port 9222

### Advanced Usage

```bash
# Custom configuration
bun run dev -- --chrome-port 9500 --proxy-port 3000 --headless false

# Production with startup script
./start.sh --chrome-port 9222 --proxy-port 8080
```

### Web Integration

```javascript
// Connect to Chrome DevTools through the proxy
const response = await fetch('http://localhost:8080/json/version');
const versionInfo = await response.json();
console.log('Chrome version:', versionInfo);

// List available targets
const targets = await fetch('http://localhost:8080/json/list');
const targetList = await targets.json();
console.log('Available targets:', targetList);

// Connect to Chrome DevTools via WebSocket through the proxy
const target = targetList[0]; // Get the first target
const ws = new WebSocket(`ws://localhost:8080/devtools/page/${target.id}`);

ws.onopen = () => {
  console.log('WebSocket connected to Chrome DevTools');
  
  // Send a CDP command
  ws.send(JSON.stringify({
    id: 1,
    method: 'Runtime.evaluate',
    params: { expression: 'window.location.href' }
  }));
};

ws.onmessage = (event) => {
  const response = JSON.parse(event.data);
  console.log('CDP Response:', response);
};

ws.onclose = () => {
  console.log('WebSocket connection closed');
};
```

## 🏗 Project Structure

```
remote-cdp-browser/
├── src/
│   ├── index.ts           # Main application entry point
│   ├── chrome-launcher.ts # Chrome process management
│   └── proxy-server.ts    # HTTP proxy server
├── dist/                  # Built JavaScript files
├── start.sh              # Production startup script
├── docker.sh             # Docker management script
├── Dockerfile            # Docker image definition
├── docker-compose.yml    # Docker Compose configuration
├── .dockerignore         # Docker build exclusions
├── test-websocket.html   # WebSocket testing interface
├── package.json          # Dependencies and scripts
├── tsconfig.json         # TypeScript configuration
├── .env.example          # Environment variables template
└── README.md             # This file
```

## � Docker Deployment

The application includes full Docker support with Chrome bundled in the container.

### Docker Features

- **Self-contained**: Includes Chrome browser in the Docker image
- **Production ready**: Optimized for container environments
- **Security**: Runs Chrome with appropriate sandbox settings
- **Health checks**: Built-in container health monitoring
- **Volume persistence**: Optional Chrome data persistence

### Quick Start with Docker

```bash
# Using Docker Compose (recommended)
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f

# Stop services  
docker-compose down
```

### Docker Management Script

The included `docker.sh` script provides easy container management:

```bash
# Build and run (headless mode, default ports)
./docker.sh run

# Run with GUI mode and custom ports
./docker.sh run false 3000 9223

# View container logs
./docker.sh logs

# Stop container
./docker.sh stop

# Restart with new settings
./docker.sh restart true 8080 9222
```

### Manual Docker Commands

```bash
# Build the image
docker build -t remote-cdp-browser .

# Run container with custom settings
docker run -d \
  --name remote-cdp-browser \
  -p 8080:8080 \
  -p 9222:9222 \
  -e HEADLESS=true \
  -e CHROME_PORT=9222 \
  -e PROXY_PORT=8080 \
  --shm-size=2gb \
  remote-cdp-browser:latest

# View logs
docker logs -f remote-cdp-browser

# Stop and remove
docker stop remote-cdp-browser
docker rm remote-cdp-browser
```

### Docker Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CHROME_PORT` | `9222` | Chrome CDP port |
| `PROXY_PORT` | `8080` | Proxy server port |
| `HEADLESS` | `true` | Run Chrome in headless mode |
| `USER_DATA_DIR` | `/app/chrome-data` | Chrome user data directory |
| `DOCKER_CONTAINER` | `true` | Automatically set in container |

### Important Docker Notes

- **Shared Memory**: Use `--shm-size=2gb` for better Chrome performance
- **Security**: Chrome runs with `--no-sandbox` in containers (standard practice)
- **Ports**: Both 8080 (proxy) and 9222 (CDP) are exposed
- **Persistence**: Chrome data can be persisted using Docker volumes
- **Health Check**: Container includes health check endpoint

## �🔧 Development

### Available Scripts

- `bun run dev` - Start in development mode with file watching
- `bun run build` - Build for production
- `bun run start` - Run production build
- `bun run type-check` - Run TypeScript type checking

### Testing WebSocket Functionality & Tab Management

A comprehensive test HTML file (`test-websocket.html`) is included for testing WebSocket forwarding and visual tab management:

1. Start the Remote CDP Browser: `bun run dev`
2. Open `test-websocket.html` in a web browser
3. Click "Refresh Tabs" to see all available Chrome tabs
4. Click "Screenshot" on any tab to capture its current screen
5. Click "Connect" to establish a WebSocket connection to a specific tab
6. Use the browser interaction controls to navigate and interact with web pages
7. Try the various CDP commands to test bidirectional communication

The test page provides a comprehensive interface featuring:

**Tab Management:**
- Visual list of all Chrome tabs/targets
- Real-time screenshot capture for each tab
- Quick connection switching between tabs
- New tab creation
- Tab type identification (page, worker, etc.)

**WebSocket Testing:**
- Connect/disconnect from Chrome CDP via WebSocket
- Send common CDP commands (evaluate JavaScript, get page info, etc.)
- View real-time CDP responses with syntax highlighting
- Monitor connection status

**Browser Interaction:**
- **Navigation Controls**: Navigate to URLs, go back/forward, reload pages
- **Mouse Actions**: Click at coordinates, right-click, double-click, mouse movement
- **Keyboard Input**: Type text, send key presses, keyboard shortcuts
- **Element Inspection**: Find elements by CSS selector with detailed information
- **Page Scrolling**: Scroll to top, bottom, or specific coordinates
- **Interactive Screenshots**: Click on screenshots to set mouse coordinates

**Screenshot Capabilities:**
- Live screenshot preview of any Chrome tab
- Automatic screenshot capture via Chrome DevTools Protocol
- Visual tab thumbnails for easy identification
- Support for different page formats and sizes
- Click-to-set mouse coordinates on screenshots

**Key Features:**
- **Visual Tab Browser**: See all Chrome tabs with titles, URLs, and types
- **Remote Browser Control**: Full interaction capabilities with any Chrome tab
- **Live Screenshots**: Capture and display current screen of any tab
- **Multi-tab Support**: Connect to different tabs without restarting
- **Real-time Updates**: Auto-refresh target list and screenshots
- **Error Handling**: Graceful handling of connection failures

### Adding Features

The application is modular and easy to extend:

- **Chrome Options**: Modify `ChromeLauncher` class in `src/chrome-launcher.ts`
- **Proxy Behavior**: Extend `ProxyServer` class in `src/proxy-server.ts`
- **Configuration**: Update `AppConfig` interface in `src/index.ts`

## 🌐 API Endpoints

All Chrome DevTools Protocol endpoints are available through the proxy:

**HTTP Endpoints:**
- `GET /json/version` - Chrome version information
- `GET /json/list` - Available debugging targets
- `GET /json/new` - Create new target
- `GET /json/close/{targetId}` - Close a target
- `GET /json/activate/{targetId}` - Activate a target

**WebSocket Endpoints:**
- `WebSocket /devtools/page/{targetId}` - Real-time CDP communication with a page target
- `WebSocket /devtools/browser` - Browser-level CDP communication

All WebSocket connections are automatically forwarded to Chrome CDP with full bidirectional message support.

## 🛡️ Security Considerations

- The proxy removes `host` headers as specified
- CORS headers are added for web access
- Chrome runs with restricted permissions
- Consider firewall rules for production deployments

## 🐛 Troubleshooting

### Chrome Launch Issues

1. **Chrome not found**: Install Chrome or Chromium
2. **Port in use**: Change ports with `--chrome-port` and `--proxy-port`
3. **Permission denied**: Check Chrome executable permissions

### Proxy Issues

1. **Connection refused**: Ensure Chrome CDP is running first
2. **CORS errors**: The proxy includes CORS headers automatically
3. **Request timeout**: Check Chrome process health

### Docker Issues

1. **Container won't start**: Check Docker logs with `./docker.sh logs`
2. **Chrome crashes in container**: Increase shared memory with `--shm-size=2gb`
3. **Permission errors**: Chrome runs as non-root user in container
4. **Port conflicts**: Ensure ports 8080 and 9222 are available on host
5. **Build failures**: Check Docker daemon is running and has sufficient resources

### General Issues

1. **TypeScript errors**: Run `bun run type-check`
2. **Build failures**: Ensure all dependencies are installed
3. **Process hanging**: Use `Ctrl+C` for graceful shutdown

## 📝 License

MIT License - see LICENSE file for details

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📞 Support

For issues and questions:
- Check the troubleshooting section
- Review Chrome DevTools Protocol documentation
- Create an issue in the repository