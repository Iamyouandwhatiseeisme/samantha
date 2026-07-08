import { EventEmitter } from "events";
export declare class OpencodeProcess extends EventEmitter {
    private process;
    private stopping;
    private sessionId;
    get running(): boolean;
    get manualStop(): boolean;
    write(prompt: string): void;
    private handleMessage;
    stop(): void;
}
//# sourceMappingURL=opencode.d.ts.map