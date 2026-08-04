import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthStatus { idle, loading, error, authenticated }

class AuthState {
  const AuthState({
    this.status = AuthStatus.idle,
    this.selectedStaff,
    this.pin = '',
    this.errorMessage,
  });

  final AuthStatus status;
  final String? selectedStaff;
  final String pin;
  final String? errorMessage;
}

class AuthController extends Notifier<AuthState> {
  static const int _requiredPinLength = 4;

  @override
  AuthState build() => const AuthState();

  void selectStaff(String? staff) {
    if (state.status == AuthStatus.loading) {
      return;
    }

    state = AuthState(selectedStaff: staff, pin: state.pin);
  }

  void appendDigit(String digit) {
    if (state.status == AuthStatus.loading ||
        state.pin.length >= _requiredPinLength) {
      return;
    }

    state = AuthState(
      selectedStaff: state.selectedStaff,
      pin: '${state.pin}$digit',
    );
  }

  void clearPin() {
    if (state.status == AuthStatus.loading) {
      return;
    }

    state = AuthState(selectedStaff: state.selectedStaff);
  }

  void backspace() {
    if (state.status == AuthStatus.loading || state.pin.isEmpty) {
      return;
    }

    state = AuthState(
      selectedStaff: state.selectedStaff,
      pin: state.pin.substring(0, state.pin.length - 1),
    );
  }

  Future<void> submit() async {
    if (state.status == AuthStatus.loading) {
      return;
    }

    if (state.selectedStaff == null) {
      state = AuthState(
        status: AuthStatus.error,
        pin: state.pin,
        errorMessage: 'Please select a staff member.',
      );
      return;
    }

    if (state.pin.length != _requiredPinLength) {
      state = AuthState(
        status: AuthStatus.error,
        selectedStaff: state.selectedStaff,
        pin: state.pin,
        errorMessage: 'Please enter your full 4-digit PIN.',
      );
      return;
    }

    state = AuthState(
      status: AuthStatus.loading,
      selectedStaff: state.selectedStaff,
      pin: state.pin,
    );

    await Future<void>.delayed(const Duration(milliseconds: 800));

    state = AuthState(
      status: AuthStatus.authenticated,
      selectedStaff: state.selectedStaff,
      pin: state.pin,
    );
  }
}

final NotifierProvider<AuthController, AuthState> authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
