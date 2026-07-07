import { ChildProcess, spawn } from "child_process";
import { EventEmitter } from "events";

const ANSI_RE = /[\u001b\u009b][[()#;?]*(?:[0-9]{1,4}(?:;[0-9]{0,4})*)?[0-9A-ORZcf-nqry=><]/g;

export class OpencodeProcess extends EventEmitter {
  private process: ChildProcess | null = null;
  private outputBuffer = "";

  get running(): boolean {
    return this.process !== null && !this.process.killed;
  }

  start(): boolean {
    if (this.process) {
      this.stop();
    }

    this.process = spawn("opencode", [], {
      stdio: ["pipe", "pipe", "pipe"],
      env: { ...process.env },
    });

    this.process.stdout?.on("data", (data: Buffer) => {
      this.outputBuffer += this.stripAnsi(data.toString());
      this.flushBuffer();
    });

    this.process.stderr?.on("data", (data: Buffer) => {
      this.outputBuffer += this.stripAnsi(data.toString());
      this.flushBuffer();
    });

    this.process.on("error", (err: Error) => {
      console.error(`[bridge] opencode error: ${err.message}`);
      this.emit("error", err);
    });

    this.process.on("exit", (code: number | null) => {
      console.log(`[bridge] opencode exited with code ${code}`);
      this.emit("exit", code);
      this.process = null;
    });

    return true;
  }

  private flushBuffer(): void {
    const lines = this.outputBuffer.split("\n");
    this.outputBuffer = lines.pop() ?? "";

    for (const line of lines) {
      this.emit("output", line + "\n");
    }
  }

  private stripAnsi(text: string): string {
    return text.replace(ANSI_RE, "");
  }

  write(input: string): void {
    if (this.process?.stdin?.writable) {
      this.process.stdin.write(input);
    }
  }

  stop(): void {
    if (this.process) {
      this.process.kill("SIGTERM");
      this.process = null;
    }
  }
}
