class AppConstants {
  AppConstants._();

  static const String appName = 'Dépôt Distribution';
  static const String appVersion = '1.0.0';

  static const String usersCollection = 'users';
  static const String productsCollection = 'products';
  static const String ordersCollection = 'orders';
  static const String deliveriesCollection = 'deliveries';
  static const String inventoryCollection = 'inventory';
  static const String movementsCollection = 'movements';
  static const String categoriesCollection = 'categories';

  static const String secureTokenKey = 'auth_token';
  static const String secureRoleKey = 'user_role';
  static const String rememberMeKey = 'remember_me';
  static const String savedEmailKey = 'saved_email';
  static const String cachedUserKey = 'cached_user';

  static const Duration authCheckDuration = Duration(seconds: 2);

  // License
  static const String licenseSecret = 'D3p0tD1str0!2026#S3cr3tK3y';
  static const String masterKeySentinel = 'MASTER_KEY';
  static const int trialDays = 30;
  static const String licenseFirstLaunchKey = 'license_first_launch';
  static const String licenseActivatedKey = 'license_activated';
  static const String licenseKeyStored = 'license_key';
  static const String deviceIdKey = 'device_id';

  // Backup
  static const String backupFileName = 'centredistro_backup.json';
}
