import { ChildProcess, spawn } from "child_process";
import { EventEmitter } from "events";

export class OpencodeProcess extends EventEmitter {
  private process: ChildProcess | null = null;
  private stopping = false;
  private sessionId: string | null = null;
  private readonly serveUrl: string;

  constructor(serveUrl: string) {
    super();
    this.serveUrl = serveUrl;
  }

  get running(): boolean {
    return this.process !== null && !this.process.killed;
  }

  get manualStop(): boolean {
    return this.stopping;
  }

  get currentSessionId(): string | null {
    return this.sessionId;
  }

  setSessionId(id: string): void {
    this.sessionId = id;
  }

  write(prompt: string, model?: string): void {
    if (this.process) {
      this.stop();
    }
    this.stopping = false;

    const args = ["run", "--format", "json", "--attach", this.serveUrl];
    if (model) {
      args.push("--model", model);
    }
    if (this.sessionId) {
      args.push("--session", this.sessionId);
    }
    args.push(prompt);

    this.process = spawn("opencode", args, {
      stdio: ["ignore", "pipe", "pipe"],
      env: { ...process.env },
    });

    let buffer = "";

    this.process.stdout?.on("data", (data: Buffer) => {
      buffer += data.toString();
      const lines = buffer.split("\n");
      buffer = lines.pop() ?? "";
      for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed) continue;
        try {
          const msg = JSON.parse(trimmed);
          this.handleMessage(msg);
        } catch {
          // skip unparseable lines
        }
      }
    });

    this.process.stderr?.on("data", (data: Buffer) => {
      console.error(`[bridge:opencode:stderr] ${data.toString().trim()}`);
    });

    this.process.on("error", (err: Error) => {
      console.error(`[bridge:opencode] spawn error: ${err.message}`);
      this.emit("error", err);
    });

    this.process.on("exit", (code: number | null) => {
      console.log(`[bridge:opencode] exited with code ${code}`);
      if (buffer.trim()) {
        try {
          const msg = JSON.parse(buffer.trim());
          this.handleMessage(msg);
        } catch {
          // skip trailing incomplete JSON
        }
      }
      this.process = null;
    });
  }

  private handleMessage(msg: any) {
    switch (msg.type) {
      case "step_start":
        if (msg.sessionID && !this.sessionId) {
          this.sessionId = msg.sessionID;
          console.log(`[bridge:opencode] session: ${this.sessionId}`);
        }
        break;

      case "text":
        if (msg.part?.text) {
          this.emit("output", msg.part.text);
        }
        break;

      case "thinking":
        if (msg.part?.text) {
          this.emit("thinking", msg.part.text);
        }
        break;

      case "step_finish":
        this.process = null;
        this.emit("exit", 0);
        break;

      case "error":
        this.emit("error", new Error(msg.message ?? "Unknown error"));
        break;

      default:
        break;
    }
  }

  stop(): void {
    if (!this.process) return;
    this.stopping = true;
    this.process.kill("SIGTERM");
    this.process = null;
  }
}
