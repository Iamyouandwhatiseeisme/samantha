import { EventEmitter } from "events";
import { get as httpGet, request as httpRequest, IncomingMessage } from "http";

interface ToolState {
  status: string;
  input?: Record<string, unknown>;
  output?: string;
  error?: string;
  title?: string;
}

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
  metadata?: Record<string, unknown>;
}

export class OpencodeProcess extends EventEmitter {
  sessionId: string | null = null;
  private readonly serveUrl: string;
  private sseRequest: ReturnType<typeof httpGet> | null = null;
  private sseResponse: IncomingMessage | null = null;
  private stopping = false;

  constructor(serveUrl: string) {
    super();
    this.serveUrl = serveUrl;
  }

  get running(): boolean {
    return this.sseRequest !== null;
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

  async write(prompt: string, model?: string): Promise<void> {
    if (this.sseRequest) {
      this.stop();
    }
    this.stopping = false;

    try {
      // 1. Create session if needed
      if (!this.sessionId) {
        const sessionUrl = new URL("/session", this.serveUrl);
        const session = await this.postJSON(sessionUrl, {});
        this.sessionId = session.id as string;
        console.log(`[bridge:opencode] created session: ${this.sessionId}`);
      }

      // 2. Connect SSE FIRST so we don't miss events
      this.connectSSE();
      // Give the SSE connection a moment to establish
      await new Promise((resolve) => setTimeout(resolve, 100));

      // 3. Send prompt async
      const promptUrl = new URL(
        `/session/${this.sessionId}/prompt_async`,
        this.serveUrl,
      );
      const body: Record<string, unknown> = {
        parts: [{ type: "text", text: prompt }],
      };
      if (model) {
        const parts = model.split("/");
        if (parts.length === 2) {
          body.model = { providerID: parts[0], modelID: parts[1] };
        }
      }
      console.log(`[bridge:opencode] sending prompt to session ${this.sessionId}`);
      await this.postJSON(promptUrl, body);
    } catch (err) {
      console.error(
        `[bridge:opencode] write error: ${err instanceof Error ? err.message : String(err)}`,
      );
      this.emit("error", err instanceof Error ? err : new Error(String(err)));
    }
  }

  async reply(permissionID: string, response: "allow" | "deny"): Promise<void> {
    if (!this.sessionId) return;
    const url = new URL(
      `/session/${this.sessionId}/permissions/${permissionID}`,
      this.serveUrl,
    );
    console.log(
      `[bridge:opencode] replying to permission ${permissionID}: ${response}`,
    );
    await this.postJSON(url, { response });
  }

  private connectSSE(): void {
    const url = new URL("/event", this.serveUrl);
    console.log(`[bridge:opencode] connecting SSE: ${url.href}`);

    const req = httpGet(url, (res) => {
      console.log(
        `[bridge:opencode] SSE connected, status: ${res.statusCode}`,
      );
      this.sseResponse = res;

      if (res.statusCode !== 200) {
        let body = "";
        res.on("data", (chunk: Buffer) => (body += chunk.toString()));
        res.on("end", () => {
          console.error(`[bridge:opencode] SSE non-200 response: ${body}`);
          this.sseRequest = null;
          this.sseResponse = null;
          this.emit("error", new Error(`SSE connection failed: HTTP ${res.statusCode}`));
        });
        return;
      }

      let buffer = "";

      res.on("data", (chunk: Buffer) => {
        buffer += chunk.toString();
        const parts = buffer.split("\n\n");
        buffer = parts.pop() ?? "";

        for (const part of parts) {
          if (!part.trim()) continue;
          const msg = this.parseSSE(part);
          if (msg) {
            try {
              const parsed = JSON.parse(msg.data);
              this.handleMessage(parsed, msg.event);
            } catch {
              // skip unparseable
            }
          }
        }
      });

      res.on("end", () => {
        console.log("[bridge:opencode] SSE stream ended");
        this.sseRequest = null;
        this.sseResponse = null;
      });

      res.on("close", () => {
        console.log("[bridge:opencode] SSE stream closed");
        this.sseRequest = null;
        this.sseResponse = null;
      });

      res.on("error", (err: Error) => {
        console.error(`[bridge:opencode:sse] error: ${err.message}`);
        this.sseRequest = null;
        this.sseResponse = null;
        if (!this.stopping) {
          this.emit("error", err);
        }
      });
    });

    req.on("error", (err: Error) => {
      console.error(
        `[bridge:opencode:sse] request error: ${err.message}`,
      );
      if (this.sseRequest === req) {
        this.sseRequest = null;
        this.sseResponse = null;
      }
    });

    req.on("close", () => {
      console.log("[bridge:opencode:sse] request closed");
    });

    req.setTimeout(0); // No timeout for SSE
    req.end();
    this.sseRequest = req;
  }

  private parseSSE(raw: string): { event?: string; data: string } | null {
    const lines = raw.split("\n");
    let event: string | undefined;
    let data = "";

    for (const line of lines) {
      if (line.startsWith("event: ")) {
        event = line.slice(7);
      } else if (line.startsWith("data: ")) {
        data += line.slice(6);
      }
    }

    if (!data) return null;
    return { event, data };
  }

  private handleMessage(msg: Record<string, unknown>, sseEvent?: string): void {
    const type = sseEvent ?? (msg.type as string | undefined);

    switch (type) {
      case "server.connected":
        console.log("[bridge:opencode] server connected event received");
        break;

      case "step_start":
        if (msg.sessionID && !this.sessionId) {
          this.sessionId = msg.sessionID as string;
          console.log(`[bridge:opencode] session: ${this.sessionId}`);
        }
        break;

      case "step_finish":
        console.log("[bridge:opencode] step finished");
        this.sseRequest?.abort();
        this.sseRequest = null;
        this.sseResponse = null;
        this.emit("exit", 0);
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
        const state = part?.state as ToolState | undefined;
        const toolName = (part?.tool as string) ?? "unknown";
        const status = state?.status ?? "pending";
        const input = state?.input;
        let description = "";
        if (typeof input?.command === "string") {
          description = input.command;
        } else if (typeof input?.description === "string") {
          description = input.description;
        } else if (input && typeof input === "object") {
          const key = Object.keys(input as Record<string, unknown>)[0];
          if (key === "description" && typeof (input as Record<string, unknown>).description === "string") {
            description = (input as Record<string, string>).description;
          } else if (typeof (input as Record<string, unknown>).pattern === "string") {
            description = (input as Record<string, string>).pattern;
          } else if (typeof (input as Record<string, unknown>).path === "string") {
            description = (input as Record<string, string>).path;
          }
        }
        this.emit("tool", {
          tool: toolName,
          status,
          description,
          output: status === "completed" && typeof state?.output === "string" ? state.output : undefined,
          error: status === "error" && typeof state?.error === "string" ? state.error : undefined,
          title: typeof state?.title === "string" ? state.title : undefined,
          callID: part?.callID,
        } as ToolEvent);
        break;
      }

      case "permission.updated":
      case "permission": {
        const perm = msg as unknown as PermissionEvent;
        if (perm.id) {
          console.log(
            `[bridge:opencode] permission requested: ${perm.id} — ${perm.title ?? "untitled"}`,
          );
          this.emit("permission", {
            id: perm.id,
            sessionID: perm.sessionID ?? this.sessionId,
            title: perm.title,
            metadata: perm.metadata,
          } as PermissionEvent);
        }
        break;
      }

      case "error":
        this.emit("error", new Error((msg.message as string) ?? "Unknown error"));
        break;

      default:
        // Silently skip unknown types
        break;
    }
  }

