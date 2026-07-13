# Samanṭha Bridge Server

Bridge server that proxies to `opencode serve` and exposes it over WebSocket +
HTTP for remote access from the Samanṭha Flutter app.

The bridge does **not** spawn a raw `opencode` CLI process. It expects
`opencode serve` to be running (and starts it automatically if not) and
translates between the serve process's HTTP API + SSE event stream and the
simpler WebSocket protocol the app uses.

## Install

```bash
npm install
```

## Run

```bash
BRIDGE_AUTH_TOKEN=your-secret-token npm start
```

The bridge will start `opencode serve` automatically (on `127.0.0.1:0` by
default, or a configured port). If `opencode serve` is already running, the
bridge connects to it.

Or for development with auto-reload:

```bash
BRIDGE_AUTH_TOKEN=your-secret-token npm run dev
```

### Environment Variables

| Variable             | Default     | Description                                    |
| -------------------- | ----------- | ---------------------------------------------- |
| `BRIDGE_AUTH_TOKEN`  | (required)  | Shared secret for client authentication        |
| `PORT`               | `8383`      | HTTP + WebSocket listen port                   |

`opencode` must be installed and on `PATH`.

## Endpoints

| Method | Path         | Description                                        |
| ------ | ------------ | -------------------------------------------------- |
| GET    | `/health`    | `200 {"status":"ok"}` — bridge health check        |
| GET    | `/projects`  | Proxied to opencode serve `/project`               |
| GET    | `/sessions`  | Proxied to opencode serve `/session` (+ model info)|
| WS     | `/chat`      | Authenticated WebSocket for chat streaming         |

### WebSocket Protocol

#### Client → Server
| `type`                 | Fields                            | When                    |
| ---------------------- | --------------------------------- | ----------------------- |
| `auth`                 | `token`                           | First message           |
| `prompt`               | `content`, `model?`               | User message            |
| `get_models`           | —                                 | Request model list      |
| `set_model`            | `model`                           | Switch active model     |
| `get_session_messages` | `session_id`                      | Load session history    |
| `set_project`          | `path`                            | Set workspace           |
| `set_session`          | `session_id`, `path`              | Set session + workspace |
| `permission_response`  | `id`, `response` (`allow`/`deny`) | Respond to permission   |

#### Server → Client
| `type`               | Meaning                                       |
| -------------------- | --------------------------------------------- |
| `token`              | Assistant output chunk                        |
| `done`               | Turn complete (with token counts, cost)       |
| `thinking`           | Reasoning delta                               |
| `thinking_end`       | Reasoning block finished                      |
| `tool`               | Tool call status/result                       |
| `models`             | Available model providers                     |
| `model_set`          | Acknowledges `set_model`                      |
| `current_model`      | Active model from opencode serve              |
| `session_messages`   | Resumed session history                       |
| `permission_request` | Tool needs user approval                      |
| `auth_failed`        | Bad auth — client must NOT retry              |
| `error`              | Other error                                   |

### SSE Event Stream (`events.ts`)

The bridge subscribes to `opencode serve`'s `/event` SSE endpoint (scoped to
the active workspace directory) to get:

- **Reasoning deltas** — `message.part.delta` events for reasoning parts,
  coalesced on a 50ms timer so a fast model doesn't produce one WebSocket
  frame per token.
- **Reasoning block completion** — `message.part.updated` with `time.end`
  emits a `thinking_end` event with the block's duration.

Events are session-scoped: only reasoning parts matching the current
`sessionId` are forwarded, so a TUI running against the same serve process
doesn't leak into the app.

The stream auto-reconnects with exponential backoff (500ms → 5s cap).

## Tailscale Setup

1. Install Tailscale: https://tailscale.com/download
2. Authenticate: `tailscale up`
3. Get your tailnet IP: `tailscale ip -4`
4. Use that IP in the Flutter app's connection settings

## Running Persistently

### macOS (launchd)

Create `~/Library/LaunchAgents/com.samantha.bridge.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.samantha.bridge</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/node</string>
    <string>/path/to/bridge/dist/index.js</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>BRIDGE_AUTH_TOKEN</key>
    <string>your-secret-token</string>
    <key>PORT</key>
    <string>8383</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
</dict>
</plist>
```

Then: `launchctl load ~/Library/LaunchAgents/com.samantha.bridge.plist`

### Linux (systemd)

Create `/etc/systemd/system/samantha-bridge.service`:

```
[Unit]
Description=Samantha Bridge Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/node /path/to/bridge/dist/index.js
Environment=BRIDGE_AUTH_TOKEN=your-secret-token
Environment=PORT=8383
Restart=always

[Install]
WantedBy=multi-user.target
```

Then: `sudo systemctl enable --now samantha-bridge`

### Using pm2

```bash
npm install -g pm2
pm2 start dist/index.js --name samantha-bridge \
  --env BRIDGE_AUTH_TOKEN=your-secret-token
pm2 save
pm2 startup
```
