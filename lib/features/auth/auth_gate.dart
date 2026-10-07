import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_role.dart';
import '../admin/dashboard/admin_dashboard_screen.dart';
import '../driver/home/driver_home_screen.dart';
import 'splash_screen.dart';
import 'pin_login_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return authState.status.when(
      unknown: () => const SplashScreen(),
      authenticated: () {
        final user = authState.user;
        if (user == null) return const PinLoginScreen();

        switch (user.role) {
          case UserRole.admin:
            return const AdminDashboardScreen();
          case UserRole.driver:
            return const DriverHomeScreen();
        }
      },
      unauthenticated: () => const PinLoginScreen(),
    );
  }
}

extension on AuthStatus {
  Widget when({
    required Widget Function() unknown,
    required Widget Function() authenticated,
    required Widget Function() unauthenticated,
  }) {
    switch (this) {
      case AuthStatus.unknown:
        return unknown();
      case AuthStatus.authenticated:
        return authenticated();
      case AuthStatus.unauthenticated:
        return unauthenticated();
    }
  }
}
