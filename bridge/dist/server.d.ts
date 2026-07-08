import { IncomingMessage, ServerResponse } from "http";
interface BridgeConfig {
    port: number;
    authToken: string;
    opencodeServeUrl: string;
    restartOpencodeServe: (cwd?: string) => Promise<void>;
}
export declare function createBridgeServer(config: BridgeConfig): import("http").Server<typeof IncomingMessage, typeof ServerResponse>;
export {};
//# sourceMappingURL=server.d.ts.map