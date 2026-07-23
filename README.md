# Samanṭha

Remote chat client for [OpenCode](https://github.com/anomalyco/opencode) via Tailscale.

Use opencode from your phone — talk to your AI coding assistant anywhere.

## Architecture

```
Phone (Flutter app) ──WebSocket──▶ Laptop (bridge server) ──HTTP/SSE──▶ opencode serve
         │                                  │
         └──────── Tailscale VPN ────────────┘
```

| Component          | Runs on                             |
| ------------------ | ----------------------------------- |
| Tailscale client   | Laptop AND phone                    |
| Bridge server      | Laptop only                         |
| `opencode serve`   | Laptop only (managed by the bridge) |
| Flutter app        | Phone only                          |

The laptop must be powered on, connected to Tailscale, and running the
bridge process for the app to work. This is not a hosted/always-on
service — it's your own machine acting as the server.

The bridge does **not** spawn a raw `opencode` CLI process. Instead it
expects `opencode serve` to be running (or starts it itself) and proxies
to its HTTP API + SSE event stream. All assistant output, tool calls,
reasoning deltas, and session history come from the serve process's API.

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

The bridge will start `opencode serve` automatically if it's not already
running. See [bridge/README.md](bridge/README.md) for persistent setup
options (launchd, systemd, pm2) and environment variables.

comes with presefined bash script to properly runopencode

### 3. Build the Flutter App

```bash
flutter pub get
dart run build_runner build        # regen injection.config.dart + router.gr.dart
flutter run
```

### 4. Connect

1. Open the app on your phone.
2. Enter the laptop's Tailscale IP and auth token in Connection Settings.
3. Tap "Test Connection" to verify the bridge is reachable.
4. Tap "Save & Connect" — on success you'll land on the Project Selection
   screen.
5. Pick a repository (new session) or an existing session, then chat.

## Optional: Tailscale ACL Hardening

Limit which devices can reach the bridge port (8383) in the Tailscale
admin console.

---

## Flutter Project Structure

```
lib/
├── main.dart                              App entry point
├── app/
│   ├── app.dart                           Root widget: MultiBlocProvider + MaterialApp.router
│   ├── theme.dart                         Design tokens: dark/light ThemeData + AppColors extension
│   ├── theme_mode_cubit.dart              Persists theme mode to SharedPreferences
│   ├── injection.dart                     configureDependencies() — injectable init
│   ├── injection.config.dart              GENERATED — do not hand-edit
│   ├── module.dart                        @module: Dio + SharedPreferences singletons
│   ├── router.dart                        AppRouter: ConnectionSettings → ProjectSelection → Chat
│   └── router.gr.dart                     GENERATED auto_route routes
├── common/
│   └── extensions/
│       └── date_time_x.dart               toRelative() extension on DateTime
├── features/
│   ├── connection_settings/
│   │   ├── data/
│   │   │   ├── connection_api.dart                 dio GET /health
│   │   │   └── connection_settings_repository.dart  SharedPreferences: host, token, projectPath, sessionId
│   │   └── presentation/
│   │       ├── connection_settings_screen.dart     Form UI: Test Connection, Save & Connect
│   │       └── state/
│   │           ├── connection_settings_cubit.dart   load/save/updateHost/updateAuthToken/testConnection
│   │           └── connection_settings_state.dart   sealed: Initial/Loading/Loaded/Testing/TestSuccess/TestFailure
│   ├── project_selection/
│   │   ├── data/
│   │   │   └── project_api.dart                    dio GET /projects, /sessions (proxied to opencode serve)
│   │   └── presentation/
│   │       └── project_selection_screen.dart       Tabbed: Repositories | Sessions → Chat
│   └── chat/
│       ├── data/
│       │   ├── chat_socket_client.dart             WebSocket: auth, events, set_model, permissions, sessions
│       │   ├── chat_repository.dart                Wraps socket client + settings repo + tool-content parsing
│       │   └── error_message.dart                  formatErrorMessage() — human-friendly error strings
│       ├── domain/
│       │   ├── entities.dart                       ChatMessage, ChatRole, ToolResult, ToolContent, TodoItem
│       │   └── chat_message_formatting.dart        buildFooterParts() — token count, cost, duration
│       └── presentation/
│           ├── chat_screen.dart                    Top bar (glass), message list, input, scroll control
│           └── widgets/
│               ├── message_bubble.dart             User/agent bubbles, tap-to-copy, asymmetric corners
│               ├── chat_message_content.dart       Markdown + code parsing, streaming cursor, thinking block
│               ├── code_block.dart                 Language-labeled, copy button, horizontal scroll, diff coloring
│               ├── terminal_cursor.dart            Blinking block cursor — streaming signature element
│               ├── thinking_block.dart             Collapsible reasoning, shimmer label while thinking
│               ├── collapsible_block.dart          Reusable expand/collapse with chevron rotation
│               ├── tool_result_chip.dart           Tool call results, todo lists, success/error states
│               ├── tool_status_banner.dart         Active tool-call progress indicator
│               ├── message_input.dart              Multi-line input, context chips, rectangular send button
│               ├── model_text_field.dart           Model picker — opens as bottom sheet with search
│               ├── status_dot.dart                 Connection chip: repo name + status label + pulsing dot
│               ├── scroll_to_bottom_button.dart    "Jump to latest" glass pill
│               ├── scroll_to_bottom_fab.dart       AnimatedCrossFade wrapper for the button
│               ├── pulse_dot.dart                  Pulsing opacity dot for "thinking" state
│               └── error_banner.dart               Error display with retry action
└── (core/ — reserved, currently empty)
```

## Stack

- **State management**: flutter_bloc (Cubit)
- **DI**: injectable + get_it
- **Routing**: auto_route (3 routes: ConnectionSettings → ProjectSelection → Chat)
- **HTTP**: dio (health check, project/session listing)
- **WebSocket**: web_socket_channel (chat streaming)
- **Local storage**: shared_preferences (host, token, project path, session ID, theme mode)
- **Theming**: custom `AppTheme` with `AppColors` `ThemeExtension` — dark mode default
- **Testing**: bloc_test + mocktail

## Design System

Defined in `lib/app/theme.dart`:

- **Dark mode is the default** (designed first); light mode is a clean inverse.
- **Palette**: near-black base (`#0B0B0D`), orange accent (`#F97316`) for user
  messages and primary actions, neutral surface tones for agent messages,
  green/red semantic pair for diff and tool success/fail.
- **Type**: monospace for all code, paths, timestamps, labels; system sans for
  prose and UI chrome. No serif.
- **Glassmorphism**: `BackdropFilter` blur on transient layers only — top bar,
  input bar, scroll-to-bottom pill. Never the base surface.
- **Signature element**: blinking terminal block cursor (`TerminalCursor`)
  signals streaming, tied to opencode's terminal origins.
