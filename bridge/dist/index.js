"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const server_1 = require("./server");
const PORT = parseInt(process.env.PORT || "8383", 10);
const AUTH_TOKEN = process.env.BRIDGE_AUTH_TOKEN;
if (!AUTH_TOKEN) {
    console.error("[bridge] BRIDGE_AUTH_TOKEN environment variable is required");
    console.error("[bridge] Set it: BRIDGE_AUTH_TOKEN=your-secret npm start");
    process.exit(1);
}
const server = (0, server_1.createBridgeServer)({ port: PORT, authToken: AUTH_TOKEN });
server.listen(PORT, "0.0.0.0", () => {
    console.log(`[bridge] listening on http://0.0.0.0:${PORT}`);
    console.log(`[bridge] health check: http://localhost:${PORT}/health`);
    console.log(`[bridge] WebSocket: ws://localhost:${PORT}/chat`);
});
const shutdown = (sig) => () => {
    console.log(`\n[bridge] received ${sig}, shutting down...`);
    server.close();
    process.exit(0);
};
process.on("SIGINT", shutdown("SIGINT"));
process.on("SIGTERM", shutdown("SIGTERM"));
//# sourceMappingURL=index.js.map