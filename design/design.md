# Samanṭha — Design

The visual and interaction design for the Flutter chat client. This document
describes what was built, not what was planned — see `PROJECT_GUIDE.md` for
architecture and `scroll_position_control.md` for the scroll-follow spec.

## Context

A chat UI for an AI coding agent (`opencode`). Messages include code blocks,
diffs, file paths, tool-call output, and long streaming responses. Closer to
Claude Code / Cursor chat than to WhatsApp: content is technical,
monospace-heavy, and often long-form.

## Design system (`lib/app/theme.dart`)

### Palette

| Role              | Dark hex   | Light hex   | Usage                              |
| ----------------- | ---------- | ----------- | ---------------------------------- |
| Base surface      | `#0B0B0D`  | `#FAFAFA`   | Scaffold background                |
| Surface container | `#16161A`  | `#E4E4E7`   | Cards, input fields, chips         |
| Surface high      | `#1E1E24`  | `#D4D4D8`   | Buttons, elevated containers       |
| On-surface        | `#E4E4E7`  | `#18181B`   | Primary text                       |
| On-surface variant| `#71717A`  | `#52525B`   | Secondary text, labels             |
| Accent            | `#F97316`  | `#F97316`   | User messages, primary actions     |
| Accent dim        | `#B45309`  | `#B45309`   | Accent borders (dark)              |
| Agent surface     | `#111114`  | `#F4F4F5`   | Agent message bubble background    |
| User surface      | `#331C0A`  | `#FFEDD5`   | User message bubble background     |
| Code surface      | `#08080A`  | `#FFFFFF`   | Code block background              |
| Diff add          | `#22C55E`  | `#22C55E`   | `+` lines in diffs, tool success   |
| Diff remove       | `#EF4444`  | `#EF4444`   | `-` lines in diffs, errors         |
| Outline           | `#3F3F46`  | `#D4D4D8`   | Borders (0.5px default)            |
| Outline variant   | `#27272A`  | `#E4E4E7`   | Subtle borders                     |

### Type

- **Monospace** (`monospace`): all code, file paths, timestamps, tool labels,
  status text, model names, footer metadata. Leans into the coding-tool
  identity.
- **System sans** (null fontFamily): prose and UI chrome.
- **No serif** — it reads as generic "AI writing assistant," not a dev tool.

### Spacing scale

`4, 8, 12, 16, 24, 32, 48` — exposed as `AppTheme.space*` constants.

### Motion

- Short: 200ms (collapsible expand, opacity fades, chevron rotation)
- Medium: 300ms (scroll-to-bottom animation, send button)
- Long: 400ms (reserved)

### Glassmorphism

`BackdropFilter` with `sigmaX/Y: 15` and `surface.withValues(alpha: 0.5)` on
**transient/overlay layers only**:

- Top bar (`chat_screen.dart` `_TopBar`)
- Input bar (`message_input.dart`)
- Scroll-to-bottom pill (`scroll_to_bottom_button.dart`)

Never the base surface. Blur signals "temporary, content still below."

### Dark mode as default

`ThemeModeCubit` starts with `ThemeMode.dark`. Dark is the primary designed
theme (near-black base, true blacks for code surfaces). Light mode is a clean
inverse, not an afterthought.

---

## Component notes

### Message bubble (`message_bubble.dart`)

- **Sender differentiation**: alignment + color, never color alone.
  - User: right-aligned, accent-tinted surface (`userSurface`), accent border.
  - Agent: left-aligned, neutral surface (`agentSurface`), subtle border.
- **Asymmetric corner radius**: user bubble has a small bottom-right corner
  (4px); agent has a small bottom-left corner. Creates a "tail" pointing
  toward the sender.
- **Max width**: 76% of screen width (leaves room for the copy icon beside
  the bubble).
- **Tap to copy**: tapping a bubble with content reveals a bare copy icon
  beside it (left of user, right of agent). `AnimatedOpacity` fade in/out
  (200ms, no layout movement). Auto-hides after 5 seconds. Copies message
  content to clipboard; icon switches to a check for 1.5s.
- **Footer** (agent only): monospace metadata — token count, cost, duration,
  joined with middle dots.

**States**: default (rendered) / streaming (terminal cursor appended) /
thinking (shimmer label + pulse dot) / empty content (no copy button).

### Code block (`code_block.dart`)

- **All languages** supported (not just bash) — the parser extracts the
  language label from the opening fence.
- **Header bar**: language label (monospace) + terminal/code icon + copy
  button. Copy button shows a check + "Copied" for 1.5s.
- **Horizontal scroll** instead of wrap — long lines don't break the layout.
- **Diff coloring**: `diff` language blocks render line-by-line with
  `+` lines in green (`diffAdd` + `diffAddBg`), `-` lines in red
  (`diffRemove` + `diffRemoveBg`), `@@` hunk headers in tertiary.