  stop(): void {
    if (this.sseRequest) {
      this.stopping = true;
      console.log("[bridge:opencode] stopping SSE connection");
      this.sseRequest.abort();
      this.sseRequest = null;
      this.sseResponse = null;
    }
  }

  private postJSON(
    url: URL,
    body: unknown,
  ): Promise<Record<string, unknown>> {
    return new Promise((resolve, reject) => {
      const data = body ? JSON.stringify(body) : null;
      const req = httpRequest(
        url,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Accept: "application/json",
            ...(data
              ? { "Content-Length": String(Buffer.byteLength(data)) }
              : {}),
          },
        },
        (res) => {
          let responseData = "";
          res.on("data", (chunk: Buffer) => (responseData += chunk.toString()));
          res.on("end", () => {
            if (
              res.statusCode &&
              res.statusCode >= 200 &&
              res.statusCode < 300
            ) {
              try {
                resolve(
                  JSON.parse(responseData || "{}") as Record<string, unknown>,
                );
              } catch {
                resolve({});
              }
            } else {
              reject(new Error(`HTTP ${res.statusCode}: ${responseData}`));
            }
          });
        },
      );

      req.on("error", reject);
      req.setTimeout(10000, () => {
        req.destroy();
        reject(new Error("Request timeout"));
      });
      if (data) req.write(data);
      req.end();
    });
  }
}
