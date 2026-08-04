import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/auth_controller.dart';
import '../../core/theme/app_spacing.dart';
import '../kitchen_display/kitchen_display_screen.dart';
import 'widgets/login_form_card.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AuthState>(authControllerProvider, (
      AuthState? previous,
      AuthState next,
    ) {
      if (next.status == AuthStatus.authenticated &&
          previous?.status != AuthStatus.authenticated) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => const KitchenDisplayScreen(),
          ),
        );
      }
    });

    final AuthState authState = ref.watch(authControllerProvider);
    final AuthController authController = ref.read(
      authControllerProvider.notifier,
    );

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              sliver: SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppSpacing.touchTargetMin * 10,
                    ),
                    child: LoginFormCard(
                      selectedStaff: authState.selectedStaff,
                      pinLength: authState.pin.length,
                      isLoading: authState.status == AuthStatus.loading,
                      errorMessage: authState.errorMessage,
                      onStaffChanged: authController.selectStaff,
                      onDigit: authController.appendDigit,
                      onClear: authController.clearPin,
                      onBackspace: authController.backspace,
                      onSubmit: authController.submit,
                      onTechnicalSupport: () {},
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
