# Samanṭha Bridge Server

Bridge server that spawns `opencode` and exposes it over WebSocket + HTTP
for remote access from the Samanṭha Flutter app.

## Install

```bash
npm install
```

## Run

```bash
BRIDGE_AUTH_TOKEN=your-secret-token PORT=8383 npm start
```

Or for development with auto-reload:

```bash
BRIDGE_AUTH_TOKEN=your-secret-token npm run dev
```

### Environment Variables

| Variable             | Default | Description                              |
| -------------------- | ------- | ---------------------------------------- |
| `BRIDGE_AUTH_TOKEN`  | (required) | Shared secret for client authentication |
| `PORT`               | `8383`  | HTTP + WebSocket listen port             |

## Endpoints

- `GET /health` — `200 {"status":"ok","opencodeRunning":true}`
- `WS /chat` — Authenticated WebSocket for opencode communication

### WebSocket Protocol

1. Client sends auth message first: `{"type":"auth","token":"<secret>"}`
2. Client sends prompts: `{"type":"prompt","content":"<text>"}`
3. Server streams tokens: `{"type":"token","content":"<chunk>"}`
4. Server signals completion: `{"type":"done"}`
5. Server signals errors: `{"type":"error","message":"<text>"}`

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
