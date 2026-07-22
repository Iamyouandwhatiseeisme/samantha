# Samanṭha — TODO

Everything that needs to be done to support opencode wholly. Items are grouped
by area and ordered by priority within each group.

---

## Broken / non-functional

- [ ] **Fix permission flow.** The bridge runs `opencode run --auto`
      (`bridge/src/opencode.ts:109`), which auto-approves every tool call.
      `OpencodeProcess.reply()` is an empty no-op
      (`bridge/src/opencode.ts:339-341`). The app has a permission dialog UI
      (`chat_screen.dart:118`) and handles `PermissionRequestEvent`, but it
      will never fire. Either remove `--auto` and wire `reply()` to the
      opencode serve permission API, or remove the permission UI entirely.
- [ ] **Fix `set_model` to persist on the serve side.** The bridge just
      stores `currentModel` locally (`server.ts:550-555`) and passes it as
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

- [ ] **Stop / abort a running turn.** The bridge has
      `OpencodeProcess.stop()` (`opencode.ts:332`) but there's no `stop`
      message type in the WebSocket protocol and no stop button in the UI.
      Add a `stop` client→bridge message, wire it to `OpencodeProcess.stop()`,
      and add a stop button to the input bar that replaces the send button
      while streaming.
- [ ] **Syntax highlighting in code blocks.** Code blocks are monospace-only.
      Add a highlighting package (`flutter_highlight` or similar) and render
      code with language-appropriate colors. The `CodeBlock` widget
      (`code_block.dart`) already extracts the language label.
- [ ] **Message actions: retry, edit, branch.** Long-press a message → action
      menu with: retry (re-run from that point), edit (change the prompt and
      re-run), copy code, branch from here (fork the session at that message).
      opencode's serve API supports session forking.
- [ ] **Collapsible tool output with line-count summary.** Tool output is
      collapsible but defaults to expanded. Change the default to collapsed
      with a summary like "127 lines" or "2.3 KB" and expand on tap. This is
      the single highest-leverage difference from a consumer chat app for a
      coding tool.
- [ ] **Image rendering in messages.** `ChatMessage` (`entities.dart`) has no
      image field. If opencode returns image parts they are silently dropped.
      Add an image field to `ChatMessage`, handle image parts in the bridge's
      `fetchSessionMessages` serializer (`server.ts:367-483`), and render
      images in `ChatMessageContent`.
- [ ] **File attachments in input.** No way to attach images or files to a
      prompt. Add an attachment button to the input bar, encode images, and
      send them via the WebSocket protocol.
- [ ] **Agent selection.** opencode supports multiple agents (coder, task,
      etc.). Add an agent selector to the input bar or top bar and pass it
      through the bridge to the serve API.
- [ ] **Session branching UI.** The project selection screen lists sessions
      linearly. opencode sessions can branch — show "forked from" indicators
      and a tree-aware list rather than a flat list.
- [ ] **Session management.** Add the ability to delete and rename sessions
      from the project selection screen.
- [x] **Search within conversation.** Pull-down gesture on the chat list
      reveals a search bar that filters messages by text content.
- [x] **Export / share conversation.** Add a share button that exports the
      conversation as markdown or plain text.

---

## Mobile-specific

- [x] **Background socket survival.** The WebSocket dies when the app goes to
      background on iOS. Add a background mode (or a graceful pause/resume
      that re-attaches to the session on foreground) so a long agentic run
      doesn't silently disconnect.
- [x] **Completion notification.** If the app is backgrounded during a long
      turn, send a local notification when the response finishes.
- [ ] **Offline message queue.** If the connection drops, typed messages are
      lost. Queue unsent messages and retry on reconnect.
- [ ] **Reconnection to in-progress stream.** If the socket drops mid-stream
      and reconnects, the app starts fresh. The session still exists on the
      serve side — re-attach to the running turn by fetching session messages
      and checking if the turn is still active.

---

## UX gaps from the design brief

- [ ] **Swipe-left = copy, long-press = action menu.** Swipe-left currently
      reveals timestamps only. The design brief specifies swipe-left = copy,
      long-press = action menu (retry, edit, copy code, branch). Keep the
      timestamp reveal on swipe but add long-press actions.
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
- [ ] **Context chips should be interactive.** The repo + model chips above
      the input are display-only. Make them tappable: repo chip opens project
      selection, model chip opens the model picker bottom sheet.

---

## Bridge-side gaps

- [ ] **Remove 500-char truncation on tool content.**
      `extractToolContent` slices output to 500 characters (`server.ts:349`,
      `opencode.ts:326`). Long file reads or shell output is silently cut
      off. Send the full content and let the client collapse it.
- [ ] **Streaming tool output.** Tool output arrives as a single completed
      event. Long-running tools (multi-minute bash commands) show no progress.
      Stream intermediate output via the SSE event bus.
- [ ] **Session messages fetch should include images.** The
      `fetchSessionMessages` serializer (`server.ts:367-483`) only extracts
      text, reasoning, and tool parts — no image parts.
- [ ] **Config proxy.** No `/config` proxy endpoint. The app can't view or
      change opencode configuration (tools enabled, system prompt, etc.).
- [ ] **Health check should report serve status.** `/health` only reports the
      bridge's own status, not whether `opencode serve` is alive. Include
      `opencodeRunning: true/false` so the app can distinguish "bridge down"
      from "serve down."
