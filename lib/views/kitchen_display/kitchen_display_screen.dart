import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/order_controller.dart';
import '../../core/constants/kds_timing.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/cancelled_cooking_visibility.dart';
import '../../core/utils/kds_api_logger.dart';
import '../../core/utils/order_catch_up.dart';
import '../../models/auth_session.dart';
import '../../models/bootstrap_result.dart';
import '../../models/kds_api_error.dart';
import '../../models/order_model.dart';
import '../../providers/providers.dart';
import '../../services/kds_api_service.dart';
import '../../services/kds_websocket_service.dart';
import '../login/login_screen.dart';
import 'widgets/kds_keyboard_scope.dart';
import 'widgets/kds_top_bar.dart';
import 'widgets/keypad_legend_bar.dart';
import 'widgets/keypad_type_ahead_indicator.dart';
import 'widgets/order_board.dart';
import 'widgets/product_sidebar.dart';
import 'widgets/shift_opened_dialog.dart';

class KitchenDisplayScreen extends ConsumerStatefulWidget {
  const KitchenDisplayScreen({super.key, this.socket});

  final KdsWebSocketService? socket;

  @override
  ConsumerState<KitchenDisplayScreen> createState() =>
      _KitchenDisplayScreenState();
}

class _KitchenDisplayScreenState extends ConsumerState<KitchenDisplayScreen> {
  late final KdsWebSocketService _socket =
      widget.socket ?? KdsWebSocketService();
  bool _catchUpInFlight = false;
  ProviderSubscription<AsyncValue<List<Order>>>? _shiftOpenedBoardSub;

  @override
  void initState() {
    super.initState();
    _socket.resolveAppliedCursor = () =>
        ref.read(orderControllerProvider.notifier).syncCursor;
    _socket.resolveSession = () => ref.read(authControllerProvider).session;
    _socket.onOrderEvent = (Order order, String? cursor) {
      final OrderController controller = ref.read(
        orderControllerProvider.notifier,
      );
      controller.replaceOrder(order);
      controller.updateSyncCursor(cursor);
    };
    _socket.onSyncRequired = () {
      unawaited(_catchUpSync());
    };
    _socket.onShiftEvent = _onShiftEvent;
    _socket.onError = (Object error) {
      KdsApiLogger.websocket('onError: $error');
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectSocket();
    });
  }

  @override
  void dispose() {
    _detachShiftOpenedAutoDismiss();
    _socket.dispose();
    super.dispose();
  }

  void _onShiftEvent(ShiftEventKind kind, String message) {
    if (!mounted) {
      return;
    }
    if (ref.read(announcementsEnabledProvider)) {
      unawaited(ref.read(kdsTtsServiceProvider).speak(message));
    }
    switch (kind) {
      case ShiftEventKind.closed:
        _showShiftClosedToast(message);
      case ShiftEventKind.opened:
        ref.read(orderControllerProvider.notifier).markCurrentOrdersStale();
        unawaited(_presentShiftOpenedDialog(message));
    }
  }

  void _showShiftClosedToast(String message) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTextStyles.bodyMd.copyWith(color: colors.onInverseSurface),
        ),
        backgroundColor: colors.inverseSurface,
        behavior: SnackBarBehavior.floating,
        duration: KdsTiming.shiftNoticeDuration,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        margin: const EdgeInsets.all(AppSpacing.gutter),
      ),
    );
  }

  bool _hasCookingBoardTickets(List<Order> orders) {
    return hasCookingBoardOrders(
      orders: orders,
      stationId: ref.read(selectedStationProvider),
      now: ref.read(kdsClockProvider).value ?? DateTime.now(),
      cancelledDisplayDuration: Duration(
        seconds: ref.read(cancelledDisplaySecondsProvider),
      ),
    );
  }

  void _detachShiftOpenedAutoDismiss() {
    _shiftOpenedBoardSub?.close();
    _shiftOpenedBoardSub = null;
  }

  void _attachShiftOpenedAutoDismiss() {
    _detachShiftOpenedAutoDismiss();
    _shiftOpenedBoardSub = ref.listenManual<AsyncValue<List<Order>>>(
      orderControllerProvider,
      (AsyncValue<List<Order>>? previous, AsyncValue<List<Order>> next) {
        final List<Order> orders = next.value ?? <Order>[];
        if (!_hasCookingBoardTickets(orders)) {
          return;
        }
        _detachShiftOpenedAutoDismiss();
        final NavigatorState navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.pop();
        }
      },
    );
  }

  Future<void> _presentShiftOpenedDialog(String message) async {
    if (!mounted) {
      return;
    }
    final List<Order> orders =
        ref.read(orderControllerProvider).value ?? <Order>[];
    final bool autoDismissOnFirstOrder = !_hasCookingBoardTickets(orders);
    if (autoDismissOnFirstOrder) {
      _attachShiftOpenedAutoDismiss();
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return ShiftOpenedDialog(
          message: message,
          onDismiss: () => Navigator.of(dialogContext).pop(),
          onClear: () {
            Navigator.of(dialogContext).pop();
            ref.read(orderControllerProvider.notifier).clearStationOrders();
          },
        );
      },
    );
    // Cancel, X, Clear, and auto-dismiss all complete this future — drop the
    // listen so a later order cannot pop an unrelated route.
    _detachShiftOpenedAutoDismiss();
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
    if (_catchUpInFlight) {
      return;
    }
    _catchUpInFlight = true;
    try {
      final AuthState auth = ref.read(authControllerProvider);
      final AuthSession? session = auth.session;
      final String? deviceId = auth.deviceId;
      final String? stationId = ref.read(selectedStationProvider);
      final OrderController orders = ref.read(orderControllerProvider.notifier);
      if (session == null || deviceId == null || stationId == null) {
        await orders.refresh();
        return;
      }

      final KdsApiService api = ref.read(kdsApiServiceProvider);
      await catchUpOrders(
        cursor: orders.syncCursor,
        syncSinceCursor: (String cursor) {
          return api.syncSinceCursor(
            session: session,
            deviceId: deviceId,
            stationId: stationId,
            cursor: cursor,
          );
        },
        applySyncResult: orders.applySyncResult,
        refresh: orders.refresh,
      );
    } finally {
      _catchUpInFlight = false;
    }
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
        await ref
            .read(kdsApiServiceProvider)
            .setDeviceStation(
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
      body: KdsKeyboardScope(
        child: Column(
          children: [
            const KdsTopBar(),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ordersAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (Object error, StackTrace stackTrace) => Center(
                      child: Text(
                        error is KdsApiError ? error.message : error.toString(),
                      ),
                    ),
                    data: (_) {
                      final bool showProductQuantityList = ref.watch(
                        productQuantityListVisibleProvider,
                      );
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showProductQuantityList) const ProductSidebar(),
                          Expanded(
                            child: ColoredBox(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              child: Padding(
                                padding: const EdgeInsets.all(
                                  AppSpacing.pageMargin,
                                ),
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
                      );
                    },
                  ),
                  const KeypadTypeAheadIndicator(),
                ],
              ),
            ),
            const KeypadLegendBar(),
          ],
        ),
      ),
    );
  }
}
