import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import 'login_header.dart';
import 'numeric_keypad.dart';
import 'pin_indicator.dart';

class LoginFormCard extends StatelessWidget {
  const LoginFormCard({
    super.key,
    required this.pinLength,
    required this.isLoading,
    required this.errorMessage,
    required this.onDigit,
    required this.onClear,
    required this.onBackspace,
    required this.onSubmit,
    required this.onTechnicalSupport,
  });

  final int pinLength;
  final bool isLoading;
  final String? errorMessage;
  final ValueChanged<String> onDigit;
  final VoidCallback onClear;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;
  final VoidCallback onTechnicalSupport;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          border: Border.all(color: AppColors.outlineVariant),
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LoginHeader(),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Enter PIN',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelCaps.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.pageMargin),
                  Center(child: PinIndicator(filledCount: pinLength)),
                  if (errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.unit),
                    Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelCaps.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.cardPadding),
                  NumericKeypad(
                    onDigit: onDigit,
                    onClear: onClear,
                    onBackspace: onBackspace,
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: AppSpacing.cardPadding),
                  SizedBox(
                    width: double.infinity,
                    height: AppSpacing.touchTargetMin,
                    child: ElevatedButton.icon(
                      onPressed: isLoading ? null : onSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryContainer,
                        disabledBackgroundColor: AppColors.primaryContainer,
                        foregroundColor: AppColors.onPrimaryContainer,
                        disabledForegroundColor: AppColors.onPrimaryContainer,
                      ),
                      icon: isLoading
                          ? const SizedBox.square(
                              dimension: AppSpacing.pageMargin,
                              child: CircularProgressIndicator(
                                color: AppColors.onPrimaryContainer,
                              ),
                            )
                          : const Icon(
                              Icons.login,
                              size: AppSpacing.pageMargin,
                            ),
                      label: Text(
                        isLoading ? 'Accessing...' : 'Login',
                        style: AppTextStyles.headlineMd,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                border: Border(
                  top: BorderSide(color: AppColors.outlineVariant),
                ),
              ),
              child: TextButton.icon(
                onPressed: onTechnicalSupport,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.onSurfaceVariant,
                  minimumSize: const Size.fromHeight(AppSpacing.touchTargetMin),
                ),
                icon: const Icon(Icons.help_outline, size: AppSpacing.gutter),
                label: Text(
                  'Technical Support',
                  style: AppTextStyles.labelCaps,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
