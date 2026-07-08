"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.OpencodeProcess = void 0;
const events_1 = require("events");
const http_1 = require("http");
class OpencodeProcess extends events_1.EventEmitter {
    sessionId = null;
    serveUrl;
    sseRequest = null;
    sseResponse = null;
    stopping = false;
    constructor(serveUrl) {
        super();
        this.serveUrl = serveUrl;
    }
    get running() {
        return this.sseRequest !== null;
    }
    get manualStop() {
        return this.stopping;
    }
    get currentSessionId() {
        return this.sessionId;
    }
    setSessionId(id) {
        this.sessionId = id;
    }
    async write(prompt, model) {
        if (this.sseRequest) {
            this.stop();
        }
        this.stopping = false;
        try {
            // 1. Create session if needed
            if (!this.sessionId) {
                const sessionUrl = new URL("/session", this.serveUrl);
                const session = await this.postJSON(sessionUrl, {});
                this.sessionId = session.id;
                console.log(`[bridge:opencode] created session: ${this.sessionId}`);
            }
            // 2. Connect SSE FIRST so we don't miss events
            this.connectSSE();
            // Give the SSE connection a moment to establish
            await new Promise((resolve) => setTimeout(resolve, 100));
            // 3. Send prompt async
            const promptUrl = new URL(`/session/${this.sessionId}/prompt_async`, this.serveUrl);
            const body = {
                parts: [{ type: "text", text: prompt }],
            };
            if (model) {
                const parts = model.split("/");
                if (parts.length === 2) {
                    body.model = { providerID: parts[0], modelID: parts[1] };
                }
            }
            console.log(`[bridge:opencode] sending prompt to session ${this.sessionId}`);
            await this.postJSON(promptUrl, body);
        }
        catch (err) {
            console.error(`[bridge:opencode] write error: ${err instanceof Error ? err.message : String(err)}`);
            this.emit("error", err instanceof Error ? err : new Error(String(err)));
        }
    }
    async reply(permissionID, response) {
        if (!this.sessionId)
            return;
        const url = new URL(`/session/${this.sessionId}/permissions/${permissionID}`, this.serveUrl);
        console.log(`[bridge:opencode] replying to permission ${permissionID}: ${response}`);
        await this.postJSON(url, { response });
    }
    connectSSE() {
        const url = new URL("/event", this.serveUrl);
        console.log(`[bridge:opencode] connecting SSE: ${url.href}`);
        const req = (0, http_1.get)(url, (res) => {
            console.log(`[bridge:opencode] SSE connected, status: ${res.statusCode}`);
            this.sseResponse = res;
            if (res.statusCode !== 200) {
                let body = "";
                res.on("data", (chunk) => (body += chunk.toString()));
                res.on("end", () => {
                    console.error(`[bridge:opencode] SSE non-200 response: ${body}`);
                    this.sseRequest = null;
                    this.sseResponse = null;
                    this.emit("error", new Error(`SSE connection failed: HTTP ${res.statusCode}`));
                });
                return;
            }
            let buffer = "";
            res.on("data", (chunk) => {
                buffer += chunk.toString();
                const parts = buffer.split("\n\n");
                buffer = parts.pop() ?? "";
                for (const part of parts) {
                    if (!part.trim())
                        continue;
                    const msg = this.parseSSE(part);
                    if (msg) {
                        try {
                            const parsed = JSON.parse(msg.data);
                            this.handleMessage(parsed, msg.event);
                        }
                        catch {
                            // skip unparseable
                        }
                    }
                }
            });
            res.on("end", () => {
                console.log("[bridge:opencode] SSE stream ended");
                this.sseRequest = null;
                this.sseResponse = null;
            });
            res.on("close", () => {
                console.log("[bridge:opencode] SSE stream closed");
                this.sseRequest = null;
                this.sseResponse = null;
            });
            res.on("error", (err) => {
                console.error(`[bridge:opencode:sse] error: ${err.message}`);
                this.sseRequest = null;
                this.sseResponse = null;
                if (!this.stopping) {
                    this.emit("error", err);
                }
            });
        });
        req.on("error", (err) => {
            console.error(`[bridge:opencode:sse] request error: ${err.message}`);
            if (this.sseRequest === req) {
                this.sseRequest = null;
                this.sseResponse = null;
            }
        });
        req.on("close", () => {
            console.log("[bridge:opencode:sse] request closed");
        });
        req.setTimeout(0); // No timeout for SSE
        req.end();
        this.sseRequest = req;
    }
    parseSSE(raw) {
        const lines = raw.split("\n");
        let event;
        let data = "";
        for (const line of lines) {
            if (line.startsWith("event: ")) {
                event = line.slice(7);
            }
            else if (line.startsWith("data: ")) {
                data += line.slice(6);
            }
        }
        if (!data)
            return null;
        return { event, data };
    }
    handleMessage(msg, sseEvent) {
        const type = sseEvent ?? msg.type;
        switch (type) {
            case "server.connected":
                console.log("[bridge:opencode] server connected event received");
                break;
            case "step_start":
                if (msg.sessionID && !this.sessionId) {
                    this.sessionId = msg.sessionID;
                    console.log(`[bridge:opencode] session: ${this.sessionId}`);
                }
                break;
            case "step_finish":
                console.log("[bridge:opencode] step finished");
                this.sseRequest?.abort();
                this.sseRequest = null;
                this.sseResponse = null;
                this.emit("exit", 0);
                break;
            case "text":
                if (msg.part?.text) {
                    this.emit("output", msg.part.text);
                }
                break;
            case "thinking":
                if (msg.part?.text) {
                    this.emit("thinking", msg.part.text);
                }
                break;
            case "tool": {
                const part = msg.part;
                const state = part?.state;
                const toolName = part?.tool ?? "unknown";
                const status = state?.status ?? "pending";
                const input = state?.input;
                let description = "";
                if (typeof input?.command === "string") {
                    description = input.command;
                }
                else if (typeof input?.description === "string") {
                    description = input.description;
                }
                else if (input && typeof input === "object") {
                    const key = Object.keys(input)[0];
                    if (key === "description" && typeof input.description === "string") {
                        description = input.description;
                    }
                    else if (typeof input.pattern === "string") {
                        description = input.pattern;
                    }
                    else if (typeof input.path === "string") {
                        description = input.path;
                    }
                }
                this.emit("tool", {
                    tool: toolName,
                    status,
                    description,
                    output: status === "completed" && typeof state?.output === "string" ? state.output : undefined,
                    error: status === "error" && typeof state?.error === "string" ? state.error : undefined,
                    title: typeof state?.title === "string" ? state.title : undefined,
                    callID: part?.callID,
                });
                break;
            }
            case "permission.updated":
            case "permission": {
                const perm = msg;
                if (perm.id) {
                    console.log(`[bridge:opencode] permission requested: ${perm.id} — ${perm.title ?? "untitled"}`);
                    this.emit("permission", {
                        id: perm.id,
                        sessionID: perm.sessionID ?? this.sessionId,
                        title: perm.title,
                        metadata: perm.metadata,
                    });
                }
                break;
            }
            case "error":
                this.emit("error", new Error(msg.message ?? "Unknown error"));
                break;
            default:
                // Silently skip unknown types
                break;
        }
    }
    stop() {
        if (this.sseRequest) {
            this.stopping = true;
            console.log("[bridge:opencode] stopping SSE connection");
            this.sseRequest.abort();
            this.sseRequest = null;
            this.sseResponse = null;
        }
    }
    postJSON(url, body) {
        return new Promise((resolve, reject) => {
            const data = body ? JSON.stringify(body) : null;
            const req = (0, http_1.request)(url, {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    Accept: "application/json",
                    ...(data
                        ? { "Content-Length": String(Buffer.byteLength(data)) }
                        : {}),
                },
            }, (res) => {
                let responseData = "";
                res.on("data", (chunk) => (responseData += chunk.toString()));
                res.on("end", () => {
                    if (res.statusCode &&
                        res.statusCode >= 200 &&
                        res.statusCode < 300) {
                        try {
                            resolve(JSON.parse(responseData || "{}"));
                        }
                        catch {
                            resolve({});
                        }
                    }
                    else {
                        reject(new Error(`HTTP ${res.statusCode}: ${responseData}`));
                    }
                });
            });
            req.on("error", reject);
            req.setTimeout(10000, () => {
                req.destroy();
                reject(new Error("Request timeout"));
            });
            if (data)
                req.write(data);
            req.end();
        });
    }
}
exports.OpencodeProcess = OpencodeProcess;
//# sourceMappingURL=opencode.js.map