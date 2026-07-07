# Project: Flutter Remote Chat Client for OpenCode (via Tailscale)

## Summary

`opencode` is a terminal CLI with no network interface — it only reads
stdin and writes stdout. This project makes it remotely accessible from a
phone by adding:

1. A **bridge server** that runs on the same laptop as `opencode`. It
   spawns/manages the `opencode` process and exposes it over WebSocket +
   HTTP on the local network.
2. **Tailscale**, installed on both the laptop and the phone, which gives
   the laptop a stable, routable IP/hostname reachable from anywhere
   (no port forwarding, no public exposure).
3. A **Flutter app** that is a pure WebSocket client — it has zero
   Tailscale-specific code. It just connects to whatever host/port the
   user configures in a settings screen, because the OS network stack
   (via Tailscale's VPN interface) transparently routes that traffic
   through the tailnet.

### Where everything runs

| Component          | Runs on                             |
| ------------------ | ----------------------------------- |
| Tailscale client   | Laptop AND phone                    |
| Bridge server      | Laptop only                         |
| `opencode` process | Laptop only (spawned by the bridge) |
| Flutter app        | Phone only                          |

The laptop must be powered on, connected to Tailscale, and running the
bridge process for the app to work. This is not a hosted/always-on
service — it's the user's own machine acting as the server.

### Data flow

---

## Part 1 — Bridge Server (`bridge/`)

### Purpose

Translate between "structured JSON over WebSocket" and "a terminal
process reading stdin / writing stdout." Also owns process lifecycle and
auth.

### Before writing code

Check whether `opencode` already exposes a server/daemon/JSON-RPC mode
(`opencode --help`, check its docs/repo). If it does, the bridge becomes a
thin authenticated proxy to that API instead of scraping raw terminal
output — much simpler and more reliable. Only fall back to raw
stdin/stdout piping if no such mode exists.

### Requirements

**Endpoints:**

- `GET /health` → `200 { "status": "ok" }`
  Used by the app's "Test Connection" button in settings.
- `WS /chat`
  - First message from client must be: `{ "type": "auth", "token": "<secret>" }`
    Reject/close the connection if missing or wrong.
  - Client → server: `{ "type": "prompt", "content": "<user text>" }`
  - Server → client, streamed:
    - `{ "type": "token", "content": "<chunk>" }` (repeated as output arrives)
    - `{ "type": "done" }` when the turn is complete
    - `{ "type": "error", "message": "<text>" }` on failure

**Behavior:**

- Spawn `opencode` as a child process per connection (or a shared process
  if opencode doesn't support concurrent sessions — verify this).
- Strip ANSI escape codes / terminal control sequences from stdout before
  forwarding as `token` events.
- Bind to `0.0.0.0:PORT` (default `8383`) so it's reachable via the
  Tailscale interface, not just localhost.
- Read `BRIDGE_AUTH_TOKEN` and `PORT` from environment variables — never
  hardcode secrets.
- Log connection open/close, auth failures, and child process errors to
  stdout.
- Gracefully kill the child process when the WebSocket disconnects.

### Tasks

1. `npm init -y`, add `ws` (or `socket.io`) + `express`/`fastify`.
2. Implement `/health`.
3. Implement `/chat` with the auth handshake described above.
4. Implement child process spawn/pipe/cleanup logic for `opencode`.
5. Write `bridge/README.md` covering:
   - Install: `npm install`
   - Run: `BRIDGE_AUTH_TOKEN=xxxx PORT=8383 npm start`
   - How to install Tailscale on this machine and get its IP:
     `tailscale up` then `tailscale ip -4`
   - How to keep it running persistently (systemd service on Linux,
     launchd on macOS, or just a note on using `pm2`/`screen`/`tmux`)

---

## Part 2 — Flutter App (`app/`)

### Stack conventions to follow

- State management: `flutter_bloc` (Cubit-based)
- Architecture: clean architecture, feature-first folder structure
- DI: `injectable` + `get_it`
- Routing: `auto_route`
- HTTP: `dio`
- WebSocket: `web_socket_channel`
- Local storage: `shared_preferences` (`SharedPreferencesAsync`)
- Testing: `bloc_test` + `mocktail`

### Feature: `connection_settings`

**Purpose:** let the user type in the laptop's Tailscale host/IP and the
shared auth token, and verify it works — instead of hardcoding it.

`data/`

- `ConnectionSettingsRepository`
  - `Future<void> saveHost(String host)`
  - `Future<String?> getHost()`
  - `Future<void> saveAuthToken(String token)`
  - `Future<String?> getAuthToken()`
  - Persisted via `SharedPreferencesAsync`, keys `opencode_host` /
    `opencode_auth_token`
- `ConnectionApi`
  - `Future<bool> checkHealth(String host)` → Dio GET to
    `http://$host:8383/health`, true on HTTP 200

`presentation/`

- `ConnectionSettingsCubit`
  States: `initial`, `loading`, `loaded(host, token)`, `testing`,
  `testSuccess`, `testFailure(message)`
- `ConnectionSettingsScreen`
  - Text field: host/IP (e.g. `100.101.102.103` or
    `laptop.tailnet-name.ts.net`)
  - Text field: auth token
  - "Test Connection" button → calls `checkHealth`, shows inline result
  - "Save" button → persists via repository

### Feature: `chat`

`data/`

- `ChatSocketClient`
  - Wraps `WebSocketChannel`
  - Sends the `auth` handshake message immediately on connect
  - Exposes `Stream<ChatEvent>` (typed: `TokenEvent`, `DoneEvent`,
    `ErrorEvent`) and `void sendPrompt(String text)`
- `ChatRepository`
  - Depends on `ChatSocketClient` + `ConnectionSettingsRepository`
  - `Future<void> connect()` — reads saved host/token, opens the socket
  - `Stream<ChatEvent> get events`
  - `void send(String prompt)`
  - `Future<void> disconnect()`

`domain/`

- `ChatMessage { id, role (user/assistant), content, isStreaming }`

`presentation/`

- `ChatCubit`
  States: `disconnected`, `connecting`, `connected`, `streaming`
  (appending tokens to the in-progress assistant message), `error(message)`
  - Implement reconnect-with-backoff on unexpected disconnect; surface
    connection state to the UI rather than silently retrying forever
- `ChatScreen`
  - Scrollable message list
  - Text input + send button
  - Connection status indicator in the app bar (connected/disconnected +
    current host)

### Routing

- Register `ConnectionSettingsRoute` and `ChatRoute` in `auto_route`.
- Guard `ChatRoute`: if no host is saved yet, redirect to
  `ConnectionSettingsRoute` first (same pattern as an `AuthGuard`).

### DI (injectable)

- `ConnectionSettingsRepository`, `ConnectionApi`, `ChatRepository` →
  lazy singleton
- `ChatSocketClient` → factory (fresh instance per connection, not a
  singleton)

### Testing

- `ConnectionSettingsCubit`: bloc_test for save success/failure and test-
  connection success/failure, mocking `ConnectionApi` with mocktail.
- `ChatCubit`: bloc_test for connect → streaming → done, and for connect
  failure → error. Simulate the event stream with a `StreamController` in
  tests to drive token-by-token arrival.

---

## Part 3 — Tailscale Setup (manual steps, document in root README)

1. Install Tailscale on the laptop: https://tailscale.com/download
2. `tailscale up`, log in with your account.
3. Install the Tailscale app on the phone, log into the **same account**.
4. On the laptop: `tailscale ip -4` to get the stable tailnet IP, or use
   the MagicDNS hostname shown in the Tailscale admin console
   (`laptop-name.tailnet-name.ts.net`).
5. Start the bridge server on the laptop.
6. In the Flutter app's Connection Settings screen: enter the host and
   auth token, tap "Test Connection," then "Save."
7. Optional hardening later: Tailscale ACLs to restrict which tailnet
   devices can reach port `8383`.

---

## Definition of done

- [ ] `bridge/` runs, responds to `/health`, authenticates WS connections,
      and streams a real `opencode` response back over `/chat`
- [ ] `app/` builds and runs on device/emulator
- [ ] Connection Settings screen saves host + token and successfully
      tests against a bridge on the same LAN (Tailscale not required to
      verify this — LAN/localhost is fine for initial dev)
- [ ] Chat screen connects, sends a prompt, renders streamed tokens live
- [ ] Reconnect logic handles a dropped WebSocket without crashing the UI
- [ ] Unit tests for `ConnectionSettingsCubit` and `ChatCubit` pass
- [ ] Root `README.md` documents full Tailscale + bridge + app setup

## Out of scope for this pass

- Multiple simultaneous opencode sessions/devices
- iOS background-mode hardening for long-lived sockets
- Visual polish beyond a functional chat + settings UI
- Any use of Tailscale's `tsnet` embedding — assumes the standard
  Tailscale apps are installed on both devices
