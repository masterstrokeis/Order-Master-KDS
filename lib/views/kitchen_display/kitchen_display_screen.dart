import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/order_controller.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/kds_api_logger.dart';
import '../../models/auth_session.dart';
import '../../models/bootstrap_result.dart';
import '../../models/order_model.dart';
import '../../providers/kds_backend_providers.dart';
import '../../services/kds_api_service.dart';
import '../../services/kds_websocket_service.dart';
import '../login/login_screen.dart';
import 'widgets/kds_top_bar.dart';
import 'widgets/order_board.dart';
import 'widgets/product_sidebar.dart';

class KitchenDisplayScreen extends ConsumerStatefulWidget {
  const KitchenDisplayScreen({super.key});

  @override
  ConsumerState<KitchenDisplayScreen> createState() =>
      _KitchenDisplayScreenState();
}

class _KitchenDisplayScreenState extends ConsumerState<KitchenDisplayScreen> {
  final KdsWebSocketService _socket = KdsWebSocketService();

  @override
  void initState() {
    super.initState();
    _socket.onOrderEvent = (Order order, String? cursor) {
      final OrderController controller = ref.read(
        orderControllerProvider.notifier,
      );
      controller.replaceOrder(order);
      controller.updateSyncCursor(cursor);
    };
    _socket.onSyncRequired = () {
      _catchUpSync();
    };
    _socket.onError = (Object error) {
      KdsApiLogger.websocket('onError: $error');
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectSocket();
    });
  }

  @override
  void dispose() {
    _socket.dispose();
    super.dispose();
  }

  Future<void> _connectSocket() async {
    final AuthState auth = ref.read(authControllerProvider);
    final AuthSession? session = auth.session;
    final String? deviceId = auth.deviceId;
    final BootstrapResult? bootstrap = ref.read(bootstrapControllerProvider);
    final String? stationId = ref.read(selectedStationProvider);
    if (session == null ||
        deviceId == null ||
        bootstrap == null ||
        stationId == null) {
      return;
    }

    final OrderController orders = ref.read(orderControllerProvider.notifier);
    await _socket.connect(
      config: bootstrap.websocket,
      session: session,
      deviceId: deviceId,
      stationId: stationId,
      lastCursor: orders.syncCursor,
    );
  }

  Future<void> _catchUpSync() async {
    final AuthState auth = ref.read(authControllerProvider);
    final AuthSession? session = auth.session;
    final String? deviceId = auth.deviceId;
    final String? stationId = ref.read(selectedStationProvider);
    final OrderController orders = ref.read(orderControllerProvider.notifier);
    final String? cursor = orders.syncCursor;
    if (session == null ||
        deviceId == null ||
        stationId == null ||
        cursor == null) {
      await orders.refresh();
      return;
    }

    final KdsApiService api = ref.read(kdsApiServiceProvider);
    final result = await api.syncSinceCursor(
      session: session,
      deviceId: deviceId,
      stationId: stationId,
      cursor: cursor,
    );
    await orders.applySyncResult(result);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (
      AuthState? previous,
      AuthState next,
    ) {
      final bool expired =
          next.status == AuthStatus.error &&
          next.errorMessage == AuthController.sessionExpiredMessage &&
          next.session == null;
      if (!expired) {
        return;
      }
      if (previous?.session == null &&
          previous?.errorMessage == AuthController.sessionExpiredMessage) {
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => const LoginScreen(),
        ),
        (Route<dynamic> route) => false,
      );
    });

    ref.listen<String?>(selectedStationProvider, (
      String? previous,
      String? next,
    ) async {
      if (next == null || next == previous) {
        return;
      }
      final AuthState auth = ref.read(authControllerProvider);
      if (auth.session != null && auth.deviceId != null) {
        await ref.read(kdsApiServiceProvider).setDeviceStation(
          session: auth.session!,
          deviceId: auth.deviceId!,
          stationId: next,
        );
      }
      await ref.read(orderControllerProvider.notifier).refresh();
      final OrderController orders = ref.read(orderControllerProvider.notifier);
      await _socket.updateStation(
        stationId: next,
        lastCursor: orders.syncCursor,
      );
    });

    final AsyncValue<List<Order>> ordersAsync = ref.watch(
      orderControllerProvider,
    );

    return Scaffold(
      body: Column(
        children: [
          const KdsTopBar(),
          Expanded(
            child: ordersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object error, StackTrace stackTrace) => Center(
                child: Text('Failed to load orders: $error'),
              ),
              data: (_) => Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ProductSidebar(),
                  Expanded(
                    child: ColoredBox(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.pageMargin),
                        child: LayoutBuilder(
                          builder:
                              (
                                BuildContext context,
                                BoxConstraints constraints,
                              ) {
                                return OrderBoard(
                                  boardWidth: constraints.maxWidth,
                                  boardHeight: constraints.maxHeight,
                                );
                              },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
