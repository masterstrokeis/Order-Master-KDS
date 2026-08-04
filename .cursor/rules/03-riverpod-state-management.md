---
description: How to structure and use Riverpod providers/notifiers in this app, including rebuild-optimization rules (.family, select) for the live order grid. Apply whenever writing or editing any provider, controller, or widget that reads state via ref.
alwaysApply: true
---

# Riverpod Rules

## Provider style
- Use **code-generated Riverpod** (`@riverpod` annotation + `riverpod_generator`)
  ONLY if the project already has build_runner set up and the team is fine with
  the codegen step. Otherwise, plain hand-written `NotifierProvider` /
  `AsyncNotifierProvider` is perfectly fine and one less build step to fight with
  in Cursor. Pick one style and stay consistent across the whole app — don't mix.
- Prefer `AsyncNotifier`/`FutureProvider` for anything backed by network/websocket
  (order list), so loading/error/data states are handled by Riverpod instead of
  hand-rolled booleans (`isLoading`, `hasError` fields).
- Use plain `StateProvider` for trivial UI-only toggles (dark mode, selected tab,
  selected station) — no need for a full Notifier class for a single value.

## Where state lives
- **Order list / statuses** → `AsyncNotifier<List<Order>>` in `OrderController`.
  Real-time updates (websocket/polling) push into this notifier; the UI never
  polls directly.
- **Selected station, selected tab, dark mode** → simple `StateProvider`s.
- **Derived data** (e.g. "orders filtered to Cooking tab", "count for badge")
  → a `Provider` (not stored state) that watches the base provider and computes
  the result. Never manually keep two lists in sync.

```dart
final ordersForTabProvider = Provider<List<Order>>((ref) {
  final tab = ref.watch(selectedTabProvider);
  final orders = ref.watch(orderControllerProvider).valueOrNull ?? [];
  return orders.where((o) => o.status == tab.toStatus()).toList();
});
```

## Rebuild discipline (this matters a lot for a grid of live-updating cards)
1. **Never watch the whole order list in a leaf widget** (e.g. a single
   `OrderCard`). Watch a provider scoped to that specific order's id
   (`.family`) so updating one order doesn't rebuild every card on screen.

```dart
final orderByIdProvider = Provider.family<Order, String>((ref, id) {
  return ref.watch(orderControllerProvider).valueOrNull
      ?.firstWhere((o) => o.id == id) ?? ...;
});
```

2. Use `select` when a widget only cares about one field of a bigger object
   (e.g. a card only needs `order.status` to decide its header color, not the
   whole `Order`):

```dart
final status = ref.watch(orderByIdProvider(orderId).select((o) => o.status));
```

3. Keep `ConsumerWidget`/`Consumer` scope as small as possible — wrap just the
   piece that needs to rebuild (e.g. the header color band), not the entire
   card, if only the status changes but items don't.
4. Avoid `ref.watch` inside `build()` methods that also do expensive layout
   work (e.g. the masonry column-packing calculation) — compute that in a
   controller/provider and hand the widget tree the already-resolved layout.

## Don't over-engineer
- No custom `Result<T>`/`Either` wrapper types unless the project already uses
  one elsewhere — Riverpod's `AsyncValue` already gives you loading/error/data.
- No service locator on top of Riverpod (no get_it + Riverpod both). Riverpod
  IS the DI here.
- Don't create a provider for something that's genuinely just local widget
  state (e.g. whether a card is mid-tap-animation) — plain `StatefulWidget`
  with `setState` is correct and simpler for pure UI micro-state.
