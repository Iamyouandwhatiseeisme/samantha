import { createServer, IncomingMessage, ServerResponse } from "http";
import { get as httpGet } from "http";
import { WebSocketServer, WebSocket } from "ws";
import { OpencodeProcess } from "./opencode";

interface BridgeConfig {
  port: number;
  authToken: string;
  opencodeServeUrl: string;
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
    if (req.method === "GET" && req.url === "/projects") {
      const url = new URL("/project", config.opencodeServeUrl);
      fetchJson(url.href)
        .then((body) => {
          res.writeHead(200, { "Content-Type": "application/json" });
          res.end(JSON.stringify(body));
        })
        .catch((err) => {
          res.writeHead(502, { "Content-Type": "application/json" });
          res.end(JSON.stringify({ error: err.message }));
        });
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

    const fetchModels = () => {
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
            ws.send(JSON.stringify({ type: "error", message: "Failed to parse models" }));
          }
        });
      }).on("error", (err) => {
        ws.send(JSON.stringify({ type: "error", message: `Failed to fetch models: ${err.message}` }));
      });
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
              opencode.write(
                msg.content.trim(),
                msg.model ?? currentModel ?? undefined,
                currentProjectPath ?? undefined,
              );
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

        case "set_project":
          if (typeof msg.path === "string") {
            currentProjectPath = msg.path;
            console.log(`[bridge] project set to: ${currentProjectPath}`);
            ws.send(JSON.stringify({ type: "project_set", path: currentProjectPath }));
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
