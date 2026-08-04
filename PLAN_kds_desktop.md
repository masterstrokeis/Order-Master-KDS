# KDS Desktop Screen Plan

## Scope and constraints
- Reproduce only the visible KDS desktop board: top controls, product summary sidebar, Cooking/Completed board, dynamic order cards, and continuation cards.
- Follow all six project rules: lightweight MVC; hand-written Riverpod (the project has no generator); no `GridView`, `Wrap`, or board/card scrollables; provider-computed packing; semantic theme tokens; and stable segment keys.
- Add no code generation. The only approved new runtime dependency is `shared_preferences` for the persisted theme choice.
- Reuse and extend [`lib/core/theme/`](lib/core/theme/) for all colors, dimensions, typography, and radii. Add a light `ThemeData` matching the screenshot while retaining the existing dark theme.

## 1. Screen inventory
- `KitchenDisplayScreen` — page-level constraints and shell; [`lib/views/kitchen_display/kitchen_display_screen.dart`](lib/views/kitchen_display/kitchen_display_screen.dart).
- `KdsTopBar` — La Botica label and the three control groups; [`lib/views/kitchen_display/widgets/kds_top_bar.dart`](lib/views/kitchen_display/widgets/kds_top_bar.dart).
  - `StationSelector` — Cooking Station dropdown; [`lib/views/kitchen_display/widgets/station_selector.dart`](lib/views/kitchen_display/widgets/station_selector.dart).
  - `OrderStatusTabs` — Cooking/Completed tabs and derived counts; [`lib/views/kitchen_display/widgets/order_status_tabs.dart`](lib/views/kitchen_display/widgets/order_status_tabs.dart).
  - `DarkModeToggle` — persisted `ThemeMode` switch; [`lib/views/kitchen_display/widgets/dark_mode_toggle.dart`](lib/views/kitchen_display/widgets/dark_mode_toggle.dart).
  - `UserAvatar` — initials derived from the selected login staff (`MC` in the reference); [`lib/views/kitchen_display/widgets/user_avatar.dart`](lib/views/kitchen_display/widgets/user_avatar.dart).
- `ProductSidebar` — fixed left rail and PRODUCT/QTY heading; [`lib/views/kitchen_display/widgets/product_sidebar.dart`](lib/views/kitchen_display/widgets/product_sidebar.dart).
  - `ProductCategorySection` — category heading plus rows; keep private in `product_sidebar.dart` initially.
  - `ProductQuantityRow` and dumb `QtyBadge` — product name and quantity derived from active Cooking orders; [`lib/views/kitchen_display/widgets/product_quantity_row.dart`](lib/views/kitchen_display/widgets/product_quantity_row.dart).
- `OrderBoard` — renders the already-packed `Row` of fixed-height `Column`s with no scrollables; [`lib/views/kitchen_display/widgets/order_board.dart`](lib/views/kitchen_display/widgets/order_board.dart).
  - `OrderBoardColumn` — one packed column; keep private in `order_board.dart` unless its build method becomes too large.
  - `BoardOverflowIndicator` — edge chip such as “+3 more orders waiting,” driven by `unplacedOrderIds`; [`lib/views/kitchen_display/widgets/board_overflow_indicator.dart`](lib/views/kitchen_display/widgets/board_overflow_indicator.dart).
