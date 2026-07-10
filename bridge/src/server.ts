import {
  createServer,
  get as httpGet,
  IncomingMessage,
  ServerResponse,
} from "http";
import { WebSocket, WebSocketServer } from "ws";
import { OpencodeProcess } from "./opencode";
import { OpencodeEventStream } from "./events";

interface BridgeConfig {
  port: number;
  authToken: string;
  opencodeServeUrl: string;
  restartOpencodeServe: (cwd?: string) => Promise<void>;
}

const fetchJson = (url: string): Promise<any> =>
  new Promise((resolve, reject) => {
    httpGet(url, (res) => {
      let data = "";
      res.on("data", (chunk) => (data += chunk));
      res.on("end", () => {
        try {
          resolve(JSON.parse(data));
        } catch {
          reject(new Error("Failed to parse JSON response"));
        }
      });
    }).on("error", reject);
  });

export function createBridgeServer(config: BridgeConfig) {
  const server = createServer((req: IncomingMessage, res: ServerResponse) => {
    if (req.method === "GET" && req.url === "/health") {
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ status: "ok" }));
      return;
    }
    const proxyGet = (path: string) => {
      const url = new URL(path, config.opencodeServeUrl);
      fetchJson(url.href)
        .then((body) => {
          res.writeHead(200, { "Content-Type": "application/json" });
          res.end(JSON.stringify(body));
        })
        .catch((err) => {
          res.writeHead(502, { "Content-Type": "application/json" });
          res.end(JSON.stringify({ error: err.message }));
        });
    };

    if (req.method === "GET" && req.url === "/projects") {
      proxyGet("/project");
      return;
    }
    if (req.method === "GET" && req.url === "/sessions") {
      proxyGet("/session");
      return;
    }
    res.writeHead(404);
    res.end("Not found");
  });

  const wss = new WebSocketServer({ server, path: "/chat" });

  wss.on("connection", (ws: WebSocket) => {
    console.log(`[bridge] WebSocket client connected`);

    let authenticated = false;
    let opencode: OpencodeProcess | null = null;
    let events: OpencodeEventStream | null = null;
    let currentModel: string | null = null;
    let currentProjectPath: string | null = null;
    let currentSessionId: string | null = null;

    const teardownOpencode = () => {
      if (opencode) {
        opencode.stop();
        opencode = null;
      }
      if (events) {
        events.close();
        events = null;
      }
    };

    const createOpencode = () => {
      opencode = new OpencodeProcess(config.opencodeServeUrl);

      // Token-level reasoning only exists on the serve process's event bus; the
      // CLI's JSON output emits a reasoning block once it has already finished.
      events = new OpencodeEventStream(config.opencodeServeUrl);
      events.setDirectory(currentProjectPath);
      events.setSession(currentSessionId);
      events.start();

      events.on("thinking", (content: string) => {
        if (ws.readyState === WebSocket.OPEN) {
          ws.send(JSON.stringify({ type: "thinking", content }));
        }
      });

      events.on("thinking_end", (durationMs: number | undefined) => {
        if (ws.readyState === WebSocket.OPEN) {
          ws.send(JSON.stringify({ type: "thinking_end", duration_ms: durationMs }));
        }
      });

      opencode.on("session", (sessionId: string) => {
        currentSessionId = sessionId;
        events?.setSession(sessionId);
      });

      opencode.on("output", (data: string) => {
        if (ws.readyState === WebSocket.OPEN) {
          ws.send(JSON.stringify({ type: "token", content: data }));
        }
      });

      opencode.on("tool", (data: any) => {
        if (ws.readyState === WebSocket.OPEN) {
          ws.send(JSON.stringify({ type: "tool", ...data }));
        }
      });

      opencode.on("permission", (data: any) => {
        if (ws.readyState === WebSocket.OPEN) {
          ws.send(
            JSON.stringify({
              type: "permission_request",
              id: data.id,
              title: data.title,
            }),
          );
        }
      });

      opencode.on("exit", (durationMs: number | undefined, inputTokens?: number, outputTokens?: number, cost?: number) => {
        if (
          ws.readyState === WebSocket.OPEN &&
          opencode &&
          !opencode.manualStop
        ) {
          ws.send(JSON.stringify({ type: "done", duration_ms: durationMs, input_tokens: inputTokens, output_tokens: outputTokens, cost: cost }));
        }
      });

      opencode.on("error", (err: Error) => {
        if (ws.readyState === WebSocket.OPEN) {
          ws.send(JSON.stringify({ type: "error", message: err.message }));
        }
      });
    };

    const fetchModels = (retries = 3, delay = 1000) => {
      const url = new URL("/config/providers", config.opencodeServeUrl);
      httpGet(url.href, (res) => {
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => {
          try {
            const body = JSON.parse(data);
            const providers = body.providers ?? body;
            ws.send(JSON.stringify({ type: "models", providers }));
          } catch {
            if (retries > 0) {
              setTimeout(() => fetchModels(retries - 1, delay), delay);
            }
          }
        });
      }).on("error", () => {
        if (retries > 0) {
          setTimeout(() => fetchModels(retries - 1, delay), delay);
        }
      });
    };

    const formatToolDesc = (
      tool: string,
      input: any,
      status: string,
    ): string => {
      const action =
        status === "error" ? "\u2717 " : status === "running" ? "" : "\u2713 ";
      if (!input || typeof input !== "object")
        return `${action}${tool} (${status})`;
      switch (tool) {
        case "bash":
        case "shell":
          return (
            action +
            (typeof input.command === "string"
              ? input.command
              : `${tool} (${status})`)
          );
        case "write":
        case "edit":
          return (
            action +
            (typeof input.filePath === "string"
              ? `\u270E ${input.filePath}`
              : `${tool} (${status})`)
          );
        case "read":
        case "glob":
        case "grep": {
          const p =
            typeof input.path === "string"
              ? input.path
              : typeof input.pattern === "string"
                ? input.pattern
                : typeof input.filePath === "string"
                  ? input.filePath
                  : "";
          return action + (p || `${tool} (${status})`);
        }
        case "webfetch":
          return (
            action +
            (typeof input.url === "string" ? input.url : `${tool} (${status})`)
          );
        default:
          return action + `${tool} (${status})`;
      }
    };

    const extractToolContent = (
      tool: string,
      input: any,
      state: any,
    ): string | undefined => {
      if (!input) return undefined;
      switch (tool) {
        case "write":
          return typeof input.content === "string"
            ? input.content
            : typeof state?.output === "string"
              ? (state.output as string).slice(0, 500)
              : undefined;
        case "edit":
          return typeof input.newString === "string"
            ? input.newString
            : undefined;
        case "bash":
        case "shell":
          return typeof state?.output === "string"
            ? (state.output as string).slice(0, 500)
            : undefined;
        default:
          return typeof state?.output === "string"
            ? (state.output as string).slice(0, 500)
            : undefined;
      }
    };

    const fetchSessionMessages = () => {
      if (!currentSessionId) return;
      const url = new URL(
        `/session/${currentSessionId}/message`,
        config.opencodeServeUrl,
      );
      fetchJson(url.href)
        .then((messages: any) => {
          const simplified = (Array.isArray(messages) ? messages : []).map(
            (m: any, i: number) => {
              const info = m.info ?? {};

              const parts = m.parts ?? [];
              const role = info.role === "user" ? "user" : "assistant";
              const duration =
                (typeof info.duration_ms === "number"
                  ? info.duration_ms
                  : undefined) ??
                (typeof info.durationMs === "number"
                  ? info.durationMs
                  : undefined) ??
                (info.usage && typeof info.usage.duration_ms === "number"
                  ? info.usage.duration_ms
                  : undefined) ??
                (info.usage && typeof info.usage.total_duration_ms === "number"
                  ? info.usage.total_duration_ms
                  : undefined);

              let inputTokens: number | undefined;
              let outputTokens: number | undefined;
              const tokensObj =
                info.usage as Record<string, unknown> | undefined;
              const altTokens =
                info.tokens as Record<string, unknown> | undefined;
              const msgTokens =
                m.tokens as Record<string, unknown> | undefined;
              if (tokensObj && typeof tokensObj === "object") {
                if (typeof tokensObj.input_tokens === "number") {
                  inputTokens = tokensObj.input_tokens as number;
                }
                if (typeof tokensObj.output_tokens === "number") {
                  outputTokens = tokensObj.output_tokens as number;
                }
              }
              if (inputTokens === undefined && altTokens && typeof altTokens === "object") {
                if (typeof altTokens.input === "number") {
                  inputTokens = altTokens.input as number;
                }
                if (typeof altTokens.output === "number") {
                  outputTokens = altTokens.output as number;
                }
              }
              if (inputTokens === undefined && msgTokens && typeof msgTokens === "object") {
                if (typeof msgTokens.input === "number") {
                  inputTokens = msgTokens.input as number;
                }
                if (typeof msgTokens.output === "number") {
                  outputTokens = msgTokens.output as number;
                }
              }

              const textSegments: string[] = [];
              const thinkingSegments: string[] = [];
              let thinkingMs = 0;
              const toolResults: Array<{
                tool: string;
                description: string;
                content?: string;
              }> = [];

              for (const p of Array.isArray(parts) ? parts : []) {
                if (p.type === "text" && p.text) {
                  textSegments.push(p.text);
                } else if (p.type === "reasoning" && p.text) {
                  thinkingSegments.push(p.text);
                  if (typeof p.time?.start === "number" && typeof p.time?.end === "number") {
                    thinkingMs += p.time.end - p.time.start;
                  }
                } else if (p.type === "tool") {
                  const toolName = p.tool ?? "tool";
                  const input = p.state?.input;
                  const state = p.state;
                  const status = state?.status ?? "completed";
                  const description = formatToolDesc(toolName, input, status);
                  const content = extractToolContent(toolName, input, state);
                  toolResults.push({ tool: toolName, description, content });
                }
              }

              const content = textSegments.join("\n\n");
              const thinkingContent = thinkingSegments.join("\n\n");
              const timestamp = info.created ?? info.timestamp ?? info.time;
              const cost = typeof info.cost === "number" ? info.cost : (typeof m.cost === "number" ? m.cost : undefined);
              return {
                role,
                content,
                thinkingContent,
                thinkingMs: thinkingMs > 0 ? thinkingMs : undefined,
                toolResults,
                duration,
                inputTokens,
                outputTokens,
                cost,
                timestamp,
              };
            },
          );
          ws.send(
            JSON.stringify({ type: "session_messages", messages: simplified }),
          );
        })
        .catch((err: Error) => {
          console.error(
            `[bridge] failed to fetch session messages: ${err.message}`,
          );
        });
    };

    const handleMessage = (raw: Buffer) => {
      let msg: any;
      try {
        msg = JSON.parse(raw.toString());
      } catch {
        ws.send(
          JSON.stringify({ type: "error", message: "Invalid message format" }),
        );
        return;
      }

      if (!authenticated) {
        if (msg?.type === "auth" && msg.token === config.authToken) {
          authenticated = true;
          console.log(`[bridge] client authenticated`);
          createOpencode();
          fetchModels();
        } else {
          console.log(`[bridge] auth failed`);
          if (ws.readyState === WebSocket.OPEN) {
            ws.send(
              JSON.stringify({
                type: "auth_failed",
                message: "Authentication failed",
              }),
            );
          }
          ws.close();
        }
        return;
      }

      switch (msg?.type) {
        case "prompt":
          if (typeof msg.content === "string") {
            console.log(`[bridge] received prompt: ${msg.content.trim()}`);
            if (opencode) {
              opencode
                .write(
                  msg.content.trim(),
                  msg.model ?? currentModel ?? undefined,
                  currentProjectPath ?? undefined,
                )
                .catch((err: Error) => {
                  console.error(`[bridge] prompt failed: ${err.message}`);
                  if (ws.readyState === WebSocket.OPEN) {
                    ws.send(JSON.stringify({ type: "error", message: err.message }));
                  }
                });
            }
          }
          break;

        case "permission_response":
          if (typeof msg.id === "string" && typeof msg.response === "string") {
            console.log(
              `[bridge] permission response: ${msg.id} → ${msg.response}`,
            );
            if (opencode) {
              opencode.reply(msg.id, msg.response as "allow" | "deny");
            }
          }
          break;

        case "set_model":
          if (typeof msg.model === "string") {
            currentModel = msg.model;
            console.log(`[bridge] model set to: ${currentModel}`);
            ws.send(JSON.stringify({ type: "model_set", model: currentModel }));
          }
          break;

        case "get_models":
          fetchModels();
          break;

        case "set_session": {
          const sessionId = msg.session_id as string | undefined;
          const sessionPath = msg.path as string | undefined;
          if (sessionId) {
            currentSessionId = sessionId;
            currentProjectPath = sessionPath ?? currentProjectPath;
            console.log(`[bridge] session set to: ${currentSessionId}`);
            opencode?.setSessionId(currentSessionId);
            events?.setDirectory(currentProjectPath);
            events?.setSession(currentSessionId);
            ws.send(
              JSON.stringify({
                type: "session_set",
                session_id: currentSessionId,
              }),
            );
            fetchModels();
            fetchSessionMessages();
          }
          break;
        }

        case "set_project":
          if (typeof msg.path === "string") {
            currentProjectPath = msg.path;
            console.log(`[bridge] project set to: ${currentProjectPath}`);
            events?.setDirectory(currentProjectPath);
            ws.send(
              JSON.stringify({ type: "project_set", path: currentProjectPath }),
            );
            fetchModels();
          }
          break;
      }
    };

    ws.on("message", handleMessage);

    ws.on("close", () => {
      console.log(`[bridge] WebSocket client disconnected`);
      teardownOpencode();
    });

    ws.on("error", (err: Error) => {
      console.error(`[bridge] WebSocket error: ${err.message}`);
      teardownOpencode();
    });
  });

  return server;
}
