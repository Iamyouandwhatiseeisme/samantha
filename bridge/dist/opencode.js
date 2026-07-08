"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.OpencodeProcess = void 0;
const events_1 = require("events");
const child_process_1 = require("child_process");
class OpencodeProcess extends events_1.EventEmitter {
    process = null;
    stopping = false;
    sessionId = null;
    serveUrl;
    constructor(serveUrl) {
        super();
        this.serveUrl = serveUrl;
    }
    get running() {
        return this.process !== null && !this.process.killed;
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
    write(prompt, model, projectPath) {
        if (this.process) {
            this.stop();
        }
        this.stopping = false;
        const args = ["run", "--format", "json", "--auto", "--attach", this.serveUrl];
        if (model) {
            args.push("--model", model);
        }
        if (projectPath) {
            args.push("--dir", projectPath);
        }
        if (this.sessionId) {
            args.push("--session", this.sessionId);
        }
        args.push(prompt);
        // PTY via script for line-buffered stdout (real-time streaming)
        const ptyArgs = ["-q", "/dev/null", "opencode", ...args];
        this.process = (0, child_process_1.spawn)("script", ptyArgs, {
            stdio: ["ignore", "pipe", "pipe"],
            env: { ...process.env },
        });
        let buffer = "";
        this.process.stdout?.on("data", (data) => {
            buffer += data.toString();
            const lines = buffer.split("\n");
            buffer = lines.pop() ?? "";
            for (const line of lines) {
                const trimmed = line.trim();
                if (!trimmed)
                    continue;
                try {
                    const msg = JSON.parse(trimmed);
                    this.handleCliMessage(msg);
                }
                catch {
                    // skip unparseable lines
                }
            }
        });
        this.process.stderr?.on("data", (data) => {
            console.error(`[bridge:opencode:stderr] ${data.toString().trim()}`);
        });
        this.process.on("error", (err) => {
            console.error(`[bridge:opencode] spawn error: ${err.message}`);
            this.emit("error", err);
        });
        this.process.on("exit", (code) => {
            console.log(`[bridge:opencode] exited with code ${code}`);
            if (buffer.trim()) {
                try {
                    const msg = JSON.parse(buffer.trim());
                    this.handleCliMessage(msg);
                }
                catch {
                    // skip trailing incomplete JSON
                }
            }
            this.process = null;
            // Also emit exit event (only when not manually stopped)
            if (!this.stopping) {
                this.emit("exit", 0);
            }
        });
    }
    handleCliMessage(msg) {
        switch (msg.type) {
            case "step_start":
                if (msg.sessionID && !this.sessionId) {
                    this.sessionId = msg.sessionID;
                    console.log(`[bridge:opencode] session: ${this.sessionId}`);
                }
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
                const description = this.formatToolDesc(toolName, input, status);
                this.emit("tool", {
                    tool: toolName,
                    status,
                    description,
                    output: status === "completed" && typeof state?.output === "string"
                        ? state.output.slice(0, 200) : undefined,
                    error: status === "error" && typeof state?.error === "string"
                        ? state.error : undefined,
                    title: typeof state?.title === "string" ? state.title : undefined,
                    callID: part?.callID,
                });
                break;
            }
            case "step_finish":
                // Exit event is already emitted on process exit
                break;
            case "error":
                this.emit("error", new Error(msg.message ?? "Unknown error"));
                break;
            default:
                // Log once per unknown type for debugging
                console.log(`[bridge:opencode] unknown msg type: ${msg.type}`);
                break;
        }
    }
    formatToolDesc(tool, input, status) {
        if (!input)
            return tool;
        switch (tool) {
            case "bash":
            case "shell":
                return typeof input.command === "string" ? input.command : tool;
            case "write":
                return typeof input.filePath === "string" ? `\u270E ${input.filePath}` : tool;
            case "edit":
                return typeof input.filePath === "string" ? `\u270E ${input.filePath}` : tool;
            case "read":
            case "glob":
            case "grep": {
                const p = typeof input.path === "string" ? input.path
                    : typeof input.pattern === "string" ? input.pattern
                        : typeof input.filePath === "string" ? input.filePath : "";
                return p || tool;
            }
            case "webfetch":
                return typeof input.url === "string" ? input.url : tool;
            default:
                return tool;
        }
    }
    stop() {
        if (!this.process)
            return;
        this.stopping = true;
        this.process.kill("SIGTERM");
        this.process = null;
    }
    async reply(_permissionID, _response) {
        // Permissions are auto-approved by --auto. This stub exists for
        // protocol compatibility — interactive permission dialogs need
        // the SSE-based approach.
    }
}
exports.OpencodeProcess = OpencodeProcess;
//# sourceMappingURL=opencode.js.map