- `OrderCard` — primary ticket composition and stable `orderId:segmentIndex` key; [`lib/views/kitchen_display/widgets/order_card.dart`](lib/views/kitchen_display/widgets/order_card.dart).
  - `StatusHeaderBand` — layered status/urgency color, order number, time, and a compact top-right order-type indicator (icon + short label such as “Dine-In” / “Delivery” / “Take-Out”); [`lib/views/kitchen_display/widgets/status_header_band.dart`](lib/views/kitchen_display/widgets/status_header_band.dart).
    - `OrderTypeHeaderIndicator` — small high-contrast icon + short type label in the header’s former action-icon slot; keep private in `status_header_band.dart` unless reused. Distinct from the full detail row below (header says “Dine-In”; row says “Table - 05”).
  - `OrderTypeRow` / `OrderTypeBadge` — full detail under the header: “Table - 05” / “Delivery” / “Take-Out” plus customer/diner name and icon; [`lib/views/kitchen_display/widgets/order_type_row.dart`](lib/views/kitchen_display/widgets/order_type_row.dart). Unchanged in role — keeps specific table/customer detail, not the compact type summary.
  - `OrderItemList` / `OrderItemRow` — quantity, item name, optional modifier subtext, optional Note line; double-tap toggles item done (strikethrough) only while parent order is `cooking`; [`lib/views/kitchen_display/widgets/order_item_row.dart`](lib/views/kitchen_display/widgets/order_item_row.dart).
  - `OrderActionFooter` — fixed-height status action area: Start/Cooking/Complete progression for active orders, and a durable outlined “Roll back” action for completed orders. The rollback uses an existing neutral/secondary token rather than critical red and keeps the same footer height so tab/status changes do not affect packing; [`lib/views/kitchen_display/widgets/order_action_footer.dart`](lib/views/kitchen_display/widgets/order_action_footer.dart).
  - `ContinuedLabel` — incoming/outgoing “Continued…” marker; [`lib/views/kitchen_display/widgets/continued_label.dart`](lib/views/kitchen_display/widgets/continued_label.dart).
- `ContinuationCard` — omits the original order header/type row, renders its item slice (same double-tap item-done behavior when parent is cooking), and only shows the order action footer on the final segment; [`lib/views/kitchen_display/widgets/continuation_card.dart`](lib/views/kitchen_display/widgets/continuation_card.dart).

## 2. Models needed
Use immutable handwritten classes/enums under [`lib/models/`](lib/models/) with explicit public field types and `copyWith` only where mutation is required.

- `Order` in [`lib/models/order_model.dart`](lib/models/order_model.dart):
  - Required: `id`, `displayNumber`, `stationId`, `createdAt`, `type`, `status`, `items`.
  - Optional: `tableNumber` (dine-in only), `customerName`, and `note` only if an order-level note appears later.
  - No `headerAction` — trash/print header actions are removed from the design.
  - Header color is derived, never stored: `status` supplies the base semantic color and elapsed-time urgency can override it.
- `OrderStatus` enum: `newOrder`, `cooking`, `completed`; authoritative for lifecycle and tab filtering.
  - Base header colors (named theme tokens): slate for new, orange for cooking, neutral slate/gray for completed.
- `OrderUrgency` enum: `normal`, `warning`, `critical`; derived from `createdAt`, not stored on `Order`. Constants live in [`lib/core/constants/kds_timing.dart`](lib/core/constants/kds_timing.dart): 10 minutes warning (amber), 15 minutes critical (red overrides base).
- `OrderType` enum: `dineIn`, `delivery`, `takeOut`; drives both the compact header indicator labels/icons and the full type-row detail. `tableNumber` is valid only for `dineIn`.
- `OrderItem` in [`lib/models/order_item_model.dart`](lib/models/order_item_model.dart):
  - Required: `id`, `productId`, `nameSnapshot`, `quantity`, `isCompleted` (bool, default `false`).
  - Optional: `modifierText` (gray ingredient/modifier subtext), `note` (the emphasized “Note: No onions” line).
  - Keep a name snapshot so a live product rename does not alter an existing ticket.
  - `isCompleted` is item-level prep state owned by `OrderController`, not local widget state — it must survive rebuilds and re-packing. Marking all items done does **not** auto-complete the order.
- `Product` in [`lib/models/product_model.dart`](lib/models/product_model.dart): required `id`, `name`, `categoryId`. Quantity is derived from active Cooking orders and is not stored. Item-level station routing is deferred to v2.
- `ProductCategory` in [`lib/models/product_category_model.dart`](lib/models/product_category_model.dart): required `id`, `name`, `sortOrder`; supports SEAFOODS/SOUPS/SALADS grouping.
- `Station` in [`lib/models/station_model.dart`](lib/models/station_model.dart): required `id`, `name`; optional `displayOrder`.
- `CardSegment` and `PackedOrderBoard` in [`lib/core/utils/order_column_packer.dart`](lib/core/utils/order_column_packer.dart): layout-only immutable DTOs, not domain models. A segment carries `orderId`, `segmentIndex`, item start/end indices, primary/final flags, estimated height, and continuation-label flags; the packed result carries columns plus unplaced order IDs.
- No new user model in this scope: `UserAvatar` derives initials from existing auth/current-staff state.

