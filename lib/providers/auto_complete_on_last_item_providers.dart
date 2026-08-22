import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../services/auto_complete_on_last_item_preference_service.dart';

final Provider<AutoCompleteOnLastItemPreferenceService>
autoCompleteOnLastItemPreferenceServiceProvider =
    Provider<AutoCompleteOnLastItemPreferenceService>(
      (Ref ref) => AutoCompleteOnLastItemPreferenceService(),
    );

/// When true, striking the last active line also completes the ticket.
final StateProvider<bool> autoCompleteOnLastItemProvider = StateProvider<bool>(
  (Ref ref) => true,
);
