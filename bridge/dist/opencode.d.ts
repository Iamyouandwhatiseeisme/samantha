import { EventEmitter } from "events";
export interface ToolEvent {
    tool: string;
    status: string;
    description: string;
    output?: string;
    error?: string;
    title?: string;
    callID?: string;
    content?: string;
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
    private _durationMs?;
    private _inputTokens?;
    private _outputTokens?;
    private _cost?;
    private _textBuffers;
    constructor(serveUrl: string);
    get running(): boolean;
    get manualStop(): boolean;
    get currentSessionId(): string | null;
    setSessionId(id: string): void;
    /**
     * Create the session up front rather than waiting to latch it off the CLI's
     * `step_start` line. The event stream filters reasoning by session ID, and by
     * the time `step_start` reaches us on stdout the first deltas have already
     * been published. This mirrors what `opencode run` does internally.
     */
    private ensureSession;
    write(prompt: string, model?: string, projectPath?: string): Promise<void>;
    private handleCliMessage;
    private formatToolDesc;
    private extractToolContent;
    stop(): void;
    reply(_permissionID: string, _response: string): Promise<void>;
}
//# sourceMappingURL=opencode.d.ts.map