## 3. Controllers and providers
Declare top-level providers together in [`lib/providers/providers.dart`](lib/providers/providers.dart), matching the existing handwritten Riverpod style.

- `OrderController` / `AsyncNotifierProvider<OrderController, List<Order>>` in [`lib/controllers/order_controller.dart`](lib/controllers/order_controller.dart):
  - Owns the canonical order list.
  - Whole-order transitions: `startOrder(orderId)` (`newOrder` → `cooking`) and `completeOrder(orderId)` (`cooking` → `completed`) via the footer.
  - Recovery transition: `rollbackOrder(orderId)` changes only `completed` orders back to `cooking`; it is guarded/no-op for `newOrder` or `cooking`. It deliberately does not reset the order or its item completion state.
  - After rollback, existing derived filtering handles the move automatically: the order disappears from Completed and reappears in Cooking as an in-progress order. Do not add separate tab-specific lists or manual movement logic.
  - Item-level: `toggleItemCompleted(orderId, itemId)` flips `OrderItem.isCompleted`, allowed only when the parent order’s status is `cooking` (no-op for `newOrder` / `completed`).
  - Marking every item done does **not** call `completeOrder` — order completion stays a manual footer action.
  - Loads deterministic active and completed data from [`lib/services/mock_orders_service.dart`](lib/services/mock_orders_service.dart); later, only the service/controller input changes to API/websocket updates.
- `selectedKdsTabProvider` (`StateProvider<KdsTab>`): stored UI state for Cooking vs Completed.
- `selectedStationProvider` (`StateProvider<String?>`): stored selected station ID; station choices come from `stationsProvider` backed by mock data.
- `themeModeProvider` (`StateProvider<ThemeMode>`): app-wide theme selection (single global `ThemeMode`), initialized to light. App bootstrap reads the saved value through [`lib/services/theme_preference_service.dart`](lib/services/theme_preference_service.dart), toggles persist through `shared_preferences`, and [`lib/app.dart`](lib/app.dart) applies `appLightTheme`/`appDarkTheme`. No per-screen theme override.
- `ordersForCurrentViewProvider`: derived from canonical orders + selected tab + selected station. Cooking selects all non-completed orders; Completed selects only completed orders.
- `tabCountsProvider`: derived Cooking/Completed counts for the selected station.
- `productQuantitiesProvider`: derived category/product totals from active Cooking orders for the selected station, regardless of the open tab.
- `orderByIdProvider.family`: derived per-order lookup; leaf consumers use `.select` for fields such as status or individual item `isCompleted`.
- `kdsClockProvider`: one shared tick every **30 seconds**, used only by header urgency consumers. This bounds warning/critical color staleness to under 30 seconds and must not rebuild or repack the full board.
- `orderUrgencyProvider.family`: derived from `createdAt` plus the clock. Under 10 minutes uses the status base color; 10–15 minutes layers amber warning; 15+ minutes overrides the header to critical red.
- `packedOrderBoardProvider.family<PackedOrderBoard, BoardLayoutConstraints>`: derived/cached packing output. It watches filtered orders and receives immutable board width/height from the screen’s one top-level `LayoutBuilder`. Repacking happens only when constraints or order/item *content that affects height* change — toggling `isCompleted` must **not** trigger a repack (height is identical with or without strikethrough).
- The packing algorithm remains a pure function; do not introduce a mutable `MasonryController` or stored column lists.

## 4. Masonry grid and continuation-card plan
Implement and unit-test a pure Dart `packOrderColumns(...)` function in [`lib/core/utils/order_column_packer.dart`](lib/core/utils/order_column_packer.dart); the Riverpod family supplies inputs and caches its derived output.

