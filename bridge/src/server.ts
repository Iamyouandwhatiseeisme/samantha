import { createServer } from "http";
import { WebSocketServer } from "ws";
import { BridgeConfig } from "./types";
import { createRequestHandler } from "./http_routes";
import { setupWebSocket } from "./ws_handler";

export function createBridgeServer(config: BridgeConfig) {
  const server = createServer(createRequestHandler(config));

  const wss = new WebSocketServer({ server, path: "/chat" });
  setupWebSocket(wss, config);

  return server;
}
