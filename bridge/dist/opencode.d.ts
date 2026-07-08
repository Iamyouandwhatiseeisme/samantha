import { EventEmitter } from "events";
export interface ToolEvent {
    tool: string;
    status: string;
    description: string;
    output?: string;
    error?: string;
    title?: string;
    callID?: string;
}
export interface PermissionEvent {
    id: string;
    sessionID: string;
    title?: string;
    metadata?: Record<string, unknown>;
}
export declare class OpencodeProcess extends EventEmitter {
    sessionId: string | null;
    private readonly serveUrl;
    private sseRequest;
    private sseResponse;
    private stopping;
    constructor(serveUrl: string);
    get running(): boolean;
    get manualStop(): boolean;
    get currentSessionId(): string | null;
    setSessionId(id: string): void;
    write(prompt: string, model?: string): Promise<void>;
    reply(permissionID: string, response: "allow" | "deny"): Promise<void>;
    private connectSSE;
    private parseSSE;
    private handleMessage;
    stop(): void;
    private postJSON;
}
//# sourceMappingURL=opencode.d.ts.map