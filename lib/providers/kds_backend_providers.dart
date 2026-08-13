import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../controllers/auth_controller.dart';
import '../models/auth_session.dart';
import '../models/bootstrap_result.dart';
import '../models/product_category_model.dart';
import '../models/product_model.dart';
import '../models/station_model.dart';
import '../services/kds_api_service.dart';
import '../services/kds_http_client.dart';
import '../services/mock_orders_service.dart';

final Provider<KdsHttpClient> kdsHttpClientProvider = Provider<KdsHttpClient>((
  Ref ref,
) {
  return KdsHttpClient(
    onUnauthorized: () {
      return ref.read(authControllerProvider.notifier).refreshSession();
    },
  );
});

final Provider<KdsApiService> kdsApiServiceProvider = Provider<KdsApiService>((
  Ref ref,
) {
  return KdsApiService(httpClient: ref.watch(kdsHttpClientProvider));
});

final Provider<MockOrdersService> mockOrdersServiceProvider =
    Provider<MockOrdersService>((Ref ref) => const MockOrdersService());

final StateProvider<String?> selectedStationProvider = StateProvider<String?>((
  Ref ref,
) {
  final List<Station> stations = const MockOrdersService().fetchStations();
  return stations.isEmpty ? null : stations.first.id;
});

/// Bootstrap catalog after login. Null until [BootstrapController.load] succeeds.
class BootstrapController extends Notifier<BootstrapResult?> {
  @override
  BootstrapResult? build() => null;

  Future<BootstrapResult?> load() async {
    final AuthState auth = ref.read(authControllerProvider);
    final AuthSession? session = auth.session;
    final String? deviceId = auth.deviceId;
    if (session == null || deviceId == null) {
      return null;
    }

    final BootstrapResult result = await ref
        .read(kdsApiServiceProvider)
        .bootstrap(session: session, deviceId: deviceId);
    state = result;

    final List<Station> activeStations = result.stations
        .where((Station s) => s.isActive)
        .toList();
    if (activeStations.isNotEmpty) {
      final String? current = ref.read(selectedStationProvider);
      final bool currentValid = activeStations.any(
        (Station s) => s.id == current,
      );
      if (!currentValid) {
        ref.read(selectedStationProvider.notifier).state =
            activeStations.first.id;
      }
      final String? stationId = ref.read(selectedStationProvider);
      if (stationId != null) {
        await ref.read(kdsApiServiceProvider).setDeviceStation(
          session: session,
          deviceId: deviceId,
          stationId: stationId,
        );
      }
    }
    return result;
  }

  void clear() => state = null;
}

final NotifierProvider<BootstrapController, BootstrapResult?>
bootstrapControllerProvider =
    NotifierProvider<BootstrapController, BootstrapResult?>(
      BootstrapController.new,
    );

final Provider<List<Station>> stationsProvider = Provider<List<Station>>((
  Ref ref,
) {
  final BootstrapResult? bootstrap = ref.watch(bootstrapControllerProvider);
  if (bootstrap != null) {
    return bootstrap.stations.where((Station s) => s.isActive).toList();
  }
  return ref.watch(mockOrdersServiceProvider).fetchStations();
});

final Provider<List<Product>> productsProvider = Provider<List<Product>>((
  Ref ref,
) {
  final BootstrapResult? bootstrap = ref.watch(bootstrapControllerProvider);
  if (bootstrap != null) {
    return bootstrap.products.where((Product p) => p.isActive).toList();
  }
  return ref.watch(mockOrdersServiceProvider).fetchProducts();
});

final Provider<List<ProductCategory>> productCategoriesProvider =
    Provider<List<ProductCategory>>((Ref ref) {
      final BootstrapResult? bootstrap = ref.watch(bootstrapControllerProvider);
      if (bootstrap != null) {
        return bootstrap.categories;
      }
      return ref.watch(mockOrdersServiceProvider).fetchCategories();
    });
