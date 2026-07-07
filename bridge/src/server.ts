import { createServer, IncomingMessage, ServerResponse } from "http";
import { WebSocketServer, WebSocket } from "ws";
import { OpencodeProcess } from "./opencode";

export function createBridgeServer(
  port: number,
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

  const wss = new WebSocketServer({ server });

  wss.on("connection", (ws: WebSocket) => {
    const outputHandler = (data: string) => {
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ type: "output", content: data }));
      }
    };

    const exitHandler = (code: number | null) => {
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({
          type: "status",
          status: "stopped",
          message: code !== null
            ? `Opencode exited with code ${code}`
            : "Opencode stopped",
        }));
      }
    };

    const errorHandler = (err: Error) => {
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({
          type: "status",
          status: "error",
          message: err.message,
        }));
      }
    };

    opencode.on("output", outputHandler);
    opencode.on("exit", exitHandler);
    opencode.on("error", errorHandler);

    const statusMessage = opencode.running
      ? { type: "status", status: "running", message: "Opencode is running" }
      : { type: "status", status: "stopped", message: "Opencode is not running" };
    ws.send(JSON.stringify(statusMessage));

    ws.on("message", (raw: Buffer) => {
      try {
        const msg = JSON.parse(raw.toString());
        if (msg.type === "input" && typeof msg.content === "string") {
          opencode.write(msg.content);
        }
      } catch {
        opencode.write(raw.toString());
      }
    });

    ws.on("close", () => {
      opencode.off("output", outputHandler);
      opencode.off("exit", exitHandler);
      opencode.off("error", errorHandler);
    });
  });

  return server;
}
