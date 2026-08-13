import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/order_controller.dart';
import '../../core/theme/app_spacing.dart';
import '../../providers/kds_backend_providers.dart';
import '../kitchen_display/kitchen_display_screen.dart';
import 'widgets/login_form_card.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AuthState>(authControllerProvider, (
      AuthState? previous,
      AuthState next,
    ) async {
      if (next.status == AuthStatus.authenticated &&
          previous?.status != AuthStatus.authenticated) {
        await ref.read(bootstrapControllerProvider.notifier).load();
        await ref.read(orderControllerProvider.notifier).refresh();
        if (!context.mounted) {
          return;
        }
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
                hasScrollBody: true,
                child: Center(
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AppSpacing.touchTargetMin * 10,
                      ),
                      child: LoginFormCard(
                        pinLength: authState.pin.length,
                        isLoading: authState.status == AuthStatus.loading,
                        errorMessage: authState.errorMessage,
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
            ),
          ],
        ),
      ),
    );
  }
}
