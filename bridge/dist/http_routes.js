"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createRequestHandler = createRequestHandler;
const http_1 = require("http");
const helpers_1 = require("./helpers");
const fetchLastMessageTokens = (sessionId, ctxWin, opencodeServeUrl) => {
    const url = new URL(`/session/${sessionId}/message`, opencodeServeUrl);
    return (0, helpers_1.fetchJson)(url.href)
        .then((messages) => {
        if (!Array.isArray(messages) || messages.length === 0) {
            return { contextUsed: 0, ctxPct: 0 };
        }
        for (let i = messages.length - 1; i >= 0; i--) {
            const msg = messages[i];
            const tokens = msg.info?.tokens ?? msg.tokens ?? {};
            const input = tokens.input ?? 0;
            const cacheRead = tokens.cache?.read ?? 0;
            if (input > 0 || cacheRead > 0) {
                const contextUsed = input + cacheRead;
                const ctxPct = contextUsed > 0
                    ? Math.min(Math.round((contextUsed / ctxWin) * 1000) / 10, 100)
                    : 0;
                return { contextUsed, ctxPct };
            }
        }
        return { contextUsed: 0, ctxPct: 0 };
    })
        .catch(() => ({ contextUsed: 0, ctxPct: 0 }));
};
const proxyGet = (path, res, opencodeServeUrl) => {
    const url = new URL(path, opencodeServeUrl);
    (0, helpers_1.fetchJson)(url.href)
        .then((body) => {
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify(body));
    })
        .catch((err) => {
        res.writeHead(502, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: err.message }));
    });
};
const handleSessions = (res, config) => {
    const modelsUrl = new URL("/config/providers", config.opencodeServeUrl);
    (0, http_1.get)(modelsUrl.href, (modelsRes) => {
        let modelsData = "";
        modelsRes.on("data", (chunk) => (modelsData += chunk));
        modelsRes.on("end", () => {
            let modelCtxMap = {};
            try {
                const parsed = JSON.parse(modelsData);
                const providers = parsed.providers ?? parsed ?? [];
                for (const p of providers) {
                    for (const [_, model] of Object.entries(p.models ?? {})) {
                        const m = model;
                        if (m.id && m.limit?.context) {
                            modelCtxMap[m.id] = m.limit.context;
                        }
                    }
                }
            }
            catch {
                /* use empty map */
            }
            const sessionsUrl = new URL("/session", config.opencodeServeUrl);
            (0, http_1.get)(sessionsUrl.href, (sessionsRes) => {
                let sessionsData = "";
                sessionsRes.on("data", (chunk) => (sessionsData += chunk));
                sessionsRes.on("end", () => {
                    try {
                        const sessions = JSON.parse(sessionsData);
                        const list = Array.isArray(sessions) ? sessions : [];
                        const enrichedPromises = list.map((s) => {
                            const tokens = s.tokens ?? {};
                            const inputTokens = tokens.input ?? 0;
                            const cost = s.cost ?? 0;
                            const modelId = s.model?.id;
                            const ctxWin = modelCtxMap[modelId] ?? 200000;
                            return fetchLastMessageTokens(s.id, ctxWin, config.opencodeServeUrl).then(({ contextUsed, ctxPct }) => ({
                                ...s,
                                inputTokens,
                                cost,
                                contextPercent: ctxPct,
                                contextUsed,
                                lastActivity: (0, helpers_1.formatRelativeTime)(s.time?.updated ?? 0),
                            }));
                        });
                        Promise.all(enrichedPromises)
                            .then((enriched) => {
                            if (list.length > 0) {
                                const s = enriched[0];
                                console.log(`[bridge:sessions] session[0]: id=${s.id}, title=${s.title}`, `model=${s.model?.id}, ctxWindow=${modelCtxMap[s.model?.id] ?? 200000}`, `contextUsed=${s.contextUsed}, contextPct=${s.contextPercent}%`);
                            }
                            res.writeHead(200, { "Content-Type": "application/json" });
                            res.end(JSON.stringify(enriched));
                        })
                            .catch((err) => {
                            res.writeHead(502, { "Content-Type": "application/json" });
                            res.end(JSON.stringify({ error: err.message }));
                        });
                    }
                    catch (err) {
                        res.writeHead(502, { "Content-Type": "application/json" });
                        res.end(JSON.stringify({ error: err.message }));
                    }
                });
            }).on("error", (err) => {
                res.writeHead(502, { "Content-Type": "application/json" });
                res.end(JSON.stringify({ error: err.message }));
            });
        });
    }).on("error", (err) => {
        res.writeHead(502, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: err.message }));
    });
};
function createRequestHandler(config) {
    return (req, res) => {
        if (req.method === "GET" && req.url === "/health") {
            res.writeHead(200, { "Content-Type": "application/json" });
            res.end(JSON.stringify({ status: "ok" }));
            return;
        }
        if (req.method === "GET" && req.url === "/projects") {
            proxyGet("/project", res, config.opencodeServeUrl);
            return;
        }
        if (req.method === "GET" && req.url === "/sessions") {
            handleSessions(res, config);
            return;
        }
        res.writeHead(404);
        res.end("Not found");
    };
}
//# sourceMappingURL=http_routes.js.map