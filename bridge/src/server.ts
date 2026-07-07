import { createServer, IncomingMessage, ServerResponse } from "http";
import { WebSocketServer, WebSocket } from "ws";
import { OpencodeProcess } from "./opencode";

interface BridgeConfig {
  port: number;
  authToken: string;
}

export function createBridgeServer(
  config: BridgeConfig,
  opencode: OpencodeProcess
) {
  const server = createServer((req: IncomingMessage, res: ServerResponse) => {
    if (req.url === "/health") {
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({
        status: "ok",
        opencodeRunning: opencode.running,
      }));
      return;
    }

    res.writeHead(404);
    res.end("Not found");
  });

  const wss = new WebSocketServer({ server, path: "/chat" });

  wss.on("connection", (ws: WebSocket) => {
    console.log(`[bridge] WebSocket client connected`);

    let authenticated = false;
    let currentOutputHandler: ((data: string) => void) | null = null;
    let currentExitHandler: ((code: number | null) => void) | null = null;
    let currentErrorHandler: ((err: Error) => void) | null = null;
    let opencodeStarted = false;

    const cleanup = () => {
      if (currentOutputHandler) opencode.off("output", currentOutputHandler);
      if (currentExitHandler) opencode.off("exit", currentExitHandler);
      if (currentErrorHandler) opencode.off("error", currentErrorHandler);
    };

    ws.on("message", (raw: Buffer) => {
      try {
        const msg = JSON.parse(raw.toString());

        if (!authenticated) {
          if (msg.type === "auth" && msg.token === config.authToken) {
            authenticated = true;
            console.log(`[bridge] client authenticated`);
            startOpencode();
            return;
          } else {
            console.log(`[bridge] auth failed`);
            ws.send(JSON.stringify({
              type: "error",
              message: "Authentication failed",
            }));
            ws.close();
            return;
          }
        }

        if (msg.type === "prompt" && typeof msg.content === "string") {
          opencode.write(msg.content);
        }
      } catch {
        ws.send(JSON.stringify({
          type: "error",
          message: "Invalid message format",
        }));
      }
    });

    const startOpencode = () => {
      opencodeStarted = true;

      currentOutputHandler = (data: string) => {
        if (ws.readyState === WebSocket.OPEN) {
          ws.send(JSON.stringify({ type: "token", content: data }));
        }
      };

      currentExitHandler = (code: number | null) => {
        if (ws.readyState === WebSocket.OPEN) {
          ws.send(JSON.stringify({ type: "done" }));
        }
      };

      currentErrorHandler = (err: Error) => {
        if (ws.readyState === WebSocket.OPEN) {
          ws.send(JSON.stringify({
            type: "error",
            message: err.message,
          }));
        }
      };

      opencode.on("output", currentOutputHandler);
      opencode.on("exit", currentExitHandler);
      opencode.on("error", currentErrorHandler);
    };

    ws.on("close", () => {
      console.log(`[bridge] WebSocket client disconnected`);
      cleanup();
      if (opencodeStarted && opencode.running) {
        opencode.stop();
      }
    });

    ws.on("error", (err: Error) => {
      console.error(`[bridge] WebSocket error: ${err.message}`);
    });
  });

  return server;
}
