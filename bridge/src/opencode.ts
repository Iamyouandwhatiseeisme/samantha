import { EventEmitter } from "events";
import { spawn, ChildProcess } from "child_process";
import { request as httpRequest } from "http";

export interface ToolEvent {
  tool: string;
  status: string;
  description: string;
  output?: string;
  error?: string;
  title?: string;
  callID?: string;
  content?: string;
}

export interface PermissionEvent {
  id: string;
  sessionID: string;
  title?: string;
}

const postJson = (url: string): Promise<any> =>
  new Promise((resolve, reject) => {
    const target = new URL(url);
    const req = httpRequest(
      {
        hostname: target.hostname,
        port: target.port,
        path: `${target.pathname}${target.search}`,
        method: "POST",
        headers: { "Content-Type": "application/json", "Content-Length": 2 },
      },
      (res) => {
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => {
          try {
            resolve(JSON.parse(data));
          } catch {
            reject(new Error(`Failed to parse response from ${url}`));
          }
        });
      },
    );
    req.on("error", reject);
    req.end("{}");
  });

export class OpencodeProcess extends EventEmitter {
  private process: ChildProcess | null = null;
  private stopping = false;
  sessionId: string | null = null;
  private readonly serveUrl: string;
  private _durationMs?: number;
  private _inputTokens?: number;
  private _outputTokens?: number;
  private _cost?: number;
  private _textBuffers: Map<string, string> = new Map();

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

  /**
   * Create the session up front rather than waiting to latch it off the CLI's
   * `step_start` line. The event stream filters reasoning by session ID, and by
   * the time `step_start` reaches us on stdout the first deltas have already
   * been published. This mirrors what `opencode run` does internally.
   */
  private async ensureSession(projectPath?: string): Promise<string> {
    if (this.sessionId) return this.sessionId;

    const url = new URL("/session", this.serveUrl);
    if (projectPath) url.searchParams.set("directory", projectPath);
    const session = await postJson(url.href);
    if (!session?.id) throw new Error("opencode did not return a session id");

    this.sessionId = session.id as string;
    console.log(`[bridge:opencode] created session: ${this.sessionId}`);
    return this.sessionId;
  }

  async write(prompt: string, model?: string, projectPath?: string): Promise<void> {
    if (this.process) {
      this.stop();
    }
    this.stopping = false;

    const sessionId = await this.ensureSession(projectPath);
    this.emit("session", sessionId);

    const args = ["run", "--format", "json", "--auto", "--attach", this.serveUrl];
    if (model) {
      args.push("--model", model);
    }
    if (projectPath) {
      args.push("--dir", projectPath);
    }
    args.push("--session", sessionId);
    args.push(prompt);

    const ptyArgs = ["-q", "/dev/null", "opencode", ...args];
    this.process = spawn("script", ptyArgs, {
      stdio: ["ignore", "pipe", "pipe"],
      env: { ...process.env },
      detached: true,
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
      if (!this.stopping) {
        this.emit("exit", this._durationMs, this._inputTokens, this._outputTokens, this._cost);
      }
      this._durationMs = undefined;
      this._inputTokens = undefined;
      this._outputTokens = undefined;
      this._cost = undefined;
    });
  }

