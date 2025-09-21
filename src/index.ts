import { ChromeLauncher } from "./chrome-launcher.js";
import { ProxyServer } from "./proxy-server.js";

interface AppConfig {
  chromePort: number;
  proxyPort: number;
  headless: boolean;
  proxyUsername?: string;
  proxyPassword?: string;
}

class RemoteCdpBrowser {
  private chromeLauncher: ChromeLauncher;
  private proxyServer: ProxyServer;
  private config: AppConfig;

  constructor(config: Partial<AppConfig> = {}) {
    this.config = {
      chromePort: config.chromePort ?? 9222,
      proxyPort: config.proxyPort ?? 8080,
      headless: config.headless ?? false,
    };

    this.chromeLauncher = new ChromeLauncher({
      port: this.config.chromePort,
      headless: this.config.headless,
    });

    this.proxyServer = new ProxyServer({
      port: this.config.proxyPort,
      targetHost: "localhost",
      targetPort: this.config.chromePort,
      username: this.config.proxyUsername,
      password: this.config.proxyPassword,
    });
  }

  /**
   * Start the application
   */
  async start(): Promise<void> {
    console.log("🚀 Starting Remote CDP Browser...");
    console.log(`Chrome CDP Port: ${this.config.chromePort}`);
    console.log(`Proxy Server Port: ${this.config.proxyPort}`);
    console.log(`Headless: ${this.config.headless}`);
    if (this.config.proxyUsername && this.config.proxyPassword) {
      console.log(`Proxy Authentication: ${this.config.proxyUsername}:***`);
    } else {
      console.log(`Proxy Authentication: Disabled`);
    }
    console.log("");

    try {
      // Start Chrome with CDP
      await this.chromeLauncher.launch();
      
      // Wait a bit more for Chrome to be fully ready
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      // Start the proxy server
      await this.proxyServer.start();

      console.log("");
      console.log("✅ Remote CDP Browser is ready!");
      console.log(`🌐 Proxy server: http://localhost:${this.config.proxyPort}`);
      console.log(`🔧 Chrome CDP: http://localhost:${this.config.chromePort}`);
      console.log("");
      console.log("Press Ctrl+C to stop");

    } catch (error) {
      console.error("❌ Failed to start:", error);
      await this.stop();
      process.exit(1);
    }
  }

  /**
   * Stop the application
   */
  async stop(): Promise<void> {
    console.log("");
    console.log("🛑 Shutting down Remote CDP Browser...");

    try {
      // Stop proxy server first
      if (this.proxyServer.isRunning()) {
        await this.proxyServer.stop();
      }

      // Then stop Chrome
      if (this.chromeLauncher.isRunning()) {
        await this.chromeLauncher.kill();
      }

      console.log("✅ Shutdown complete");
    } catch (error) {
      console.error("❌ Error during shutdown:", error);
    }
  }

  /**
   * Check application health
   */
  getStatus(): {
    chrome: boolean;
    proxy: boolean;
    chromeUrl: string;
    proxyUrl: string;
  } {
    return {
      chrome: this.chromeLauncher.isRunning(),
      proxy: this.proxyServer.isRunning(),
      chromeUrl: this.chromeLauncher.getCdpUrl(),
      proxyUrl: this.proxyServer.getUrl(),
    };
  }
}

/**
 * Parse command line arguments
 */
function parseArgs(): Partial<AppConfig> {
  const args = process.argv.slice(2);
  const config: Partial<AppConfig> = {};

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    
    switch (arg) {
      case "--chrome-port":
        config.chromePort = parseInt(args[++i]);
        break;
      case "--proxy-port":
        config.proxyPort = parseInt(args[++i]);
        break;
      case "--headless":
        config.headless = args[++i] !== "false";
        break;
      case "--proxy-username":
        config.proxyUsername = args[++i];
        break;
      case "--proxy-password":
        config.proxyPassword = args[++i];
        break;
      case "--help":
        console.log(`
Remote CDP Browser

Usage: bun run src/index.ts [options]

Options:
  --chrome-port <port>       Chrome CDP port (default: 9222)
  --proxy-port <port>        Proxy server port (default: 8080) 
  --headless <boolean>       Run Chrome in headless mode (default: false)
  --proxy-username <user>    Proxy authentication username
  --proxy-password <pass>    Proxy authentication password
  --help                     Show this help message

Examples:
  bun run src/index.ts
  bun run src/index.ts --chrome-port 9223 --proxy-port 8081
  bun run src/index.ts --headless true
  bun run src/index.ts --proxy-username user --proxy-password pass
        `);
        process.exit(0);
        break;
    }
  }

  return config;
}

/**
 * Main function
 */
async function main(): Promise<void> {
  const config = parseArgs();
  
  // Override with environment variables if available
  if (process.env.PROXY_USERNAME && !config.proxyUsername) {
    config.proxyUsername = process.env.PROXY_USERNAME;
  }
  if (process.env.PROXY_PASSWORD && !config.proxyPassword) {
    config.proxyPassword = process.env.PROXY_PASSWORD;
  }
  
  const app = new RemoteCdpBrowser(config);

  // Handle graceful shutdown
  const shutdown = async (signal: string) => {
    console.log(`\nReceived ${signal}, shutting down gracefully...`);
    await app.stop();
    process.exit(0);
  };

  process.on("SIGINT", () => shutdown("SIGINT"));
  process.on("SIGTERM", () => shutdown("SIGTERM"));

  // Handle uncaught exceptions
  process.on("uncaughtException", async (error) => {
    console.error("Uncaught exception:", error);
    await app.stop();
    process.exit(1);
  });

  process.on("unhandledRejection", async (reason) => {
    console.error("Unhandled rejection:", reason);
    await app.stop();
    process.exit(1);
  });

  // Start the application
  await app.start();
}

// Run the application
if (import.meta.main) {
  main().catch(async (error) => {
    console.error("Fatal error:", error);
    process.exit(1);
  });
}