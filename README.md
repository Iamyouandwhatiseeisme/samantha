# Samanṭha

Remote chat client for [OpenCode](https://github.com/anomalyco/opencode) via Tailscale.

Use opencode from your phone — talk to your AI coding assistant anywhere.

## Architecture

```
Phone (Flutter app) ──WebSocket──▶ Laptop (bridge server) ──stdin/stdout──▶ opencode CLI
        │                                  │
        └──────── Tailscale VPN ────────────┘
```

| Component          | Runs on                             |
| ------------------ | ----------------------------------- |
| Tailscale client   | Laptop AND phone                    |
| Bridge server      | Laptop only                         |
| `opencode` process | Laptop only (spawned by the bridge) |
| Flutter app        | Phone only                          |

The laptop must be powered on, connected to Tailscale, and running the
bridge process for the app to work. This is not a hosted/always-on
service — it's your own machine acting as the server.

## Setup

### 1. Install Tailscale

On both the laptop and phone:

- Laptop: https://tailscale.com/download
- Phone: Tailscale app from the App Store / Play Store

Authenticate both devices to the **same Tailscale account**.

```bash
# On the laptop, get your tailnet IP:
tailscale up
tailscale ip -4
```

### 2. Start the Bridge Server

```bash
cd bridge
npm install
BRIDGE_AUTH_TOKEN=your-secret-token npm start
```

See [bridge/README.md](bridge/README.md) for persistent setup options (launchd, systemd, pm2).

### 3. Build the Flutter App

```bash
flutter pub get
dart run build_runner build
flutter run
```

### 4. Connect

1. Open the app on your phone
2. Enter the laptop's Tailscale IP and auth token in Connection Settings
3. Tap "Test Connection" to verify
4. Tap "Save & Connect" to start chatting with opencode

## Optional: Tailscale ACL Hardening

Limit which devices can reach the bridge port (8383) in the Tailscale admin console.

---

## Flutter Project Structure

```
lib/
├── main.dart                          # App entry point
├── app/
│   ├── app.dart                       # Root widget with BlocProviders
│   ├── injection.dart                 # DI setup (get_it + injectable)
│   ├── injection.config.dart          # Generated DI bindings
│   ├── module.dart                    # Module registrations (Dio, Prefs)
│   ├── router.dart                    # auto_route config
│   └── router.gr.dart                 # Generated routes
├── features/
│   ├── connection_settings/
│   │   ├── data/
│   │   │   ├── connection_api.dart
│   │   │   └── connection_settings_repository.dart
│   │   └── presentation/
│   │       ├── connection_settings_screen.dart
│   │       └── state/
│   │           ├── connection_settings_cubit.dart
│   │           └── connection_settings_state.dart
│   └── chat/
│       ├── data/
│       │   ├── chat_repository.dart
│       │   └── chat_socket_client.dart
│       ├── domain/
│       │   └── entities.dart          # ChatMessage, ChatRole
│       └── presentation/
│           ├── chat_screen.dart
│           └── state/
│               ├── chat_cubit.dart
│               └── chat_state.dart
└── core/
    └── models/
        └── app_error.dart
```

## Stack

- **State management**: flutter_bloc (Cubit)
- **DI**: injectable + get_it
- **Routing**: auto_route
- **HTTP**: dio
- **WebSocket**: web_socket_channel
- **Local storage**: shared_preferences (SharedPreferencesAsync)
