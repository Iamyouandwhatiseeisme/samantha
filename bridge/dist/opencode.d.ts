import { EventEmitter } from "events";
export declare class OpencodeProcess extends EventEmitter {
    private process;
    private stdoutBuffer;
    private stopping;
    get running(): boolean;
    start(): void;
    write(input: string): void;
    stop(): void;
    get manualStop(): boolean;
    private flushStdout;
    private stripAnsi;
}
//# sourceMappingURL=opencode.d.ts.map