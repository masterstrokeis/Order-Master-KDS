import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:order_master_kds/controllers/auth_controller.dart';

void main() {
  test('reports an error when staff is not selected', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(authControllerProvider.notifier).submit();

    final AuthState state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.error);
    expect(state.errorMessage, 'Please select a staff member.');
  });

  test('enters loading then authenticates for a valid stub login', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final AuthController controller = container.read(
      authControllerProvider.notifier,
    );

    controller.selectStaff('Chef Maria');
    for (final String digit in <String>['1', '2', '3', '4']) {
      controller.appendDigit(digit);
    }

    final Future<void> submission = controller.submit();
    expect(container.read(authControllerProvider).status, AuthStatus.loading);

    await submission;
    expect(
      container.read(authControllerProvider).status,
      AuthStatus.authenticated,
    );
  });
}
