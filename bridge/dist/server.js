"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createBridgeServer = createBridgeServer;
const http_1 = require("http");
const http_2 = require("http");
const ws_1 = require("ws");
const opencode_1 = require("./opencode");
const fetchJson = (url) => new Promise((resolve, reject) => {
    (0, http_2.get)(url, (res) => {
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => {
            try {
                resolve(JSON.parse(data));
            }
            catch {
                reject(new Error("Failed to parse JSON response"));
            }
        });
    }).on("error", reject);
});
function createBridgeServer(config) {
    const server = (0, http_1.createServer)((req, res) => {
        if (req.method === "GET" && req.url === "/health") {
            res.writeHead(200, { "Content-Type": "application/json" });
            res.end(JSON.stringify({ status: "ok" }));
            return;
        }
        const proxyGet = (path) => {
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
    const wss = new ws_1.WebSocketServer({ server, path: "/chat" });
    wss.on("connection", (ws) => {
        console.log(`[bridge] WebSocket client connected`);
        let authenticated = false;
        let opencode = null;
        let currentModel = null;
        let currentProjectPath = null;
        let currentSessionId = null;
        const teardownOpencode = () => {
            if (opencode) {
                opencode.stop();
                opencode = null;
            }
        };
        const createOpencode = () => {
            opencode = new opencode_1.OpencodeProcess(config.opencodeServeUrl);
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
        };
        const fetchModels = (retries = 3, delay = 1000) => {
            const url = new URL("/config/providers", config.opencodeServeUrl);
            (0, http_2.get)(url.href, (res) => {
                let data = "";
                res.on("data", (chunk) => (data += chunk));
                res.on("end", () => {
                    try {
                        const body = JSON.parse(data);
                        const providers = body.providers ?? body;
                        ws.send(JSON.stringify({ type: "models", providers }));
                    }
                    catch {
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
                    createOpencode();
                    fetchModels();
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
            switch (msg?.type) {
                case "prompt":
                    if (typeof msg.content === "string") {
                        console.log(`[bridge] received prompt: ${msg.content.trim()}`);
                        if (opencode) {
                            if (currentSessionId && !opencode.currentSessionId) {
                                opencode.setSessionId(currentSessionId);
                            }
                            opencode.write(msg.content.trim(), msg.model ?? currentModel ?? undefined);
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
                    const sessionId = msg.session_id;
                    const sessionPath = msg.path;
                    if (sessionId) {
                        currentSessionId = sessionId;
                        currentProjectPath = sessionPath ?? currentProjectPath;
                        console.log(`[bridge] session set to: ${currentSessionId}`);
                        ws.send(JSON.stringify({ type: "session_set", session_id: currentSessionId }));
                        if (sessionPath) {
                            config.restartOpencodeServe(sessionPath).then(() => {
                                console.log("[bridge] server restarted for session, re-fetching models");
                                fetchModels();
                            }).catch((err) => {
                                console.error(`[bridge] failed to restart opencode serve: ${err.message}`);
                            });
                        }
                    }
                    break;
                }
                case "set_project":
                    if (typeof msg.path === "string") {
                        currentProjectPath = msg.path;
                        console.log(`[bridge] project set to: ${currentProjectPath}`);
                        ws.send(JSON.stringify({ type: "project_set", path: currentProjectPath }));
                        config.restartOpencodeServe(currentProjectPath ?? undefined).then(() => {
                            console.log("[bridge] server restarted, re-fetching models");
                            fetchModels();
                        }).catch((err) => {
                            console.error(`[bridge] failed to restart opencode serve: ${err.message}`);
                        });
                    }
                    break;
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