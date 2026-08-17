import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../core/utils/order_title_number.dart';
import '../services/order_title_number_preference_service.dart';

final Provider<OrderTitleNumberPreferenceService>
orderTitleNumberPreferenceServiceProvider =
    Provider<OrderTitleNumberPreferenceService>(
      (Ref ref) => OrderTitleNumberPreferenceService(),
    );

/// Ticket number shown in `Order #…` / `Cancelled #…` and spoken in TTS.
final StateProvider<OrderTitleNumberSource> orderTitleNumberSourceProvider =
    StateProvider<OrderTitleNumberSource>(
      (Ref ref) => OrderTitleNumberSource.displayNumber,
    );
