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
            case "tool":
            case "tool_use": {
                const part = msg.part;
                const rawMsg = part ?? msg;
                const state = (part?.state ?? rawMsg.state ?? rawMsg);
                const toolName = part?.tool ?? rawMsg.name ?? rawMsg.tool ?? "unknown";
                const explicitStatus = state?.status ?? "";
                const status = (explicitStatus === "completed" || explicitStatus === "error")
                    ? explicitStatus : "running";
                const input = (state?.input ?? rawMsg.input);
                const description = this.formatToolDesc(toolName, input, status);
                const writtenContent = this.extractToolContent(toolName, input, state);
                this.emit("tool", {
                    tool: toolName,
                    status,
                    description,
                    output: status === "completed" && typeof state?.output === "string"
                        ? state.output.slice(0, 500) : undefined,
                    error: (status === "error" || rawMsg.error) ? (state?.error ?? rawMsg.error) : undefined,
                    title: typeof state?.title === "string" ? state.title : undefined,
                    callID: (part?.callID ?? rawMsg.callID ?? rawMsg.id),
                    content: writtenContent,
                });
                break;
            }
            case "tool_result": {
                const toolName = msg.name ?? msg.tool ?? "tool";
                const isError = msg.is_error === true;
                const content = typeof msg.content === "string" ? msg.content.slice(0, 500) : "";
                this.emit("tool", {
                    tool: toolName,
                    status: isError ? "error" : "completed",
                    description: isError ? `${toolName} failed` : `${toolName} finished`,
                    output: isError ? undefined : content,
                    error: isError ? content : undefined,
                    callID: (msg.tool_use_id ?? msg.callID ?? msg.id),
                    content: isError ? undefined : content,
                });
                break;
            }
            case "step_finish":
                break;
            case "error":
                this.emit("error", new Error(msg.message ?? "Unknown error"));
                break;
            default:
                console.log(`[bridge:opencode] unknown msg type: ${msg.type}`);
                break;
        }
    }
    formatToolDesc(tool, input, status) {
        if (!input)
            return `${tool} (${status})`;
        const pre = status === "error" ? "\u2717 " : status === "completed" ? "\u2713 " : "";
        switch (tool) {
            case "bash":
            case "shell":
                return pre + (typeof input.command === "string" ? input.command : `${tool} (${status})`);
            case "write":
                return pre + (typeof input.filePath === "string" ? `\u270E ${input.filePath}` : `${tool} (${status})`);
            case "edit":
                return pre + (typeof input.filePath === "string" ? `\u270E ${input.filePath}` : `${tool} (${status})`);
            case "read":
            case "glob":
            case "grep": {
                const p = typeof input.path === "string" ? input.path
                    : typeof input.pattern === "string" ? input.pattern
                        : typeof input.filePath === "string" ? input.filePath : "";
                return pre + (p || `${tool} (${status})`);
            }
            case "webfetch":
                return pre + (typeof input.url === "string" ? input.url : `${tool} (${status})`);
            default:
                return pre + `${tool} (${status})`;
        }
    }
    extractToolContent(tool, input, state) {
        if (!input)
            return undefined;
        switch (tool) {
            case "write":
                return typeof input.content === "string" ? input.content
                    : typeof state?.output === "string" ? state.output.slice(0, 500) : undefined;
            case "edit":
                return typeof input.newString === "string" ? input.newString : undefined;
            case "bash":
            case "shell":
                return typeof state?.output === "string" ? state.output.slice(0, 500) : undefined;
            default:
                return typeof state?.output === "string" ? state.output.slice(0, 500) : undefined;
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
        // Permissions auto-approved via --auto
    }
}
exports.OpencodeProcess = OpencodeProcess;
//# sourceMappingURL=opencode.js.map