import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/local_first_auth_service.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? error;
  final bool isLoading;

  /// True when the user is signed in locally but no Supabase session exists,
  /// so the device is working from its local database only.
  final bool offline;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.error,
    this.isLoading = false,
    this.offline = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? error,
    bool? isLoading,
    bool? offline,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
      isLoading: isLoading ?? this.isLoading,
      offline: offline ?? this.offline,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._authService) : super(const AuthState());

  final LocalFirstAuthService _authService;

  static const String _invalidPinMessage = 'Code PIN incorrect.';

  static String _message(dynamic e) {
    if (e is AuthFailure) return e.message;
    return e.toString().replaceFirst('Exception: ', '');
  }

  /// Restores a previous session on cold start.
  ///
  /// A cached user with no Supabase session is still a valid signed-in state:
  /// the app reads from the local database, so being offline is normal rather
  /// than an error.
  Future<void> checkAuthStatus() async {
    try {
      final user = await _authService.restoreSession();
      if (user == null) {
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }

      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        offline: !_authService.hasOnlineSession,
      );
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// Verifies a PIN on-device. This is the primary login path and never
  /// requires a network round trip.
  ///
  /// When the device has nothing to compare against locally (fresh install,
  /// wiped storage, or a PIN that was rotated on another device) the PIN is
  /// sent to `login_with_pin` so the server can judge it. A local miss with
  /// known hashes, or a locked-out device, is final without going online.
  Future<void> loginWithPin(String pin) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _authService.authenticatePin(pin);
      if (user != null) {
        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
        );

        // Fire and forget: a session is only needed for syncing, and failing to
        // get one must not undo a successful local login.
        unawaited(_authService.tryEstablishSession(pin));
        return;
      }

      // A deliberate device lockout must not be bypassable through the online
      // exchange.
      if (await _authService.isDeviceLockedOut()) {
        state = state.copyWith(isLoading: false, error: _invalidPinMessage);
        return;
      }

      // No usable local hash: let the server verify the PIN and pull the depot
      // users down for offline logins from here on.
      final online = await _authService.tryOnlinePinLogin(pin);
      if (online != null) {
        state = AuthState(status: AuthStatus.authenticated, user: online);
        return;
      }

      state = state.copyWith(isLoading: false, error: _invalidPinMessage);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _message(e));
    }
  }

  /// Admin email + password fallback.
  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _authService.loginWithEmail(email, password);
      if (user == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Identifiants invalides ou aucune connexion.',
        );
        return;
      }
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _message(e));
    }
  }

  Future<void> register({
    required String email,
    required String name,
    required String pin,
    required UserRole role,
    String phone = '',
    String? depotId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _authService.registerWithPin(
        email: email,
        name: name,
        pin: pin,
        role: role,
        phone: phone,
        depotId: depotId,
      );
      if (user == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Échec de la création du compte.',
        );
        return;
      }
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _message(e));
    }
  }

  Future<void> setDriverPin(String userId, String pin) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _authService.setDriverPin(userId, pin);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _message(e));
    }
  }

  Future<void> logout() async {
    // Signs out the session and clears the cached profile, but keeps the
    // on-device PIN hashes so an offline keypad login still works after logout.
    // (Wiping every hash here would make offline login impossible, since the
    // keypad is only reachable once the cached user is gone.)
    await _authService.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authServiceProvider));
});