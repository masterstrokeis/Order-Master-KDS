import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../providers/providers.dart';

class OrderStatusTabs extends ConsumerWidget {
  const OrderStatusTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final KdsTab selected = ref.watch(selectedKdsTabProvider);
    final TabCounts counts = ref.watch(tabCountsProvider);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.lightSidebar,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TabButton(
            label: 'Cooking (${counts.cooking})',
            selected: selected == KdsTab.cooking,
            selectedColor: AppColors.statusTabActive,
            selectedForeground: AppColors.onStatusHeader,
            onTap: () {
              ref.read(selectedKdsTabProvider.notifier).state = KdsTab.cooking;
            },
          ),
          const SizedBox(width: 4),
          _TabButton(
            label: 'Completed (${counts.completed})',
            selected: selected == KdsTab.completed,
            selectedColor: Colors.white,
            selectedForeground: AppColors.lightOnSurface,
            onTap: () {
              ref.read(selectedKdsTabProvider.notifier).state =
                  KdsTab.completed;
            },
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.selectedForeground,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final Color selectedForeground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? selectedColor : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.touchTargetMin * 0.75,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.gutter + 8,
              vertical: 10,
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? selectedForeground : Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
