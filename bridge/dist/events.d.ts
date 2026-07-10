import { EventEmitter } from "events";
export declare class OpencodeEventStream extends EventEmitter {
    private readonly serveUrl;
    private request;
    private response;
    private started;
    private closed;
    private reconnectTimer;
    private reconnectDelay;
    private directory;
    private sessionId;
    private readonly reasoning;
    private pending;
    private flushTimer;
    constructor(serveUrl: string);
    /**
     * Reasoning parts belong to a session; anything from another one (a TUI open
     * against the same serve, say) is dropped.
     */
    setSession(sessionId: string | null): void;
    /**
     * The `/event` stream is scoped to a workspace: subscribing without a matching
     * `directory` yields heartbeats and nothing else. Changing it reopens the stream.
     */
    setDirectory(directory: string | null): void;
    start(): void;
    close(): void;
    private discardBuffered;
    private teardownRequest;
    private cancelReconnect;
    private cancelFlush;
    private connect;
    private scheduleReconnect;
    private handleEvent;
    private scheduleFlush;
    private flush;
}
//# sourceMappingURL=events.d.ts.map