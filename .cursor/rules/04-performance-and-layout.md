---
description: Performance and layout rules for the no-scroll, dynamic-height masonry order grid with continuation cards. Apply when building or editing the kitchen display screen, order grid, order cards, or any column-packing/measurement logic.
alwaysApply: false
---

# Performance & Layout Rules (Masonry Order Grid)

This screen updates live and must stay smooth. These rules are specific to the
"no scroll, dynamic-height cards, overflow continues in next column" layout.

## Layout approach
1. **Do not use a `GridView`** — it assumes fixed cell sizes and doesn't fit
   variable-height cards. Do not use `Wrap` either, since it doesn't guarantee
   items land in a fixed number of columns with no scrolling.
2. Build the masonry layout with a **custom column-packing algorithm** run in a
   controller/provider (pure Dart, no widgets involved):
   - Measure each order's rendered height ahead of layout using a lightweight
     estimate (line count × known row height + header height + footer height)
     rather than actually rendering off-screen widgets to measure them.
   - Pack orders into N columns (N = however many fit the current screen width)
     greedily by remaining column height, splitting an order into a "primary"
     + "continuation" segment when it would overflow the visible column height.
   - Output a plain data structure (e.g. `List<List<CardSegment>>`, one list
     per column) that the widget tree just renders — no measuring logic inside
     `build()`.
3. On the widget side, lay out columns with a `Row` of `Column`s (or
   `IntrinsicHeight`/`Flex` as needed), each column sized to the available
   screen height, **no scrollables anywhere** (no `SingleChildScrollView`,
   no `ListView`). This matches the "no scroll" requirement directly.
4. Recompute the packing only when:
   - the order list changes (new order, item added/removed, status changed), or
   - the screen is resized/rotated.
   Never recompute it on every frame or every rebuild unrelated to those events.

## General Flutter performance rules
1. Use `const` constructors everywhere possible (card chrome, icons, static
   text) — this is a live-updating screen, const widgets are skipped on rebuild.
2. Give every `OrderCard` (and continuation card) a **stable `Key`** based on
   order id (+ segment index for continuations), so Flutter can diff instead of
   rebuilding the whole grid when one order changes.
3. Avoid rebuilding the entire grid provider when only one order's status
   changes — see `03-riverpod-state-management.md` for `.family` + `select`
   usage. The grid-packing provider should itself only recompute for the
   specific column(s) affected, if that's feasible; otherwise at minimum the
   individual `OrderCard` widgets must not fully rebuild.
4. No `Opacity` widgets for static content — use `AnimatedOpacity`/precomputed
   colors instead; `Opacity` forces a full repaint layer.
5. Any status-color transition (red → green header) should use a short
   `AnimatedContainer`/`AnimatedSwitcher` (150–250ms), not an abrupt jump —
   feels smoother for staff watching the board, but keep durations short so the
   board still reads as "live," not "laggy."
6. Real-time updates (websocket) should update Riverpod state directly;
   don't poll with `Timer.periodic` rebuilding the full screen if a socket/stream
   is available.
7. Test with a realistic worst case: ~20+ simultaneous orders, several with
   10+ items, to confirm no scroll/no jank and that continuation logic holds up
   before considering the layout done.

## Things to avoid
- Don't rebuild the masonry packing algorithm inside `build()`.
- Don't use `MediaQuery.of(context)` deep inside every card — read screen
  dimensions once at the top (kitchen_display_screen.dart) and pass computed
  column width down.
- Don't add scroll physics "just in case" — the spec is explicitly no-scroll;
  if content doesn't fit, that's a continuation-card case, not a scroll case.
