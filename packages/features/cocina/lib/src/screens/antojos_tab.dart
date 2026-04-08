import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:domain/domain.dart';
import 'package:core/core.dart';
import '../providers/cocina_providers.dart';
import '../providers/cooking_session_provider.dart';
import 'suggestions_tab.dart';

/// "Antojos" tab - Shows Cravings (Desserts, Snacks) from LOCAL Spanish recipes
class AntojosTab extends ConsumerStatefulWidget {
  const AntojosTab({super.key});

  @override
  ConsumerState<AntojosTab> createState() => _AntojosTabState();
}

class _AntojosTabState extends ConsumerState<AntojosTab> {
  List<Recipe> _allCravings = [];
  List<Recipe> _cravings = [];
  bool _loading = false;
  MealType? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadCravings();
  }

  Future<void> _loadCravings() async {
    setState(() => _loading = true);
    try {
      final localDb = LocalRecipeDatabaseService();
      // Fetch desserts and snacks from local Spanish database
      final desserts = await localDb.searchByType(MealType.postre, limit: 25);
      final snacks = await localDb.searchByType(MealType.snack, limit: 15);
      final bebidas = await localDb.searchByType(MealType.bebida, limit: 15);

      // Combine and shuffle
      final all = [...desserts, ...snacks, ...bebidas]..shuffle();
      setState(() {
        _allCravings = all;
        _applyFilter();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    if (_selectedCategory == null) {
      _cravings = _allCravings.take(15).toList();
    } else {
      _cravings =
          _allCravings.where((r) => r.tipoComida == _selectedCategory).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF9800)));
    }

    if (_cravings.isEmpty && _allCravings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cookie, size: 64, color: Colors.white24),
            const SizedBox(height: 12),
            const Text(
              'No se encontraron antojos.',
              style: TextStyle(color: Colors.white38),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadCravings,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9800)),
            ),
          ],
        ),
      );
    }

    final categories = [
      null,
      MealType.postre,
      MealType.snack,
      MealType.bebida,
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('🍫 Antojos',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFFF9800)),
            onPressed: _loadCravings,
          ),
        ],
      ),
      body: Column(
        children: [
          // Category filter chips
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final type = categories[index];
                  final isSelected = _selectedCategory == type;
                  return FilterChip(
                    label: Text(
                        type == null ? 'Todos' : '${type.emoji} ${type.label}',
                        style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    onSelected: (v) {
                      setState(() {
                        _selectedCategory = v ? type : null;
                        _applyFilter();
                      });
                    },
                    backgroundColor: const Color(0xFF2A2A40),
                    selectedColor: const Color(0xFFFF9800).withAlpha(60),
                    checkmarkColor: const Color(0xFFFF9800),
                  );
                },
              ),
            ),
          ),
          // Recipe count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${_cravings.length} receta${_cravings.length != 1 ? 's' : ''}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
          // Grid
          Expanded(
            child: _cravings.isEmpty
                ? const Center(
                    child: Text('No hay antojos en esta categoría',
                        style: TextStyle(color: Colors.white38)),
                  )
                : Padding(
                    padding: const EdgeInsets.all(12),
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: _cravings.length,
                      itemBuilder: (ctx, i) {
                        final recipe = _cravings[i];
                        return _AntojoCard(
                          recipe: recipe,
                          onTap: () => _showRecipeDetail(context, recipe),
                          onSave: () => _saveRecipe(context, recipe),
                          onCook: () => _cookRecipe(context, recipe),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showRecipeDetail(BuildContext context, Recipe recipe) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => RecipeDetailSheet(recipe: recipe),
    );
  }

  void _saveRecipe(BuildContext context, Recipe recipe) {
    ref.read(recipesProvider.notifier).saveRecipe(recipe).then((_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Receta guardada'),
              backgroundColor: Color(0xFF00E676)),
        );
      }
    });
  }

  Future<void> _cookRecipe(BuildContext context, Recipe recipe) async {
    ref.read(cookingSessionProvider.notifier).startSession(
          recipeName: recipe.name,
          recipeId: recipe.id,
          originalServings: recipe.servings,
        );

    final inventoryNotifier = ref.read(inventoryProvider.notifier);
    final deducted =
        await inventoryNotifier.deductRecipeIngredients(recipe.ingredients);

    if (context.mounted) {
      if (deducted.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '⚠️ No tienes ingredientes coincidentes en tu despensa para ${recipe.name}.'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🍳 ¡Cocinando! Ingredientes descontados:'),
                const SizedBox(height: 4),
                Text(
                  deducted.join(', '),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFFF9800),
            duration: const Duration(seconds: 3),
          ),
        );
        inventoryNotifier.load();
      }
    }
  }
}

class _AntojoCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  final VoidCallback onSave;
  final VoidCallback onCook;

  const _AntojoCard({
    required this.recipe,
    required this.onTap,
    required this.onSave,
    required this.onCook,
  });

  @override
  Widget build(BuildContext context) {
    final mealType = recipe.tipoComida ?? MealType.postre;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2A1F0D), Color(0xFF1F1709)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(0xFFFF9800).withAlpha(60), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(mealType.emoji,
                          style: const TextStyle(fontSize: 24)),
                      const Spacer(),
                      Text('${recipe.durationMinutes} min',
                          style: const TextStyle(
                              color: Color(0xFF00E676), fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    recipe.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (recipe.ingredients.isNotEmpty)
                    Text(
                      recipe.ingredients
                              .take(2)
                              .map((e) => e.ingredientName)
                              .join(', ') +
                          (recipe.ingredients.length > 2 ? '...' : ''),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        minimumSize: const Size(0, 28),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child:
                          const Text('Guardar', style: TextStyle(fontSize: 10)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onCook,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9800),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        minimumSize: const Size(0, 28),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child:
                          const Text('Cocinar', style: TextStyle(fontSize: 10)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
