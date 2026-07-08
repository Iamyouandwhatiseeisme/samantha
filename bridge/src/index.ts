import { spawn, ChildProcess } from "child_process";
import { createBridgeServer } from "./server";

const BRIDGE_PORT = parseInt(process.env.PORT || "8383", 10);
const AUTH_TOKEN = process.env.BRIDGE_AUTH_TOKEN;
const OPENCODE_PORT = parseInt(process.env.OPENCODE_PORT || "4096", 10);
const OPENCODE_HOST = process.env.OPENCODE_HOST || "127.0.0.1";

if (!AUTH_TOKEN) {
  console.error("[bridge] BRIDGE_AUTH_TOKEN environment variable is required");
  console.error("[bridge] Set it: BRIDGE_AUTH_TOKEN=your-secret npm start");
  process.exit(1);
}

const opencodeServeUrl = `http://${OPENCODE_HOST}:${OPENCODE_PORT}`;
let opencodeServe: ChildProcess | null = null;

const startOpencodeServe = () => {
  console.log(`[bridge] starting opencode serve on ${opencodeServeUrl}...`);
  opencodeServe = spawn("opencode", ["serve", "--port", String(OPENCODE_PORT), "--hostname", "0.0.0.0"], {
    stdio: ["ignore", "pipe", "pipe"],
    env: { ...process.env },
  });

  opencodeServe.stdout?.on("data", (data: Buffer) => {
    console.log(`[bridge:opencode:serve] ${data.toString().trim()}`);
  });

  opencodeServe.stderr?.on("data", (data: Buffer) => {
    console.log(`[bridge:opencode:serve] ${data.toString().trim()}`);
  });

  opencodeServe.on("error", (err: Error) => {
    console.error(`[bridge:opencode:serve] spawn error: ${err.message}`);
  });

  opencodeServe.on("exit", (code: number | null) => {
    console.log(`[bridge:opencode:serve] exited with code ${code}`);
    opencodeServe = null;
  });
};

const stopOpencodeServe = () => {
  if (opencodeServe) {
    console.log("[bridge] stopping opencode serve...");
    opencodeServe.kill("SIGTERM");
    opencodeServe = null;
  }
};

const server = createBridgeServer({
  port: BRIDGE_PORT,
  authToken: AUTH_TOKEN,
  opencodeServeUrl,
});

startOpencodeServe();

server.listen(BRIDGE_PORT, "0.0.0.0", () => {
  console.log(`[bridge] listening on http://0.0.0.0:${BRIDGE_PORT}`);
  console.log(`[bridge] opencode serve at ${opencodeServeUrl}`);
});

const shutdown = (sig: string) => () => {
  console.log(`\n[bridge] received ${sig}, shutting down...`);
  server.close();
  stopOpencodeServe();
  process.exit(0);
};

process.on("SIGINT", shutdown("SIGINT"));
process.on("SIGTERM", shutdown("SIGTERM"));
