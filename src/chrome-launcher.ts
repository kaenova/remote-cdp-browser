import { spawn, type Subprocess } from "bun";
import { existsSync } from "fs";

export interface ChromeLauncherOptions {
  port?: number;
  headless?: boolean;
  userDataDir?: string;
  additionalArgs?: string[];
}

export class ChromeLauncher {
  private chromeProcess: Subprocess | null = null;
  private readonly port: number;
  private readonly headless: boolean;
  private readonly userDataDir: string;
  private readonly additionalArgs: string[];

  constructor(options: ChromeLauncherOptions = {}) {
    this.port = options.port ?? 9222;
    this.headless = options.headless ?? false;
    this.userDataDir = options.userDataDir ?? "/tmp/chrome-cdp";
    this.additionalArgs = options.additionalArgs ?? [];
  }

  /**
   * Find Chrome executable path based on the operating system
   */
  private getChromePath(): string {
    const possiblePaths = [
      // Docker/Linux (prioritized for container environments)
      "/usr/bin/google-chrome",
      "/usr/bin/google-chrome-stable", 
      "/usr/bin/chromium",
      "/usr/bin/chromium-browser",
      // macOS
      "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
      "/Applications/Chromium.app/Contents/MacOS/Chromium",
      // Windows (if running through WSL or similar)
      "/mnt/c/Program Files/Google/Chrome/Application/chrome.exe",
      "/mnt/c/Program Files (x86)/Google/Chrome/Application/chrome.exe",
    ];

    for (const path of possiblePaths) {
      if (existsSync(path)) {
        return path;
      }
    }

    throw new Error("Chrome executable not found. Please install Chrome or Chromium.");
  }

  /**
   * Check if running in Docker environment
   */
  private isDockerEnvironment(): boolean {
    return existsSync("/.dockerenv") || process.env.DOCKER_CONTAINER === "true";
  }

  /**
   * Launch Chrome with CDP enabled
   */
  async launch(): Promise<void> {
    if (this.chromeProcess) {
      console.log("Chrome is already running");
      return;
    }

    const chromePath = this.getChromePath();
    const args = [
      `--remote-debugging-port=${this.port}`,
      `--user-data-dir=${this.userDataDir}`,
      "--no-first-run",
      "--no-default-browser-check",
      "--disable-background-timer-throttling",
      "--disable-backgrounding-occluded-windows",
      "--disable-renderer-backgrounding",
      "--disable-features=TranslateUI",
      "--disable-ipc-flooding-protection",
      ...this.additionalArgs,
    ];

    // Add Docker-specific arguments if running in container
    if (this.isDockerEnvironment()) {
      args.push(
        "--no-sandbox",
        "--disable-setuid-sandbox",
        "--disable-dev-shm-usage",
        "--disable-gpu",
        "--remote-debugging-address=0.0.0.0"
      );
      console.log("Docker environment detected, added container-specific Chrome arguments");
    }

    if (this.headless) {
      args.push("--headless");
    }

    console.log(`Launching Chrome with CDP on port ${this.port}...`);
    console.log(`Chrome path: ${chromePath}`);
    console.log(`Arguments: ${args.join(" ")}`);

    this.chromeProcess = spawn({
      cmd: [chromePath, ...args],
      stdio: ["ignore", "pipe", "pipe"],
    });

    // Handle stdout if it's a ReadableStream
    if (this.chromeProcess.stdout && typeof this.chromeProcess.stdout !== 'number') {
      this.chromeProcess.stdout.pipeTo(new WritableStream({
        write(chunk: Uint8Array) {
          console.log(`Chrome stdout: ${new TextDecoder().decode(chunk)}`);
        }
      })).catch(console.error);
    }

    // Handle stderr if it's a ReadableStream
    if (this.chromeProcess.stderr && typeof this.chromeProcess.stderr !== 'number') {
      this.chromeProcess.stderr.pipeTo(new WritableStream({
        write(chunk: Uint8Array) {
          console.log(`Chrome stderr: ${new TextDecoder().decode(chunk)}`);
        }
      })).catch(console.error);
    }

    this.chromeProcess.exited.then((code: number) => {
      console.log(`Chrome process exited with code ${code}`);
      this.chromeProcess = null;
    }).catch((error: Error) => {
      console.error("Chrome process error:", error);
      this.chromeProcess = null;
    });

    // Wait a bit for Chrome to start up
    await new Promise((resolve) => setTimeout(resolve, 2000));

    console.log("Chrome launched successfully");
  }

  /**
   * Check if Chrome is running
   */
  isRunning(): boolean {
    return this.chromeProcess !== null && !this.chromeProcess.killed;
  }

  /**
   * Kill the Chrome process
   */
  async kill(): Promise<void> {
    if (!this.chromeProcess) {
      return;
    }

    console.log("Shutting down Chrome...");
    this.chromeProcess.kill();

    // Wait for graceful shutdown, then force kill if necessary
    try {
      await Promise.race([
        this.chromeProcess.exited,
        new Promise<void>((_, reject) => 
          setTimeout(() => reject(new Error("Timeout")), 5000)
        )
      ]);
    } catch {
      console.log("Force killing Chrome process...");
      this.chromeProcess.kill(9); // SIGKILL
    }

    this.chromeProcess = null;
    console.log("Chrome shut down");
  }

  /**
   * Get the CDP endpoint URL
   */
  getCdpUrl(): string {
    return `http://localhost:${this.port}`;
  }
}