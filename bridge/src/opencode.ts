import { ChildProcess, spawn } from "child_process";
import { EventEmitter } from "events";

const ANSI_RE = /[\u001b\u009b][[()#;?]*(?:[0-9]{1,4}(?:;[0-9]{0,4})*)?[0-9A-ORZcf-nqry=><]/g;

export class OpencodeProcess extends EventEmitter {
  private process: ChildProcess | null = null;
  private stdoutBuffer = "";
  private stopping = false;

  get running(): boolean {
    return this.process !== null && !this.process.killed;
  }

  start(): void {
    if (this.process) {
      this.stop();
    }
    this.stopping = false;
    this.stdoutBuffer = "";

    this.process = spawn("opencode", [], {
      stdio: ["pipe", "pipe", "pipe"],
      env: { ...process.env },
    });

    this.process.stdout?.on("data", (data: Buffer) => {
      this.stdoutBuffer += this.stripAnsi(data.toString());
      this.flushStdout();
    });

    // Diagnostics/warnings from stderr are not model output — log them
    // on the bridge console instead of leaking into the chat stream.
    this.process.stderr?.on("data", (data: Buffer) => {
      const text = this.stripAnsi(data.toString()).trim();
      if (text) console.error(`[bridge:opencode:stderr] ${text}`);
    });

    this.process.on("error", (err: Error) => {
      console.error(`[bridge:opencode] spawn error: ${err.message}`);
      this.emit("error", err);
    });

    this.process.on("exit", (code: number | null) => {
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

  write(input: string): void {
    if (this.process?.stdin?.writable) {
      this.process.stdin.write(input);
    }
  }

  stop(): void {
    if (!this.process) return;
    this.stopping = true;
    this.process.kill("SIGTERM");
    this.process = null;
  }

  get manualStop(): boolean {
    return this.stopping;
  }

  private flushStdout(): void {
    const lines = this.stdoutBuffer.split("\n");
    this.stdoutBuffer = lines.pop() ?? "";
    for (const line of lines) {
      this.emit("output", line + "\n");
    }
  }

  private stripAnsi(text: string): string {
    return text.replace(ANSI_RE, "");
  }
}