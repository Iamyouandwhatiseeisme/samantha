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
    write(prompt, model) {
        if (this.process) {
            this.stop();
        }
        this.stopping = false;
        const args = ["run", "--format", "json", "--attach", this.serveUrl, "--auto"];
        if (model) {
            args.push("--model", model);
        }
        if (this.sessionId) {
            args.push("--session", this.sessionId);
        }
        args.push(prompt);
        // Use `script` to create a PTY so the child process line-buffers
        // stdout instead of block-buffering. Without a PTY, pipe-based
        // stdio causes full buffering — streaming events arrive only on exit.
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
                    this.handleMessage(msg);
                }
                catch {
                    // skip unparseable lines (e.g. script's own output)
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
                    this.handleMessage(msg);
                }
                catch {
                    // skip trailing incomplete JSON
                }
            }
            this.process = null;
        });
    }
    handleMessage(msg) {
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
            case "step_finish":
                this.process = null;
                this.emit("exit", 0);
                break;
            case "tool": {
                const state = msg.part?.state;
                const toolName = msg.part?.tool ?? "unknown";
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
                const output = status === "completed" && typeof state?.output === "string"
                    ? state.output.slice(0, 200) : undefined;
                const error = status === "error" && typeof state?.error === "string"
                    ? state.error : undefined;
                this.emit("tool", {
                    tool: toolName,
                    status,
                    description,
                    output,
                    error,
                    title: typeof state?.title === "string" ? state.title : undefined,
                    callID: msg.part?.callID,
                });
                break;
            }
        }
    }
    stop() {
        if (!this.process)
            return;
        this.stopping = true;
        this.process.kill("SIGTERM");
        this.process = null;
    }
}
exports.OpencodeProcess = OpencodeProcess;
//# sourceMappingURL=opencode.js.map