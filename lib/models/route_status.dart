enum RouteStatus {
  planned,
  inProgress,
  completed,
  cancelled;

  String get value {
    switch (this) {
      case RouteStatus.planned:
        return 'planned';
      case RouteStatus.inProgress:
        return 'in_progress';
      case RouteStatus.completed:
        return 'completed';
      case RouteStatus.cancelled:
        return 'cancelled';
    }
  }

  static RouteStatus fromString(String status) {
    switch (status) {
      case 'planned':
        return RouteStatus.planned;
      case 'in_progress':
        return RouteStatus.inProgress;
      case 'completed':
        return RouteStatus.completed;
      case 'cancelled':
        return RouteStatus.cancelled;
      default:
        return RouteStatus.planned;
    }
  }
}
