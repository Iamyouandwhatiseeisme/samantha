export interface BridgeConfig {
  port: number;
  authToken: string;
  opencodeServeUrl: string;
  restartOpencodeServe: (cwd?: string) => Promise<void>;
}
