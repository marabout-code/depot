enum UserRole {
  superadmin,
  admin,
  driver;

  String get value {
    switch (this) {
      case UserRole.superadmin:
        return 'superadmin';
      case UserRole.admin:
        return 'admin';
      case UserRole.driver:
        return 'driver';
    }
  }

  bool get isAdmin =>
      this == UserRole.superadmin || this == UserRole.admin;

  static UserRole fromString(String role) {
    switch (role) {
      case 'superadmin':
        return UserRole.superadmin;
      case 'admin':
        return UserRole.admin;
      case 'driver':
        return UserRole.driver;
      default:
        return UserRole.driver;
    }
  }
}
