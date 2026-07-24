# Samanṭha — TODO

Everything that needs to be done to support opencode wholly. Items are grouped
by area and ordered by priority within each group.

---

## Broken / non-functional

- [ ] **Fix permission flow.** The bridge runs `opencode run --auto`
      (`bridge/src/opencode.ts:172`), which auto-approves every tool call.
      `OpencodeProcess.reply()` is an empty no-op
      (`bridge/src/opencode.ts:455-457`). The app has a permission dialog UI
      (`chat_screen.dart:103-128`) and handles `PermissionRequestEvent`, but it
      will never fire. Either remove `--auto` and wire `reply()` to the
      opencode serve permission API, or remove the permission UI entirely.
- [ ] **Fix `set_model` to persist on the serve side.** The bridge just
      stores `currentModel` locally (`ws_handler.ts:434-442`) and passes it as
      `--model` on the next `opencode run` invocation. It doesn't call any
      serve API to persist the choice for the active session.
- [ ] **Fix `chat_cubit_test.dart`.** `sendMessage()` adds 2 messages (user +
      assistant streaming placeholder) but the test expects 1. The test
      assertion needs to match the actual emit sequence.
- [ ] **`opencode serve` crash recovery.** If the serve process crashes
      mid-stream, the bridge doesn't restart it. A serve crash hangs the
      WebSocket silently. Add a supervisor that detects serve death and
      restarts it, then notifies the client.

---

## Missing core features

- [x] **Stop / abort a running turn.** Stop message in WS protocol
      (`ws_handler.ts:444-456`), stop button in UI (`message_input.dart:147-164`),
      `OpencodeProcess.stop()` (`opencode.ts:425-453`), `ChatSocketClient.stop()`
      and `ChatCubit.stopGeneration()` all wired up.
- [x] **Syntax highlighting in code blocks.** Uses `highlight: ^0.7.0` with
      full RichText rendering and language-appropriate spans
      (`code_block.dart:123-158`).
- [x] **Message actions: retry, edit, branch.** Long-press triggers
      `MessageActionMenu` with retry, edit, copy code, branch
      (`message_bubble.dart:78-97`). `retryMessage()`, `editMessage()`,
      `branchFromMessage()` implemented in `chat_cubit.dart:462-596`.
- [x] **Collapsible tool output with line-count summary.** `CollapsibleBlock`
      defaults to collapsed (`initialExpanded = false`) with summary showing
      line count / KB / MB (`entities.dart:128-145`, `collapsible_block.dart:20`).
- [x] **Image rendering in messages.** `ChatMessage` has `images` field
      (`entities.dart:12`). Bridge extracts `image_url` and `binary` parts
      (`ws_handler.ts:304-317`). Images rendered with `Image.network`
      (`chat_message_content.dart:60-86`).
- [x] **File attachments in input.** Attachment button with `file_picker`
      integration (`message_input.dart:119-131, 202-234`). `PendingAttachment`
      entity, sent via WS prompt, bridge handles and forwards to serve API.
- [ ] **Agent selection.** opencode supports multiple agents (coder, task,
      etc.). Add an agent selector to the input bar or top bar and pass it
      through the bridge to the serve API.
- [x] **Session branching UI.** Tree-aware session list with fork indicators
      and "Branched session" label (`session_list_view.dart:61-77, 154-174`).
      `buildSessionTree()` builds parent-child tree (`project_api.dart:102-144`).
- [x] **Session management.** Delete with confirmation dialog and rename with
      text field dialog from popup menu on session tiles
      (`project_selection_screen.dart:89-202`, `session_list_view.dart:184-222`).
      API endpoints: `DELETE /session/:id` and `PATCH /session/:id`
      (`http_routes.ts:211-221`).
- [x] **Search within conversation.** Pull-down gesture on the chat list
      reveals a search bar that filters messages by text content
      (`message_list.dart:233-276`). Searches across `content`,
      `thinkingContent`, and `toolResults`. Matching text is highlighted
      with a primary-colored background (`chat_message_content.dart:164-211`).
- [x] **Export / share conversation.** Share button in top bar
      (`chat_top_bar.dart:78-87`), `ExportSheet` with markdown/plain text
      options, `ConversationExporter` class, uses `share_plus`.

---

## Mobile-specific

- [x] **Background socket survival.** `BackgroundTaskService` with native
      platform channel. `onAppPaused()` begins background task when streaming,
      `onAppResumed()` ends task and reconnects (`chat_cubit.dart:605-644`).
- [x] **Completion notification.** `NotificationService` with
      `flutter_local_notifications`. Triggered on `_handleDone()` with
      `shouldNotifyOnCompletion` logic and permission request flow.
- [ ] **Offline message queue.** If the connection drops, typed messages are
      lost. Queue unsent messages and retry on reconnect.
- [x] **Reconnection to in-progress stream.** On resume, the app reconnects,
      calls `set_session` to re-attach, then queries `turn_status` from the
      bridge (`ws_handler.ts:458-506`). The bridge checks the serve API for
      incomplete tool calls in the last message. If the turn is still active,
      the client keeps the streaming message and continues receiving tokens.
      If the turn finished, `_handleTurnStatus()` (`chat_cubit.dart:340-363`)
      finalizes the streaming message with the server's content and sets
      status to connected.

---

## UX gaps from the design brief

- [ ] **Swipe-left = copy, long-press = action menu.** Long-press = action
      menu is **done** (`message_bubble.dart:201`). Swipe-left still only
      reveals timestamps (`message_list.dart:286-300`). Needs swipe-left =
      copy gesture added per-message.
- [ ] **Adaptive input layout.** The design brief specifies "compact input
      vs. expanded composer with attachment/context chips" depending on
      session type (quick question vs. long agentic run vs. reviewing a
      diff). Currently the input is static.
- [ ] **Per-message delivery status.** The status chip shows global
      connection state but not per-message delivery status. The brief calls
      for treating connection state like a delivery receipt.
- [ ] **Command-line-style breadcrumbs for the active session.** The brief
      calls for this as a signature element alongside the terminal cursor.
      Show the session path / branch / model as a breadcrumb trail.
- [ ] **Context chips should be interactive.** Model chip **is** tappable
      (opens picker, `model_text_field.dart:90-91`). Repo chip is
      **display-only** (`status_dot.dart:70-78`) — needs to open project
      selection when tapped.

---

## Bridge-side gaps

- [ ] **Remove 500-char truncation on tool content.**
      `extractToolContent` slices output to 500 characters in 5 places:
      `helpers.ts:96-97`, `opencode.ts:284, 296, 414, 419, 421`. Long file
      reads or shell output is silently cut off. Send the full content and
      let the client collapse it.
- [ ] **Streaming tool output.** Tool output arrives as a single completed
      event. Long-running tools (multi-minute bash commands) show no progress.
      Stream intermediate output via the SSE event bus.
- [x] **Session messages fetch should include images.**
      `fetchSessionMessages` extracts both `image_url` and `binary` parts
      (`ws_handler.ts:304-317`) and includes them in the serialized response.
- [ ] **Config proxy.** No `/config` proxy endpoint. The app can't view or
      change opencode configuration (tools enabled, system prompt, etc.).
      Current routes: `/health`, `/projects`, `/sessions`,
      `DELETE /session/:id`, `PATCH /session/:id`.
- [ ] **Health check should report serve status.** `/health` only reports
      `{status: "ok"}` (`http_routes.ts:195-198`). Include
      `opencodeRunning: true/false` so the app can distinguish "bridge down"
      from "serve down."
