---
description: Theming, color, spacing, and reusable widget conventions matching the Order Master KDS design (badges, status bands, item rows, buttons). Apply when building or editing any UI widget, theme file, or styling-related code.
alwaysApply: false
---

# UI & Styling Rules

## Theming
- Define all colors, spacing, radii, and text styles in `core/theme/` — no
  hardcoded hex colors or magic numbers (`16.0`, `12.0`) scattered in widgets.
- Support light theme (as shown in design) and the "Dark Mode" toggle seen in
  the top bar — use `ThemeData`/`ThemeMode` properly, don't hand-roll a second
  color set with if/else checks in every widget.
- Status colors (red = new, green = active tab/cooking, orange = Start button,
  dark navy = sidebar/topbar, gray = ready/completed) should be named semantic
  constants (`AppColors.statusNew`, `AppColors.statusCooking`, etc.), not raw
  hex values reused inline.

## Reusable widgets to extract (matches the reference design)
- `OrderTypeBadge` — bordered, bold-text pill for "Table - 05" / "Delivery" /
  "Take-Out".
- `StatusHeaderBand` — colored top section of the card (order #, timestamp,
  status icon).
- `OrderItemRow` — qty + name + optional modifier subtext + optional Note line.
- `StartButton` — outlined button used at card footer.
- `ContinuedLabel` — "Continued... ↓ / ↑" indicator, reused on both the
  truncated card and its continuation.
- `QtyBadge` — used in the sidebar product list.

Keep each of these small and dumb (pure UI, props in → widget out). No
`ref.watch` inside these leaf widgets unless it's genuinely needed for a
per-order rebuild optimization (see performance doc) — prefer passing data in
via constructor from the parent `OrderCard`.

## Consistency
- Match spacing/radius from the reference: ~8–12px card corner radius,
  consistent internal padding (use one `AppSpacing` scale, e.g. 4/8/12/16/24,
  don't invent new values per widget).
- Icons: use `Icons.*`/an icon package already in the project rather than
  custom SVG assets unless a specific icon (shopping bag, printer, timer) isn't
  available in Material icons.

## Don't over-engineer the UI layer
- No custom widget-building "DSL" or config-driven card renderer — a card has
  a known, fixed shape (header, order-type row, item list, footer). Just build
  it directly as a widget tree.
- No animation library unless the project already has one — Flutter's built-in
  `Animated*` widgets are enough for header color transitions and card entry.