  private handleCliMessage(msg: Record<string, unknown>): void {
    switch (msg.type) {
      // The session is created before the CLI is spawned, so there is nothing to
      // latch here anymore.
      case "step_start":
        break;

      case "text": {
        const part = msg.part as Record<string, unknown> | undefined;
        if (part?.text) {
          const partId = (part.id as string) ?? "";
          const newText = part.text as string;
          const prevText = this._textBuffers.get(partId) ?? "";
          this._textBuffers.set(partId, newText);
          const delta = newText.slice(prevText.length);
          if (delta) {
            this.emit("output", delta);
          }
        }
        break;
      }

      case "text_delta": {
        const delta = (msg.delta as string) ?? "";
        if (delta) {
          this.emit("output", delta);
        }
        break;
      }

      case "tool":
      case "tool_use": {
        const part = msg.part as Record<string, unknown> | undefined;
        const rawMsg = part ?? (msg as Record<string, unknown>);
        const state = (part?.state ?? rawMsg.state ?? rawMsg) as Record<string, unknown> | undefined;
        const toolName = (part?.tool as string) ?? (rawMsg.name as string) ?? (rawMsg.tool as string) ?? "unknown";
        const explicitStatus = (state?.status as string) ?? "";
        const status = (explicitStatus === "completed" || explicitStatus === "error")
          ? explicitStatus : "running";
        const input = (state?.input ?? rawMsg.input) as Record<string, unknown> | undefined;
        const description = this.formatToolDesc(toolName, input, status);
        const writtenContent = this.extractToolContent(toolName, input, state as Record<string, unknown> | undefined);
        this.emit("tool", {
          tool: toolName,
          status,
          description,
          output: status === "completed" && typeof state?.output === "string"
            ? (state.output as string).slice(0, 500) : undefined,
          error: (status === "error" || rawMsg.error) ? ((state?.error ?? rawMsg.error) as string | undefined) : undefined,
          title: typeof state?.title === "string" ? state.title : undefined,
          callID: (part?.callID ?? rawMsg.callID ?? rawMsg.id) as string | undefined,
          content: writtenContent,
        } as ToolEvent);
        break;
      }

      case "tool_result": {
        const toolName = (msg.name as string) ?? (msg.tool as string) ?? "tool";
        const isError = msg.is_error === true;
        const content = typeof msg.content === "string" ? msg.content.slice(0, 500) : "";
        this.emit("tool", {
          tool: toolName,
          status: isError ? "error" : "completed",
          description: isError ? `${toolName} failed` : `${toolName} finished`,
          output: isError ? undefined : content,
          error: isError ? content : undefined,
          callID: (msg.tool_use_id ?? msg.callID ?? msg.id) as string | undefined,
          content: isError ? undefined : content,
        } as ToolEvent);
        break;
      }

      case "step_finish":
        console.log(`[bridge:opencode] step_finish full:`, JSON.stringify(msg));
        if (typeof msg.duration_ms === "number") {
          this._durationMs = msg.duration_ms;
        } else if (typeof msg.durationMs === "number") {
          this._durationMs = msg.durationMs;
        } else if (msg.usage && typeof msg.usage === "object") {
          const usage = msg.usage as Record<string, unknown>;
          if (typeof usage.duration_ms === "number") {
            this._durationMs = usage.duration_ms as number;
          } else if (typeof usage.total_duration_ms === "number") {
            this._durationMs = usage.total_duration_ms as number;
          }
        }
        const part = msg.part as Record<string, unknown> | undefined;
        if (part && part.tokens && typeof part.tokens === "object") {
          const tokens = part.tokens as Record<string, unknown>;
          if (typeof tokens.input === "number") {
            this._inputTokens = tokens.input as number;
          }
          if (typeof tokens.output === "number") {
            this._outputTokens = tokens.output as number;
          }
          console.log(`[bridge:opencode] tokens extracted: input=${this._inputTokens}, output=${this._outputTokens}`);
        }
        if (part && typeof part.cost === "number") {
          this._cost = part.cost as number;
          console.log(`[bridge:opencode] cost extracted: ${this._cost}`);
        }
        break;

      case "error":
        this.emit("error", new Error((msg.message as string) ?? "Unknown error"));
        break;

      default:
        console.log(`[bridge:opencode] unknown msg type: ${msg.type}`, JSON.stringify(msg));
        break;
    }
  }

  private formatToolDesc(tool: string, input: Record<string, unknown> | undefined, status: string): string {
    if (!input) return `${tool} (${status})`;
    const pre = status === "error" ? "\u2717 " : status === "completed" ? "\u2713 " : "";
    switch (tool) {
      case "bash":
      case "shell":
        return pre + (typeof input.command === "string" ? input.command : `${tool} (${status})`);
      case "write":
        return pre + (typeof input.filePath === "string" ? `\u270E ${input.filePath}` : `${tool} (${status})`);
      case "edit":
        return pre + (typeof input.filePath === "string" ? `\u270E ${input.filePath}` : `${tool} (${status})`);
      case "read":
      case "glob":
      case "grep": {
        const p = typeof input.path === "string" ? input.path
          : typeof input.pattern === "string" ? input.pattern
          : typeof input.filePath === "string" ? input.filePath : "";
        return pre + (p || `${tool} (${status})`);
      }
      case "webfetch":
        return pre + (typeof input.url === "string" ? input.url : `${tool} (${status})`);
      default:
        return pre + `${tool} (${status})`;
    }
  }

  private extractToolContent(
    tool: string,
    input: Record<string, unknown> | undefined,
    state: Record<string, unknown> | undefined,
  ): string | undefined {
    if (!input) return undefined;
    switch (tool) {
      case "write":
        return typeof input.content === "string" ? input.content
          : typeof state?.output === "string" ? (state.output as string).slice(0, 500) : undefined;
      case "edit":
        return typeof input.newString === "string" ? input.newString : undefined;
      case "bash":
      case "shell":
        return typeof state?.output === "string" ? (state.output as string).slice(0, 500) : undefined;
      default:
        return typeof state?.output === "string" ? (state.output as string).slice(0, 500) : undefined;
    }
  }

  stop(): void {
    if (!this.process) return;
    this.stopping = true;
    const pid = this.process.pid;
    try {
      if (pid !== undefined) process.kill(-pid, "SIGTERM");
    } catch {
      try {
        this.process.kill("SIGTERM");
      } catch {}
    }
    this.process = null;

    if (this.sessionId) {
      const url = new URL(`/session/${this.sessionId}/abort`, this.serveUrl);
      const req = httpRequest(url.href, { method: "POST", headers: { "Content-Type": "application/json" } }, (res) => {
        res.resume();
        if (res.statusCode === 200) {
          console.log(`[bridge:opencode] session ${this.sessionId} aborted`);
        } else {
          console.log(`[bridge:opencode] abort returned ${res.statusCode}`);
        }
      });
      req.on("error", (err: Error) => {
        console.error(`[bridge:opencode] abort failed: ${err.message}`);
      });
      req.end();
    }
  }

  async reply(_permissionID: string, _response: string): Promise<void> {
    // Permissions auto-approved via --auto
  }
}
