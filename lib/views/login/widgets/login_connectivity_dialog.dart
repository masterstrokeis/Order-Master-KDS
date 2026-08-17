import 'package:flutter/material.dart';

import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class LoginConnectivityDialog extends StatelessWidget {
  const LoginConnectivityDialog({
    super.key,
    required this.onChangeServer,
    required this.onDismiss,
  });

  final VoidCallback onChangeServer;
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
              'Server unreachable',
              style: AppTextStyles.headlineMd.copyWith(
                color: colors.onSurface,
              ),
            ),
          ),
          IconButton(
            key: const Key('login-connectivity-close'),
            onPressed: onDismiss,
            icon: Icon(Icons.close, color: colors.onSurfaceVariant),
          ),
        ],
      ),
      content: Text(
        'Could not reach the kitchen server. Check that this device is on '
        'the same Wi‑Fi network and that the server address is correct.',
        style: AppTextStyles.bodyMd.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
      actions: [
        TextButton(
          key: const Key('login-connectivity-dismiss'),
          onPressed: onDismiss,
          child: Text(
            'Dismiss',
            style: AppTextStyles.bodyMd.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        FilledButton(
          key: const Key('login-connectivity-change-server'),
          onPressed: onChangeServer,
          child: Text(
            'Change server',
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
