import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/controllers/order_controller.dart';
import 'package:order_master_kds/models/order_model.dart';
import 'package:order_master_kds/providers/providers.dart';

void main() {
  final DateTime now = DateTime.now();

  Future<ProviderContainer> pumpBoard({int cancelledSeconds = 30}) async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        kdsClockProvider.overrideWith((Ref ref) async* {
          yield now;
        }),
        cancelledDisplaySecondsProvider.overrideWith(
          (Ref ref) => cancelledSeconds,
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(orderControllerProvider.future);
    return container;
  }

  test('recent cancelled stays on Cooking and Cancelled; stale leaves Cooking',
      () async {
    final ProviderContainer container = await pumpBoard();
    final OrderController controller = container.read(
      orderControllerProvider.notifier,
    );
    final List<Order> cooking = container
        .read(orderControllerProvider)
        .requireValue
        .where((Order o) => o.status == OrderStatus.cooking)
        .toList();
    expect(cooking.length, greaterThanOrEqualTo(2));

    final Order recent = cooking[0].copyWith(
      status: OrderStatus.cancelled,
      version: cooking[0].version + 1,
      updatedAt: now.subtract(const Duration(seconds: 10)),
    );
    final Order stale = cooking[1].copyWith(
      status: OrderStatus.cancelled,
      version: cooking[1].version + 1,
      updatedAt: now.subtract(const Duration(seconds: 90)),
    );
    controller.replaceOrder(recent);
    controller.replaceOrder(stale);

    container.read(selectedKdsTabProvider.notifier).state = KdsTab.cooking;
    final List<String> cookingIds = container
        .read(ordersForCurrentViewProvider)
        .map((Order o) => o.id)
        .toList();
    expect(cookingIds, contains(recent.id));
    expect(cookingIds, isNot(contains(stale.id)));

    container.read(selectedKdsTabProvider.notifier).state = KdsTab.cancelled;
    final List<String> cancelledIds = container
        .read(ordersForCurrentViewProvider)
        .map((Order o) => o.id)
        .toList();
    expect(cancelledIds, containsAll(<String>[recent.id, stale.id]));

    final TabCounts counts = container.read(tabCountsProvider);
    expect(counts.cancelled, greaterThanOrEqualTo(2));
    expect(
      container
          .read(orderControllerProvider)
          .requireValue
          .where((Order o) => o.status == OrderStatus.completed)
          .length,
      counts.completed,
    );
  });

  test('1 minute setting keeps a 45-second-old cancel on Cooking', () async {
    final ProviderContainer container = await pumpBoard(cancelledSeconds: 60);

    final Order cooking = container
        .read(orderControllerProvider)
        .requireValue
        .firstWhere((Order o) => o.status == OrderStatus.cooking);
    container.read(orderControllerProvider.notifier).replaceOrder(
      cooking.copyWith(
        status: OrderStatus.cancelled,
        updatedAt: now.subtract(const Duration(seconds: 45)),
      ),
    );

    container.read(selectedKdsTabProvider.notifier).state = KdsTab.cooking;
    expect(
      container.read(ordersForCurrentViewProvider).map((Order o) => o.id),
      contains(cooking.id),
    );
  });
}
