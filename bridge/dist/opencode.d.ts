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
}
export declare class OpencodeProcess extends EventEmitter {
    private process;
    private stopping;
    sessionId: string | null;
    private readonly serveUrl;
    constructor(serveUrl: string);
    get running(): boolean;
    get manualStop(): boolean;
    get currentSessionId(): string | null;
    setSessionId(id: string): void;
    write(prompt: string, model?: string, projectPath?: string): void;
    private handleCliMessage;
    stop(): void;
    reply(_permissionID: string, _response: string): Promise<void>;
}
//# sourceMappingURL=opencode.d.ts.map