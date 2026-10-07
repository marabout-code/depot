import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/string_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/inventory_model.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/product_provider.dart';
import 'inventory_movement_screen.dart';
import 'inventory_history_screen.dart';

class InventoryListScreen extends ConsumerStatefulWidget {
  const InventoryListScreen({super.key});

  @override
  ConsumerState<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends ConsumerState<InventoryListScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(inventoryProvider.notifier).loadInventory();
      final products = ref.read(productProvider);
      if (products.products.isNotEmpty) {
        ref.read(inventoryProvider.notifier).syncFromProducts(products.products);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryProvider);
    final notifier = ref.read(inventoryProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(StringConstants.frInventoryList),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildBody(state, notifier)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Rechercher dans l\'inventaire...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
              : null,
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
    );
  }

  Widget _buildBody(InventoryState state, InventoryNotifier notifier) {
    switch (state.status) {
      case InventoryStatus.initial:
      case InventoryStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case InventoryStatus.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
              const SizedBox(height: 12),
              Text(state.error ?? StringConstants.frErrorGeneral),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => notifier.loadInventory(),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        );
      case InventoryStatus.loaded:
        var items = state.items;
        if (_searchQuery.isNotEmpty) {
          items = items
              .where((i) => i.productName
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()))
              .toList();
        }
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 64, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text('Aucun article dans l\'inventaire',
                    style: GoogleFonts.roboto(
                        fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => notifier.loadInventory(),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            itemBuilder: (_, i) => _buildItemCard(items[i], context),
          ),
        );
    }
  }

  Widget _buildItemCard(InventoryModel item, BuildContext context) {
    final available =
        item.availableQuantity > 0 ? item.availableQuantity : item.currentStock;
    Color stockColor;
    if (available <= 0) {
      stockColor = AppTheme.errorColor;
    } else if (available <= 5) {
      stockColor = AppTheme.secondaryColor;
    } else {
      stockColor = Colors.green;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showItemActions(context, item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.inventory_2,
                    color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.productName,
                        style: GoogleFonts.roboto(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    if (item.location != null)
                      Text(item.location!,
                          style: GoogleFonts.roboto(
                              fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$available',
                      style: GoogleFonts.roboto(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: stockColor)),
                  Text('en stock',
                      style: GoogleFonts.roboto(
                          fontSize: 11, color: Colors.grey[500])),
                  if (item.unitCost > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${item.stockValue.toStringAsFixed(0)} XAF',
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showItemActions(BuildContext context, InventoryModel item) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(item.productName,
                  style: GoogleFonts.roboto(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.add_circle_outline,
                    color: Colors.green),
                title: const Text('Enregistrer un mouvement'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          InventoryMovementScreen(item: item),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.history, color: Colors.blue),
                title: const Text('Voir l\'historique'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          InventoryHistoryScreen(item: item),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
