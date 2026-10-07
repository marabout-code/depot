/// Supabase project configuration.
///
/// Values are read from --dart-define so any other environment can override
/// them at build time:
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://PROJECT_REF.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=ANON_KEY
///
/// The defaults are this depot's public anon key. It is safe to ship in the
/// binary: Supabase's security boundary is row level security, not the anon
/// key hiding from the client.
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://slrmvchmzyvmawakxrhj.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNscm12Y2htenl2bWF3YWt4cmhqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTEyNDQ0MzQsImV4cCI6MjEwNjgyMDQzNH0.FAdubo0XKP9Rb_yJ49ajsm0Y3uau3V_DnK4yVwLbBNk',
  );

  /// True when the build has no usable project credentials: empty values or the
  /// old scaffold placeholders left over from before real ones were embedded.
  static bool get isPlaceholder =>
      url.isEmpty ||
      anonKey.isEmpty ||
      url.contains('your-project-ref') ||
      anonKey == 'your-anon-key';
}