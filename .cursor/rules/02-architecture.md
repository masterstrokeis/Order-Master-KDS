---
description: MVC folder structure and layer responsibilities (Model/Controller/View) for the KDS app. Always relevant when creating or placing any new file.
alwaysApply: true
---

# Architecture — MVC, kept lightweight

## Folder structure
lib/
  main.dart
  app.dart                      # MaterialApp, theme, routing
  core/
    theme/                      # colors, text styles, spacing constants
    constants/
    utils/                      # pure helper functions only
    widgets/                    # shared/reusable widgets (buttons, badges)
  models/
    order_model.dart
    order_item_model.dart
    product_model.dart
    ...
  controllers/                  # Riverpod StateNotifier / Notifier classes
    order_controller.dart
    station_controller.dart
    ...
  views/
    kitchen_display/
      kitchen_display_screen.dart
      widgets/                  # widgets used ONLY on this screen
        order_card.dart
        order_card_header.dart
        continuation_card.dart
        product_sidebar.dart
        station_selector.dart
    completed_orders/
      ...
  services/                     # I/O boundary: API, websocket, local db
    orders_api_service.dart
    orders_socket_service.dart
  providers/
    providers.dart              # all top-level provider declarations, grouped

## The three layers, mapped to Flutter + Riverpod

- **Model** = plain Dart data classes in `models/`. Immutable, use `freezed` only
  if the project already depends on it; otherwise a hand-written `copyWith` is
  fine for a model with 5-6 fields. Don't add freezed/json_serializable just for
  this feature if the project doesn't already use them elsewhere.
- **Controller** = Riverpod `Notifier` / `AsyncNotifier` classes in `controllers/`.
  This is where order state, station selection, tab selection (Cooking/Completed),
  and "Start" button transitions live. Controllers talk to `services/`, never
  directly to widgets.
- **View** = widgets in `views/`. Views read state via `ref.watch`, call
  controller methods via `ref.read(...).method()`. Views must not contain
  business logic (no sorting/filtering/status math inline in `build()` —
  push that into the controller or a small pure function in `core/utils/`).

## Rules
1. **One controller per real concern**, not one per screen and not one per widget.
   Realistic set for this app: `OrderController` (order list + status transitions),
   `StationController` (selected cooking station), `TabController`-equivalent
   (Cooking vs Completed — this can just be a simple `StateProvider<KdsTab>`,
   no need for a full Notifier class for a two-value toggle).
2. **Don't wrap every primitive in a class.** A `StateProvider<bool>` for dark
   mode is fine as-is. Not everything needs a Notifier.
3. Services (`services/`) are the only place that talk to network/websocket/DB.
   Controllers depend on services through the constructor/provider, not by
   importing `dio`/`http` directly.
4. Keep **widgets in `views/<screen>/widgets/` scoped to that screen**. Only
   promote a widget to `core/widgets/` once it's actually reused in a second
   screen — don't guess ahead of time.
5. No `Provider` soup: before adding a new provider, check if the data can just
   be a derived/computed value from an existing one (`ref.watch` + a getter),
   instead of storing duplicate state.
