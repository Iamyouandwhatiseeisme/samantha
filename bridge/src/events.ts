import { EventEmitter } from "events";
import { get as httpGet, ClientRequest, IncomingMessage } from "http";

// The `opencode run --format json` printer only writes a reasoning line once the
// block is finished (it gates on `part.time.end`), so the CLI's stdout can never
// give us token-level thinking. The serve process publishes the underlying deltas
// on its SSE bus instead, which is what we subscribe to here.
//
// Reasoning arrives as three kinds of frame, all scoped to a directory:
//   message.part.updated  part.type=reasoning, time={start}          -> block opened
//   message.part.delta    partID, field="text", delta="..."          -> token
//   message.part.updated  part.type=reasoning, time={start,end}      -> block closed
//
// Deltas are coalesced on a short timer so a fast model doesn't turn into one
// WebSocket frame (and one Flutter rebuild) per token.
const FLUSH_INTERVAL_MS = 50;

const RECONNECT_MIN_MS = 500;
const RECONNECT_MAX_MS = 5000;

interface ReasoningPart {
  text: string;
  startedAt?: number;
}

export class OpencodeEventStream extends EventEmitter {
  private readonly serveUrl: string;
  private request: ClientRequest | null = null;
  private response: IncomingMessage | null = null;
  private started = false;
  private closed = false;
  private reconnectTimer: NodeJS.Timeout | null = null;
  private reconnectDelay = RECONNECT_MIN_MS;

  private directory: string | null = null;
  private sessionId: string | null = null;

  private readonly reasoning = new Map<string, ReasoningPart>();
  private pending = "";
  private flushTimer: NodeJS.Timeout | null = null;

  constructor(serveUrl: string) {
    super();
    this.serveUrl = serveUrl;
  }

  /**
   * Reasoning parts belong to a session; anything from another one (a TUI open
   * against the same serve, say) is dropped.
   */
  setSession(sessionId: string | null): void {
    if (this.sessionId === sessionId) return;
    this.sessionId = sessionId;
    this.discardBuffered();
  }

  /**
   * The `/event` stream is scoped to a workspace: subscribing without a matching
   * `directory` yields heartbeats and nothing else. Changing it reopens the stream.
   */
  setDirectory(directory: string | null): void {
    if (this.directory === directory) return;
    this.directory = directory;
    this.discardBuffered();
    // Before start() there is nothing to reopen; the first connect picks this up.
    if (this.started && !this.closed) this.connect();
  }

  start(): void {
    if (this.started) return;
    this.started = true;
    this.closed = false;
    this.connect();
  }

  close(): void {
    this.started = false;
    this.closed = true;
    this.cancelReconnect();
    this.cancelFlush();
    this.discardBuffered();
    this.teardownRequest();
  }

  private discardBuffered(): void {
    this.reasoning.clear();
    this.pending = "";
  }

  private teardownRequest(): void {
    this.response?.destroy();
    this.request?.destroy();
    this.response = null;
    this.request = null;
  }

  private cancelReconnect(): void {
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
  }

  private cancelFlush(): void {
    if (this.flushTimer) {
      clearTimeout(this.flushTimer);
      this.flushTimer = null;
    }
  }

  private connect(): void {
    this.cancelReconnect();
    this.teardownRequest();

    const url = new URL("/event", this.serveUrl);
    if (this.directory) url.searchParams.set("directory", this.directory);

    const request = httpGet(url.href, { headers: { Accept: "text/event-stream" } }, (res) => {
      if (res.statusCode !== 200) {
        console.error(`[bridge:events] /event returned ${res.statusCode}`);
        res.resume();
        this.scheduleReconnect();
        return;
      }
      this.response = res;
      this.reconnectDelay = RECONNECT_MIN_MS;
      res.setEncoding("utf8");

      let buffer = "";
      res.on("data", (chunk: string) => {
        buffer += chunk;
        // SSE frames are separated by a blank line; each carries one `data:` line.
        const frames = buffer.split("\n\n");
        buffer = frames.pop() ?? "";
        for (const frame of frames) {
          for (const line of frame.split("\n")) {
            if (!line.startsWith("data:")) continue;
            try {
              this.handleEvent(JSON.parse(line.slice(5).trim()));
            } catch {
              // skip unparseable frames
            }
          }
        }
      });

      res.on("end", () => this.scheduleReconnect());
      res.on("error", (err: Error) => {
        console.error(`[bridge:events] stream error: ${err.message}`);
        this.scheduleReconnect();
      });
    });

    request.on("error", (err: Error) => {
      console.error(`[bridge:events] connect error: ${err.message}`);
      this.scheduleReconnect();
    });

    this.request = request;
  }

  private scheduleReconnect(): void {
    if (this.closed || this.reconnectTimer) return;
    this.teardownRequest();
    const delay = this.reconnectDelay;
    this.reconnectDelay = Math.min(this.reconnectDelay * 2, RECONNECT_MAX_MS);
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = null;
      this.connect();
    }, delay);
  }

  private handleEvent(event: Record<string, unknown>): void {
    const properties = event.properties as Record<string, unknown> | undefined;
    if (!properties) return;

    switch (event.type) {
      case "message.part.updated": {
        const part = properties.part as Record<string, unknown> | undefined;
        if (!part || part.type !== "reasoning") return;
        if (part.sessionID !== this.sessionId) return;

        const id = part.id as string;
        const time = part.time as { start?: number; end?: number } | undefined;

        if (!this.reasoning.has(id)) {
          this.reasoning.set(id, { text: "", startedAt: time?.start });
        }
        if (time?.end === undefined) return;

        const tracked = this.reasoning.get(id)!;
        // Some providers hand back a finished block with no deltas at all; fall
        // back to the part's own text so the turn isn't silently empty.
        if (!tracked.text) {
          const full = typeof part.text === "string" ? part.text : "";
          if (full) this.pending += full;
        }
        this.flush();
        this.reasoning.delete(id);

        const startedAt = tracked.startedAt ?? time.start;
        this.emit("thinking_end", startedAt !== undefined ? time.end - startedAt : undefined);
        return;
      }

      case "message.part.delta": {
        if (properties.sessionID !== this.sessionId) return;
        if (properties.field !== "text") return;
        const partId = properties.partID as string;
        const tracked = this.reasoning.get(partId);
        if (!tracked) return; // a text part, not reasoning

        const delta = properties.delta as string;
        tracked.text += delta;
        this.pending += delta;
        this.scheduleFlush();
        return;
      }
    }
  }

  private scheduleFlush(): void {
    if (this.flushTimer) return;
    this.flushTimer = setTimeout(() => {
      this.flushTimer = null;
      this.flush();
    }, FLUSH_INTERVAL_MS);
  }

  private flush(): void {
    this.cancelFlush();
    if (!this.pending) return;
    const content = this.pending;
    this.pending = "";
    this.emit("thinking", content);
  }
}
