enum UserRole {
  admin,
  driver;

  String get value {
    switch (this) {
      case UserRole.admin:
        return 'admin';
      case UserRole.driver:
        return 'driver';
    }
  }

  static UserRole fromString(String role) {
    switch (role) {
      case 'admin':
        return UserRole.admin;
      case 'driver':
        return UserRole.driver;
      default:
        return UserRole.driver;
    }
  }
}
