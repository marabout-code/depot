enum UserStatus {
  active,
  inactive;

  String get value {
    switch (this) {
      case UserStatus.active:
        return 'active';
      case UserStatus.inactive:
        return 'inactive';
    }
  }

  static UserStatus fromString(String status) {
    switch (status) {
      case 'active':
        return UserStatus.active;
      case 'inactive':
        return UserStatus.inactive;
      default:
        return UserStatus.active;
    }
  }
}
