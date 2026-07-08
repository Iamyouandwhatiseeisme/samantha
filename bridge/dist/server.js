"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createBridgeServer = createBridgeServer;
const http_1 = require("http");
const ws_1 = require("ws");
const opencode_1 = require("./opencode");
function createBridgeServer(config) {
    const server = (0, http_1.createServer)((req, res) => {
        if (req.method === "GET" && req.url === "/health") {
            res.writeHead(200, { "Content-Type": "application/json" });
            res.end(JSON.stringify({ status: "ok" }));
            return;
        }
        res.writeHead(404);
        res.end("Not found");
    });
    const wss = new ws_1.WebSocketServer({ server, path: "/chat" });
    wss.on("connection", (ws) => {
        console.log(`[bridge] WebSocket client connected`);
        let authenticated = false;
        let opencode = null;
        const teardownOpencode = () => {
            if (opencode) {
                opencode.stop();
                opencode = null;
            }
        };
        const startOpencode = () => {
            opencode = new opencode_1.OpencodeProcess();
            opencode.on("output", (data) => {
                if (ws.readyState === ws_1.WebSocket.OPEN) {
                    ws.send(JSON.stringify({ type: "token", content: data }));
                }
            });
            opencode.on("exit", (_code) => {
                if (ws.readyState === ws_1.WebSocket.OPEN && opencode && !opencode.manualStop) {
                    ws.send(JSON.stringify({ type: "done" }));
                }
            });
            opencode.on("error", (err) => {
                if (ws.readyState === ws_1.WebSocket.OPEN) {
                    ws.send(JSON.stringify({ type: "error", message: err.message }));
                }
            });
            opencode.start();
        };
        const handleMessage = (raw) => {
            let msg;
            try {
                msg = JSON.parse(raw.toString());
            }
            catch {
                ws.send(JSON.stringify({ type: "error", message: "Invalid message format" }));
                return;
            }
            if (!authenticated) {
                if (msg?.type === "auth" && msg.token === config.authToken) {
                    authenticated = true;
                    console.log(`[bridge] client authenticated`);
                    startOpencode();
                }
                else {
                    console.log(`[bridge] auth failed`);
                    if (ws.readyState === ws_1.WebSocket.OPEN) {
                        ws.send(JSON.stringify({ type: "auth_failed", message: "Authentication failed" }));
                    }
                    ws.close();
                }
                return;
            }
            if (msg?.type === "prompt" && typeof msg.content === "string") {
                if (opencode)
                    opencode.write(msg.content);
            }
        };
        ws.on("message", handleMessage);
        ws.on("close", () => {
            console.log(`[bridge] WebSocket client disconnected`);
            teardownOpencode();
        });
        ws.on("error", (err) => {
            console.error(`[bridge] WebSocket error: ${err.message}`);
            teardownOpencode();
        });
    });
    return server;
}
//# sourceMappingURL=server.js.map