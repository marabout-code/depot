import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'core/database/app_database.dart';
import 'core/services/license_service.dart';
import 'core/services/local_first_auth_service.dart';
import 'core/services/sync_service.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'features/auth/auth_gate.dart';
import 'features/admin/settings/license_dialog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Supabase is a sync peer, not a read path, so a missing or unreachable
  // project must not stop the app from starting: the local database is enough
  // to run the depot offline.
  if (!SupabaseConfig.isPlaceholder) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      // `publishableKey` is the current name for the anon key; it is the same
      // value and does not change what is committed.
      publishableKey: SupabaseConfig.anonKey,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: true,
        persistSession: true,
      ),
    );
  }

  runApp(
    const ProviderScope(
      child: DepotDistributionApp(),
    ),
  );
}

class DepotDistributionApp extends ConsumerStatefulWidget {
  const DepotDistributionApp({super.key});

  @override
  ConsumerState<DepotDistributionApp> createState() =>
      _DepotDistributionAppState();
}

class _DepotDistributionAppState extends ConsumerState<DepotDistributionApp> {
  bool _initialized = false;
  bool _syncFailed = false;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    await ref.read(secureStorageServiceProvider).init();
    await ref.read(licenseServiceProvider).init();

    // Opening the local database and attempting a first sync. A sync failure is
    // expected on a device that has never been online and is not fatal.
try {
        // Touch the lazy database handle so an unreadable file surfaces here
        // rather than inside a provider deep in the tree.
        await ref.read(appDatabaseProvider).customSelect('select 1').get();
        await ref.read(syncServiceProvider).init();
    } catch (_) {
      _syncFailed = true;
    }

    // Resolve any session cached from a previous run. Without this the gate
    // would sit on the splash screen forever.
    try {
      await ref.read(authProvider.notifier).checkAuthStatus();
    } catch (_) {
      // A failed restore simply leaves the user on the PIN screen.
    }

    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  void _checkTrialExpired() {
    final license = ref.read(licenseServiceProvider);
    if (license.status == LicenseStatus.trialExpired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const LicenseDialog(trialExpired: true),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    if (_initialized && !_syncFailed) {
      _checkTrialExpired();
    }
    return MaterialApp(
      title: 'Dépôt Distribution',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: _syncFailed
          ? const _DatabaseErrorScreen()
          : _initialized
              ? const AuthGate()
              : const _InitScreen(),
    );
  }
}

/// Shown only when the local database itself cannot be opened, which means the
/// app has no data source at all. A failing *sync* never lands here.
class _DatabaseErrorScreen extends StatelessWidget {
  const _DatabaseErrorScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.storage, size: 64, color: Colors.white),
              const SizedBox(height: 24),
              Text(
                'Base de données inaccessible',
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Le stockage local n\'a pas pu être ouvert. '
                'Redémarrez l\'application.',
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(fontSize: 14, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InitScreen extends StatelessWidget {
  const _InitScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_drink,
              size: 80,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            Text(
              'Dépôt Distribution',
              style: GoogleFonts.roboto(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}