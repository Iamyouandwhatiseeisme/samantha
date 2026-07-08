import { EventEmitter } from "events";
export declare class OpencodeProcess extends EventEmitter {
    private process;
    private stopping;
    private sessionId;
    private readonly serveUrl;
    constructor(serveUrl: string);
    get running(): boolean;
    get manualStop(): boolean;
    write(prompt: string, model?: string): void;
    private handleMessage;
    stop(): void;
}
//# sourceMappingURL=opencode.d.ts.map