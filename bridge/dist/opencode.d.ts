import { EventEmitter } from "events";
export declare class OpencodeProcess extends EventEmitter {
    private process;
    private stopping;
    private sessionId;
    private readonly serveUrl;
    constructor(serveUrl: string);
    get running(): boolean;
    get manualStop(): boolean;
    get currentSessionId(): string | null;
    setSessionId(id: string): void;
    write(prompt: string, model?: string): void;
    private handleMessage;
    stop(): void;
}
//# sourceMappingURL=opencode.d.ts.map