import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class OrderNoteBand extends StatelessWidget {
  const OrderNoteBand({super.key, required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color textColor = colors.onSurface;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.unit + 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: colors.outline)),
      ),
      child: Text.rich(
        TextSpan(
          style: AppTextStyles.bodyMd.copyWith(
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
          children: [
            const TextSpan(text: 'Note: '),
            TextSpan(text: note),
          ],
        ),
      ),
    );
  }
}
