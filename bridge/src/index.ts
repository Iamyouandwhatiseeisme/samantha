import { OpencodeProcess } from "./opencode";
import { createBridgeServer } from "./server";

const PORT = parseInt(process.env.PORT || "8080", 10);

const opencode = new OpencodeProcess();

opencode.on("output", (data: string) => {
  process.stdout.write(`[opencode] ${data}`);
});

opencode.on("error", (err: Error) => {
  console.error(`[bridge] opencode error: ${err.message}`);
});

opencode.on("exit", (code: number | null) => {
  console.log(`[bridge] opencode exited with code ${code}`);
});

opencode.start();

const server = createBridgeServer(PORT, opencode);

server.listen(PORT, () => {
  console.log(`[bridge] listening on http://0.0.0.0:${PORT}`);
  console.log(`[bridge] health check: http://localhost:${PORT}/health`);
});

process.on("SIGINT", () => {
  opencode.stop();
  server.close();
  process.exit(0);
});

process.on("SIGTERM", () => {
  opencode.stop();
  server.close();
  process.exit(0);
});
