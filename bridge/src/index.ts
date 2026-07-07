import { OpencodeProcess } from "./opencode";
import { createBridgeServer } from "./server";

const PORT = parseInt(process.env.PORT || "8383", 10);
const AUTH_TOKEN = process.env.BRIDGE_AUTH_TOKEN;

if (!AUTH_TOKEN) {
  console.error("[bridge] BRIDGE_AUTH_TOKEN environment variable is required");
  console.error("[bridge] Set it: BRIDGE_AUTH_TOKEN=your-secret npm start");
  process.exit(1);
}

const opencode = new OpencodeProcess();

opencode.on("error", (err: Error) => {
  console.error(`[bridge] opencode error: ${err.message}`);
});

opencode.on("exit", (code: number | null) => {
  console.log(`[bridge] opencode exited with code ${code}`);
});

opencode.start();

const server = createBridgeServer({ port: PORT, authToken: AUTH_TOKEN }, opencode);

server.listen(PORT, () => {
  console.log(`[bridge] listening on http://0.0.0.0:${PORT}`);
  console.log(`[bridge] health check: http://localhost:${PORT}/health`);
  console.log(`[bridge] WebSocket: ws://localhost:${PORT}/chat`);
});

process.on("SIGINT", () => {
  console.log(`\n[bridge] shutting down...`);
  opencode.stop();
  server.close();
  process.exit(0);
});

process.on("SIGTERM", () => {
  console.log(`\n[bridge] shutting down...`);
  opencode.stop();
  server.close();
  process.exit(0);
});
