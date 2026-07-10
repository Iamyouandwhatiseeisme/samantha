import { EventEmitter } from "events";
import { spawn, ChildProcess } from "child_process";

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

export class OpencodeProcess extends EventEmitter {
  private process: ChildProcess | null = null;
  private stopping = false;
  sessionId: string | null = null;
  private readonly serveUrl: string;
  private _durationMs?: number;
  private _inputTokens?: number;
  private _outputTokens?: number;

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
      if (!this.stopping) {
        this.emit("exit", this._durationMs, this._inputTokens, this._outputTokens);
      }
      this._durationMs = undefined;
      this._inputTokens = undefined;
      this._outputTokens = undefined;
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
        if (msg.usage && typeof msg.usage === "object") {
          const usage = msg.usage as Record<string, unknown>;
          if (typeof usage.input_tokens === "number") {
            this._inputTokens = usage.input_tokens as number;
          }
          if (typeof usage.output_tokens === "number") {
            this._outputTokens = usage.output_tokens as number;
          }
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
    this.process.kill("SIGTERM");
    this.process = null;
  }

  async reply(_permissionID: string, _response: string): Promise<void> {
    // Permissions auto-approved via --auto
  }
}
