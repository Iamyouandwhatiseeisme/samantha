import { spawn, ChildProcess } from "child_process";
import { get as httpGet } from "http";
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

const watchProcess = (proc: ChildProcess, label: string) => {
  proc.stdout?.on("data", (data: Buffer) => {
    console.log(`[bridge:opencode:serve] ${data.toString().trim()}`);
  });
  proc.stderr?.on("data", (data: Buffer) => {
    console.log(`[bridge:opencode:serve] ${data.toString().trim()}`);
  });
  proc.on("error", (err: Error) => {
    console.error(`[bridge:opencode:serve] spawn error: ${err.message}`);
  });
  proc.on("exit", (code: number | null) => {
    console.log(`[bridge:opencode:serve] exited with code ${code}`);
    if (opencodeServe === proc) opencodeServe = null;
  });
};

const startOpencodeServe = () => {
  console.log(`[bridge] starting opencode serve on ${opencodeServeUrl}...`);
  const proc = spawn("opencode", ["web", "--port", String(OPENCODE_PORT), "--hostname", "0.0.0.0"], {
    stdio: ["ignore", "pipe", "pipe"],
    env: { ...process.env },
  });
  opencodeServe = proc;
  watchProcess(proc, "opencode");
};

const stopOpencodeServe = () => {
  if (opencodeServe) {
    console.log("[bridge] stopping opencode serve...");
    opencodeServe.kill("SIGTERM");
    opencodeServe = null;
  }
};

const waitForHealth = (url: string, retries = 30, interval = 500): Promise<void> =>
  new Promise((resolve, reject) => {
    let timedOut = false;
    const timer = setTimeout(() => { timedOut = true; reject(new Error("Health check timed out")); }, retries * interval + 5000);
    const attempt = (n: number) => {
      if (timedOut) return;
      const req = httpGet(url, (res) => {
        res.resume();
        if (res.statusCode === 200) { clearTimeout(timer); resolve(); }
        else if (n > 0) setTimeout(() => attempt(n - 1), interval);
        else { clearTimeout(timer); reject(new Error("Server not ready after retries")); }
      });
      req.on("error", () => {
        if (n > 0) setTimeout(() => attempt(n - 1), interval);
        else { clearTimeout(timer); reject(new Error("Server not ready after retries")); }
      });
    };
    attempt(retries);
  });

const restartOpencodeServe = async (cwd?: string) => {
  stopOpencodeServe();
  await new Promise((r) => setTimeout(r, 500));
  console.log(`[bridge] starting opencode serve${cwd ? ` in ${cwd}` : ""}...`);
  const proc = spawn("opencode", ["web", "--port", String(OPENCODE_PORT), "--hostname", "0.0.0.0"], {
    cwd: cwd ?? undefined,
    stdio: ["ignore", "pipe", "pipe"],
    env: { ...process.env },
  });
  opencodeServe = proc;
  watchProcess(proc, "opencode");
  await waitForHealth(`${opencodeServeUrl}/global/health`);
  console.log("[bridge] opencode serve is ready");
};

const server = createBridgeServer({
  port: BRIDGE_PORT,
  authToken: AUTH_TOKEN,
  opencodeServeUrl,
  restartOpencodeServe,
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
