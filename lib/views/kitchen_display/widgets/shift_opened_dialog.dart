import 'package:flutter/material.dart';

import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class ShiftOpenedDialog extends StatelessWidget {
  const ShiftOpenedDialog({
    super.key,
    required this.message,
    required this.onClear,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onClear;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: colors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.unit,
        AppSpacing.unit,
        0,
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.unit,
        AppSpacing.gutter,
        AppSpacing.gutter,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.unit,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              'New business day',
              style: AppTextStyles.headlineMd.copyWith(
                color: colors.onSurface,
              ),
            ),
          ),
          IconButton(
            key: const Key('shift-opened-close'),
            onPressed: onDismiss,
            icon: Icon(Icons.close, color: colors.onSurfaceVariant),
          ),
        ],
      ),
      content: Text(
        message,
        style: AppTextStyles.bodyMd.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
      actions: [
        TextButton(
          key: const Key('shift-opened-cancel'),
          onPressed: onDismiss,
          child: Text(
            'Cancel',
            style: AppTextStyles.bodyMd.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        FilledButton(
          key: const Key('shift-opened-clear'),
          onPressed: onClear,
          child: Text(
            'Clear orders',
            style: AppTextStyles.bodyMd.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.onPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
