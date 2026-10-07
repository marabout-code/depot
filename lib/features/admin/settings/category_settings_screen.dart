import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/category_model.dart';
import '../../../providers/category_provider.dart';

class CategorySettingsScreen extends ConsumerStatefulWidget {
  const CategorySettingsScreen({super.key});

  @override
  ConsumerState<CategorySettingsScreen> createState() =>
      _CategorySettingsScreenState();
}

class _CategorySettingsScreenState
    extends ConsumerState<CategorySettingsScreen> {
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(categoryProvider.notifier).loadCategories());
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(categoryProvider);
    final notifier = ref.read(categoryProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catégories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context, notifier),
          ),
        ],
      ),
      body: _buildBody(state, notifier),
    );
  }

  Widget _buildBody(CategoriesState state, CategoryNotifier notifier) {
    switch (state.status) {
      case CategoriesStatus.initial:
      case CategoriesStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case CategoriesStatus.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: AppTheme.errorColor),
              const SizedBox(height: 12),
              Text(state.error ?? 'Erreur'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => notifier.loadCategories(),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        );
      case CategoriesStatus.loaded:
        if (state.categories.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.category_outlined,
                    size: 64, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  'Aucune catégorie',
                  style: GoogleFonts.roboto(
                      fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ajoutez une catégorie avec le bouton +',
                  style: GoogleFonts.roboto(
                      fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: state.categories.length,
          itemBuilder: (_, i) => _buildCategoryTile(
              state.categories[i], notifier),
        );
    }
  }

  Widget _buildCategoryTile(
      CategoryModel category, CategoryNotifier notifier) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.category, color: AppTheme.primaryColor),
        title: Text(category.name,
            style: GoogleFonts.roboto(fontWeight: FontWeight.w500)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () =>
                  _showEditDialog(context, notifier, category),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20,
                  color: AppTheme.errorColor),
              onPressed: () =>
                  _confirmDelete(context, notifier, category),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDialog(
      BuildContext context, CategoryNotifier notifier) {
    _nameController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvelle catégorie'),
        content: TextField(
          controller: _nameController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nom de la catégorie',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = _nameController.text.trim();
              if (name.isEmpty) return;
              notifier.addCategory(name);
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(
      BuildContext context, CategoryNotifier notifier, CategoryModel category) {
    _nameController.text = category.name;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier la catégorie'),
        content: TextField(
          controller: _nameController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nom de la catégorie',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = _nameController.text.trim();
              if (name.isEmpty) return;
              notifier.updateCategory(category.id, name);
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, CategoryNotifier notifier, CategoryModel category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text(
            'Supprimer la catégorie "${category.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              notifier.deleteCategory(category.id);
              Navigator.of(ctx).pop();
            },
            child: const Text('Supprimer',
                style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }
}
