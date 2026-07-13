# Chat scroll position control

How the conversation transcript in `MessageList` decides where it is scrolled:
when it follows a streaming reply down, when it stops following because the
user scrolled away, and how it recovers a stable resting position at the
bottom after content grows. All line references are to `message_list.dart`
unless noted.

## The two pieces of state

The whole behaviour is driven by two flags on the transcript state:

- `followsStream` (default `true`) — the intent flag. When true, the view
  wants to keep the newest content pinned to the bottom as it grows. It is the
  single source of truth every auto-scroll path checks before moving the
  viewport.
- `_showScrollToBottom` (a `ValueNotifier<bool>`, default `false`) — the
  presentation flag. When true, the "Jump to latest" button is shown. It
  reflects the observed fact that the content is taller than the container
  *and* the viewport is not currently near the bottom.

These are deliberately separate. `followsStream` is about *what the view
should do* when content changes; `_showScrollToBottom` is about *what to show
the user right now*. They usually move together but are set from different
conditions and must not be collapsed into one flag.

## Reading scroll geometry

The core of the follow/unfollow decision is `_onScroll()` (the
`ScrollController` listener). On every scroll notification it reads:

- `maxScrollExtent` — the furthest the content can scroll.
- `pixels` — the current scroll offset.
- `viewportDimension` — the visible area height.
- `contentHeight` = `maxScrollExtent + viewportDimension` — the full laid-out
  content height.

From these it derives:

- `nearBottom` — `maxScrollExtent - pixels <= 60`. The bottom edge of the
  viewport is within 60 points of the bottom edge of the content. The 60-point
  slack makes "near the bottom" forgiving rather than pixel-exact.
- `sizeChanged` — `contentHeight` or `viewportDimension` changed since the
  last call. Distinguishes content-growth events from pure user-scroll events.

An `_isPinning` guard prevents re-entrancy: programmatic `jumpTo` calls fire
scroll notifications, which would otherwise loop back into `_onScroll` with a
stale `_lastContentHeight`.

## The follow/unfollow decision

`_onScroll()` does three things in sequence:

1. **Update follow intent from user motion:**
   - If `nearBottom` is true, set `followsStream = true`. Reaching the bottom —
     by any means, including the user dragging back down — re-arms following.
   - Else if `pixels < lastOffsetY - 8`, set `followsStream = false`. A scroll
     upward of more than 8 points is read as an intentional "I want to look
     back." The 8-point threshold absorbs sub-pixel jitter and tiny layout
     nudges.
   - Note the asymmetry: only an *upward* move past the threshold turns
     following off, while *any* arrival near the bottom turns it back on.

2. **Recompute the chevron flag:** `scrollable` is
   `maxScrollExtent > 8` (content overflows by more than 8 points). The button
   shows when `scrollable && !nearBottom`. Only written when it differs from
   the current value, avoiding redundant `ValueNotifier` fires.

3. **Keep the tail pinned while following:** if `followsStream` is true *and*
   `sizeChanged` *and* `maxScrollExtent > 0`, call `_pinToTailImmediate()`
   (an instant `jumpTo(maxScrollExtent)`). This is the path that makes a
   streaming reply scroll itself: as tokens arrive the content grows taller,
   that height change fires this closure, and the viewport is re-pinned to the
   tail. It is gated on a size change so that a pure offset change (the user
   scrolling by hand) never triggers an auto-scroll and never fights the user.

`jumpTo` is used (not `animateTo`) for the geometry-path re-pin because it
clamps to the live `maxScrollExtent` — it can neither overshoot nor land short,
which is what prevents the overscroll/halfway symptoms that motivated this
design.

## Event-driven re-pinning

Geometry changes cover growth *during* streaming, but several discrete moments
also need to force the view to the bottom. These are handled by a `BlocListener`
in `MessageList.build()` that calls `_onStateChanged(state)`, keyed on a
tail-shape + connection-status `listenWhen`:

- **New turn appended** — when the message count grew and any of the new
  messages is a `.user` turn, force `followsStream = true` and settle at the
  tail. Sending always yanks you to the bottom regardless of where you were.
- **Tail changed while following** — a new assistant/tool turn arrived while
  `followsStream` is already true → settle at the tail.
- **Streaming ends while following** — `connectionStatus` flips from
  `streaming` to `connected` → settle once more so the completed reply ends
  fully bottomed-out.

## `_settleAtTail` — winning the race against layout

Every event path funnels through `_settleAtTail()`:

```dart
void _settleAtTail() {
  if (!_followsStream) return;
  _pinToTailImmediate();
  for (final delay in const [80, 350]) {
    _settleTimers.add(Timer(Duration(milliseconds: delay), () {
      if (!mounted || !_followsStream) return;
      _pinToTailImmediate();
    }));
  }
}
```

It bails immediately if the view is no longer following — so an in-flight
settle cannot drag the user back down after they have scrolled up. It then
jumps once synchronously, and schedules two more jumps at 80ms and 350ms. The
reason for the repeats: content that is still laying out (markdown rendering,
a row expanding) can change height *after* the first jump, leaving the view a
little short of the true bottom. The delayed re-jumps re-pin against the
settled height. Each delayed pass re-checks `followsStream` and `mounted`, so
if the user scrolls up during the 350ms window the remaining passes abort.

## The scroll-to-bottom button

When `_showScrollToBottom` is true, a "Jump to latest" glass pill is overlaid
at the bottom center. Tapping it calls `_onButtonPressed()` which:
1. Sets `followsStream = true` (re-arming follow).
2. Animates to `maxScrollExtent` with a single 300ms `animateTo`.
3. On completion, calls `_settleAtTail()` to catch any residual layout.

There is no competing per-token animation anymore (the geometry path uses
instant `jumpTo`), so a single `animateTo` cannot be fought into an overshoot.

## Putting it together — the lifecycle

- **Idle, bottomed-out**: `followsStream = true`, button hidden.
- **User sends a message**: count grows with a `.user` tail → follow forced
  on, `_settleAtTail` snaps to bottom.
- **Assistant streams**: each token grows content height → geometry closure
  re-pins the tail while following. Viewport tracks the growing reply.
- **User scrolls up mid-stream**: offset drops more than 8 points →
  `followsStream = false`; content is scrollable and not near bottom → button
  appears. Subsequent height growth no longer re-pins, and any in-flight
  settle passes abort at their guard.
- **User scrolls back down (or taps the pill)**: reaching within 60 points of
  the bottom sets `nearBottom` → `followsStream = true`, button hides,
  following resumes.
- **Stream finishes while following**: `connectionStatus → connected`
  triggers a final `_settleAtTail` so the reply ends flush at the bottom.

## Why it is built this way

- **Intent vs. presentation split** keeps the "should I auto-scroll" decision
  independent from the "should I show the button" decision.
- **Thresholds** (60-point near-bottom slack, 8-point scroll-up deadband) make
  the flags robust to sub-pixel geometry noise and streaming layout shifts.
- **Size-change gating** on the geometry auto-scroll is the key to never
  fighting the user: the viewport only re-pins when the *content* changed
  size, never in response to the user's own scrolling.
- **Instant `jumpTo`** for the re-pin (not `animateTo`) clamps to the live
  bottom — no overshoot, no landing short.
- **The repeated delayed re-pins** absorb asynchronous layout that finishes
  after the initial jump.
