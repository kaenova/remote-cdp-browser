# Remote CDP Browser with 3proxy

A Docker container that combines [3proxy](https://github.com/3proxy/3proxy) HTTP proxy server with Chromium browser exposing Chrome DevTools Protocol (CDP) endpoints.

## Features

- **3proxy HTTP Proxy Server**: Lightweight and fast proxy server
- **Chromium with CDP**: Full Chrome browser with DevTools Protocol support
- **Dual Port Exposure**: Both proxy (3128) and CDP (9222) ports accessible
- **Configurable**: Environment variables for customization
- **Health Checks**: Built-in health monitoring
- **Production Ready**: Proper signal handling and graceful shutdown

## Quick Start

### Using Docker Compose (Recommended)

1. Clone the repository:
```bash
git clone <your-repo-url>
cd remote-cdp-browser
```

2. Copy environment file:
```bash
cp .env.example .env
```

3. Start the services:
```bash
# Production mode (headless)
docker-compose up -d

# Development mode (non-headless)
docker-compose -f docker-compose.dev.yml up -d
```

### Using Docker directly

```bash
# Build the image
docker build -t remote-cdp-browser .

# Run the container
docker run -d \
  --name remote-cdp-browser \
  -p 3128:3128 \
  -p 9222:9222 \
  -e HEADLESS=true \
  --security-opt seccomp:unconfined \
  --shm-size=2g \
  remote-cdp-browser
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CHROME_PORT` | `9222` | Port for Chrome DevTools Protocol |
| `PROXY_PORT` | `3128` | Port for 3proxy HTTP proxy |
| `HEADLESS` | `true` | Run Chrome in headless mode |
| `USER_DATA_DIR` | `/tmp/chrome-data` | Chrome user data directory |
| `PROXY_LOGIN` | `` | Optional proxy authentication username |
| `PROXY_PASSWORD` | `` | Optional proxy authentication password |

## Usage

### Accessing the Proxy

Configure your application to use the HTTP proxy:

```bash
# Using curl through the proxy
curl -x http://localhost:3128 https://httpbin.org/ip

# Set proxy environment variables
export http_proxy=http://localhost:3128
export https_proxy=http://localhost:3128
```

### Accessing Chrome DevTools Protocol

The CDP endpoint is available at `http://localhost:9222`. You can:

1. **Check browser status**:
```bash
curl http://localhost:9222/json/version
```

2. **List open tabs**:
```bash
curl http://localhost:9222/json/list
```

3. **Create a new tab**:
```bash
curl -X POST http://localhost:9222/json/new?url=https://example.com
```

4. **Connect with WebSocket** (for programmatic control):
```javascript
const CDP = require('chrome-remote-interface');

CDP({host: 'localhost', port: 9222}, async (client) => {
    const {Network, Page, Runtime} = client;
    
    await Network.enable();
    await Page.enable();
    
    await Page.navigate({url: 'https://example.com'});
    await Page.loadEventFired();
    
    const result = await Runtime.evaluate({
        expression: 'document.title'
    });
    
    console.log('Page title:', result.result.value);
    await client.close();
});
```

### Combined Usage

You can use both the proxy and CDP together. For example, configure Chrome to use the proxy for all requests while still accessing it via CDP:

```javascript
const CDP = require('chrome-remote-interface');

CDP({host: 'localhost', port: 9222}, async (client) => {
    const {Network, Page} = client;
    
    await Network.enable();
    await Page.enable();
    
    // Set proxy for this session
    await Network.setUserAgentOverride({
        userAgent: 'Mozilla/5.0 (compatible; Remote-CDP-Browser)',
    });
    
    await Page.navigate({url: 'https://httpbin.org/ip'});
    await Page.loadEventFired();
    
    await client.close();
});
```

## Health Checks

The container includes built-in health checks:

```bash
# Check if services are running
docker ps

# Check logs
docker logs remote-cdp-browser

# Manual health check
curl http://localhost:9222/json/version
```

## Development

### Building locally

```bash
# Build the image
docker build -t remote-cdp-browser:local .

# Run in development mode
docker-compose -f docker-compose.dev.yml up
```

### Debugging

1. **Check container logs**:
```bash
docker logs -f remote-cdp-browser
```

2. **Execute commands in container**:
```bash
docker exec -it remote-cdp-browser sh
```

3. **Test proxy functionality**:
```bash
# Test proxy
curl -x http://localhost:3128 https://httpbin.org/ip

# Test CDP
curl http://localhost:9222/json/version
```

## Architecture

The container runs two main services:

1. **3proxy**: HTTP proxy server running on port 3128
2. **Chromium**: Browser with CDP enabled on port 9222

Both services are managed by a custom entrypoint script that:
- Configures and starts 3proxy
- Launches Chromium with appropriate flags
- Handles graceful shutdown
- Provides health monitoring

## Security Considerations

- The container runs Chromium with `--no-sandbox` for compatibility
- Uses unprivileged users where possible
- Includes security options in docker-compose
- Consider running behind a reverse proxy in production

## Troubleshooting

### Common Issues

1. **Container fails to start**: Check if ports 3128 and 9222 are available
2. **CDP not accessible**: Ensure `--security-opt seccomp:unconfined` is set
3. **Proxy not working**: Check 3proxy configuration and logs
4. **Chrome crashes**: Increase `--shm-size` or add more memory

### Getting Help

Check the container logs for detailed error messages:
```bash
docker logs remote-cdp-browser
```

## License

[Specify your license here]