- **Selectable text** for non-diff blocks.

### Streaming indicator (`terminal_cursor.dart`)

- **Signature element**: a blinking orange block cursor (8x16px, 600ms blink
  cycle) tied to opencode's terminal origins. Replaces the generic
  `CircularProgressIndicator` during streaming.
- Respects `MediaQuery.disableAnimationsOf` (reduced motion) — stops blinking
  but remains visible.

### Thinking block (`thinking_block.dart`)

- **Collapsible** reasoning, collapsed by default.
- **Shimmer label** while thinking (`ShimmerText` — a band of light sweeps
  across the glyphs, 1100ms cycle). Falls back to plain text when reduced
  motion is requested.
- **Static label** when done: "Thought for 3.2s" (monospace).
- Reasoning content is italic, monospace, `onSurfaceVariant`.

### Tool result chip (`tool_result_chip.dart`)

- **Tool-specific icons**: read=book, write=edit, bash=terminal, glob=search,
  grep=find, default=build.
- **No content**: compact success-tinted chip (green border + check icon).
- **With content**: collapsible block with the tool's output (monospace,
  selectable).
- **Todo lists**: rendered as a checklist with status icons (completed=green
  check, in_progress=tertiary pending, cancelled=red cancel).

### Tool status banner (`tool_status_banner.dart`)

- Shows when a tool is actively running (`currentToolName` is set).
- Monospace status text, tool-specific icon, accent-colored spinner.
- Positioned above the input bar with 80px bottom margin (clears the glass
  input area).

### Input composer (`message_input.dart`)

- **Context chips** above the text field: repo name (folder icon, monospace)
  + model name (memory icon). Horizontally scrollable.
- **Multi-line growth**: `minLines: 1, maxLines: 6` — grows with content.
- **Rectangular send button**: 44x44, 12px radius, `Icons.send`. Accent when
  text is present + connected; grey when empty or disconnected.
- **Glass backdrop**: `BackdropFilter` blur + 0.5px top border.
- **36px bottom spacing** inside the glass container (home-indicator clearance).

**States**: connected (accent send) / disconnected (disabled, grey send) /
empty (grey send) / has-text (accent send).

### Model picker (`model_text_field.dart`)

- **Bottom sheet** (not a dropdown/overlay) with search field and
  draggable handle — follows the "bottom sheets over modals" pattern.
- Monospace model names + provider subtitles.
- Selected model highlighted with accent tint + check icon.
- Empty state: "No models found."

### Connection status (`status_dot.dart`)

- **Chip** (not a bare dot): repo name + status label in monospace.
- **Pulsing dot** for `streaming` (accent) and `connecting` (amber).
- **Static dot** for `connected` (green) and `disconnected` (red).
- Bordered, `surfaceContainer` background.

### Scroll-to-bottom button (`scroll_to_bottom_button.dart`)

- **"Jump to latest"** pill (not "scroll to bottom") — glass backdrop, accent
  arrow, monospace label.
- `AnimatedCrossFade` for show/hide (via `scroll_to_bottom_fab.dart`).
- See `scroll_position_control.md` for the full scroll-follow logic.

### Connection settings screen

- Form with floating-label text fields (theme-driven `inputDecorationTheme`).
- "Test Connection" (outlined) + "Save & Connect" (filled) buttons.
- Inline test result: success (green-tinted) or failure (red-tinted) banner.
- On success → `ProjectSelectionRoute`.

### Project selection screen

- **Tabbed**: Repositories | Sessions.
- Repository tab: list of git worktrees, select + "New Session" button.
- Session tab: list of previous sessions with token count, cost, context %.
  Tapping a session immediately continues it.
- Empty states and error retry for both tabs.

### Error banner (`error_banner.dart`)

- Red-tinted border + background, error icon, monospace RETRY button.
- `formatErrorMessage()` (`error_message.dart`) maps raw exceptions to
  human-friendly strings ("Could not reach the server", "Invalid auth token",
  etc.).

---

## Patterns applied

- **Bottom sheets over modals**: model picker is a bottom sheet, not a
  dropdown or full-screen push.
- **Gesture vocabulary**: tap bubble = copy; horizontal drag on chat =
  reveal timestamps (leftward slide).
- **Restrained glassmorphism**: blur only on transient layers (top bar, input
  bar, scroll-to-bottom pill).
- **Dark mode as default**.
- **Micro-interactions (200–400ms)**: terminal cursor blink, shimmer label,
  copy-button check confirmation, collapsible chevron rotation, opacity fades.
  No decorative load animation — motion confirms state changes only.
