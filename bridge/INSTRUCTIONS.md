# Running the OpenCode Bridge Server (for Client Setup)

This explains how to start the Node.js bridge server that the Flutter chat
client connects to over Tailscale, with `caffeinate` keeping the Mac awake
while it's running.

## Prerequisites

- macOS (uses the built-in `caffeinate` command)
- Node.js + npm installed
- The `bridge/` project checked out locally
- Tailscale running and connected on both the server machine and the client device

## 1. Script location

The startup script lives inside the bridge project itself, so it stays
versioned with the code:

```
bridge/bin/serveopencode.sh
```

Contents:

```sh
#!/bin/sh
cd "$(dirname "$0")/.." && npm run build && BRIDGE_AUTH_TOKEN="your-token" npm run start
```

- `dirname "$0"` resolves to `bridge/bin`; `/..` moves up into `bridge/` so
  `npm run build` / `npm run start` run from the correct directory regardless
  of where the script is called from.
- Replace `"your-token"` with the actual `BRIDGE_AUTH_TOKEN` value the client
  is configured to send.

Make it executable once:

```bash
chmod +x bridge/bin/serveopencode.sh
```

## 2. Shell alias

Add an alias so the server can be started with one command, wrapped in
`caffeinate` so the machine won't idle-sleep mid-session:

```bash
echo 'alias serveopencode="caffeinate -i -s /absolute/path/to/bridge/bin/serveopencode.sh"' >> ~/.zshrc
source ~/.zshrc
```

Use the **absolute path** so the alias works from any directory.

`caffeinate` flags used:
- `-i` — prevent idle sleep
- `-s` — tie the caffeinate session to the script's process; sleep prevention
  ends automatically when the server stops

(Optional: add `-d` too if the display should also stay awake.)

## 3. Starting the server

From any terminal:

```bash
serveopencode
```

This will:
1. Keep the Mac from sleeping for as long as the process runs
2. Build the bridge (`npm run build`)
3. Start it with the auth token set (`npm run start`)

## 4. Client-side connection

Once the bridge is running, the Flutter client connects to it over Tailscale
using:
- The Tailscale IP/hostname of the machine running the bridge
- The same `BRIDGE_AUTH_TOKEN` value configured in the script

## Troubleshooting

- **`Permission denied`** → the script isn't executable yet; run
  `chmod +x bridge/bin/serveopencode.sh` again.
- **Alias not found after adding it** → run `source ~/.zshrc`, or open a new
  terminal tab.
- **Vim swap file warning on `.zshrc`** → harmless leftover from a previous
  edit session; safe to delete with `rm ~/.zshrc.swp` if no editor still has
  the file open.