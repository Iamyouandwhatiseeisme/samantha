"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.OpencodeProcess = void 0;
const child_process_1 = require("child_process");
const events_1 = require("events");
const ANSI_RE = /[\u001b\u009b][[()#;?]*(?:[0-9]{1,4}(?:;[0-9]{0,4})*)?[0-9A-ORZcf-nqry=><]/g;
class OpencodeProcess extends events_1.EventEmitter {
    process = null;
    stdoutBuffer = "";
    stopping = false;
    get running() {
        return this.process !== null && !this.process.killed;
    }
    start() {
        if (this.process) {
            this.stop();
        }
        this.stopping = false;
        this.stdoutBuffer = "";
        this.process = (0, child_process_1.spawn)("opencode", [], {
            stdio: ["pipe", "pipe", "pipe"],
            env: { ...process.env },
        });
        this.process.stdout?.on("data", (data) => {
            this.stdoutBuffer += this.stripAnsi(data.toString());
            this.flushStdout();
        });
        // Diagnostics/warnings from stderr are not model output — log them
        // on the bridge console instead of leaking into the chat stream.
        this.process.stderr?.on("data", (data) => {
            const text = this.stripAnsi(data.toString()).trim();
            if (text)
                console.error(`[bridge:opencode:stderr] ${text}`);
        });
        this.process.on("error", (err) => {
            console.error(`[bridge:opencode] spawn error: ${err.message}`);
            this.emit("error", err);
        });
        this.process.on("exit", (code) => {
            console.log(`[bridge:opencode] exited with code ${code}`);
            // Flush any trailing stdout that lacked a trailing newline.
            if (this.stdoutBuffer.length > 0) {
                this.emit("output", this.stdoutBuffer);
                this.stdoutBuffer = "";
            }
            this.emit("exit", code);
            this.process = null;
        });
    }
    write(input) {
        if (this.process?.stdin?.writable) {
            this.process.stdin.write(input);
        }
    }
    stop() {
        if (!this.process)
            return;
        this.stopping = true;
        this.process.kill("SIGTERM");
        this.process = null;
    }
    get manualStop() {
        return this.stopping;
    }
    flushStdout() {
        const lines = this.stdoutBuffer.split("\n");
        this.stdoutBuffer = lines.pop() ?? "";
        for (const line of lines) {
            this.emit("output", line + "\n");
        }
    }
    stripAnsi(text) {
        return text.replace(ANSI_RE, "");
    }
}
exports.OpencodeProcess = OpencodeProcess;
//# sourceMappingURL=opencode.js.map