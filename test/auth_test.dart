import 'package:flutter_test/flutter_test.dart';
import 'package:depot_distribution_app/providers/auth_provider.dart';

void main() {
  group('AuthState', () {
    test('should have initial unknown status', () {
      const state = AuthState();
      expect(state.status, AuthStatus.unknown);
      expect(state.user, isNull);
      expect(state.error, isNull);
      expect(state.isLoading, false);
    });

    test('should copyWith correctly', () {
      const state = AuthState();

      final loading = state.copyWith(isLoading: true);
      expect(loading.isLoading, true);
      expect(loading.status, AuthStatus.unknown);

      final authenticated = state.copyWith(
        status: AuthStatus.authenticated,
      );
      expect(authenticated.status, AuthStatus.authenticated);

      final withError = state.copyWith(error: 'Test error');
      expect(withError.error, 'Test error');
    });
  });

  group('AuthStatus', () {
    test('should have all status values', () {
      expect(AuthStatus.values.length, 3);
      expect(AuthStatus.values, contains(AuthStatus.unknown));
      expect(AuthStatus.values, contains(AuthStatus.authenticated));
      expect(AuthStatus.values, contains(AuthStatus.unauthenticated));
    });
  });
}
