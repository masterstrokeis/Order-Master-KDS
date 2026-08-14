import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../providers/providers.dart';
import '../../../services/theme_preference_service.dart';

class DarkModeToggle extends ConsumerWidget {
  const DarkModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode mode = ref.watch(themeModeProvider);
    final bool isDark = mode == ThemeMode.dark;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Switch.adaptive(
          value: isDark,
          activeThumbColor: AppColors.statusTabActive,
          inactiveThumbColor: colorScheme.onSurfaceVariant,
          inactiveTrackColor: colorScheme.outline,
          onChanged: (bool value) async {
            final ThemeMode next = value ? ThemeMode.dark : ThemeMode.light;
            ref.read(themeModeProvider.notifier).state = next;
            final ThemePreferenceService service = ref.read(
              themePreferenceServiceProvider,
            );
            await service.save(next);
          },
        ),
        const SizedBox(width: AppSpacing.unit),
        Text(
          'Dark Mode',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
