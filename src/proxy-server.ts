import { readFileSync } from "fs";
import { join } from "path";

export interface ProxyServerOptions {
  port?: number;
  targetHost?: string;
  targetPort?: number;
}

interface WebSocketData {
  targetWsUrl: string;
}

export class ProxyServer {
  private server: import("bun").Server | null = null;
  private readonly port: number;
  private readonly targetHost: string;
  private readonly targetPort: number;

  constructor(options: ProxyServerOptions = {}) {
    this.port = options.port ?? 8080;
    this.targetHost = options.targetHost ?? "localhost";
    this.targetPort = options.targetPort ?? 9222;
  }

  /**
   * Start the proxy server
   */
  async start(): Promise<void> {
    if (this.server) {
      console.log("Proxy server is already running");
      return;
    }

    console.log(`Starting proxy server on port ${this.port}...`);
    console.log(`Forwarding requests to ${this.targetHost}:${this.targetPort}`);

    this.server = Bun.serve({
      port: this.port,
      fetch: async (request: Request): Promise<Response> => {
        return this.handleRequest(request);
      },
      websocket: {
        message: (ws, message) => this.handleWebSocketMessage(ws as any, message),
        open: (ws) => this.handleWebSocketOpen(ws as any),
        close: (ws, code, message) => this.handleWebSocketClose(ws as any, code, message),
      },
      error: (error: Error): Response => {
        console.error("Server error:", error);
        return new Response("Internal Server Error", { status: 500 });
      },
    });

    console.log(`Proxy server started at http://localhost:${this.port}`);
  }

