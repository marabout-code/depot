enum DeliveryStatus {
  assigned,
  pickedUp,
  inTransit,
  delivered,
  failed,
  cancelled;

  String get value {
    switch (this) {
      case DeliveryStatus.assigned:
        return 'assigned';
      case DeliveryStatus.pickedUp:
        return 'picked_up';
      case DeliveryStatus.inTransit:
        return 'in_transit';
      case DeliveryStatus.delivered:
        return 'delivered';
      case DeliveryStatus.failed:
        return 'failed';
      case DeliveryStatus.cancelled:
        return 'cancelled';
    }
  }

  static DeliveryStatus fromString(String status) {
    switch (status) {
      case 'assigned':
        return DeliveryStatus.assigned;
      case 'picked_up':
        return DeliveryStatus.pickedUp;
      case 'in_transit':
        return DeliveryStatus.inTransit;
      case 'delivered':
        return DeliveryStatus.delivered;
      case 'failed':
        return DeliveryStatus.failed;
      case 'cancelled':
        return DeliveryStatus.cancelled;
      default:
        return DeliveryStatus.assigned;
    }
  }
}
