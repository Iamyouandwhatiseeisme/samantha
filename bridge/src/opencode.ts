import { EventEmitter } from "events";
import { spawn, ChildProcess } from "child_process";
import { get as httpGet, request as httpRequest } from "http";

export interface ToolEvent {
  tool: string;
  status: string;
  description: string;
  output?: string;
  error?: string;
  title?: string;
  callID?: string;
}

export interface PermissionEvent {
  id: string;
  sessionID: string;
  title?: string;
}

export class OpencodeProcess extends EventEmitter {
  private process: ChildProcess | null = null;
  private stopping = false;
  sessionId: string | null = null;
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

  write(prompt: string, model?: string, projectPath?: string): void {
    if (this.process) {
      this.stop();
    }
    this.stopping = false;

    const args = ["run", "--format", "json", "--auto", "--attach", this.serveUrl];
    if (model) {
      args.push("--model", model);
    }
    if (projectPath) {
      args.push("--dir", projectPath);
    }
    if (this.sessionId) {
      args.push("--session", this.sessionId);
    }
    args.push(prompt);

    // PTY via script for line-buffered stdout (real-time streaming)
    const ptyArgs = ["-q", "/dev/null", "opencode", ...args];
    this.process = spawn("script", ptyArgs, {
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
          this.handleCliMessage(msg);
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
          this.handleCliMessage(msg);
        } catch {
          // skip trailing incomplete JSON
        }
      }
      this.process = null;

      // Also emit exit event (only when not manually stopped)
      if (!this.stopping) {
        this.emit("exit", 0);
      }
    });
  }

  private handleCliMessage(msg: Record<string, unknown>): void {
    switch (msg.type) {
      case "step_start":
        if (msg.sessionID && !this.sessionId) {
          this.sessionId = msg.sessionID as string;
          console.log(`[bridge:opencode] session: ${this.sessionId}`);
        }
        break;

      case "text":
        if ((msg.part as Record<string, unknown>)?.text) {
          this.emit("output", (msg.part as Record<string, string>).text);
        }
        break;

      case "thinking":
        if ((msg.part as Record<string, unknown>)?.text) {
          this.emit("thinking", (msg.part as Record<string, string>).text);
        }
        break;

      case "tool": {
        const part = msg.part as Record<string, unknown> | undefined;
        const state = part?.state as Record<string, unknown> | undefined;
        const toolName = (part?.tool as string) ?? "unknown";
        const status = (state?.status as string) ?? "pending";
        const input = state?.input as Record<string, unknown> | undefined;
        let description = "";
        if (typeof input?.command === "string") {
          description = input.command;
        } else if (typeof input?.description === "string") {
          description = input.description;
        } else if (input && typeof input === "object") {
          const key = Object.keys(input)[0];
          description = String(input[key] ?? "");
        }
        this.emit("tool", {
          tool: toolName,
          status,
          description: description.slice(0, 200),
          output: status === "completed" && typeof state?.output === "string"
            ? (state.output as string).slice(0, 200) : undefined,
          error: status === "error" && typeof state?.error === "string"
            ? state.error as string : undefined,
          title: typeof state?.title === "string" ? state.title : undefined,
          callID: part?.callID as string | undefined,
        } as ToolEvent);
        break;
      }

      case "step_finish":
        // Exit event is already emitted on process exit
        break;

      case "error":
        this.emit("error", new Error((msg.message as string) ?? "Unknown error"));
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

  async reply(_permissionID: string, _response: string): Promise<void> {
    // Permissions are auto-approved by --auto. This stub exists for
    // protocol compatibility — interactive permission dialogs need
    // the SSE-based approach.
  }
}
