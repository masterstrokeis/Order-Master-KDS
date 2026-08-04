import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';

enum ContinuedLabelDirection { outgoing, incoming }

class ContinuedLabel extends StatelessWidget {
  const ContinuedLabel({super.key, required this.direction});

  final ContinuedLabelDirection direction;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool outgoing = direction == ContinuedLabelDirection.outgoing;

    return Padding(
      padding: EdgeInsets.only(
        top: outgoing ? AppSpacing.unit : 0,
        bottom: outgoing ? 0 : AppSpacing.unit,
        right: outgoing ? AppSpacing.unit + 4 : 0,
        left: outgoing ? 0 : AppSpacing.unit + 4,
      ),
      child: Align(
        alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Continued...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              outgoing ? Icons.south_east : Icons.north_east,
              size: 12,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
