"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.OpencodeProcess = void 0;
const child_process_1 = require("child_process");
const events_1 = require("events");
class OpencodeProcess extends events_1.EventEmitter {
    process = null;
    stopping = false;
    sessionId = null;
    get running() {
        return this.process !== null && !this.process.killed;
    }
    get manualStop() {
        return this.stopping;
    }
    write(prompt) {
        if (this.process) {
            this.stop();
        }
        this.stopping = false;
        const args = ["run", "--format", "json"];
        if (this.sessionId) {
            args.push("--session", this.sessionId);
        }
        args.push(prompt);
        this.process = (0, child_process_1.spawn)("opencode", args, {
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
                    this.emit("output", msg.part.text);
                }
                break;
            case "step_finish":
                this.process = null;
                this.emit("exit", 0);
                break;
            case "error":
                this.emit("error", new Error(msg.message ?? "Unknown error"));
                break;
            default:
                // unknown message type — ignore
                break;
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