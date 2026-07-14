"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createBridgeServer = createBridgeServer;
const http_1 = require("http");
const ws_1 = require("ws");
const http_routes_1 = require("./http_routes");
const ws_handler_1 = require("./ws_handler");
function createBridgeServer(config) {
    const server = (0, http_1.createServer)((0, http_routes_1.createRequestHandler)(config));
    const wss = new ws_1.WebSocketServer({ server, path: "/chat" });
    (0, ws_handler_1.setupWebSocket)(wss, config);
    return server;
}
//# sourceMappingURL=server.js.map