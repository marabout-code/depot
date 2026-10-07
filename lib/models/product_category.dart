enum ProductCategory {
  beer,
  softDrink,
  water,
  energyDrink;

  String get value {
    switch (this) {
      case ProductCategory.beer:
        return 'Beer';
      case ProductCategory.softDrink:
        return 'Soft Drink';
      case ProductCategory.water:
        return 'Water';
      case ProductCategory.energyDrink:
        return 'Energy Drink';
    }
  }

  static ProductCategory fromString(String category) {
    switch (category) {
      case 'Beer':
        return ProductCategory.beer;
      case 'Soft Drink':
        return ProductCategory.softDrink;
      case 'Water':
        return ProductCategory.water;
      case 'Energy Drink':
        return ProductCategory.energyDrink;
      default:
        return ProductCategory.beer;
    }
  }
}