  /**
   * Handle incoming requests and forward them to Chrome CDP
   */
  private async handleRequest(request: Request): Promise<Response> {
    try {
      const url = new URL(request.url);
      
      // // Serve the test interface at the root path
      // if (url.pathname === "/" || url.pathname === "/index.html") {
      //   return this.serveTestInterface();
      // }
      
      // Check if this is a WebSocket upgrade request
      if (request.headers.get("upgrade")?.toLowerCase() === "websocket") {
        return this.handleWebSocketUpgrade(request);
      }
      
      // Construct the target URL
      const targetUrl = new URL(url.pathname + url.search, `http://${this.targetHost}:${this.targetPort}`);
      
      // Create headers for the forwarded request (excluding host header)
      const forwardHeaders = new Headers();
      for (const [key, value] of request.headers.entries()) {
        if (key.toLowerCase() !== "host") {
          forwardHeaders.set(key, value);
        }
      }

      // Create the forwarded request
      const forwardedRequest = new Request(targetUrl.toString(), {
        method: request.method,
        headers: forwardHeaders,
        body: request.body,
      });

      console.log(`${request.method} ${url.pathname} -> ${targetUrl.toString()}`);

      // Forward the request to Chrome CDP
      const response = await fetch(forwardedRequest);

      // Create response with the same status and headers
      const responseHeaders = new Headers();
      for (const [key, value] of response.headers.entries()) {
        responseHeaders.set(key, value);
      }

      // Add CORS headers if needed
      responseHeaders.set("Access-Control-Allow-Origin", "*");
      responseHeaders.set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
      responseHeaders.set("Access-Control-Allow-Headers", "*");

      return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers: responseHeaders,
      });

    } catch (error) {
      console.error("Error forwarding request:", error);
      return new Response("Proxy Error: Unable to forward request", { 
        status: 502,
        headers: {
          "Content-Type": "text/plain",
          "Access-Control-Allow-Origin": "*",
        }
      });
    }
  }

  /**
   * Check if the server is running
   */
  isRunning(): boolean {
    return this.server !== null;
  }

  /**
   * Stop the proxy server
   */
  async stop(): Promise<void> {
    if (!this.server) {
      return;
    }

    console.log("Stopping proxy server...");
    this.server.stop();
    this.server = null;
    console.log("Proxy server stopped");
  }

  /**
   * Get the server URL
   */
  getUrl(): string {
    return `http://localhost:${this.port}`;
  }

  /**
   * Handle WebSocket upgrade requests
   */
  private handleWebSocketUpgrade(request: Request): Response {
    const url = new URL(request.url);
    
    // Create WebSocket connection to Chrome CDP
    const targetWsUrl = `ws://${this.targetHost}:${this.targetPort}${url.pathname}${url.search}`;
    
    console.log(`WebSocket ${url.pathname} -> ${targetWsUrl}`);
    
    // Upgrade the connection to WebSocket
    const success = this.server?.upgrade(request, {
      data: { targetWsUrl }
    });
    
    if (!success) {
      return new Response("WebSocket upgrade failed", { status: 400 });
    }
    
    return new Response(null, { status: 101 });
  }

  /**
   * Handle WebSocket connection open
   */
  private async handleWebSocketOpen(ws: import("bun").ServerWebSocket<WebSocketData>): Promise<void> {
    try {
      const { targetWsUrl } = ws.data;
      console.log(`WebSocket opened, connecting to ${targetWsUrl}`);
      
      // Create connection to Chrome CDP WebSocket
      const targetWs = new WebSocket(targetWsUrl);
      
      // Store the target WebSocket connection
      (ws as any).targetWs = targetWs;
      
      targetWs.onopen = () => {
        console.log(`Connected to Chrome CDP WebSocket: ${targetWsUrl}`);
      };
      
      targetWs.onmessage = (event) => {
        // Forward messages from Chrome to client
        ws.send(event.data);
      };
      
      targetWs.onclose = (event) => {
        console.log(`Chrome CDP WebSocket closed: ${event.code} ${event.reason}`);
        ws.close(event.code, event.reason);
      };
      
      targetWs.onerror = (error) => {
        console.error("Chrome CDP WebSocket error:", error);
        ws.close(1011, "Upstream WebSocket error");
      };
      
    } catch (error) {
      console.error("Error setting up WebSocket connection:", error);
      ws.close(1011, "Failed to establish upstream connection");
    }
  }

  /**
   * Handle WebSocket messages from client
   */
  private handleWebSocketMessage(
    ws: import("bun").ServerWebSocket<WebSocketData>, 
    message: string | Buffer
  ): void {
    try {
      const targetWs = (ws as any).targetWs as WebSocket;
      
      if (targetWs && targetWs.readyState === WebSocket.OPEN) {
        // Forward message to Chrome CDP
        targetWs.send(message);
      } else {
        console.warn("Target WebSocket not ready, dropping message");
      }
    } catch (error) {
      console.error("Error forwarding WebSocket message:", error);
    }
  }

  /**
   * Handle WebSocket connection close
   */
  private handleWebSocketClose(
    ws: import("bun").ServerWebSocket<WebSocketData>, 
    code: number, 
    message: string
  ): void {
    try {
      const targetWs = (ws as any).targetWs as WebSocket;
      
      if (targetWs) {
        console.log(`Client WebSocket closed: ${code} ${message}`);
        targetWs.close(code, message);
      }
    } catch (error) {
      console.error("Error closing target WebSocket:", error);
    }
  }

  /**
   * Serve the test interface HTML file
   */
  private serveTestInterface(): Response {
    try {
      // Get the path to the HTML file - it's in the project root
      const htmlPath = join(process.cwd(), "test-websocket.html");
      const htmlContent = readFileSync(htmlPath, "utf-8");
      
      return new Response(htmlContent, {
        status: 200,
        headers: {
          "Content-Type": "text/html",
          "Access-Control-Allow-Origin": "*",
        },
      });
    } catch (error) {
      console.error("Error serving test interface:", error);
      return new Response("Test interface not found", {
        status: 404,
        headers: {
          "Content-Type": "text/plain",
          "Access-Control-Allow-Origin": "*",
        },
      });
    }
  }
}