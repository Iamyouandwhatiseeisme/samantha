import { createServer, IncomingMessage, ServerResponse } from "http";
import { WebSocketServer, WebSocket } from "ws";
import { OpencodeProcess } from "./opencode";

interface BridgeConfig {
  port: number;
  authToken: string;
  opencodeServeUrl: string;
}

export function createBridgeServer(config: BridgeConfig) {
  const server = createServer((req: IncomingMessage, res: ServerResponse) => {
    if (req.method === "GET" && req.url === "/health") {
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ status: "ok" }));
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
        } else {
          console.log(`[bridge] auth failed`);
          if (ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify({ type: "auth_failed", message: "Authentication failed" }));
          }
          ws.close();
        }
        return;
      }

      if (msg?.type === "prompt" && typeof msg.content === "string") {
        console.log(`[bridge] received prompt: ${msg.content.trim()}`);
        if (opencode) {
          opencode.write(msg.content.trim());
        }
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
