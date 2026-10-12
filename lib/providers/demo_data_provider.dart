import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/demo_data_service.dart';
import 'category_provider.dart';
import 'depot_provider.dart';
import 'driver_provider.dart';
import 'inventory_provider.dart';
import 'order_provider.dart';
import 'product_provider.dart';
import 'route_provider.dart';

/// Whether the sample dataset is currently installed, for the settings switch.
class DemoDataState {
  final bool enabled;
  final bool busy;
  final String? error;

  const DemoDataState({
    this.enabled = false,
    this.busy = false,
    this.error,
  });

  DemoDataState copyWith({bool? enabled, bool? busy, String? error}) {
    return DemoDataState(
      enabled: enabled ?? this.enabled,
      busy: busy ?? this.busy,
      error: error,
    );
  }
}

class DemoDataNotifier extends StateNotifier<DemoDataState> {
  DemoDataNotifier(this._service, this._ref) : super(const DemoDataState()) {
    _load();
  }

  static const String _prefsKey = 'demo_data_enabled';

  final DemoDataService _service;
  final Ref _ref;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_prefsKey) ?? false;

      // Reconcile the saved flag with the database so a restored backup or a
      // wiped store can never leave the switch reporting the wrong state.
      final seeded = await _service.isSeeded();
      if (enabled && !seeded) {
        await _service.seed();
      } else if (!enabled && seeded) {
        await _service.clear();
      }

      state = state.copyWith(enabled: enabled);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Installs or removes the sample dataset and persists the choice.
  Future<void> setEnabled(bool value) async {
    if (state.busy) return;
    state = state.copyWith(busy: true, error: null);
    try {
      if (value) {
        await _service.seed();
      } else {
        await _service.clear();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
      state = DemoDataState(enabled: value);
      _reloadScreens();
    } catch (e) {
      state = state.copyWith(busy: false, error: e.toString());
    }
  }

  /// Refreshes the tabs so the change is visible without a restart.
  void _reloadScreens() {
    _ref.read(productProvider.notifier).loadProducts();
    _ref.read(categoryProvider.notifier).loadCategories();
    _ref.read(inventoryProvider.notifier).loadInventory();
    _ref.read(orderProvider.notifier).loadOrders();
    _ref.read(routeProvider.notifier).loadRoutes();
    _ref.read(driverProvider.notifier).loadDrivers();
    _ref.read(depotProvider.notifier).loadDepots();
  }
}

final demoDataProvider =
    StateNotifierProvider<DemoDataNotifier, DemoDataState>((ref) {
  return DemoDataNotifier(ref.read(demoDataServiceProvider), ref);
});
