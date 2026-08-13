import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_session.dart';
import '../models/kds_api_error.dart';
import '../services/auth_service.dart';
import '../services/device_identity_service.dart';
import '../services/session_store.dart';
import '../views/login/widgets/pin_indicator.dart';

enum AuthStatus { idle, loading, error, authenticated }

class AuthState {
  const AuthState({
    this.status = AuthStatus.idle,
    this.pin = '',
    this.errorMessage,
    this.session,
    this.deviceId,
  });

  final AuthStatus status;
  final String pin;
  final String? errorMessage;
  final AuthSession? session;
  final String? deviceId;

  /// Display name from the authenticated staff session.
  String? get selectedStaffName => session?.staff.name;
}

class AuthController extends Notifier<AuthState> {
  static const int requiredPinLength = PinIndicator.pinLength;
  static const String sessionExpiredMessage =
      'Session expired, please sign in again.';

  AuthService get _authService => ref.read(authServiceProvider);
  DeviceIdentityService get _deviceIdentity =>
      ref.read(deviceIdentityServiceProvider);

  Future<String?>? _inFlightRefresh;

  @override
  AuthState build() => const AuthState();

  void appendDigit(String digit) {
    if (state.status == AuthStatus.loading ||
        state.pin.length >= requiredPinLength) {
      return;
    }

    state = AuthState(
      pin: '${state.pin}$digit',
      deviceId: state.deviceId,
      session: state.session,
    );
  }

  void clearPin() {
    if (state.status == AuthStatus.loading) {
      return;
    }

    state = AuthState(
      deviceId: state.deviceId,
      session: state.session,
    );
  }

  void backspace() {
    if (state.status == AuthStatus.loading || state.pin.isEmpty) {
      return;
    }

    state = AuthState(
      pin: state.pin.substring(0, state.pin.length - 1),
      deviceId: state.deviceId,
      session: state.session,
    );
  }

  Future<void> submit() async {
    if (state.status == AuthStatus.loading) {
      return;
    }

    if (state.pin.length != requiredPinLength) {
      state = AuthState(
        status: AuthStatus.error,
        pin: state.pin,
        deviceId: state.deviceId,
        errorMessage: 'Please enter your full $requiredPinLength-digit PIN.',
      );
      return;
    }

    state = AuthState(
      status: AuthStatus.loading,
      pin: state.pin,
      deviceId: state.deviceId,
    );

    try {
      final String deviceId = await _deviceIdentity.getOrCreateDeviceId();
      final AuthSession session = await _authService.login(
        pin: state.pin,
        deviceId: deviceId,
      );

      state = AuthState(
        status: AuthStatus.authenticated,
        pin: state.pin,
        deviceId: deviceId,
        session: session,
      );
    } on KdsApiError catch (error) {
      state = AuthState(
        status: AuthStatus.error,
        pin: state.pin,
        deviceId: state.deviceId,
        errorMessage: _messageFor(error),
      );
    } catch (error, stackTrace) {
      // TEMP DIAGNOSTIC — remove after macOS login issue is resolved
      // ignore: avoid_print
      print('LOGIN ERROR (raw): $error');
      print('LOGIN ERROR (stack): $stackTrace');
      state = AuthState(
        status: AuthStatus.error,
        pin: state.pin,
        deviceId: state.deviceId,
        errorMessage: 'Unable to sign in. Check connection and try again.',
      );
    }
  }

  /// Silent access-token refresh for authenticated 401 recovery.
  /// Concurrent callers share one in-flight refresh.
  Future<String?> refreshSession() {
    final Future<String?>? inFlight = _inFlightRefresh;
    if (inFlight != null) {
      return inFlight;
    }

    final Future<String?> future = _refreshSessionBody();
    _inFlightRefresh = future;
    future.whenComplete(() {
      if (identical(_inFlightRefresh, future)) {
        _inFlightRefresh = null;
      }
    });
    return future;
  }

  Future<String?> _refreshSessionBody() async {
    final AuthSession? session = state.session;
    final String? deviceId = state.deviceId;
    if (session == null || deviceId == null || deviceId.isEmpty) {
      await _markSessionExpired();
      return null;
    }

    try {
      final AuthSession refreshed = await _authService.refresh(
        refreshToken: session.refreshToken,
        deviceId: deviceId,
      );
      state = AuthState(
        status: AuthStatus.authenticated,
        pin: state.pin,
        deviceId: deviceId,
        session: refreshed,
      );
      return refreshed.accessToken;
    } catch (_) {
      await _markSessionExpired();
      return null;
    }
  }

  Future<void> _markSessionExpired() async {
    try {
      await _authService.logout();
    } catch (_) {
      // Best-effort clear of persisted tokens.
    }
    state = const AuthState(
      status: AuthStatus.error,
      errorMessage: sessionExpiredMessage,
    );
  }

  Future<void> logout() async {
    await _authService.logout();
    state = const AuthState();
  }

  String _messageFor(KdsApiError error) {
    return switch (error.code) {
      'INVALID_PIN' => 'Incorrect PIN. Please try again.',
      'STAFF_NOT_ALLOWED' => 'This staff member cannot use KDS.',
      'DEVICE_NOT_ALLOWED' =>
        'This device is blocked. Contact a manager.',
      'UNAUTHORIZED' => sessionExpiredMessage,
      _ => error.message,
    };
  }
}

final Provider<SessionStore> sessionStoreProvider = Provider<SessionStore>(
  (Ref ref) => SessionStore(),
);

final Provider<DeviceIdentityService> deviceIdentityServiceProvider =
    Provider<DeviceIdentityService>((Ref ref) => DeviceIdentityService());

final Provider<AuthService> authServiceProvider = Provider<AuthService>((
  Ref ref,
) {
  return AuthService(sessionStore: ref.watch(sessionStoreProvider));
});

final NotifierProvider<AuthController, AuthState> authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