1. Derive usable board width after the sidebar and page gutters. Use **280px** as the baseline `minimumColumnWidth` (from the HTML reference). Compute `columnCount = floor((usableWidth + gutter) / (minimumColumnWidth + gutter))`, clamp to the design target of **2–5 columns** (2 on tablet, 4–5 on desktop), and fall back to one only when the window cannot hold two minimum-width cards. Compute exact shared column width from the remaining width. Keep minimum width, max columns, and chrome heights in centralized layout/theme constants. Exact breakpoint tuning is deferred to visual calibration against `screen.png` in build step 10.
2. Estimate each item at the resolved width: estimate wrapped line counts from available text width and a conservative average-character width; multiply by known name/modifier/note line heights; then add row gaps/padding and fixed chrome heights. Header chrome includes room for the compact order-type indicator (icon + short label) in the top-right slot formerly occupied by the action icon — size the header-band height constant to fit order number, time, and that indicator without clipping. Also add fixed order-type-row, continuation-label, footer, border, and column-gap heights. Add a small safety allowance so estimates split early rather than clip. Do not render widgets off-screen to measure.
3. **Packing-safety constraint — dynamic state never changes reserved height:** `OrderItem.isCompleted` changes only text decoration (`TextDecoration.lineThrough` on name/modifier/note), and `OrderActionFooter` reserves the same fixed height for Start, Cooking/Complete, Completed, and Roll back states. Item rows and footers therefore retain identical height across status changes. Height estimation must ignore `isCompleted`. Tests must verify item-height stability independently for (a) a name-only item, (b) an item with wrapped modifier text, (c) an item with a Note line, and (d) an item containing both modifier and Note lines; also verify footer-height stability for completed/rollback rendering.
4. Sort filtered orders oldest first, then fill columns chronologically left-to-right and top-to-bottom. This is deliberate KDS reading order, not shortest-column balancing. First test whether the complete primary segment, including footer, fits the current remaining height.
5. If it does not fit, take the largest whole-item prefix that fits with primary chrome plus an outgoing `Continued…` label. If even one item cannot fit, advance to the next column rather than producing an empty/tiny segment.
6. Start the next physical column with a continuation segment and keep taking the largest whole-item slice that fits. Intermediate segments reserve both incoming and outgoing labels; only the final segment reserves and renders the action footer. Support more than one continuation for very large orders.
7. Reserve the standard card gap after each segment. Return stable segment indices and explicit estimated heights so the widget tree performs only a simple render pass.
8. If all columns are exhausted, return remaining order IDs in `unplacedOrderIds` and render a non-intrusive edge chip such as “+3 more orders waiting.” Do not add scrolling. Pagination/auto-rotation is a fast-follow, not v1 scope.

Risk assumptions and open points specific to packing:
- Chronological column flow is confirmed because staff must read oldest tickets first and continuations must begin in the next physical column.
- Text estimates can differ across platforms. Use conservative estimates and boundary tests; if clipping remains, tune constants rather than adding hidden scrolling or off-screen measurement.
- The reference demonstrates one continuation per order; support multiple segments because the no-scroll rule otherwise fails for very long tickets.
- Minimum column width is locked at 280px; 2 / 4–5 column targets are locked. Exact pixel breakpoints for tablet vs desktop are calibration targets during step 10, not pre-specified constants.
- Finite capacity is explicit: `unplacedOrderIds` is always valid and visible through the overflow indicator rather than silently dropping orders.
- Item-done strikethrough is explicitly height-neutral so live double-taps cannot thrash the packer.

