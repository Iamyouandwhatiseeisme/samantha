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
