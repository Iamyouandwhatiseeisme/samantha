"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createBridgeServer = createBridgeServer;
const http_1 = require("http");
const ws_1 = require("ws");
const opencode_1 = require("./opencode");
const events_1 = require("./events");
const fetchJson = (url) => new Promise((resolve, reject) => {
    (0, http_1.get)(url, (res) => {
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
            const modelsUrl = new URL("/config/providers", config.opencodeServeUrl);
            (0, http_1.get)(modelsUrl.href, (modelsRes) => {
                let modelsData = "";
                modelsRes.on("data", (chunk) => (modelsData += chunk));
                modelsRes.on("end", () => {
                    let modelCtxMap = {};
                    try {
                        const parsed = JSON.parse(modelsData);
                        const providers = parsed.providers ?? parsed ?? [];
                        for (const p of providers) {
                            for (const [_, model] of Object.entries(p.models ?? {})) {
                                const m = model;
                                if (m.id && m.limit?.context) {
                                    modelCtxMap[m.id] = m.limit.context;
                                }
                            }
                        }
                    }
                    catch { /* use empty map */ }
                    const sessionsUrl = new URL("/session", config.opencodeServeUrl);
                    (0, http_1.get)(sessionsUrl.href, (sessionsRes) => {
                        let sessionsData = "";
                        sessionsRes.on("data", (chunk) => (sessionsData += chunk));
                        sessionsRes.on("end", () => {
                            try {
                                const sessions = JSON.parse(sessionsData);
                                const list = Array.isArray(sessions) ? sessions : [];
                                const enriched = list.map((s, i) => {
                                    const tokens = s.tokens ?? {};
                                    const inputTokens = tokens.input ?? 0;
                                    const cost = s.cost ?? 0;
                                    const modelId = s.model?.id;
                                    const ctxWin = modelCtxMap[modelId] ?? 200000;
                                    const ctxPct = inputTokens > 0
                                        ? Math.round((inputTokens / ctxWin) * 1000) / 10
                                        : 0;
                                    if (i === 0) {
                                        console.log(`[bridge:sessions] session[0]: id=${s.id}, title=${s.title}`, `model=${modelId}, ctxWindow=${ctxWin} (fromAPI=${!!modelCtxMap[modelId]})`, `input=${inputTokens}, output=${tokens.output ?? 0}, reasoning=${tokens.reasoning ?? 0}`, `cache.read=${tokens.cache?.read ?? 0}, cache.write=${tokens.cache?.write ?? 0}`, `cost=${cost}, contextPct=${ctxPct}%`);
                                    }
                                    return { ...s, inputTokens, cost, contextPercent: ctxPct };
                                });
                                res.writeHead(200, { "Content-Type": "application/json" });
                                res.end(JSON.stringify(enriched));
                            }
                            catch (err) {
                                res.writeHead(502, { "Content-Type": "application/json" });
                                res.end(JSON.stringify({ error: err.message }));
                            }
                        });
                    }).on("error", (err) => {
                        res.writeHead(502, { "Content-Type": "application/json" });
                        res.end(JSON.stringify({ error: err.message }));
                    });
                });
            }).on("error", (err) => {
                res.writeHead(502, { "Content-Type": "application/json" });
                res.end(JSON.stringify({ error: err.message }));
            });
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
        let events = null;
        let currentModel = null;
        let currentProjectPath = null;
        let currentSessionId = null;
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
            opencode = new opencode_1.OpencodeProcess(config.opencodeServeUrl);
            // Token-level reasoning only exists on the serve process's event bus; the
            // CLI's JSON output emits a reasoning block once it has already finished.
            events = new events_1.OpencodeEventStream(config.opencodeServeUrl);
            events.setDirectory(currentProjectPath);
            events.setSession(currentSessionId);
            events.start();
            events.on("thinking", (content) => {
                if (ws.readyState === ws_1.WebSocket.OPEN) {
                    ws.send(JSON.stringify({ type: "thinking", content }));
                }
            });
            events.on("thinking_end", (durationMs) => {
                if (ws.readyState === ws_1.WebSocket.OPEN) {
                    ws.send(JSON.stringify({ type: "thinking_end", duration_ms: durationMs }));
                }
            });
            opencode.on("session", (sessionId) => {
                currentSessionId = sessionId;
                events?.setSession(sessionId);
            });
            opencode.on("output", (data) => {
                if (ws.readyState === ws_1.WebSocket.OPEN) {
                    ws.send(JSON.stringify({ type: "token", content: data }));
                }
            });
            opencode.on("tool", (data) => {
                if (ws.readyState === ws_1.WebSocket.OPEN) {
                    ws.send(JSON.stringify({ type: "tool", ...data }));
                }
            });
            opencode.on("permission", (data) => {
                if (ws.readyState === ws_1.WebSocket.OPEN) {
                    ws.send(JSON.stringify({
                        type: "permission_request",
                        id: data.id,
                        title: data.title,
                    }));
                }
            });
            opencode.on("exit", (durationMs, inputTokens, outputTokens, cost) => {
                if (ws.readyState === ws_1.WebSocket.OPEN &&
                    opencode &&
                    !opencode.manualStop) {
                    ws.send(JSON.stringify({ type: "done", duration_ms: durationMs, input_tokens: inputTokens, output_tokens: outputTokens, cost: cost }));
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
            (0, http_1.get)(url.href, (res) => {
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
        // Reads opencode's currently chosen model — either from a specific session
        // (when the app binds one via set_session) or from the most recent session —
        // and pushes it to the client so the dropdown can show what opencode will
        // actually use for the next prompt. The qualified form `providerID/modelId`
        // matches what the app sends back via set_model.
        const fetchCurrentModel = (sessionId, retries = 3, delay = 500) => {
            const url = sessionId
                ? new URL(`/session/${sessionId}`, config.opencodeServeUrl)
                : new URL("/session", config.opencodeServeUrl);
            (0, http_1.get)(url.href, (res) => {
                let data = "";
                res.on("data", (chunk) => (data += chunk));
                res.on("end", () => {
                    try {
                        const body = JSON.parse(data);
                        const session = sessionId
                            ? body
                            : Array.isArray(body) && body.length > 0
                                ? body[0]
                                : null;
                        if (session &&
                            session.model &&
                            typeof session.model.id === "string" &&
                            typeof session.model.providerID === "string") {
                            const modelId = `${session.model.providerID}/${session.model.id}`;
                            console.log(`[bridge] current model: ${modelId}`);
                            if (ws.readyState === ws_1.WebSocket.OPEN) {
                                ws.send(JSON.stringify({ type: "current_model", model: modelId }));
                            }
                        }
                    }
                    catch {
                        if (retries > 0) {
                            setTimeout(() => fetchCurrentModel(sessionId, retries - 1, delay), delay);
                        }
                    }
                });
            }).on("error", () => {
                if (retries > 0) {
                    setTimeout(() => fetchCurrentModel(sessionId, retries - 1, delay), delay);
                }
            });
        };
        const formatToolDesc = (tool, input, status) => {
            const action = status === "error" ? "\u2717 " : status === "running" ? "" : "\u2713 ";
            if (!input || typeof input !== "object")
                return `${action}${tool} (${status})`;
            switch (tool) {
                case "bash":
                case "shell":
                    return (action +
                        (typeof input.command === "string"
                            ? input.command
                            : `${tool} (${status})`));
                case "write":
                case "edit":
                    return (action +
                        (typeof input.filePath === "string"
                            ? `\u270E ${input.filePath}`
                            : `${tool} (${status})`));
                case "read":
                case "glob":
                case "grep": {
                    const p = typeof input.path === "string"
                        ? input.path
                        : typeof input.pattern === "string"
                            ? input.pattern
                            : typeof input.filePath === "string"
                                ? input.filePath
                                : "";
                    return action + (p || `${tool} (${status})`);
                }
                case "webfetch":
                    return (action +
                        (typeof input.url === "string" ? input.url : `${tool} (${status})`));
                default:
                    return action + `${tool} (${status})`;
            }
        };
        const extractToolContent = (tool, input, state) => {
            if (!input)
                return undefined;
            switch (tool) {
                case "write":
                    return typeof input.content === "string"
                        ? input.content
                        : typeof state?.output === "string"
                            ? state.output.slice(0, 500)
                            : undefined;
                case "edit":
                    return typeof input.newString === "string"
                        ? input.newString
                        : undefined;
                case "bash":
                case "shell":
                    return typeof state?.output === "string"
                        ? state.output.slice(0, 500)
                        : undefined;
                default:
                    return typeof state?.output === "string"
                        ? state.output.slice(0, 500)
                        : undefined;
            }
        };
        const fetchSessionMessages = () => {
            if (!currentSessionId)
                return;
            const url = new URL(`/session/${currentSessionId}/message`, config.opencodeServeUrl);
            fetchJson(url.href)
                .then((messages) => {
                const simplified = (Array.isArray(messages) ? messages : []).map((m, i) => {
                    const info = m.info ?? {};
                    const parts = m.parts ?? [];
                    const role = info.role === "user" ? "user" : "assistant";
                    const duration = (typeof info.duration_ms === "number"
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
                    let inputTokens;
                    let outputTokens;
                    const tokensObj = info.usage;
                    const altTokens = info.tokens;
                    const msgTokens = m.tokens;
                    if (tokensObj && typeof tokensObj === "object") {
                        if (typeof tokensObj.input_tokens === "number") {
                            inputTokens = tokensObj.input_tokens;
                        }
                        if (typeof tokensObj.output_tokens === "number") {
                            outputTokens = tokensObj.output_tokens;
                        }
                    }
                    if (inputTokens === undefined && altTokens && typeof altTokens === "object") {
                        if (typeof altTokens.input === "number") {
                            inputTokens = altTokens.input;
                        }
                        if (typeof altTokens.output === "number") {
                            outputTokens = altTokens.output;
                        }
                    }
                    if (inputTokens === undefined && msgTokens && typeof msgTokens === "object") {
                        if (typeof msgTokens.input === "number") {
                            inputTokens = msgTokens.input;
                        }
                        if (typeof msgTokens.output === "number") {
                            outputTokens = msgTokens.output;
                        }
                    }
                    const textSegments = [];
                    const thinkingSegments = [];
                    let thinkingMs = 0;
                    const toolResults = [];
                    for (const p of Array.isArray(parts) ? parts : []) {
                        if (p.type === "text" && p.text) {
                            textSegments.push(p.text);
                        }
                        else if (p.type === "reasoning" && p.text) {
                            thinkingSegments.push(p.text);
                            if (typeof p.time?.start === "number" && typeof p.time?.end === "number") {
                                thinkingMs += p.time.end - p.time.start;
                            }
                        }
                        else if (p.type === "tool") {
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
                });
                ws.send(JSON.stringify({ type: "session_messages", messages: simplified }));
            })
                .catch((err) => {
                console.error(`[bridge] failed to fetch session messages: ${err.message}`);
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
                    fetchCurrentModel(currentSessionId);
                }
                else {
                    console.log(`[bridge] auth failed`);
                    if (ws.readyState === ws_1.WebSocket.OPEN) {
                        ws.send(JSON.stringify({
                            type: "auth_failed",
                            message: "Authentication failed",
                        }));
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
                                .write(msg.content.trim(), msg.model ?? currentModel ?? undefined, currentProjectPath ?? undefined)
                                .catch((err) => {
                                console.error(`[bridge] prompt failed: ${err.message}`);
                                if (ws.readyState === ws_1.WebSocket.OPEN) {
                                    ws.send(JSON.stringify({ type: "error", message: err.message }));
                                }
                            });
                        }
                    }
                    break;
                case "permission_response":
                    if (typeof msg.id === "string" && typeof msg.response === "string") {
                        console.log(`[bridge] permission response: ${msg.id} → ${msg.response}`);
                        if (opencode) {
                            opencode.reply(msg.id, msg.response);
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
                        opencode?.setSessionId(currentSessionId);
                        events?.setDirectory(currentProjectPath);
                        events?.setSession(currentSessionId);
                        ws.send(JSON.stringify({
                            type: "session_set",
                            session_id: currentSessionId,
                        }));
                        fetchModels();
                        fetchSessionMessages();
                        fetchCurrentModel(currentSessionId);
                    }
                    break;
                }
                case "set_project":
                    if (typeof msg.path === "string") {
                        currentProjectPath = msg.path;
                        console.log(`[bridge] project set to: ${currentProjectPath}`);
                        events?.setDirectory(currentProjectPath);
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
        ws.on("error", (err) => {
            console.error(`[bridge] WebSocket error: ${err.message}`);
            teardownOpencode();
        });
    });
    return server;
}
//# sourceMappingURL=server.js.map