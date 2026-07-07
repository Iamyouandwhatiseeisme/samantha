import { ChildProcess, spawn } from "child_process";
import { EventEmitter } from "events";

export interface OpencodeProcessEvents {
  output: (data: string) => void;
  error: (error: Error) => void;
  exit: (code: number | null) => void;
}

export class OpencodeProcess extends EventEmitter {
  private process: ChildProcess | null = null;

  get running(): boolean {
    return this.process !== null && !this.process.killed;
  }

  start(): void {
    if (this.process) {
      this.stop();
    }

    this.process = spawn("opencode", [], {
      stdio: ["pipe", "pipe", "pipe"],
      env: { ...process.env },
    });

    this.process.stdout?.on("data", (data: Buffer) => {
      const text = data.toString();
      this.emit("output", text);
    });

    this.process.stderr?.on("data", (data: Buffer) => {
      const text = data.toString();
      this.emit("output", text);
    });

    this.process.on("error", (err: Error) => {
      this.emit("error", err);
    });

    this.process.on("exit", (code: number | null) => {
      this.process = null;
      this.emit("exit", code);
    });
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
