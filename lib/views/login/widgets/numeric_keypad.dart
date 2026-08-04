import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

class NumericKeypad extends StatelessWidget {
  const NumericKeypad({
    super.key,
    required this.onDigit,
    required this.onClear,
    required this.onBackspace,
    this.enabled = true,
  });

  static const List<List<String>> _digits = <List<String>>[
    <String>['1', '2', '3'],
    <String>['4', '5', '6'],
    <String>['7', '8', '9'],
  ];

  final ValueChanged<String> onDigit;
  final VoidCallback onClear;
  final VoidCallback onBackspace;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final List<String> row in _digits) ...[
          _KeypadRow(labels: row, onPressed: enabled ? onDigit : null),
          const SizedBox(height: AppSpacing.unit),
        ],
        _KeypadRow(
          labels: const <String>['CLEAR', '0', 'BACKSPACE'],
          onPressed: enabled
              ? (String value) {
                  switch (value) {
                    case 'CLEAR':
                      onClear();
                      return;
                    case 'BACKSPACE':
                      onBackspace();
                      return;
                    default:
                      onDigit(value);
                  }
                }
              : null,
        ),
      ],
    );
  }
}

class _KeypadRow extends StatelessWidget {
  const _KeypadRow({required this.labels, required this.onPressed});

  final List<String> labels;
  final ValueChanged<String>? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.keypadButtonHeight,
      child: Row(
        children: [
          for (int index = 0; index < labels.length; index++) ...[
            Expanded(
              child: _KeypadButton(
                label: labels[index],
                onPressed: onPressed == null
                    ? null
                    : () => onPressed!(labels[index]),
              ),
            ),
            if (index < labels.length - 1)
              const SizedBox(width: AppSpacing.unit),
          ],
        ],
      ),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool isClear = label == 'CLEAR';
    final bool isBackspace = label == 'BACKSPACE';

    return SizedBox.expand(
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.surfaceContainerHighest,
          disabledBackgroundColor: AppColors.surfaceContainerHigh,
          foregroundColor: isClear ? AppColors.error : AppColors.onSurface,
          disabledForegroundColor: AppColors.onSurfaceVariant,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.defaultRadius),
          ),
        ),
        child: isBackspace
            ? const Icon(Icons.backspace_outlined, size: AppSpacing.pageMargin)
            : Text(
                label,
                style: isClear
                    ? AppTextStyles.labelCaps
                    : AppTextStyles.headlineMd,
              ),
      ),
    );
  }
}