## 5. Incremental build order
1. Add immutable domain models (including `OrderItem.isCompleted`), deterministic mock catalog/stations/active and completed orders, and model/controller tests — covering `startOrder`, `completeOrder`, `rollbackOrder`, and `toggleItemCompleted` status guards. Verify rollback only allows `completed` → `cooking`, preserves item state, and is a no-op for other statuses.
2. Extend semantic status/urgency theme tokens (`statusNew`, `statusCooking`, `statusCompleted`, `urgencyWarning` amber, `urgencyCritical` red) and add `appLightTheme`; default the KDS to light without changing unrelated login styling.
3. Build the static `KitchenDisplayScreen` shell: top bar, display-only sidebar, and empty fixed-height board; verify landscape constraints and 48px touch targets.
4. Build card anatomy with representative mock orders, modifiers, notes, all order types, layered status/urgency bands with compact header type indicator, and a manually supplied continuation segment. Wire no-op TODO callbacks only for remaining unspecified actions (e.g. card tap, avatar). No trash/print header actions.
5. Implement `packOrderColumns` and tests for exact fit, early move, primary+continuation, multi-continuation, footer placement, resize/column-count boundaries, and exhausted-board reporting. Add explicit before/after-`isCompleted` height assertions for a name-only item, an item with wrapped modifier text, an item with a Note line, and an item containing both modifier and Note lines. Include a 20+ order / 10+ item worst case.
6. Add `packedOrderBoardProvider.family` and render columns with stable keys; verify there are no scrollables and no packing work in leaf widget builds.
7. Wire selected station/tab, derived counts, Cooking-only sidebar totals, urgency clock, per-order providers, whole-order Start/Complete/Roll back transitions, and item double-tap → `toggleItemCompleted`. On Completed, the final segment’s fixed-height footer invokes `rollbackOrder(orderId)`; derived filtering naturally moves the order back to Cooking. The final continuation uses the same order-ID footer methods. Keep Consumer scopes narrow and animate headers for 150–250ms.
8. Persist light/dark preference with `shared_preferences` (app-wide), then wire successful PIN login to the KDS and derive avatar initials from `AuthState.selectedStaff`.
9. Add `BoardOverflowIndicator`; verify unplaced orders are counted without crashes or silent disappearance. Leave pagination/auto-rotation as a documented fast-follow.
10. Calibrate spacing/type and column breakpoints against `screen.png` (280px min width, 2-tablet / 4–5-desktop targets), run `flutter analyze` and tests, then profile resize/live updates for smooth 60fps behavior — including double-tap item-done without grid thrashing.
11. Later integration boundary: replace mock loading with the real API/websocket service while preserving `AsyncValue` and existing view/provider contracts.

## 6. Confirmed decisions and remaining open questions
Confirmed for v1:
- Status is authoritative: slate base for new, orange base for cooking, neutral slate/gray for completed — all as named theme tokens. Elapsed urgency layers over status: amber for 10–15 minutes warning, red for 15+ minutes critical.
- Tabs fully swap board data; sidebar totals always represent active Cooking work only.
- Start acts on the whole order, keeps it visible, and replaces the button with “Cooking…”, then Complete moves it to the Completed tab. A final continuation uses the same order-ID footer actions.
- Every completed order has a durable, always-available outlined “Roll back” action in its final card footer. `rollbackOrder(orderId)` permits only `completed` → `cooking`, preserves order/item data, and relies on existing tab filtering to move the ticket from Completed back to Cooking. Its neutral/secondary styling must not resemble the red critical state, and its fixed height must match every other footer state.
- Overflow is represented by a small `+N more orders waiting` chip. Pagination/rotation is deferred.
- Packing is chronological; station filtering is order-level; sidebar rows are display-only.
- Header has **no** trash/print actions. The top-right header slot is a compact order-type indicator (icon + short label). The full `OrderTypeRow` below stays for table/customer detail without duplicating the same text.
- Per-item mark-as-done: double-tap toggles `OrderItem.isCompleted` via `OrderController.toggleItemCompleted`, only while order status is `cooking`. Visual = strikethrough; height unchanged so packing is unaffected. Completing all items does **not** auto-complete the order.
- Urgency time updates use one shared 30-second clock tick, limiting threshold-color staleness to under 30 seconds without triggering board repacking.
- Optional later polish (not v1): subtle Complete-button highlight when all items are marked done — hint only, never an automatic trigger.
- Card tap and avatar hooks remain visible no-op callbacks with TODO comments where behavior is still unspecified.
- Theme is app-wide (single global `ThemeMode` via `shared_preferences`). KDS defaults to light after login; a manual dark switch applies app-wide including across logout/login. No per-screen theme override.
- Minimum column width is 280px; target 4–5 columns on desktop and 2 on tablet. Exact breakpoint pixels are tuned visually in build step 10.
- KDS is the post-login destination; avatar initials come from selected staff.

Still open/deferred:
- Optional Complete-button highlight when all items are marked done (nice-to-have polish; not v1).
- Optional immediate post-Complete snackbar/toast with a short-lived fast “Undo.” This supplements the durable Completed-tab Roll back button and must never replace it.
- Pagination / auto-rotation for overflow beyond the `+N more` chip (fast-follow).
- Item-level station routing (v2 model change if real kitchens need grill vs cold splits).
