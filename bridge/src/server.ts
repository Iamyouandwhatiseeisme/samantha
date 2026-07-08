import { createServer, IncomingMessage, ServerResponse } from "http";
import { get as httpGet } from "http";
import { WebSocketServer, WebSocket } from "ws";
import { OpencodeProcess } from "./opencode";

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
    let currentModel: string | null = null;
    let currentProjectPath: string | null = null;
    let currentSessionId: string | null = null;

    const teardownOpencode = () => {
      if (opencode) {
        opencode.stop();
        opencode = null;
      }
    };

    const createOpencode = () => {
      opencode = new OpencodeProcess(config.opencodeServeUrl);

      opencode.on("output", (data: string) => {
        if (ws.readyState === WebSocket.OPEN) {
          ws.send(JSON.stringify({ type: "token", content: data }));
        }
      });

      opencode.on("thinking", (data: string) => {
        if (ws.readyState === WebSocket.OPEN) {
          ws.send(JSON.stringify({ type: "thinking", content: data }));
        }
      });

      opencode.on("tool", (data: any) => {
        if (ws.readyState === WebSocket.OPEN) {
          ws.send(JSON.stringify({ type: "tool", ...data }));
        }
      });

      opencode.on("permission", (data: any) => {
        if (ws.readyState === WebSocket.OPEN) {
          ws.send(JSON.stringify({
            type: "permission_request",
            id: data.id,
            title: data.title,
          }));
        }
      });

      opencode.on("exit", (_code: number | null) => {
        if (ws.readyState === WebSocket.OPEN && opencode && !opencode.manualStop) {
          ws.send(JSON.stringify({ type: "done" }));
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

    const fetchSessionMessages = () => {
      if (!currentSessionId) return;
      const url = new URL(`/session/${currentSessionId}/message`, config.opencodeServeUrl);
      fetchJson(url.href)
        .then((messages: any) => {
          const simplified = (Array.isArray(messages) ? messages : []).map((m: any) => {
            const info = m.info ?? {};
            const parts = m.parts ?? [];
            const role = info.role === "user" ? "user" : "assistant";

            const segments: string[] = [];
            for (const p of Array.isArray(parts) ? parts : []) {
              if (p.type === "text" && p.text) {
                segments.push(p.text);
              } else if (p.type === "tool") {
                const toolName = p.tool ?? "tool";
                const input = p.state?.input;
                const status = p.state?.status ?? "completed";
                const formatted = formatToolInput(toolName, input, status);
                if (formatted) segments.push(formatted);
                const output = p.state?.output;
                if (typeof output === "string" && output.trim()) {
                  const preview = output.length > 800 ? output.slice(0, 800) + "\n..." : output;
                  segments.push(`\`\`\`\n${preview}\n\`\`\``);
                }
                const errMsg = p.state?.error;
                if (typeof errMsg === "string") {
                  segments.push(`\`\`\`error\n${errMsg}\n\`\`\``);
                }
              }
            }

            const content = segments.join("\n\n");
            return { role, content };
          });
          ws.send(JSON.stringify({ type: "session_messages", messages: simplified }));
        })
        .catch((err: Error) => {
          console.error(`[bridge] failed to fetch session messages: ${err.message}`);
        });
    };

    const formatToolInput = (tool: string, input: any, status: string): string | null => {
      if (!input || typeof input !== "object") return null;
      const action = status === "error" ? "\u2717" : status === "running" ? "\u23F3" : "\u2713";

      switch (tool) {
        case "bash":
        case "shell":
          return typeof input.command === "string"
            ? `\`\`\`sh\n${input.command}\n\`\`\``
            : null;

        case "write": {
          const fp = typeof input.filePath === "string" ? input.filePath : "";
          const content = typeof input.content === "string" ? input.content
            : typeof input.filePath === "string" ? JSON.stringify(input) : null;
          if (!fp) return null;
          const ext = fp.includes(".") ? fp.split(".").pop() ?? "" : "";
          const preview = content
            ? content.length > 600 ? content.slice(0, 600) + "\n..." : content
            : "(empty)";
          return `${action} **${tool}** \`${fp}\`\n\`\`\`${ext}\n${preview}\n\`\`\``;
        }

        case "edit": {
          const fp = typeof input.filePath === "string" ? input.filePath : "";
          const oldText = typeof input.oldString === "string" ? input.oldString.slice(0, 100) : "";
          const newText = typeof input.newString === "string" ? input.newString.slice(0, 100) : "";
          return fp
            ? `${action} **${tool}** \`${fp}\`\n\`\`\`diff\n- ${oldText}\n+ ${newText}\n\`\`\``
            : null;
        }

        case "read":
        case "glob":
        case "grep": {
          const path = typeof input.path === "string" ? input.path
            : typeof input.pattern === "string" ? input.pattern
            : typeof input.filePath === "string" ? input.filePath : "";
          return path ? `${action} **${tool}** \`${path}\`` : null;
        }

        case "webfetch": {
          const url = typeof input.url === "string" ? input.url : "";
          return url ? `${action} **${tool}** ${url}` : null;
        }

        default:
          return `${action} **${tool}** \`\`\`json\n${JSON.stringify(input, null, 2)}\n\`\`\``;
      }
    };

    const handleMessage = (raw: Buffer) => {
      let msg: any;
      try {
        msg = JSON.parse(raw.toString());
      } catch {
        ws.send(JSON.stringify({ type: "error", message: "Invalid message format" }));
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
            ws.send(JSON.stringify({ type: "auth_failed", message: "Authentication failed" }));
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
              if (currentSessionId && !opencode.currentSessionId) {
                opencode.setSessionId(currentSessionId);
              }
              opencode.write(
                msg.content.trim(),
                msg.model ?? currentModel ?? undefined,
                currentProjectPath ?? undefined,
              );
            }
          }
          break;

        case "permission_response":
          if (typeof msg.id === "string" && typeof msg.response === "string") {
            console.log(`[bridge] permission response: ${msg.id} → ${msg.response}`);
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
            ws.send(JSON.stringify({ type: "session_set", session_id: currentSessionId }));
            fetchModels();
            fetchSessionMessages();
          }
          break;
        }

        case "set_project":
          if (typeof msg.path === "string") {
            currentProjectPath = msg.path;
            console.log(`[bridge] project set to: ${currentProjectPath}`);
            ws.send(JSON.stringify({ type: "project_set", path: currentProjectPath }));
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
